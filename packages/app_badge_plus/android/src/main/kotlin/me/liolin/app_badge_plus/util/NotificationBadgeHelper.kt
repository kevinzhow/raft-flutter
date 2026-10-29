package me.liolin.app_badge_plus.util

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.annotation.Keep
import kotlin.math.min

/**
 * HyperOS / POCO: badge count = number of active non-ongoing notifications.
 */
@Keep
object NotificationBadgeHelper {
    private const val TAG = "Badge"
    private const val CHANNEL_ID = "app_badge_plus_badge"
    private const val CHANNEL_NAME = "App badge"
    private const val MULTI_ID_BASE = 0x0BAD7000
    private const val MAX_MULTI_COUNT = 99
    private const val REPOST_DELAY_MS = 40L

    private val mainHandler = Handler(Looper.getMainLooper())
    private val repostToken = Any()

    fun updateMiuiBadgeHyperOs(context: Context, count: Int) {
        val appContext = context.applicationContext
        val manager =
            appContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return

        mainHandler.removeCallbacksAndMessages(repostToken)
        clearMultiNotifications(manager)

        if (count <= 0) {
            return
        }

        ensureChannel(manager)

        val target = min(count, MAX_MULTI_COUNT)
        val icon = appContext.applicationInfo.icon.takeIf { it != 0 }
            ?: android.R.drawable.sym_def_app_icon
        val appName = appContext.applicationInfo.loadLabel(appContext.packageManager).toString()

        mainHandler.postAtTime(
            {
                try {
                    for (i in 0 until target) {
                        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Notification.Builder(appContext, CHANNEL_ID)
                        } else {
                            @Suppress("DEPRECATION")
                            Notification.Builder(appContext)
                        }
                        val notification = builder
                            .setContentTitle(appName)
                            .setContentText((i + 1).toString())
                            .setSmallIcon(icon)
                            .setNumber(1)
                            .setOngoing(false)
                            .setOnlyAlertOnce(true)
                            .setAutoCancel(false)
                            .setShowWhen(false)
                            .setSortKey(String.format("%02d", i))
                            .setGroup("app_badge_plus_$i")
                            .build()
                        manager.notify(MULTI_ID_BASE + i, notification)
                    }
                    Log.d(TAG, "HyperOS badge via $target notification(s)")
                } catch (e: Exception) {
                    Log.e(TAG, "Unable to post HyperOS badge notifications", e)
                }
            },
            repostToken,
            SystemClock.uptimeMillis() + REPOST_DELAY_MS
        )
    }

    private fun clearMultiNotifications(manager: NotificationManager) {
        for (i in 0 until MAX_MULTI_COUNT) {
            manager.cancel(MULTI_ID_BASE + i)
        }
    }

    private fun ensureChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) {
            if (!existing.canShowBadge() ||
                existing.importance < NotificationManager.IMPORTANCE_DEFAULT
            ) {
                manager.deleteNotificationChannel(CHANNEL_ID)
            } else {
                return
            }
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            setShowBadge(true)
            description = "Shows the app icon badge count"
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }
}
