# smbj: optional Kerberos (GSS-API) and EL event filters aren't on Android and aren't used.
-dontwarn org.ietf.jgss.**
-dontwarn javax.el.**
-dontwarn org.slf4j.**

# smbj dispatches SMB events through mbassador (annotation/reflection based).
-keep class com.hierynomus.** { *; }
-keep class net.engio.mbassy.** { *; }
# BouncyCastle provides MD4/AES-CMAC for NTLM and SMB3 signing.
-keep class org.bouncycastle.** { *; }

# FFmpegKit's native library calls back into these classes by name.
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.arthenica.smartexception.** { *; }

# BouncyCastle LDAP cert store (unused on Android).
-dontwarn javax.naming.**
