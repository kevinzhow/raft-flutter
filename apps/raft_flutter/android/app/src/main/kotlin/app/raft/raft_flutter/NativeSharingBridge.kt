package app.raft.raft_flutter

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Outgoing exports and provider metadata; incoming intents use the pub plugin. Provider I/O runs off the UI thread. */
class NativeSharingBridge(private val activity: Activity, engine: FlutterEngine, private val onReady: () -> Unit) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "app.raft/sharing")
    private val request = 45072
    private var pending: MethodChannel.Result? = null
    private val io = Executors.newSingleThreadExecutor()
    private var disposed = false
    init {
        channel.setMethodCallHandler { call, result ->
            when(call.method) {
                "incomingDirectory" -> result.success(File(activity.noBackupFilesDir, "raft-incoming").path)
                "sharingReady" -> { onReady(); result.success(null) }
                "copyIncoming" -> {
                    val raw = call.argument<String>("uri") ?: ""
                    val path = call.argument<String>("path") ?: ""
                    val limit = call.argument<Number>("limit")?.toLong() ?: 0L
                    val progressId = call.argument<Number>("id")?.toInt()
                    val uri = Uri.parse(raw)
                    if (uri.scheme != "content" || uri.authority.isNullOrEmpty() || limit <= 0 || limit > 25L * 1024 * 1024) {
                        result.error("invalid", "Invalid shared file.", null)
                    } else io.execute {
                        var destination: File? = null
                        // Failure kinds the share page tells apart: too_large, permission, unreadable.
                        var code = "copy_failed"
                        try {
                            val root = File(activity.noBackupFilesDir, "raft-incoming").canonicalFile
                            val file = File(path).canonicalFile
                            require(file.parentFile?.parentFile == root &&
                                file.parentFile?.name?.matches(Regex("[a-f0-9]{32}")) == true &&
                                file.name.matches(Regex("item-[0-8]")) && !file.exists())
                            destination = file
                            var count = 0L
                            var reported = 0L
                            var reportedAt = 0L
                            // Byte progress for the share page: at most ~10 updates per second.
                            fun report(force: Boolean) {
                                val now = android.os.SystemClock.uptimeMillis()
                                if (progressId == null || count == reported || (!force && now - reportedAt < 100)) return
                                reported = count
                                reportedAt = now
                                val bytes = count
                                activity.runOnUiThread {
                                    if (!disposed) channel.invokeMethod("copyProgress", mapOf("id" to progressId, "bytes" to bytes))
                                }
                            }
                            val input = try { activity.contentResolver.openInputStream(uri) }
                                catch (e: SecurityException) { code = "permission"; throw e }
                                catch (e: java.io.FileNotFoundException) { code = "unreadable"; throw e }
                            (input ?: run { code = "unreadable"; error("Shared file unavailable") }).use { stream ->
                                file.outputStream().use { output ->
                                    val buffer = ByteArray(64 * 1024)
                                    while (true) {
                                        check(!Thread.currentThread().isInterrupted)
                                        val read = try { stream.read(buffer) }
                                            catch (e: SecurityException) { code = "permission"; throw e }
                                            catch (e: java.io.IOException) { code = "unreadable"; throw e }
                                        if (read < 0) break
                                        count += read
                                        if (count > limit) { code = "too_large"; throw IllegalArgumentException("limit") }
                                        output.write(buffer, 0, read)
                                        report(false)
                                    }
                                    output.fd.sync()
                                }
                            }
                            if (count <= 0) { code = "empty"; throw IllegalStateException("empty") }
                            report(true)
                            activity.runOnUiThread { if (!disposed) result.success(count) }
                        } catch (_: Exception) {
                            destination?.delete()
                            activity.runOnUiThread { if (!disposed) result.error(code, "The shared file could not be copied.", null) }
                        }
                    }
                }
                "sharedFileInfo" -> {
                    val uris = call.argument<List<String>>("uris") ?: emptyList()
                    if (uris.size > 10 || uris.any { Uri.parse(it).scheme != "content" || Uri.parse(it).authority.isNullOrEmpty() }) {
                        result.error("invalid", "Invalid shared files.", null)
                    } else io.execute {
                        val files = uris.map { raw ->
                            val uri = Uri.parse(raw)
                            var name = "attachment"
                            var size: Long? = null
                            try {
                                activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { cursor ->
                                    if (cursor.moveToFirst()) {
                                        val ni = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                                        val si = cursor.getColumnIndex(OpenableColumns.SIZE)
                                        if (ni >= 0) name = cursor.getString(ni)?.takeIf { it.isNotBlank() } ?: name
                                        if (si >= 0 && !cursor.isNull(si)) size = cursor.getLong(si)
                                    }
                                }
                            } catch (_: Exception) { /* A readable grant may have no metadata. */ }
                            val mime = try { activity.contentResolver.getType(uri) } catch (_: Exception) { null }
                            val mimeType = mime ?: "application/octet-stream"
                            if (!name.contains('.')) {
                                MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)?.let { name += ".$it" }
                            }
                            mapOf("uri" to raw, "filename" to name, "sizeBytes" to size, "mimeType" to mimeType)
                        }
                        activity.runOnUiThread { if (!disposed) result.success(files) }
                    }
                }
                "share" -> {
                    if (pending != null) { result.error("busy", "A share sheet is already open.", null) }
                    else try {
                        val path = call.argument<String>("path")
                        val text = call.argument<String>("text")
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = call.argument<String>("mimeType") ?: "application/octet-stream"
                            if (path != null) {
                                val file = File(path).canonicalFile
                                require(file.isFile && file.path.startsWith(File(activity.cacheDir,"raft-share").canonicalPath + File.separator))
                                val uri = FileProvider.getUriForFile(activity, activity.packageName + ".shared-files", file)
                                putExtra(Intent.EXTRA_STREAM,uri)
                                clipData = ClipData.newRawUri("Raft attachment",uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            } else { require(!text.isNullOrEmpty()); putExtra(Intent.EXTRA_TEXT,text) }
                        }
                        pending = result
                        activity.startActivityForResult(Intent.createChooser(intent,call.argument<String>("title")),request)
                    } catch (_:Exception) {pending = null; result.error("share_unavailable","The system share sheet could not be opened.",null)}
                }
                else -> result.notImplemented()
            }
        }
        io.execute { cleanExpired() }
    }
    fun dispose() {
        disposed = true
        io.shutdownNow()
        channel.setMethodCallHandler(null)
    }
    fun onActivityResult(code:Int):Boolean {
        if(code != request) return false
        // Chooser dismissal is not evidence that any recipient transmitted it.
        pending?.success(null);pending=null;return true
    }
    private fun cleanExpired() {
        val cutoff=System.currentTimeMillis()-15*60*1000
        File(activity.cacheDir,"raft-share").listFiles()?.forEach { dir ->
            if(dir.isDirectory && dir.lastModified()<cutoff) dir.deleteRecursively()
        }
    }
}
