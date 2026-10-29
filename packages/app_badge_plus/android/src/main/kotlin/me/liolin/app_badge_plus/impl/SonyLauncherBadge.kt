package me.liolin.app_badge_plus.impl

import android.annotation.SuppressLint
import android.content.AsyncQueryHandler
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Looper
import me.liolin.app_badge_plus.badge.IBadge
import me.liolin.app_badge_plus.util.LauncherTool

import androidx.annotation.Keep;

@Keep
class SonyLauncherBadge : IBadge {
    companion object {
        private const val INTENT_ACTION = "com.sonyericsson.home.action.UPDATE_BADGE"
        private const val INTENT_EXTRA_PACKAGE_NAME =
            "com.sonyericsson.home.intent.extra.badge.PACKAGE_NAME"
        private const val INTENT_EXTRA_ACTIVITY_NAME =
            "com.sonyericsson.home.intent.extra.badge.ACTIVITY_NAME"
        private const val INTENT_EXTRA_MESSAGE =
            "com.sonyericsson.home.intent.extra.badge.MESSAGE"
        private const val INTENT_EXTRA_SHOW_MESSAGE =
            "com.sonyericsson.home.intent.extra.badge.SHOW_MESSAGE"

        private const val PROVIDER_CONTENT_URI =
            "content://com.sonymobile.home.resourceprovider/badge"
        private const val PROVIDER_COLUMNS_BADGE_COUNT = "badge_count"
        private const val PROVIDER_COLUMNS_PACKAGE_NAME = "package_name"
        private const val PROVIDER_COLUMNS_ACTIVITY_NAME = "activity_name"
        private const val SONY_HOME_PROVIDER_NAME = "com.sonymobile.home.resourceprovider"

        private val BADGE_CONTENT_URI = Uri.parse(PROVIDER_CONTENT_URI)
    }

    private var mQueryHandler: AsyncQueryHandler? = null

    override fun updateBadge(context: Context, count: Int) {
        val componentName = LauncherTool.getComponentName(context) ?: return

        if (sonyBadgeContentProviderExists(context)) {
            executeBadgeByContentProvider(context, componentName, count)
        } else {
            executeBadgeByBroadcast(context, componentName, count)
        }
    }

    override fun getSupportLaunchers(): List<String> {
        return listOf("com.sonyericsson.home", "com.sonymobile.home")
    }

    private fun executeBadgeByBroadcast(
        context: Context,
        componentName: ComponentName,
        badgeCount: Int
    ) {
        val intent = Intent(INTENT_ACTION)
        intent.putExtra(INTENT_EXTRA_PACKAGE_NAME, componentName.packageName)
        intent.putExtra(INTENT_EXTRA_ACTIVITY_NAME, componentName.className)
        intent.putExtra(INTENT_EXTRA_MESSAGE, badgeCount.toString())
        intent.putExtra(INTENT_EXTRA_SHOW_MESSAGE, badgeCount > 0)
        context.sendBroadcast(intent)
    }

    /**
     * Send request to Sony badge content provider to set badge in Sony home launcher.
     *
     * @param context       the context to use
     * @param componentName the componentName to use
     * @param badgeCount    the badge count
     */
    private fun executeBadgeByContentProvider(
        context: Context,
        componentName: ComponentName,
        badgeCount: Int
    ) {
        if (badgeCount < 0) {
            return
        }
        val contentValues = createContentValues(badgeCount, componentName)
        if (Looper.myLooper() == Looper.getMainLooper()) {
            // We're in the main thread. Let's ensure the badge update happens in a background
            // thread by using an AsyncQueryHandler and an async update.
            if (mQueryHandler == null) {
                mQueryHandler = @SuppressLint("HandlerLeak")
                object : AsyncQueryHandler(
                    context.applicationContext.contentResolver
                ) {}
            }
            insertBadgeAsync(contentValues)
        } else {
            // Already in a background thread. Let's update the badge synchronously. Otherwise,
            // if we use the AsyncQueryHandler, this thread may already be dead by the time the
            // async execution finishes, which will lead to an IllegalStateException.
            insertBadgeSync(context, contentValues)
        }
    }

    /**
     * Asynchronously inserts the badge counter.
     *
     * @param contentValues Content values containing the badge count, package and activity names
     */
    private fun insertBadgeAsync(contentValues: ContentValues) {
        mQueryHandler?.startInsert(0, null, BADGE_CONTENT_URI, contentValues)
    }

    /**
     * Synchronously inserts the badge counter.
     *
     * @param context       Caller context
     * @param contentValues Content values containing the badge count, package and activity names
     */
    private fun insertBadgeSync(context: Context, contentValues: ContentValues) {
        context.applicationContext.contentResolver.insert(BADGE_CONTENT_URI, contentValues)
    }

    /**
     * Creates a ContentValues object to be used in the badge counter update. The package and
     * activity names must correspond to an activity that holds an intent filter with action
     * "android.intent.action.MAIN" and category android.intent.category.LAUNCHER" in the manifest.
     * Also, it is not allowed to publish badges on behalf of another client, so the package and
     * activity names must belong to the process from which the insert is made.
     * To be able to insert badges, the app must have the PROVIDER_INSERT_BADGE
     * permission in the manifest file. In case these conditions are not
     * fulfilled, or any content values are missing, there will be an unhandled
     * exception on the background thread.
     *
     * @param badgeCount    the badge count
     * @param componentName the component name from which package and class name will be extracted
     */
    private fun createContentValues(badgeCount: Int, componentName: ComponentName): ContentValues {
        val contentValues = ContentValues()
        contentValues.put(PROVIDER_COLUMNS_BADGE_COUNT, badgeCount)
        contentValues.put(PROVIDER_COLUMNS_PACKAGE_NAME, componentName.packageName)
        contentValues.put(PROVIDER_COLUMNS_ACTIVITY_NAME, componentName.className)
        return contentValues
    }

    /**
     * Check if the latest Sony badge content provider exists .
     *
     * @param context the context to use
     * @return true if Sony badge content provider exists, otherwise false.
     */
    private fun sonyBadgeContentProviderExists(context: Context): Boolean {
        var exists = false
        val info = context.packageManager.resolveContentProvider(SONY_HOME_PROVIDER_NAME, 0)
        if (info != null) {
            exists = true
        }
        return exists
    }
}