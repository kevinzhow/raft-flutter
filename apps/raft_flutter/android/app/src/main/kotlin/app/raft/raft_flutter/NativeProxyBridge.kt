package app.raft.raft_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.ProxySelector
import java.net.URI

/**
 * Reports the device's HTTP proxy (Settings > Wi-Fi > Proxy, a managed global
 * proxy, a PAC file) to Dart. The framework keeps the JVM's http(s).proxyHost
 * system properties and the default ProxySelector in step with it; a PAC file
 * is served to the app through a local proxy it installs, so both reads stay
 * valid. PROXY_CHANGE tells Dart to read again.
 */
class NativeProxyBridge(private val context: Context, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "app.raft/system-proxy")
    private val main = Handler(Looper.getMainLooper())
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            channel.invokeMethod("changed", null)
        }
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "snapshot" -> result.success(snapshot())
                "resolve" -> {
                    val url = call.argument<String>("url")
                    if (url == null) {
                        result.error("invalid", "Missing URL.", null)
                    } else {
                        // ProxySelector may run a PAC script: keep it off the UI thread.
                        Thread {
                            val answer = try { resolve(url) } catch (_: Exception) { emptyList() }
                            main.post { result.success(answer) }
                        }.start()
                    }
                }
                else -> result.notImplemented()
            }
        }
        ContextCompat.registerReceiver(
            context,
            receiver,
            IntentFilter("android.intent.action.PROXY_CHANGE"),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    private fun hostPort(scheme: String): String? {
        val host = System.getProperty("$scheme.proxyHost")?.trim().orEmpty()
        if (host.isEmpty()) return null
        val port = System.getProperty("$scheme.proxyPort")?.trim()?.toIntOrNull() ?: 80
        return "$host:$port"
    }

    private fun snapshot(): Map<String, Any?> {
        val socksHost = System.getProperty("socksProxyHost")?.trim().orEmpty()
        val socksPort = System.getProperty("socksProxyPort")?.trim()?.toIntOrNull() ?: 1080
        val exclusions = (System.getProperty("http.nonProxyHosts") ?: System.getProperty("https.nonProxyHosts"))
            ?.split('|', ',')
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            ?: emptyList()
        return mapOf(
            "http" to hostPort("http"),
            "https" to hostPort("https"),
            "socks" to if (socksHost.isEmpty()) null else "$socksHost:$socksPort",
            "bypass" to exclusions,
        )
    }

    private fun resolve(url: String): List<String> {
        val proxies = ProxySelector.getDefault()?.select(URI(url)) ?: return emptyList()
        return proxies.mapNotNull { proxy ->
            val address = proxy.address() as? InetSocketAddress
            val host = address?.hostString
            when (proxy.type()) {
                Proxy.Type.DIRECT -> "DIRECT"
                Proxy.Type.HTTP -> if (host == null) null else "PROXY $host:${address.port}"
                Proxy.Type.SOCKS -> if (host == null) null else "SOCKS $host:${address.port}"
                else -> null
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        try { context.unregisterReceiver(receiver) } catch (_: IllegalArgumentException) {}
    }
}
