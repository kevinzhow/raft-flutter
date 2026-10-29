package app.raft.raft_flutter

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen

internal object AppIconPalette {
    val colors = listOf("yellow", "blue", "green", "white", "pink")
    private fun component(context: Context, color: String) = ComponentName(
        context.packageName, "app.raft.raft_flutter.Icon" + color.replaceFirstChar { it.uppercase() })
    private fun enabled(context: Context, color: String): Boolean {
        return when (context.packageManager.getComponentEnabledSetting(component(context, color))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> color == "yellow"
            else -> false
        }
    }
    fun selected(context: Context): String {
        val active = colors.filter { enabled(context, it) }
        return active.firstOrNull() ?: "yellow"
    }
}

/** Theme-bound native entry points transfer the splash to ONE permanent
 * MainActivity. No Flutter engine, UI or artificial delay lives here.
 * MainActivity remains enabled for shares, OAuth, links and notifications.
 */
open class IconEntryActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        val splash = installSplashScreen()
        super.onCreate(savedInstanceState)
        splash.setKeepOnScreenCondition { true }
        // Forward the complete launch intent to the permanent owner.
        // Preserve its action, payload, URI and grant flags.
        startActivity(Intent(intent).apply {
            setClass(this@IconEntryActivity, MainActivity::class.java)
            if (action == null) action = Intent.ACTION_MAIN
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        })
        finish()
    }
}
class YellowIconEntry : IconEntryActivity()
class BlueIconEntry : IconEntryActivity()
class GreenIconEntry : IconEntryActivity()
class WhiteIconEntry : IconEntryActivity()
class PinkIconEntry : IconEntryActivity()
