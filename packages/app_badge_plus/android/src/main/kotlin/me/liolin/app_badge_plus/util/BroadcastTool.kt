package me.liolin.app_badge_plus.util

import android.content.Context
import android.content.Intent
import android.content.pm.ResolveInfo
import android.os.Build
import android.util.Log
import me.liolin.app_badge_plus.badge.BadgeException

import androidx.annotation.Keep;

@Keep
object BroadcastTool {
    private const val TAG = "Badge"

    private fun resolveBroadcast(context: Context, intent: Intent): List<ResolveInfo> {
        val packageManager = context.packageManager
        return packageManager.queryBroadcastReceivers(intent, 0)
    }

    @Throws(BadgeException::class)
    private fun sendIntentExplicitly(context: Context, intent: Intent) {
        val resolveInfoList: List<ResolveInfo> = resolveBroadcast(context, intent)
        if (resolveInfoList.isEmpty()) {
            throw BadgeException("unable to resolve intent: $intent")
        }
        for (resolveInfo in resolveInfoList) {
            val actualIntent = Intent(intent)
            actualIntent.setPackage(resolveInfo.resolvePackageName)
            context.sendBroadcast(actualIntent)
        }
    }

    fun sendBroadcast(context: Context, intent: Intent) {
        try {
            sendIntentExplicitly(context, intent)
        } catch (e: BadgeException) {
            Log.e(TAG, "Unable to send broadcast", e)
        }
    }

    fun sendDefaultBroadcast(context: Context, intent: Intent) {
        var oreoIntentSuccess = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val oreoIntent = Intent(intent)
            oreoIntent.action = "me.hacket.launcherbadge.BADGE_COUNT_UPDATE"
            oreoIntentSuccess = try {
                sendBroadcast(context, oreoIntent)
                true
            } catch (e: Exception) {
                false
            }
        }
        if (oreoIntentSuccess) {
            return
        }

        // try pre-Oreo default intent
        sendBroadcast(context, intent)
    }

}