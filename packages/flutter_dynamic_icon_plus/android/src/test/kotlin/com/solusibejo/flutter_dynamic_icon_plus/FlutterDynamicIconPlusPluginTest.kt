package com.solusibejo.flutter_dynamic_icon_plus

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.os.Bundle
import android.os.Build
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentMatchers.*
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [24, 33], manifest = Config.NONE)
class FlutterDynamicIconPlusPluginTest {
    private val pkg = "test.raft.isolated"
    private val yellow = "fixed.namespace.IconYellow"
    private val blue = "fixed.namespace.IconBlue"
    private val main = "fixed.namespace.MainActivity"
    private lateinit var context: Context
    private lateinit var pm: PackageManager
    private val states = linkedMapOf<ComponentName, Int>()
    private var calls = 0
    private var failOnce = false
    private var noEntryObserved = false
    private lateinit var infos: List<ActivityInfo>

    @Before fun setup() {
        context = mock(Context::class.java); pm = mock(PackageManager::class.java)
        `when`(context.packageName).thenReturn(pkg)
        `when`(context.packageManager).thenReturn(pm)
        infos = listOf(yellow, blue, main).map { name -> ActivityInfo().apply {
            this.name = name; packageName = pkg; enabled = name != blue
            if (name != main) targetActivity = main
        }}
        infos.forEach { states[ComponentName(pkg, it.name)] = PackageManager.COMPONENT_ENABLED_STATE_DEFAULT }
        val app = ApplicationInfo().apply { metaData = Bundle().apply {
            putString("flutter_dynamic_icon_plus.default_alias", yellow)
            putString("flutter_dynamic_icon_plus.allowed_aliases", "$yellow,$blue")
        }}
        `when`(pm.getApplicationInfo(eq(pkg), eq(PackageManager.GET_META_DATA))).thenReturn(app)
        `when`(pm.queryIntentActivities(any(Intent::class.java), eq(PackageManager.MATCH_DISABLED_COMPONENTS)))
            .thenReturn(infos.map { info -> ResolveInfo().apply { activityInfo = info } })
        `when`(pm.getComponentEnabledSetting(any(ComponentName::class.java))).thenAnswer {
            states.getValue(it.getArgument(0))
        }
        doAnswer { invocation ->
            calls++
            val component = invocation.getArgument<ComponentName>(0)
            assertNotEquals(main, component.className)
            assertEquals(PackageManager.DONT_KILL_APP, invocation.getArgument<Int>(2))
            states[component] = invocation.getArgument(1)
            recordVisibility()
            if (failOnce && component.className == yellow) { failOnce = false; error("injected partial failure") }
            null
        }.`when`(pm).setComponentEnabledSetting(any(ComponentName::class.java), anyInt(), anyInt())
        if (Build.VERSION.SDK_INT >= 33) {
        doAnswer { invocation ->
            calls++
            val batch = invocation.getArgument<List<PackageManager.ComponentEnabledSetting>>(0)
            assertEquals(setOf(yellow, blue), batch.map { requireNotNull(it.componentName).className }.toSet())
            batch.forEach { assertEquals(PackageManager.DONT_KILL_APP, it.enabledFlags); states[requireNotNull(it.componentName)] = it.enabledState }
            recordVisibility()
            if (failOnce) { failOnce = false; error("injected partial failure") }
            null
        }.`when`(pm).setComponentEnabledSettings(anyList())
        }
    }
    private fun recordVisibility() {
        val enabled = infos.filter { it.targetActivity != null }.filter {
            val state = states.getValue(ComponentName(pkg, it.name))
            state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && it.enabled
        }
        if (enabled.isEmpty()) noEntryObserved = true
    }
    @Test fun switchesAndRestoresDefaultWithoutDisablingMainActivity() {
        assertEquals(yellow, ComponentUtil.current(context))
        assertEquals(blue, ComponentUtil.select(context, blue))
        assertEquals(blue, ComponentUtil.current(context))
        assertEquals(yellow, ComponentUtil.select(context, null))
        assertEquals(PackageManager.COMPONENT_ENABLED_STATE_DEFAULT, states[ComponentName(pkg, main)])
        assertFalse(noEntryObserved)
        if (Build.VERSION.SDK_INT >= 33) verify(pm, times(2)).setComponentEnabledSettings(anyList())
        else assertEquals(4, calls)
    }
    @Test fun failureRestoresActualComponentsAndKeepsAnEntryThroughout() {
        val before = states.toMap(); failOnce = true
        try { ComponentUtil.select(context, blue); fail("Expected failure") } catch (_: IllegalStateException) {}
        assertEquals(before, states); assertEquals(yellow, ComponentUtil.current(context))
        assertFalse(noEntryObserved)
    }
    @Test fun rejectsActivityAndUnknownAliasBeforeChangingAnything() {
        for (name in listOf(main, "not.declared.Icon")) {
            try { ComponentUtil.select(context, name); fail("Expected rejection") } catch (_: IllegalArgumentException) {}
        }
        assertEquals(0, calls); assertEquals(yellow, ComponentUtil.current(context))
    }
}
