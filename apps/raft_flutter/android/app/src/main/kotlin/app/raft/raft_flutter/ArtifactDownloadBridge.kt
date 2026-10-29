package app.raft.raft_flutter

import android.webkit.CookieManager
import android.webkit.URLUtil
import android.webkit.WebView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi
import java.lang.ref.WeakReference
import java.net.URI
import java.util.Locale

/** Downloads from an explicitly attached Artifact WebView, without a page JS bridge. */
class ArtifactDownloadBridge(private val engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "app.raft/artifact-downloads")
    private val bindings = mutableMapOf<Long, Binding>()
    private var closed = false

    private data class Origin(val scheme: String, val host: String, val port: Int) {
        companion object {
            fun parse(value: String?): Origin? = try {
                val uri = value?.let(::URI)
                val scheme = uri?.scheme?.lowercase(Locale.ROOT)
                val host = uri?.host?.lowercase(Locale.ROOT)
                if (uri == null || scheme !in listOf("http", "https") ||
                    host.isNullOrEmpty() || uri.rawUserInfo != null ||
                    uri.port !in -1..65535 || uri.port == 0) null
                else Origin(scheme!!, host, if (uri.port == -1) {
                    if (scheme == "https") 443 else 80
                } else uri.port)
            } catch (_: Exception) { null }
        }
    }

    private class Binding(
        val id: Long,
        val nonce: String,
        val origin: Origin,
        view: WebView,
    ) {
        val view = WeakReference(view)
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "attach" -> attach(call, result)
                "detach" -> {
                    val id = call.argument<Number>("webViewId")?.toLong()
                    val nonce = call.argument<String>("bindingId")
                    val binding = bindings[id]
                    if (binding != null && binding.nonce == nonce) {
                        bindings.remove(id)
                        binding.view.get()?.setDownloadListener(null)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION") // Public external API; FlutterActivity owns an engine, not a plugin binding.
    private fun attach(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Number>("webViewId")?.toLong()
        val nonce = call.argument<String>("bindingId")
        val origin = Origin.parse(call.argument<String>("origin"))
        if (closed || id == null || id < 0 || nonce.isNullOrBlank() || nonce.length > 128 || origin == null) {
            result.error("invalid", "The artifact download binding is invalid.", null)
            return
        }
        val existing = bindings[id]
        if (existing != null) {
            if (existing.nonce == nonce && existing.origin == origin) result.success(null)
            else result.error("busy", "The artifact WebView is already attached.", null)
            return
        }
        val view = WebViewFlutterAndroidExternalApi.getWebView(engine, id)
        if (view == null) {
            result.error("unavailable", "The artifact WebView is unavailable.", null)
            return
        }
        val binding = Binding(id, nonce, origin, view)
        bindings[id] = binding
        view.setDownloadListener { url, userAgent, disposition, mimeType, _ ->
            if (closed || bindings[id] !== binding) return@setDownloadListener
            val event = mutableMapOf<String, Any?>(
                "webViewId" to id,
                "bindingId" to nonce,
                "url" to url,
            )
            // A callback is not permission to read cookies. Both the displayed
            // document and the download must still belong to the bound origin.
            if (Origin.parse(binding.view.get()?.url) != origin || Origin.parse(url) != origin) {
                event["error"] = "unsupported_origin"
            } else {
                try {
                    event["filename"] = URLUtil.guessFileName(url, disposition, mimeType)
                    event["mimeType"] = mimeType
                    event["userAgent"] = userAgent
                    // Only this same-origin request receives the Artifact cookie.
                    // Dart keeps it in memory and disables automatic redirects.
                    event["cookie"] = CookieManager.getInstance().getCookie(url)
                } catch (_: Exception) {
                    event["error"] = "unavailable"
                }
            }
            channel.invokeMethod("download", event)
        }
        result.success(null)
    }

    fun dispose() {
        if (closed) return
        closed = true
        bindings.values.forEach { it.view.get()?.setDownloadListener(null) }
        bindings.clear()
        channel.setMethodCallHandler(null)
    }
}
