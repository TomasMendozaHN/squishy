package com.squishy.nas

import com.hierynomus.msdtyp.AccessMask
import com.hierynomus.mserref.NtStatus
import com.hierynomus.mssmb2.SMBApiException
import com.hierynomus.msfscc.FileAttributes
import com.hierynomus.mssmb2.SMB2CreateDisposition
import com.hierynomus.mssmb2.SMB2ShareAccess
import com.hierynomus.protocol.commons.EnumWithValue
import com.hierynomus.security.bc.BCSecurityProvider
import com.hierynomus.smbj.SMBClient
import com.hierynomus.smbj.SmbConfig
import com.hierynomus.smbj.auth.AuthenticationContext
import com.hierynomus.smbj.session.Session
import com.hierynomus.smbj.share.DiskShare
import com.hierynomus.smbj.share.File
import java.util.EnumSet
import java.util.concurrent.TimeUnit

/** A directory entry on the share. [path] is relative to the share root, '/'-separated. */
data class SmbEntry(val path: String, val name: String, val isDir: Boolean, val size: Long, val modified: Long)

/**
 * Cached SMB connections, one per server. smbj multiplexes requests over one
 * session, so the HTTP bridge, scanner and uploader can share it.
 */
object Smb {
    private val config: SmbConfig = SmbConfig.builder()
        .withSecurityProvider(BCSecurityProvider())
        .withTimeout(60, TimeUnit.SECONDS)
        .withSoTimeout(180, TimeUnit.SECONDS)
        .withBufferSize(4 * 1024 * 1024)
        .build()
    private val client = SMBClient(config)
    private val sessions = mutableMapOf<String, Pair<Session, DiskShare>>()

    /** Folders that belong to NAS software, never to the media library. */
    private val ignoredDirs = setOf("@eadir", "#recycle", "#snapshot", ".squishy", "\$recycle.bin", "system volume information")

    @Synchronized
    fun share(server: NasServer): DiskShare {
        sessions[server.id]?.let { (session, share) ->
            if (session.connection.isConnected && share.isConnected) return share
            runCatching { session.close() }
        }
        val connection = client.connect(server.host, server.port)
        val auth = if (server.username.isEmpty()) {
            AuthenticationContext.guest()
        } else {
            AuthenticationContext(server.username, server.password.toCharArray(), server.domain.ifEmpty { null })
        }
        val session = connection.authenticate(auth)
        val share = session.connectShare(server.share) as? DiskShare
            ?: throw IllegalStateException("\"${server.share}\" is not a folder share")
        sessions[server.id] = session to share
        return share
    }

    @Synchronized
    fun forget(serverId: String) {
        sessions.remove(serverId)?.let { (session, _) -> runCatching { session.close() } }
    }

    fun smbPath(path: String) = path.trim('/').replace('/', '\\')

    /**
     * Runs [block]; if the connection turned out to be dead (timeout, reset, NAS
     * asleep), drops the cached session and tries once more on a fresh one.
     * SMB errors with a status (not found, access denied…) are real answers and pass through.
     */
    private inline fun <T> fresh(server: NasServer, block: () -> T): T = try {
        block()
    } catch (e: SMBApiException) {
        throw e
    } catch (e: Exception) {
        forget(server.id)
        block()
    }

    fun list(server: NasServer, path: String): List<SmbEntry> =
        fresh(server) { share(server).list(smbPath(path)) }.mapNotNull { info ->
            val name = info.fileName
            if (name == "." || name == "..") return@mapNotNull null
            val isDir = EnumWithValue.EnumUtils.isSet(info.fileAttributes, FileAttributes.FILE_ATTRIBUTE_DIRECTORY)
            val hidden = name.startsWith('.') || (isDir && name.lowercase() in ignoredDirs)
            if (hidden) return@mapNotNull null
            SmbEntry(
                path = if (path.isEmpty()) name else "${path.trim('/')}/$name",
                name = name,
                isDir = isDir,
                size = info.endOfFile,
                modified = info.changeTime.toEpochMillis(),
            )
        }

    /** Every file below [path] (depth-first), skipping NAS system folders. */
    fun walk(server: NasServer, path: String, onFile: (SmbEntry) -> Unit) {
        for (entry in list(server, path)) {
            if (entry.isDir) walk(server, entry.path, onFile) else onFile(entry)
        }
    }

    fun openRead(server: NasServer, path: String): File = fresh(server) {
        share(server).openFile(
            smbPath(path),
            EnumSet.of(AccessMask.GENERIC_READ),
            null,
            SMB2ShareAccess.ALL,
            SMB2CreateDisposition.FILE_OPEN,
            null,
        )
    }

    fun openWrite(server: NasServer, path: String): File = fresh(server) {
        share(server).openFile(
            smbPath(path),
            EnumSet.of(AccessMask.GENERIC_WRITE, AccessMask.GENERIC_READ),
            null,
            SMB2ShareAccess.ALL,
            SMB2CreateDisposition.FILE_OVERWRITE_IF,
            null,
        )
    }

    fun size(server: NasServer, path: String): Long =
        openRead(server, path).use { it.fileInformation.standardInformation.endOfFile }

    /** Servers disagree on which status means "missing"; treat them all as not found. */
    private val NOT_FOUND = setOf(
        NtStatus.STATUS_NO_SUCH_FILE,
        NtStatus.STATUS_OBJECT_NAME_NOT_FOUND,
        NtStatus.STATUS_OBJECT_PATH_NOT_FOUND,
        NtStatus.STATUS_NOT_FOUND,
    )

    private inline fun <T> orIfMissing(fallback: T, block: () -> T): T = try {
        block()
    } catch (e: SMBApiException) {
        if (e.status in NOT_FOUND) fallback else throw e
    }

    fun exists(server: NasServer, path: String): Boolean =
        orIfMissing(false) { fresh(server) { share(server).fileExists(smbPath(path)) } }

    private fun folderExists(share: DiskShare, path: String): Boolean =
        orIfMissing(false) { share.folderExists(path) }

    fun delete(server: NasServer, path: String) = fresh(server) { share(server).rm(smbPath(path)) }

    fun mkdirs(server: NasServer, path: String) = fresh(server) {
        val share = share(server)
        var acc = ""
        for (part in path.trim('/').split('/').filter { it.isNotEmpty() }) {
            acc = if (acc.isEmpty()) part else "$acc\\$part"
            if (!folderExists(share, acc)) share.mkdir(acc)
        }
    }

    fun rename(server: NasServer, from: String, to: String) = fresh(server) {
        share(server).openFile(
            smbPath(from),
            EnumSet.of(AccessMask.DELETE, AccessMask.GENERIC_READ),
            null,
            SMB2ShareAccess.ALL,
            SMB2CreateDisposition.FILE_OPEN,
            null,
        ).use { it.rename(smbPath(to), false) }
    }

    fun readText(server: NasServer, path: String): String? = orIfMissing(null) {
        // Explicit offset reads in modest chunks: some servers mis-answer smbj's
        // read-to-end helper ("Unable to deserialize SMB2 Packet Data").
        openRead(server, path).use { f ->
            val size = f.fileInformation.standardInformation.endOfFile.toInt()
            val bytes = ByteArray(size)
            var offset = 0
            while (offset < size) {
                val n = f.read(bytes, offset.toLong(), offset, minOf(64 * 1024, size - offset))
                if (n <= 0) break
                offset += n
            }
            String(bytes, 0, offset, Charsets.UTF_8)
        }
    }

    fun writeText(server: NasServer, path: String, text: String) {
        val bytes = text.toByteArray(Charsets.UTF_8)
        openWrite(server, path).use { it.write(bytes, 0L, 0, bytes.size) }
    }
}
