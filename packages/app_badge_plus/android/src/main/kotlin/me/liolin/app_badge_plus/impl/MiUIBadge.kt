package me.liolin.app_badge_plus.impl

import android.content.Context
import androidx.annotation.Keep
import me.liolin.app_badge_plus.badge.IBadge
import me.liolin.app_badge_plus.util.NotificationBadgeHelper

/**
 * Xiaomi / Redmi / POCO (MIUI & HyperOS).
 *
 * On POCO Global Launcher (`com.mi.android.globallauncher`) / HyperOS the private
 * `extraNotification` API is gone and `Notification.setNumber` is ignored. The launcher
 * badge equals the number of active non-ongoing notifications, so we post N notifications
 * for count N (and cancel them when count is 0).
 */
@Keep
class MiUIBadge : IBadge {

    override fun updateBadge(context: Context, count: Int) {
//        NotificationBadgeHelper.updateMiuiBadgeHyperOs(context, count)
    }

    override fun getSupportLaunchers(): List<String> {
        return listOf(
            "com.miui.miuilite",
            "com.miui.home",
            "com.miui.miuihome",
            "com.miui.miuihome2",
            "com.miui.mihome",
            "com.miui.mihome2",
            "com.mi.android.globallauncher",
            "com.i.miui.launcher"
        )
    }
}
