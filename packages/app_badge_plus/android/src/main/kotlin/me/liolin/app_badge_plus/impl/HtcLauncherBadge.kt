package me.liolin.app_badge_plus.impl

import android.content.Context
import android.content.Intent
import android.util.Log
import me.liolin.app_badge_plus.badge.IBadge
import me.liolin.app_badge_plus.util.BroadcastTool
import me.liolin.app_badge_plus.util.LauncherTool

import androidx.annotation.Keep;

@Keep
class HtcLauncherBadge : IBadge {

    companion object {
        private const val INTENT_UPDATE_SHORTCUT = "com.htc.launcher.action.UPDATE_SHORTCUT"
        private const val INTENT_SET_NOTIFICATION = "com.htc.launcher.action.SET_NOTIFICATION"
        private const val PACKAGE_NAME = "packagename"
        private const val EXTRA_COMPONENT = "com.htc.launcher.extra.COMPONENT"
        private const val EXTRA_COUNT = "com.htc.launcher.extra.COUNT"
        private const val COUNT = "count"
    }

    override fun updateBadge(context: Context, count: Int) {
        val componentName = LauncherTool.getComponentName(context)

        val intent1 = Intent(INTENT_SET_NOTIFICATION)
        intent1.putExtra(EXTRA_COMPONENT, componentName?.flattenToShortString())
        intent1.putExtra(EXTRA_COUNT, count)
        try {
            BroadcastTool.sendBroadcast(context, intent1)
        } catch (e: Exception) {
            Log.e("Badge", "unable to resolve intent: $intent1", e)
        }

        val intent2 = Intent(INTENT_UPDATE_SHORTCUT)
        intent2.putExtra(PACKAGE_NAME, componentName?.packageName)
        intent2.putExtra(COUNT, count)
        try {
            BroadcastTool.sendBroadcast(context, intent2)
        } catch (e: Exception) {
            Log.e("Badge", "unable to resolve intent: $intent2", e)
        }
    }

    override fun getSupportLaunchers(): List<String> {
        return listOf("com.htc.launcher")
    }
}