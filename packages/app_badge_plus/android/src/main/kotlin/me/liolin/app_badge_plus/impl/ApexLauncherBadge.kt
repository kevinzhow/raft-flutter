package me.liolin.app_badge_plus.impl

import android.content.Context
import android.content.Intent
import me.liolin.app_badge_plus.badge.IBadge
import me.liolin.app_badge_plus.util.BroadcastTool
import me.liolin.app_badge_plus.util.LauncherTool

import androidx.annotation.Keep;

@Keep
/**
 * ApexLauncher last update 2018
 */
class ApexLauncherBadge : IBadge {

    companion object {
        private const val INTENT_UPDATE_COUNTER = "com.anddoes.launcher.COUNTER_CHANGED"
        private const val PACKAGE_NAME = "package"
        private const val CLASS_NAME = "class"
        private const val COUNT = "count"
    }

    override fun updateBadge(context: Context, count: Int) {
        val componentName = LauncherTool.getComponentName(context)
        val intent = Intent(INTENT_UPDATE_COUNTER)
        intent.putExtra(PACKAGE_NAME, componentName?.packageName)
        intent.putExtra(CLASS_NAME, componentName?.className)
        intent.putExtra(COUNT, count)

        BroadcastTool.sendBroadcast(context, intent)
    }

    override fun getSupportLaunchers(): List<String> {
        return listOf("com.anddoes.launcher")
    }
}