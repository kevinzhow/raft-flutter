package app.raft.raft_flutter

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Only content URIs explicitly granted by a sending app are imported. */
class NativeSharingBridge(private val activity: Activity, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "app.raft/sharing")
    private val request = 45072
    private var pending: MethodChannel.Result? = null
    private var incoming: Map<String, Any?>? = null
    init {
        channel.setMethodCallHandler { call, result ->
            when(call.method) {
                "takeIncoming" -> { result.success(incoming); incoming = null }
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
                "readIncoming" -> {
                    val raw = call.argument<String>("uri")
                    if (raw == null || Uri.parse(raw).scheme != "content") result.error("invalid","Invalid shared file.",null)
                    else Thread {
                        try {
                            val bytes = activity.contentResolver.openInputStream(Uri.parse(raw)).use { input ->
                                requireNotNull(input)
                                val output = java.io.ByteArrayOutputStream()
                                val buffer = ByteArray(64 * 1024)
                                var total = 0
                                while (true) {
                                    val count = input.read(buffer)
                                    if (count < 0) break
                                    total += count
                                    require(total <= 50 * 1024 * 1024)
                                    output.write(buffer,0,count)
                                }
                                output.toByteArray()
                            }
                            activity.runOnUiThread { result.success(bytes) }
                        } catch (_:Exception) {activity.runOnUiThread {result.error("read_failed","The shared file could not be read (maximum 50 MB).",null)}}
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
        receive(activity.intent, false)
        cleanExpired()
    }
    fun receive(intent: Intent?, live: Boolean = true) {
        if (intent == null || intent.action !in listOf(Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE)) return
        val uris = if (intent.action == Intent.ACTION_SEND_MULTIPLE)
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: arrayListOf()
            else listOfNotNull(intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
        if (uris.size > 10 || uris.any { it.scheme != "content" }) return
        val files = uris.mapNotNull { uri ->
            try {
                var name = "attachment"; var size:Long? = null
                activity.contentResolver.query(uri,arrayOf(OpenableColumns.DISPLAY_NAME,OpenableColumns.SIZE),null,null,null)?.use { cursor ->
                    if(cursor.moveToFirst()) {
                        val ni=cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        val si=cursor.getColumnIndex(OpenableColumns.SIZE)
                        if(ni>=0) name=cursor.getString(ni) ?: name
                        if(si>=0 && !cursor.isNull(si)) size=cursor.getLong(si)
                    }
                }
                mapOf("uri" to uri.toString(),"filename" to name,"sizeBytes" to size,
                    "mimeType" to (activity.contentResolver.getType(uri) ?: "application/octet-stream"))
            } catch (_:Exception) {null}
        }
        val text=intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        if(text != null && text.length > 65536) return
        if(files.isEmpty() && text.isNullOrEmpty()) return
        val value=mapOf("files" to files,"text" to text)
        if(live) channel.invokeMethod("incomingShare",value) else incoming=value
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
