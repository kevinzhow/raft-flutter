package me.liolin.app_badge_plus.impl

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.util.Log
import me.liolin.app_badge_plus.badge.IBadge

import androidx.annotation.Keep;

@Keep
class OPPOLauncherBadge : IBadge {

    companion object {
        private const val PROVIDER_CONTENT_URI = "content://com.android.badge/badge"
        private const val INTENT_EXTRA_BADGE_UPGRADE_COUNT = "app_badge_count"
    }

    override fun updateBadge(context: Context, count: Int) {
        executeBadgeByContentProvider(context, count)
    }

    override fun getSupportLaunchers(): List<String> {
        return listOf("com.oppo.launcher")
    }

    /**
     * Send request to OPPO badge content provider to set badge in OPPO home launcher.
     *
     * @param context       the context to use
     * @param badgeCount    the badge count
     */
    @Throws(Exception::class)
    private fun executeBadgeByContentProvider(context: Context, badgeCount: Int) {
        try {
            val extras = Bundle()
            extras.putInt(INTENT_EXTRA_BADGE_UPGRADE_COUNT, badgeCount)
            context.contentResolver.call(
                Uri.parse(PROVIDER_CONTENT_URI),
                "setAppBadgeCount",
                null,
                extras
            )
        } catch (ignored: Throwable) {
            Log.e("Badge", "OPPO: Unable to execute Badge By Content Provider", ignored)
        }
    }
}