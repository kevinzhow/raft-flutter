package app.raft.raft_flutter

import android.app.Activity
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.text.TextRunShaper
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class NativeSystemFontsBridge(private val activity: Activity, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "app.raft/system-fonts")

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "read") result.success(families())
            else if (call.method == "faces") result.success(faces())
            else result.notImplemented()
        }
    }

    private fun family(appearance: Int): String {
        // Public DeviceDefault styles resolve OEM/user font overlays. Reading
        // fonts.xml or choosing "sans-serif" would miss that active selection.
        val attributes = activity.obtainStyledAttributes(appearance, intArrayOf(android.R.attr.fontFamily))
        return try {
            attributes.getString(0)?.takeIf { it.isNotBlank() } ?: "sans-serif"
        } finally {
            attributes.recycle()
        }
    }

    private fun families() = mapOf(
        "body" to family(android.R.style.TextAppearance_DeviceDefault),
        "heading" to family(android.R.style.TextAppearance_DeviceDefault_Headline),
    )

    @android.annotation.TargetApi(31)
    private fun faces(): Map<String, Any> {
        val selected = families()
        if (Build.VERSION.SDK_INT < 31) return selected + ("faces" to emptyList<Any>())
        val faces = linkedMapOf<String, Map<String, String>>()
        val primaryPaths = mutableSetOf<String>()
        fun collect(role: String, name: String, text: String, fallback: Boolean = false) {
            for ((weight, italic) in listOf(400 to false, 500 to false, 700 to false, 400 to true)) {
                val paint = Paint().apply {
                    textSize = 16f
                    textLocales = activity.resources.configuration.locales
                    typeface = Typeface.create(Typeface.create(name, Typeface.NORMAL), weight, italic)
                }
                val glyphs = TextRunShaper.shapeTextRun(text, 0, text.length, 0, text.length, 0f, 0f, false, paint)
                if (glyphs.glyphCount() == 0) continue
                val font = glyphs.getFont(0)
                val file = font.file ?: continue
                // FontLoader has no TTC face-index argument. Keep non-zero
                // collection faces in the platform's locale-aware fallback.
                if (font.ttcIndex != 0) continue
                val path = file.absolutePath
                if (fallback && path in primaryPaths) continue
                if (!fallback) primaryPaths.add(path)
                faces["$role:$path"] = mapOf("role" to role, "path" to path)
            }
        }
        val body = selected.getValue("body")
        val heading = selected.getValue("heading")
        // The pinned Flutter font manager does not match all OEM primary and
        // Chinese fallback families. Resolve their faces through native shaping.
        collect("body", body, " ")
        collect("body-fallback", body, "汉", fallback = true)
        if (heading != body) {
            collect("heading", heading, " ")
            collect("heading-fallback", heading, "汉", fallback = true)
        }
        return selected + ("faces" to faces.values.toList())
    }

    fun configurationChanged() {
        channel.invokeMethod("changed", families())
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }
}
