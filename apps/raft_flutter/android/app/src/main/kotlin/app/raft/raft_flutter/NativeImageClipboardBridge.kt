package app.raft.raft_flutter

import android.app.Activity
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Publish only a fully prepared PNG. Never clear/restore a clipboard on failure. */
class NativeImageClipboardBridge(private val activity: Activity, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "app.raft/image-clipboard")
    private val files = ClipboardImageFiles(activity.cacheDir)
    private val io = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var disposed = false

    init {
        channel.setMethodCallHandler { call, result ->
            when {
                call.method != "copyPng" -> result.notImplemented()
                pending != null -> result.error("busy", "An image is already being copied.", null)
                call.arguments !is ByteArray -> result.error("invalid_png", "Invalid PNG image.", null)
                else -> {
                    pending = result
                    val bytes = call.arguments as ByteArray
                    io.execute {
                        var staged: File? = null
                        try {
                            require(validPng(bytes))
                            val file = files.stage(bytes)
                            staged = file
                            val uri = FileProvider.getUriForFile(activity, activity.packageName + ".shared-files", file)
                            // URI grants are issued by ClipboardManager when another app
                            // reads this clip. No broad grant or storage permission needed.
                            val clip = ClipData(ClipDescription("Raft message image", arrayOf("image/png")), ClipData.Item(uri))
                            activity.runOnUiThread {
                                if (disposed) { file.delete(); return@runOnUiThread }
                                try {
                                    check(activity.hasWindowFocus())
                                    val clipboard = activity.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                                    clipboard.setPrimaryClip(clip)
                                } catch (_: Exception) {
                                    file.delete()
                                    pending?.error("clipboard_unavailable", "The clipboard did not accept the PNG.", null)
                                    pending = null
                                    return@runOnUiThread
                                }
                                // No fallible preparation after this commit point.
                                pending?.success(true)
                                pending = null
                                io.execute { files.sweep(keep = file, replaced = true, remove = ::retire) }
                            }
                        } catch (_: Exception) {
                            staged?.delete()
                            activity.runOnUiThread {
                                if (!disposed) pending?.error("invalid_png", "The PNG could not be prepared.", null)
                                pending = null
                            }
                        }
                    }
                }
            }
        }
        // Recovery after a killed process; a live URI is also checked by the
        // provider, so expiry remains enforced when no Activity is running.
        io.execute { files.sweep(remove = ::retire) }
    }

    private fun retire(file: File) {
        runCatching {
            val uri = FileProvider.getUriForFile(activity, activity.packageName + ".shared-files", file)
            activity.revokeUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            file.delete()
        }
    }

    private fun validPng(bytes: ByteArray): Boolean {
        if (bytes.size < 33 || bytes.size > ClipboardImageFiles.maxBytes ||
            !bytes.take(8).toByteArray().contentEquals(byteArrayOf(137.toByte(), 80, 78, 71, 13, 10, 26, 10))) return false
        val size = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, size)
        if (size.outMimeType != "image/png" || size.outWidth <= 0 || size.outHeight <= 0 ||
            size.outWidth.toLong() * size.outHeight > 16000000) return false
        // Validate decoding without allocating another full 16M-pixel bitmap
        // beside Flutter's already rendered preview on a memory-limited phone.
        var sample = 1
        while (((size.outWidth.toLong() + sample - 1) / sample) *
            ((size.outHeight.toLong() + sample - 1) / sample) > 1000000) sample *= 2
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        val bitmap = try { BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options) }
            catch (_: OutOfMemoryError) { null } ?: return false
        bitmap.recycle()
        return true
    }

    fun dispose() {
        disposed = true
        pending?.error("cancelled", "The image copy was cancelled.", null)
        pending = null
        channel.setMethodCallHandler(null)
        // Successfully published files belong to the clipboard lease, not the
        // Activity. A recipient can read through FileProvider after destruction.
        io.shutdown()
    }
}
