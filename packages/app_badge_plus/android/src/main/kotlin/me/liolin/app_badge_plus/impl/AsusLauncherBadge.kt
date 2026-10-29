package me.liolin.app_badge_plus.impl

import android.content.Context
import android.content.Intent
import androidx.annotation.Keep
import me.liolin.app_badge_plus.badge.IBadge
import me.liolin.app_badge_plus.util.LauncherTool


@Keep
class AsusLauncherBadge : IBadge {

    companion object {
        private const val INTENT_ACTION: String = "android.intent.action.BADGE_COUNT_UPDATE"
        private const val INTENT_EXTRA_BADGE_COUNT: String = "badge_count"
        private const val INTENT_EXTRA_PACKAGE_NAME: String = "badge_count_package_name"
        private const val INTENT_EXTRA_ACTIVITY_NAME: String = "badge_count_class_name"
    }


    override fun updateBadge(context: Context, count: Int) {
        val componentName = LauncherTool.getComponentName(context)

        val intent = Intent(INTENT_ACTION)
        intent.putExtra(INTENT_EXTRA_BADGE_COUNT, count)
        intent.putExtra(INTENT_EXTRA_PACKAGE_NAME, componentName?.packageName)
        intent.putExtra(INTENT_EXTRA_ACTIVITY_NAME, componentName?.className)
        intent.putExtra("badge_vip_count", 0)
        context.sendBroadcast(intent)
    }

    override fun getSupportLaunchers(): List<String> {
        return listOf("com.asus.launcher")
    }
}
