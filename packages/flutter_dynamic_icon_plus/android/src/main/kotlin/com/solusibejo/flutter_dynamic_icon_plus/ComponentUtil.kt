package com.solusibejo.flutter_dynamic_icon_plus

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.os.Build

/** Launcher aliases only: never disable an Activity carrying external intents. */
object ComponentUtil {
    private const val DEFAULT_ALIAS = "flutter_dynamic_icon_plus.default_alias"
    private const val ALLOWED_ALIASES = "flutter_dynamic_icon_plus.allowed_aliases"

    private fun metadata(context: Context) = context.packageManager
        .getApplicationInfo(context.packageName, PackageManager.GET_META_DATA).metaData

    private fun aliases(context: Context): List<ActivityInfo> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            .setPackage(context.packageName)
        val allowed = metadata(context)?.getString(ALLOWED_ALIASES)?.split(',')?.toSet()
        return context.packageManager.queryIntentActivities(intent, PackageManager.MATCH_DISABLED_COMPONENTS)
            .map { it.activityInfo }
            .filter { it.targetActivity != null && (allowed == null || it.name in allowed) }
            .distinctBy { it.name }
    }

    private fun enabled(context: Context, alias: ActivityInfo): Boolean = when (
        context.packageManager.getComponentEnabledSetting(ComponentName(context.packageName, alias.name))
    ) {
        PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
        PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> alias.enabled
        else -> false
    }

    fun supports(context: Context) = aliases(context).size > 1

    fun current(context: Context): String {
        val active = aliases(context).filter { enabled(context, it) }
        check(active.size == 1) { "Expected exactly one enabled launcher alias" }
        return active.single().name
    }

    fun select(context: Context, requested: String?): String {
        val available = aliases(context)
        val target = requested ?: metadata(context)?.getString(DEFAULT_ALIAS)
            ?: error("A default launcher alias must be configured")
        require(available.any { it.name == target }) { "Unknown launcher alias" }
        val pm = context.packageManager
        val before = available.associate { alias ->
            val component = ComponentName(context.packageName, alias.name)
            component to pm.getComponentEnabledSetting(component)
        }
        val desired = before.keys.associateWith { component ->
            if (component.className == target) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }
        try {
            apply(pm, desired)
            check(current(context) == target) { "Launcher alias readback mismatch" }
        } catch (failure: Exception) {
            // Older releases enable the previous live alias first during recovery.
            try {
                if (Build.VERSION.SDK_INT < 33) {
                    for (alias in available) {
                        val component = ComponentName(context.packageName, alias.name)
                        val previous = before.getValue(component)
                        if (previous == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                            previous == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && alias.enabled) {
                            pm.setComponentEnabledSetting(component, PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                                PackageManager.DONT_KILL_APP)
                        }
                    }
                }
                apply(pm, before)
            } catch (rollback: Exception) {
                failure.addSuppressed(rollback)
            }
            throw failure
        }
        return target
    }

    private fun apply(pm: PackageManager, states: Map<ComponentName, Int>) {
        if (Build.VERSION.SDK_INT >= 33) {
            pm.setComponentEnabledSettings(states.map { (component, state) ->
                PackageManager.ComponentEnabledSetting(component, state, PackageManager.DONT_KILL_APP)
            })
        } else {
            // Enable first; interruption can leave duplicates, never zero entries.
            for ((component, state) in states.entries.sortedBy { if (it.value == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) 0 else 1 }) {
                pm.setComponentEnabledSetting(component, state, PackageManager.DONT_KILL_APP)
            }
        }
    }
}
