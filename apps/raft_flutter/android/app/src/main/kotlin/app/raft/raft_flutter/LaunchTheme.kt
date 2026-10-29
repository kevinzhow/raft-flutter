package app.raft.raft_flutter

import android.app.Activity
import android.content.Context
import android.graphics.drawable.ColorDrawable
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Launch screen = the stored theme's canvas + the chosen app icon.
 *
 * Android 13+ lets an app persist ONE splash theme
 * ([android.window.SplashScreen.setSplashScreenTheme]); the system applies it
 * to every later launch before the process draws anything, so the splash
 * already has the right canvas. Dart reports appearance changes over
 * `app.raft/launch-theme`; the selected icon is read from the enabled launcher
 * alias, and MainActivity re-applies on every start (self-healing after
 * an app update, a restore or an icon change made elsewhere).
 *
 * Android 12/12L cannot choose a theme at runtime and <= 11 draws the entry
 * Activity's static windowBackground: both follow the device day/night setting
 * (res/values-night). See docs/custom-app-icons.md.
 */
internal object LaunchTheme {
    const val CHANNEL = "app.raft/launch-theme"
    private const val PREFS = "raft_launch_theme"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"

    /** Theme kinds; each maps to RaftSplash_<kind>_<icon> and a canvas colour. */
    enum class Kind(val id: String) {
        BRUTAL_LIGHT("brutal_light"),
        ELEGANT_LIGHT("elegant_light"),
        DARK("dark"),
        SYSTEM_BRUTAL("system_brutal"),
        SYSTEM_ELEGANT("system_elegant"),
    }

    /** `mode`: ThemeMode.name (system|light|dark); `light`: RaftFamily.name (brutal|elegant).
     * Unknown or missing values fall back to the Dart defaults (system, brutal). */
    fun kind(mode: String?, light: String?): Kind {
        val elegant = light == "elegant"
        return when (mode) {
            "dark" -> Kind.DARK
            "light" -> if (elegant) Kind.ELEGANT_LIGHT else Kind.BRUTAL_LIGHT
            else -> if (elegant) Kind.SYSTEM_ELEGANT else Kind.SYSTEM_BRUTAL
        }
    }

    fun styleName(kind: Kind, icon: String) = "RaftSplash_${kind.id}_$icon"

    fun store(context: Context, mode: String?, light: String?) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("mode", mode).putString("light", light).apply()
    }

    /** The stored appearance: ours when Dart already reported one, otherwise the
     * app's own Flutter preferences (first launch after an update). */
    fun current(context: Context): Kind {
        val own = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (own.contains("mode") || own.contains("light")) {
            return kind(own.getString("mode", null), own.getString("light", null))
        }
        val flutter = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        return kind(
            runCatching { flutter.getString("flutter.raft.mode", null) }.getOrNull(),
            runCatching { flutter.getString("flutter.raft.light", null) }.getOrNull(),
        )
    }

    /** Canvas colour of [kind] under the context's current day/night setting. */
    fun canvas(context: Context, kind: Kind = current(context)): Int {
        val name = when (kind) {
            Kind.BRUTAL_LIGHT -> "raft_canvas_brutal_light"
            Kind.ELEGANT_LIGHT -> "raft_canvas_elegant_light"
            Kind.DARK -> "raft_canvas_elegant_dark"
            Kind.SYSTEM_BRUTAL -> "raft_canvas_system_brutal"
            Kind.SYSTEM_ELEGANT -> "raft_canvas_system_elegant"
        }
        return context.getColor(context.resources.getIdentifier(name, "color", context.packageName))
    }

    /** Window background behind the Flutter view while the engine starts. */
    fun background(context: Context) = ColorDrawable(canvas(context))

    /** Persist the splash theme (stored appearance + enabled icon) for the next launch. */
    fun apply(activity: Activity) {
        if (Build.VERSION.SDK_INT < 33) return
        try {
            val name = styleName(current(activity), AppIconPalette.selected(activity))
            val id = activity.resources.getIdentifier(name, "style", activity.packageName)
            if (id != 0) activity.splashScreen.setSplashScreenTheme(id)
        } catch (_: Exception) {
            // The splash is cosmetic: never fail startup or an icon change.
        }
    }

    fun register(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "set" -> {
                    store(activity, call.argument<String>("mode"), call.argument<String>("light"))
                    apply(activity)
                    result.success(null)
                }
                "refresh" -> {
                    apply(activity)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
