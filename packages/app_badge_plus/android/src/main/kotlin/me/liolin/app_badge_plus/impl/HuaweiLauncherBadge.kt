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
 * 1.Honor8X(JSN-AL00a) 27(8.1.0) exceed 99，show 99+
 * 2.HUAWEI(ANE-AL00) 28(9)
 * 3.Honor nova 8 SE(JSC-AL50) Harmony OS 3.0.0
 */
class HuaweiLauncherBadge : IBadge {
    override fun updateBadge(context: Context, count: Int) {
        val localBundle = Bundle()
        localBundle.putString("package", context.packageName)
        localBundle.putString("class", LauncherTool.getClassName(context))
        localBundle.putInt("badgenumber", count)
        context.contentResolver.call(
            Uri.parse("content://com.huawei.android.launcher.settings/badge/"),
            "change_badge",
            null,
            localBundle
        )
    }

    override fun getSupportLaunchers(): List<String> {
        return listOf("com.huawei.android.launcher")
    }
}