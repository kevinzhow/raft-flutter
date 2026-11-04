package app.raft.raft_flutter

import java.io.File
import java.io.FileOutputStream
import java.util.UUID

/** A clipboard export outlives the preview and Activity, but not its 24h lease. */
internal class ClipboardImageFiles(cache: File) {
    val directory = File(cache, "raft-clipboard")
    companion object {
        const val lifetime = 24L * 60 * 60 * 1000
        const val maxBytes = 32 * 1024 * 1024
        private val filename = Regex("[a-f0-9-]{36}\\.png")
        fun owns(name: String) = filename.matches(name)
        fun expired(file: File, now: Long = System.currentTimeMillis()) =
            file.lastModified() <= 0 || now - file.lastModified() >= lifetime
    }

    fun stage(bytes: ByteArray): File {
        require(bytes.isNotEmpty() && bytes.size <= maxBytes)
        check(directory.isDirectory || directory.mkdirs())
        // A killed copy can leave a staged file. Bound retained bytes without
        // guessing which unexpired URI the system clipboard still references.
        val retained = directory.listFiles()?.filter { it.isFile && owns(it.name) }?.sumOf { it.length() } ?: 0L
        check(retained + bytes.size <= 2L * maxBytes)
        val file = File(directory, "${UUID.randomUUID()}.png")
        try {
            check(file.createNewFile())
            FileOutputStream(file).use { output -> output.write(bytes); output.fd.sync() }
            return file
        } catch (failure: Exception) {
            file.delete()
            throw failure
        }
    }

    /** Only a successful replacement retires the preceding clipboard image. */
    fun sweep(keep: File? = null, replaced: Boolean = false, remove: (File) -> Unit) {
        directory.listFiles()?.filter {
            it.isFile && owns(it.name) && it != keep && (replaced || expired(it))
        }?.forEach(remove)
    }
}
