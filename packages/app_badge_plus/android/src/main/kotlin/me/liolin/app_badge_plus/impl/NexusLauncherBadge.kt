package me.liolin.app_badge_plus.impl

import android.util.Log
import me.liolin.app_badge_plus.badge.IBadge

class NexusLauncherBadge : IBadge {
    private val tag = "NexusLauncherBadge"

    override fun updateBadge(context: android.content.Context, count: Int) {
        Log.d(
            tag,
            "Nexus Launcher does not support badge count. Please use notification dots instead. " +
                    "Link: https://developer.android.com/training/notify-user/badges"
        )
    }

    override fun getSupportLaunchers(): List<String> {
        return listOf("com.google.android.apps.nexuslauncher")
    }
}