package me.liolin.app_badge_plus.util

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.os.Build
import android.util.Log
import androidx.annotation.Keep
import java.util.Collections

@Keep
object LauncherTool {
    private const val TAG = "Badge"
    private const val FALLBACK_HOME_PACKAGE = "com.android.settings"
    private const val FALLBACK_HOME_CLASS = "com.android.settings.FallbackHome"

    fun getClassName(context: Context): String {
        val launchComponent = getComponentName(context)
        return launchComponent?.className ?: ""
    }

    fun getComponentName(context: Context): ComponentName? {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        return launchIntent?.component
    }

    fun getLauncherList(context: Context, includeFallbackHome: Boolean = true): List<ResolveInfo?> {
        val intent = Intent(Intent.ACTION_MAIN)
        intent.addCategory(Intent.CATEGORY_HOME)
        val queryFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PackageManager.MATCH_ALL
        } else {
            0
        }
        val resolveList: MutableList<ResolveInfo> =
            context.packageManager.queryIntentActivities(intent, queryFlags)
                .filter { includeFallbackHome || !isFallbackHome(it) }
                .toMutableList()
        val defaultActivity: ResolveInfo? =
            context.packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        makeSureLauncherOnTop(defaultActivity, resolveList)
        return resolveList
    }

    /**
     * Make sure the home activity is on top of the list
     *
     */
    private fun makeSureLauncherOnTop(
        defaultActivity: ResolveInfo?,
        resolveList: MutableList<ResolveInfo>
    ) {
        if (resolveList.isEmpty()) {
            return
        }

        val defaultActivityInfo = defaultActivity?.activityInfo
        if (defaultActivityInfo != null && isFallbackHome(defaultActivity)) {
            return
        }

        var indexToSwap = 0
        for (i in resolveList.indices) {
            val resolveInfo = resolveList[i]
            val activityInfo = resolveInfo.activityInfo
            Log.d(TAG, "package $i: ${activityInfo.packageName}/${activityInfo.name}")
            if (defaultActivityInfo != null &&
                activityInfo.packageName == defaultActivityInfo.packageName &&
                activityInfo.name == defaultActivityInfo.name
            ) {
                indexToSwap = i
                break
            }
        }
        Collections.swap(resolveList, 0, indexToSwap)
    }

    private fun isFallbackHome(resolveInfo: ResolveInfo?): Boolean {
        val activityInfo = resolveInfo?.activityInfo ?: return false
        return activityInfo.packageName == FALLBACK_HOME_PACKAGE &&
                activityInfo.name == FALLBACK_HOME_CLASS
    }
}
