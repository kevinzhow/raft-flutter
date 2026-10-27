package me.liolin.app_badge_plus.impl

import android.content.Context
import me.liolin.app_badge_plus.badge.IBadge

import androidx.annotation.Keep;

@Keep
class DefaultBadge : IBadge {

    override fun updateBadge(context: Context, count: Int) {
        // Starting with Android 8.0 (API level 26), notification badges—also known as notification
        // dots—appear on a launcher icon when the associated app has an active notification. Users
        // can touch & hold the app icon to reveal the notifications, along with any app shortcuts.
        //
        // These dots appear by default in launcher apps that support them, and there's nothing
        // your app needs to do.
    }

    override fun getSupportLaunchers(): List<String> {
        return emptyList()
    }
}