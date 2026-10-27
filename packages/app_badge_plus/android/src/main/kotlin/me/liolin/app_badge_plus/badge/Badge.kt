package me.liolin.app_badge_plus.badge

import android.app.Notification
import android.content.Context
import android.content.Intent
import android.content.pm.ResolveInfo
import android.util.Log
import androidx.annotation.Keep
import me.liolin.app_badge_plus.impl.ApexLauncherBadge
import me.liolin.app_badge_plus.impl.AsusLauncherBadge
import me.liolin.app_badge_plus.impl.DefaultBadge
import me.liolin.app_badge_plus.impl.HihonorLauncherBadge
import me.liolin.app_badge_plus.impl.HtcLauncherBadge
import me.liolin.app_badge_plus.impl.HuaweiLauncherBadge
import me.liolin.app_badge_plus.impl.LGLauncherBadge
import me.liolin.app_badge_plus.impl.MiUIBadge
import me.liolin.app_badge_plus.impl.NexusLauncherBadge
import me.liolin.app_badge_plus.impl.NowaLauncherBadge
import me.liolin.app_badge_plus.impl.OPPOLauncherBadge
import me.liolin.app_badge_plus.impl.SamsungLauncherBadge
import me.liolin.app_badge_plus.impl.SonyLauncherBadge
import me.liolin.app_badge_plus.impl.VivoLauncherBadge
import me.liolin.app_badge_plus.impl.YandexLauncherBadge
import me.liolin.app_badge_plus.impl.ZTELauncherBadge
import me.liolin.app_badge_plus.util.LauncherTool

@Keep
object Badge {

    private const val TAG = "Badge"
    private var BADGES: MutableList<Class<out IBadge>> = mutableListOf()
    private var iBadge: IBadge? = null
    var notification: Notification? = null

    @Volatile
    private var isBadgeSupported: Boolean? = null
    private val badgeSupportedLock = Any()

    init {
        BADGES.add(DefaultBadge::class.java)
        BADGES.add(NexusLauncherBadge::class.java)
        BADGES.add(ApexLauncherBadge::class.java)
        BADGES.add(AsusLauncherBadge::class.java)
        BADGES.add(HtcLauncherBadge::class.java)
        BADGES.add(HuaweiLauncherBadge::class.java)
        BADGES.add(HihonorLauncherBadge::class.java)
        BADGES.add(LGLauncherBadge::class.java)
        BADGES.add(MiUIBadge::class.java)
        BADGES.add(NowaLauncherBadge::class.java)
        BADGES.add(OPPOLauncherBadge::class.java)
        BADGES.add(SamsungLauncherBadge::class.java)
        BADGES.add(SonyLauncherBadge::class.java)
        BADGES.add(VivoLauncherBadge::class.java)
        BADGES.add(YandexLauncherBadge::class.java)
        BADGES.add(ZTELauncherBadge::class.java)
    }

    fun applyNotification(notification: Notification?) {
        this.notification = notification
    }

    fun isBadgeSupported(context: Context): Boolean {
        if (isBadgeSupported == null) {
            synchronized(badgeSupportedLock) {
                if (isBadgeSupported == null) {
                    for (i in 0 until 3) {
                        try {
                            Log.d(TAG, "Checking if launcher supports badge, attempt ${i + 1}")
                            if (initBadge(context)) {
                                if (iBadge is NexusLauncherBadge) return false
                                updateBadge(context, 0)
                                isBadgeSupported = true
                                Log.d(TAG, "Badge is supported by launcher")
                                break
                            } else {
                                Log.e(TAG, "Failed to initialize badge")
                                isBadgeSupported = false
                            }
                        } catch (e: BadgeException) {
                            isBadgeSupported = false
                        }
                    }
                }
            }
        }
        return isBadgeSupported ?: false
    }

    fun updateBadge(context: Context, count: Int) {
        try {
            updateBadgeOrThrow(context, count)
        } catch (e: BadgeException) {
            Log.e(TAG, "Unable to update badge", e)
        }
    }

    @Throws(BadgeException::class)
    private fun updateBadgeOrThrow(context: Context, count: Int) {
        if (iBadge == null) {
            val launcherReady: Boolean = initBadge(context)
            if (!launcherReady) {
                throw BadgeException("No default launcher available")
            }
        }
        try {
            iBadge?.updateBadge(context, count)
        } catch (e: Exception) {
            throw BadgeException("Unable to update badge", e)
        }
    }

    private fun initBadge(context: Context): Boolean {
        val launchIntent: Intent? =
            context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent == null) {
            Log.e(TAG, "Unable to find launch intent for package: " + context.packageName)
            return false
        }

        val resolveList: List<ResolveInfo?> = LauncherTool.getLauncherList(context)
        for (resolveInfo in resolveList) {
            val activityInfo = resolveInfo?.activityInfo?.packageName
            Log.i(TAG, "Checking launcher $activityInfo")

            for (badge in BADGES) {
                var tempBadge: IBadge? = null
                try {
                    tempBadge = badge.getDeclaredConstructor().newInstance()
                } catch (ignore: Exception) {
                }
                if (tempBadge != null &&
                    tempBadge.getSupportLaunchers().contains(activityInfo)
                ) {
                    iBadge = tempBadge
                    break
                }
            }
            if (iBadge != null) {
                break
            }
        }

        return iBadge != null
    }
}