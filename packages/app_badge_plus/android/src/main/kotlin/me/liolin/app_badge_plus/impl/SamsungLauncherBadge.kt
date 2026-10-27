package me.liolin.app_badge_plus.impl

import android.content.Context
import android.content.Intent
import me.liolin.app_badge_plus.badge.IBadge
import me.liolin.app_badge_plus.util.LauncherTool

import androidx.annotation.Keep;

@Keep
/**
 * Pass
 * 1. Galaxy S6 edge(SM-G9250)  exceed 99, show 99+
 * 2. Galaxy S22(SM-G9010)  exceed 99, show 99+
 */
class SamsungLauncherBadge : IBadge {

    companion object {
        private const val INTENT_ACTION = "android.intent.action.BADGE_COUNT_UPDATE"
        private const val INTENT_EXTRA_PACKAGE_NAME = "badge_count_package_name"
        private const val INTENT_EXTRA_CLASS_NAME = "badge_count_class_name"
        private const val INTENT_EXTRA_BADGE_COUNT = "badge_count"
    }

    override fun updateBadge(context: Context, count: Int) {
        val intent = Intent(INTENT_ACTION)
        intent.putExtra(INTENT_EXTRA_PACKAGE_NAME, context.packageName)
        intent.putExtra(INTENT_EXTRA_CLASS_NAME, LauncherTool.getClassName(context))
        intent.putExtra(INTENT_EXTRA_BADGE_COUNT, count)
        context.sendBroadcast(intent)
    }

    override fun getSupportLaunchers(): List<String> {
        return listOf(
            "com.sec.android.app.launcher",
            "com.sec.android.app.twlauncher"
        )
    }
}