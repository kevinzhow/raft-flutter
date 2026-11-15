package app.raft.raft_flutter

import android.app.Activity
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import android.view.ViewTreeObserver
import android.webkit.MimeTypeMap
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Copied files for the message composer, on the iOS channel's contract
 * (`app.raft/clipboard-attachments`). A copied file is a content URI that Dart
 * cannot open, so `read` resolves each one here: display name, MIME type and
 * bytes. Availability comes from the clip description only: reading the clip
 * itself shows Android's "pasted from your clipboard" notice.
 */
class NativeClipboardAttachmentsBridge(private val activity: Activity, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "app.raft/clipboard-attachments")
    private val clipboard = activity.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    private val io = Executors.newSingleThreadExecutor()
    private var disposed = false
    private var last: Boolean? = null
    private val clipChanged = ClipboardManager.OnPrimaryClipChangedListener { changed() }
    // Another app's copy is seen only when Raft has focus again (Android 10+).
    private val focusChanged = ViewTreeObserver.OnWindowFocusChangeListener { focused -> if (focused) changed() }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(available().also { last = it })
                "read" -> read(result)
                else -> result.notImplemented()
            }
        }
        clipboard.addPrimaryClipChangedListener(clipChanged)
        activity.window.decorView.viewTreeObserver.addOnWindowFocusChangeListener(focusChanged)
    }

    /** A copied file or image: any type that is not text (a URI list may name a content URI). */
    private fun available(): Boolean {
        val description = try { clipboard.primaryClipDescription } catch (_: Exception) { null } ?: return false
        return (0 until description.mimeTypeCount).any {
            val type = description.getMimeType(it)
            !type.startsWith("text/") || type == ClipDescription.MIMETYPE_TEXT_URILIST
        }
    }

    private fun changed() {
        if (disposed) return
        val value = available()
        if (value == last) return
        last = value
        channel.invokeMethod("changed", value)
    }

    private fun read(result: MethodChannel.Result) {
        // A text-only clipboard is not read here; the editor pastes it.
        val uris = if (!available()) emptyList() else try {
            clipboard.primaryClip?.let { clip -> (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).uri } }
        } catch (_: Exception) { null }.orEmpty().filter { it.scheme == ContentResolver.SCHEME_CONTENT }.distinct()
        if (uris.isEmpty()) return result.success(emptyList<Any>())
        io.execute {
            val files = uris.mapNotNull(::entry)
            activity.runOnUiThread { if (!disposed) result.success(files) }
        }
    }

    /** One copied file, or null when the provider refuses it or it is empty. */
    private fun entry(uri: Uri): Map<String, Any>? = try {
        val resolver = activity.contentResolver
        val mime = resolver.getType(uri)
        var display: String? = null
        try {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (cursor.moveToFirst() && column >= 0) display = cursor.getString(column)
            }
        } catch (_: Exception) { /* A readable grant may have no metadata. */ }
        // No size limit here: the upload selection applies the server's limit
        // and tells the user, as for picked files.
        val bytes = resolver.openInputStream(uri)?.use { it.readBytes() }
        if (bytes == null || bytes.isEmpty()) null
        else mapOf("name" to name(uri, display, mime), "bytes" to bytes)
    } catch (_: Exception) {
        null
    } catch (_: OutOfMemoryError) {
        null
    }

    private fun name(uri: Uri, display: String?, mime: String?): String {
        val own = uri.authority == activity.packageName + ".shared-files"
        var base = display?.substringAfterLast('/')?.trim().orEmpty()
        // Raft's own copied image (a staged random name) and a nameless bitmap
        // are `image.png`, as on Web and desktop.
        if (base.isEmpty() || base == "." || (own && ClipboardImageFiles.owns(base))) {
            base = if (mime?.startsWith("image/") == true) "image" else "attachment"
        }
        if (base.contains('.')) return base
        val extension = mime?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) } ?: return base
        return "$base.$extension"
    }

    fun dispose() {
        disposed = true
        clipboard.removePrimaryClipChangedListener(clipChanged)
        activity.window.decorView.viewTreeObserver.let { if (it.isAlive) it.removeOnWindowFocusChangeListener(focusChanged) }
        channel.setMethodCallHandler(null)
        io.shutdown()
    }
}
