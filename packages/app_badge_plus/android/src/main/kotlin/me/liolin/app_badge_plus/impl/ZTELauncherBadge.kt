package me.liolin.app_badge_plus.impl

import android.content.Context
import android.net.Uri
import android.os.Bundle
import me.liolin.app_badge_plus.badge.IBadge
import me.liolin.app_badge_plus.util.LauncherTool

import androidx.annotation.Keep;

@Keep
class ZTELauncherBadge : IBadge {

    companion object {
        private const val CONTENT_URI = "content://com.android.launcher3.cornermark.unreadbadge"
        private const val EXTRA_BADGE_COMPONENT = "app_badge_component_name"
        private const val EXTRA_BADGE_COUNT = "app_badge_count"
    }

    override fun updateBadge(context: Context, count: Int) {
        val extra = Bundle()
        extra.putString(
            EXTRA_BADGE_COMPONENT,
            LauncherTool.getComponentName(context)?.flattenToString()
        )
        extra.putInt(EXTRA_BADGE_COUNT, count)
        context.contentResolver.call(
            Uri.parse(CONTENT_URI),
            "setAppUnreadCount",
            null,
            extra
        )
    }

    override fun getSupportLaunchers(): List<String> {
        return emptyList()
    }
}