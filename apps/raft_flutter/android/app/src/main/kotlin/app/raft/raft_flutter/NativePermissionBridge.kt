package app.raft.raft_flutter

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Runtime-permission facts Dart cannot read through the plugins it already
/// uses. A denied request tells nothing about whether the system will ever
/// show the dialog again; [shouldShowRequestPermissionRationale] does, once the
/// permission has been asked for before (false after "don't ask again"). Only
/// the two permissions the app itself requests are answered.
class NativePermissionBridge(private val activity: Activity, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "app.raft/permissions")
    private val known = setOf("android.permission.POST_NOTIFICATIONS", "android.permission.ACCESS_LOCAL_NETWORK")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> {
                    val permission = call.argument<String>("permission")
                    if (permission == null || permission !in known) {
                        result.error("invalid", "Unknown permission.", null)
                    } else {
                        result.success(
                            mapOf(
                                "sdk" to Build.VERSION.SDK_INT,
                                "granted" to (activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED),
                                "rationale" to activity.shouldShowRequestPermissionRationale(permission),
                            ),
                        )
                    }
                }
                "openAppSettings" -> result.success(openAppSettings())
                else -> result.notImplemented()
            }
        }
    }

    // The app's own details page: where Permissions (Nearby devices) lives.
    private fun openAppSettings(): Boolean = try {
        activity.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}")),
        )
        true
    } catch (_: Exception) {
        false
    }
}
