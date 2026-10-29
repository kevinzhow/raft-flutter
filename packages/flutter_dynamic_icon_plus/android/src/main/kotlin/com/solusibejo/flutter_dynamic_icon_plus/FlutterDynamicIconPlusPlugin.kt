package com.solusibejo.flutter_dynamic_icon_plus

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Local patch: synchronous OS readback; no task-removal service or Activity toggle. */
class FlutterDynamicIconPlusPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "flutter_dynamic_icon_plus")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                MethodNames.supportsAlternateIcons -> result.success(ComponentUtil.supports(context))
                MethodNames.getAlternateIconName -> result.success(ComponentUtil.current(context))
                MethodNames.setAlternateIconName -> {
                    ComponentUtil.select(context, call.argument<String>(Arguments.iconName))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("icon_change_failed", "Unable to read or change the launcher icon.", null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
