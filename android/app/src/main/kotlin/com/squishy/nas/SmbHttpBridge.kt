package com.squishy.nas

import java.io.BufferedInputStream
import java.io.IOException
import java.io.InputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.URLEncoder
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * A tiny HTTP server on 127.0.0.1 that serves NAS files with Range support, so
 * Media3 and FFmpeg can read (and seek in) a 30 GB movie without copying it first.
 * Only URLs handed out by [url] are served; nothing else is reachable.
 */
object SmbHttpBridge {
    private const val CHUNK = 1024 * 1024
    private var server: ServerSocket? = null
    private val pool = Executors.newCachedThreadPool()
    private val routes = ConcurrentHashMap<String, Pair<NasServer, String>>()

    @Synchronized
    private fun ensureStarted(): ServerSocket {
        server?.takeIf { !it.isClosed }?.let { return it }
        val socket = ServerSocket(0, 16, InetAddress.getByName("127.0.0.1"))
        server = socket
        Thread({
            while (!socket.isClosed) {
                val client = try { socket.accept() } catch (_: IOException) { break }
                pool.execute { serve(client) }
            }
        }, "squishy-smb-bridge").apply { isDaemon = true }.start()
        return socket
    }

    /** A local URL for [path] on [nas]. The file name is kept so tools can see the extension. */
    fun url(nas: NasServer, path: String): String {
        val token = UUID.randomUUID().toString()
        routes[token] = nas to path
        val name = URLEncoder.encode(path.substringAfterLast('/'), "UTF-8").replace("+", "%20")
        return "http://127.0.0.1:${ensureStarted().localPort}/$token/$name"
    }

    fun release(url: String) {
        routes.remove(url.substringAfter("127.0.0.1:").substringAfter('/').substringBefore('/'))
    }

    private fun readLine(input: InputStream): String? {
        val sb = StringBuilder()
        while (true) {
            val b = input.read()
            if (b == -1) return if (sb.isEmpty()) null else sb.toString()
            if (b == '\n'.code) return sb.toString().trimEnd('\r')
            sb.append(b.toChar())
        }
    }

    private fun serve(socket: Socket) {
        socket.use { s ->
            try {
                val input = BufferedInputStream(s.getInputStream())
                val request = readLine(input) ?: return
                val headers = mutableMapOf<String, String>()
                while (true) {
                    val line = readLine(input) ?: break
                    if (line.isEmpty()) break
                    val i = line.indexOf(':')
                    if (i > 0) headers[line.substring(0, i).trim().lowercase()] = line.substring(i + 1).trim()
                }
                val (method, target) = request.split(' ').let { it[0] to it.getOrElse(1) { "/" } }
                val out = s.getOutputStream()
                val route = routes[target.trimStart('/').substringBefore('/')]
                if (route == null || (method != "GET" && method != "HEAD")) {
                    out.write("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".toByteArray())
                    return
                }
                val (nas, path) = route
                Smb.openRead(nas, path).use { file ->
                    val size = file.fileInformation.standardInformation.endOfFile
                    var start = 0L
                    var end = size - 1
                    val range = headers["range"]
                    val partial = range != null && range.startsWith("bytes=")
                    if (partial) {
                        val (a, b) = range!!.removePrefix("bytes=").substringBefore(',').split('-').let {
                            it[0] to it.getOrElse(1) { "" }
                        }
                        if (a.isEmpty()) {
                            start = maxOf(0, size - b.toLong())
                        } else {
                            start = a.toLong()
                            if (b.isNotEmpty()) end = minOf(b.toLong(), size - 1)
                        }
                    }
                    if (start >= size && size > 0) {
                        out.write("HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */$size\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".toByteArray())
                        return
                    }
                    val length = end - start + 1
                    val head = buildString {
                        append(if (partial) "HTTP/1.1 206 Partial Content\r\n" else "HTTP/1.1 200 OK\r\n")
                        append("Content-Type: application/octet-stream\r\n")
                        append("Accept-Ranges: bytes\r\n")
                        append("Content-Length: $length\r\n")
                        if (partial) append("Content-Range: bytes $start-$end/$size\r\n")
                        append("Connection: close\r\n\r\n")
                    }
                    out.write(head.toByteArray())
                    if (method == "HEAD") return
                    val buf = ByteArray(CHUNK)
                    var pos = start
                    while (pos <= end) {
                        val want = minOf(CHUNK.toLong(), end - pos + 1).toInt()
                        val n = file.read(buf, pos, 0, want)
                        if (n <= 0) break
                        out.write(buf, 0, n)
                        pos += n
                    }
                    out.flush()
                }
            } catch (_: IOException) {
                // Reader went away (seek or cancel): normal.
            } catch (_: Exception) {
            }
        }
    }
}
