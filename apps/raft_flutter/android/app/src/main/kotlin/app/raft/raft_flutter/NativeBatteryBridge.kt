package app.raft.raft_flutter

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Battery optimisation status for the notification settings notice. Android
/// stops background network use of an optimised app, and Raft has no push
/// service, so a background notification relies on the app being exempt.
/// Reading the status needs no permission. [openSettings] shows the system
/// list where the person chooses "Don't optimize" for Raft. It deliberately
/// does not use ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS: that action needs
/// a manifest permission which Google Play restricts to a narrow set of apps.
class NativeBatteryBridge(private val context: Context, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "app.raft/battery-optimization")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "exempt" -> {
                    val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
                    result.success(power?.isIgnoringBatteryOptimizations(context.packageName))
                }
                "openSettings" -> result.success(openSettings())
                else -> result.notImplemented()
            }
        }
    }

    private fun openSettings(): Boolean {
        val attempts = listOf(
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")),
        )
        for (intent in attempts) {
            try {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (_: Exception) {
            }
        }
        return false
    }
}
