package me.liolin.app_badge_plus.impl

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import me.liolin.app_badge_plus.badge.IBadge
import me.liolin.app_badge_plus.util.LauncherTool

import androidx.annotation.Keep;

@Keep
class NowaLauncherBadge : IBadge {
    companion object {
        private const val CONTENT_URI = "content://com.teslacoilsw.notifier/unread_count"
        private const val COUNT = "count"
    }

    override fun updateBadge(context: Context, count: Int) {
        val componentName = LauncherTool.getComponentName(context)
        val contentValues = ContentValues()
        contentValues.put("BADGE", componentName?.packageName + "/" + componentName?.className)
        contentValues.put(COUNT, count)
        context.contentResolver.insert(Uri.parse(CONTENT_URI), contentValues)
    }

    override fun getSupportLaunchers(): List<String> {
        return listOf("com.teslacoilsw.launcher")
    }
}