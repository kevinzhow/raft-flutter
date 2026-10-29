package me.liolin.app_badge_plus.impl

import android.content.Context
import android.net.Uri
import android.os.Bundle
import me.liolin.app_badge_plus.badge.IBadge
import me.liolin.app_badge_plus.util.LauncherTool

import androidx.annotation.Keep;

@Keep
/**
 * PASS
 * Honor 80 (ANN-AN00)
 */
class HihonorLauncherBadge : IBadge {
    override fun updateBadge(context: Context, count: Int) {
        val localBundle = Bundle()
        localBundle.putString("package", context.packageName)
        localBundle.putString("class", LauncherTool.getClassName(context))
        localBundle.putInt("badgenumber", count)
        context.contentResolver.call(
            Uri.parse("content://com.hihonor.android.launcher.settings/badge/"),
            "change_badge",
            null,
            localBundle
        )
    }

    override fun getSupportLaunchers(): List<String> {
        return listOf("com.hihonor.android.launcher")
    }
}