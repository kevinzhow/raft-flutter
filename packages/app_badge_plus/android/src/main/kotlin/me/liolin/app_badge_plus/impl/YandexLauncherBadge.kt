package me.liolin.app_badge_plus.impl

import android.content.Context
import android.net.Uri
import android.os.Bundle
import me.liolin.app_badge_plus.badge.IBadge
import me.liolin.app_badge_plus.util.LauncherTool

import androidx.annotation.Keep;

@Keep
class YandexLauncherBadge : IBadge {

    companion object {
        private const val AUTHORITY = "com.yandex.launcher.badges_external"
        private const val METHOD_TO_CALL = "setBadgeNumber"

        private val CONTENT_URI = Uri.parse("content://$AUTHORITY")

        private const val COLUMN_CLASS = "class"
        private const val COLUMN_PACKAGE = "package"
        private const val COLUMN_BADGES_COUNT = "badges_count"
    }

    override fun updateBadge(context: Context, count: Int) {
        val extras = Bundle()
        extras.putString(COLUMN_PACKAGE, LauncherTool.getComponentName(context)?.packageName)
        extras.putString(COLUMN_CLASS, LauncherTool.getClassName(context))
        extras.putString(COLUMN_BADGES_COUNT, java.lang.String.valueOf(count))
        context.contentResolver.call(CONTENT_URI, METHOD_TO_CALL, null, extras)
    }

    override fun getSupportLaunchers(): List<String> {
        return listOf("com.yandex.launcher")
    }

}