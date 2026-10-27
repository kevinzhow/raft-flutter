package me.liolin.app_badge_plus.badge

import android.content.Context

import androidx.annotation.Keep;

@Keep
interface IBadge {

    /**
     * Update notification badge count
     *
     * @param context     context
     * @param count       badge count
     */
    fun updateBadge(context: Context, count: Int)

    /**
     * Get launchers which support badge
     *
     * @return supported launchers package name list
     */
    fun getSupportLaunchers(): List<String>
}