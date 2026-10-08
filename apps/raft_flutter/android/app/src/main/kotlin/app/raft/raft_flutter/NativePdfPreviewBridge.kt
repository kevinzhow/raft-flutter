package app.raft.raft_flutter

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.max
import kotlin.math.roundToInt

/** Uploaded PDFs are local raster input, never a WebView/script origin. */
class NativePdfPreviewBridge(private val activity: Activity, engine: FlutterEngine) {
    init {
        MethodChannel(engine.dartExecutor.binaryMessenger, "app.raft/pdf-preview")
            .setMethodCallHandler { call, result ->
                if (call.method != "page") { result.notImplemented(); return@setMethodCallHandler }
                val path = call.argument<String>("path")
                val pageIndex = call.argument<Int>("page") ?: 0
                val dimension = (call.argument<Int>("maxDimension") ?: 1600).coerceIn(100, 1600)
                val root: String
                val file: File?
                try {
                    root = File(activity.cacheDir, "raft-previews").canonicalPath + File.separator
                    file = path?.let { File(it).canonicalFile }
                } catch (_: Exception) {
                    result.error("invalid", "The PDF input is unavailable.", null)
                    return@setMethodCallHandler
                }
                if (file == null || !file.path.startsWith(root) || !file.isFile || file.length() > 50L * 1024 * 1024) {
                    result.error("invalid", "The PDF input is unavailable.", null)
                    return@setMethodCallHandler
                }
                Thread {
                    try {
                        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                        PdfRenderer(descriptor).use { renderer ->
                            require(pageIndex >= 0 && pageIndex < renderer.pageCount)
                            renderer.openPage(pageIndex).use { page ->
                                val scale = dimension.toFloat() / max(page.width, page.height)
                                val bitmap = Bitmap.createBitmap(max(1, (page.width * scale).roundToInt()), max(1, (page.height * scale).roundToInt()), Bitmap.Config.ARGB_8888)
                                try {
                                    bitmap.eraseColor(Color.WHITE)
                                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                    val output = ByteArrayOutputStream()
                                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                                    val bytes = output.toByteArray()
                                    val pageCount = renderer.pageCount
                                    activity.runOnUiThread { result.success(mapOf("bytes" to bytes, "pageCount" to pageCount)) }
                                } finally { bitmap.recycle() }
                            }
                        }
                        }
                    } catch (_: Exception) {
                        activity.runOnUiThread { result.error("pdf_failed", "The PDF could not be opened.", null) }
                    }
                }.start()
            }
    }
}
