package com.squishy.nas

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** One SMB share the user added. The password never leaves the phone. */
data class NasServer(
    val id: String,
    val name: String,
    val host: String,
    val port: Int,
    val share: String,
    val username: String,
    val password: String,
    val domain: String,
) {
    /** What Flutter sees: everything except the password. */
    fun toPublicMap(): Map<String, Any?> = mapOf(
        "id" to id, "name" to name, "host" to host, "port" to port,
        "share" to share, "username" to username, "domain" to domain,
        "hasPassword" to password.isNotEmpty(),
    )

    val label get() = "\\\\$host\\$share"

    companion object {
        fun fromMap(m: Map<*, *>, existing: NasServer?): NasServer {
            val hostField = (m["host"] as String).trim().removePrefix("smb://").removePrefix("\\\\").trimEnd('/', '\\')
            val (host, port) = hostField.split(':').let {
                it[0] to (it.getOrNull(1)?.toIntOrNull() ?: (m["port"] as? Number)?.toInt() ?: 445)
            }
            val newPassword = m["password"] as? String
            return NasServer(
                id = existing?.id ?: (m["id"] as? String)?.takeIf { it.isNotEmpty() } ?: UUID.randomUUID().toString(),
                name = (m["name"] as? String)?.trim().orEmpty().ifEmpty { host },
                host = host,
                port = port,
                share = (m["share"] as String).trim().trim('/', '\\'),
                username = (m["username"] as? String)?.trim().orEmpty(),
                // Blank password on edit = keep the stored one.
                password = if (newPassword.isNullOrEmpty() && existing != null) existing.password else newPassword.orEmpty(),
                domain = (m["domain"] as? String)?.trim().orEmpty(),
            )
        }
    }
}

object NasStore {
    private const val PREFS = "squishy_nas"
    private const val KEY_ALIAS = "squishy_nas_secret"

    fun all(context: Context): List<NasServer> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("servers", "[]")!!
        val arr = JSONArray(raw)
        return (0 until arr.length()).map { i ->
            val o = arr.getJSONObject(i)
            NasServer(
                id = o.getString("id"),
                name = o.getString("name"),
                host = o.getString("host"),
                port = o.optInt("port", 445),
                share = o.getString("share"),
                username = o.optString("username"),
                password = o.optString("password").takeIf { it.isNotEmpty() }?.let(::decrypt).orEmpty(),
                domain = o.optString("domain"),
            )
        }
    }

    fun get(context: Context, id: String): NasServer? = all(context).firstOrNull { it.id == id }

    fun save(context: Context, server: NasServer) {
        val list = all(context).filterNot { it.id == server.id } + server
        write(context, list)
    }

    fun delete(context: Context, id: String) = write(context, all(context).filterNot { it.id == id })

    private fun write(context: Context, list: List<NasServer>) {
        val arr = JSONArray()
        list.forEach { s ->
            arr.put(JSONObject().apply {
                put("id", s.id); put("name", s.name); put("host", s.host); put("port", s.port)
                put("share", s.share); put("username", s.username); put("domain", s.domain)
                put("password", if (s.password.isEmpty()) "" else encrypt(s.password))
            })
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("servers", arr.toString()).apply()
    }

    // Passwords are AES-GCM encrypted with a key that lives in the Android Keystore.
    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(
                KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .build()
            )
        }.generateKey()
    }

    private fun encrypt(plain: String): String {
        val c = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        return Base64.encodeToString(c.iv + c.doFinal(plain.toByteArray()), Base64.NO_WRAP)
    }

    private fun decrypt(stored: String): String = runCatching {
        val bytes = Base64.decode(stored, Base64.NO_WRAP)
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes, 0, 12))
        String(c.doFinal(bytes, 12, bytes.size - 12))
    }.getOrDefault("")
}
