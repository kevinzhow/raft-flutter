package me.liolin.app_badge_plus.impl

import android.content.Context
import android.content.Intent
import me.liolin.app_badge_plus.badge.IBadge
import me.liolin.app_badge_plus.util.LauncherTool

import androidx.annotation.Keep;

@Keep
class VivoLauncherBadge : IBadge {

    companion object {
        private const val INTENT_ACTION = "launcher.action.CHANGE_APPLICATION_NOTIFICATION_NUM"
        private const val INTENT_EXTRA_PACKAGE_NAME = "packageName"
        private const val INTENT_EXTRA_CLASS_NAME = "className"
        private const val INTENT_EXTRA_BADGE_COUNT = "notificationNum"
    }

    override fun updateBadge(context: Context, count: Int) {
        val intent = Intent(INTENT_ACTION)
        intent.putExtra(INTENT_EXTRA_PACKAGE_NAME, context.packageName)
        intent.putExtra(INTENT_EXTRA_CLASS_NAME, LauncherTool.getClassName(context))
        intent.putExtra(INTENT_EXTRA_BADGE_COUNT, count)
        if (Intent::class.java.canonicalName != null) {
            intent.addFlags(
                invokeIntConstants(
                    Intent::class.java.canonicalName!!,
                    "FLAG_RECEIVER_INCLUDE_BACKGROUND",
                    0
                )
            )
        }
        context.sendBroadcast(intent)
    }

    override fun getSupportLaunchers(): List<String> {
        return listOf("com.vivo.launcher", "com.vivo.simplelauncher")
    }

    fun invokeIntConstants(canonicalName: String, name: String, defaultValue: Int): Int {
        var value = defaultValue
        try {
            val c = Class.forName(canonicalName)
            val field = c.getField(name)
            value = field.getInt(c)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return value
    }
}