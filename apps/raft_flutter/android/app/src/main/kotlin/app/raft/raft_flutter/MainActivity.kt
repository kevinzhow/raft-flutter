package app.raft.raft_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.Intent
import android.net.Uri
import java.io.File

class MainActivity : FlutterActivity() {
    private var sharing: NativeSharingBridge? = null
    private var saveResult: MethodChannel.Result? = null
    private val saveRequest = 45071

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sharing = NativeSharingBridge(this, flutterEngine)
        NativePdfPreviewBridge(this, flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.raft/attachment-files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "chooseSave" -> {
                        if (saveResult != null) {
                            result.error("busy", "A document picker is already open.", null)
                        } else {
                            saveResult = result
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = call.argument<String>("mimeType") ?: "application/octet-stream"
                                putExtra(Intent.EXTRA_TITLE, call.argument<String>("filename") ?: "attachment")
                            }
                            try { startActivityForResult(intent, saveRequest) }
                            catch (_: Exception) {
                                saveResult = null
                                result.error("unavailable", "No document picker is available.", null)
                            }
                        }
                    }
                    "writeSaved" -> {
                        val uri = call.argument<String>("uri")
                        val path = call.argument<String>("path")
                        if (uri == null || path == null ||
                            !File(path).canonicalPath.startsWith(cacheDir.canonicalPath + File.separator)) {
                            result.error("invalid", "Invalid temporary attachment file.", null)
                        } else {
                            Thread {
                                try {
                                    contentResolver.openOutputStream(Uri.parse(uri), "wt").use { output ->
                                        requireNotNull(output)
                                        File(path).inputStream().use { input -> input.copyTo(output) }
                                    }
                                    runOnUiThread { result.success(null) }
                                } catch (_: Exception) {
                                    runOnUiThread { result.error("save_failed", "The attachment could not be saved.", null) }
                                }
                            }.start()
                        }
                    }
                    "openSaved" -> {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(Uri.parse(call.argument<String>("uri")),
                                    call.argument<String>("mimeType") ?: "application/octet-stream")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("no_viewer", "No application can open this file.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        sharing?.receive(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (sharing?.onActivityResult(requestCode) == true) return
        if (requestCode == saveRequest) {
            val pending = saveResult
            saveResult = null
            pending?.success(if (resultCode == Activity.RESULT_OK) data?.data?.toString() else null)
        } else { super.onActivityResult(requestCode, resultCode, data) }
    }
}
