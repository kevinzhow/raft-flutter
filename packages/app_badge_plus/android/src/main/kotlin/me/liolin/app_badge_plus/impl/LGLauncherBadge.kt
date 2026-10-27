package me.liolin.app_badge_plus.impl

import android.content.Context
import android.content.Intent
import me.liolin.app_badge_plus.badge.IBadge
import me.liolin.app_badge_plus.util.BroadcastTool
import me.liolin.app_badge_plus.util.LauncherTool

import androidx.annotation.Keep;

@Keep
class LGLauncherBadge : IBadge {

    companion object {
        private const val INTENT_ACTION = "android.intent.action.BADGE_COUNT_UPDATE"
        private const val INTENT_EXTRA_PACKAGE_NAME = "badge_count_package_name"
        private const val INTENT_EXTRA_CLASS_NAME = "badge_count_class_name"
        private const val INTENT_EXTRA_BADGE_COUNT = "badge_count"
    }

    override fun updateBadge(context: Context, count: Int) {
        val componentName = LauncherTool.getComponentName(context) ?: return
        val intent = Intent(INTENT_ACTION)
        intent.putExtra(INTENT_EXTRA_PACKAGE_NAME, componentName.packageName)
        intent.putExtra(INTENT_EXTRA_CLASS_NAME, componentName.className)
        intent.putExtra(INTENT_EXTRA_BADGE_COUNT, count)
        BroadcastTool.sendDefaultBroadcast(context, intent)
    }

    override fun getSupportLaunchers(): List<String> {
        return listOf("com.lge.launcher", "com.lge.launcher2")
    }
}