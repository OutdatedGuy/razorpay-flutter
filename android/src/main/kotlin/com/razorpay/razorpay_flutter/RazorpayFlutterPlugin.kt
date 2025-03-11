package com.razorpay.razorpay_flutter

import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class RazorpayFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private var razorpayDelegate: RazorpayDelegate? = null
    private var pluginBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val channel = MethodChannel(binding.binaryMessenger, "razorpay_flutter")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "open" -> razorpayDelegate?.openCheckout(call.arguments as Map<String, Any>, result)
            "resync" -> razorpayDelegate?.resync(result)
            else -> result.notImplemented()
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        razorpayDelegate = RazorpayDelegate(binding.activity)
        pluginBinding = binding
        razorpayDelegate?.setPackageName(binding.activity.packageName)
        binding.addActivityResultListener(razorpayDelegate!!)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        pluginBinding?.removeActivityResultListener(razorpayDelegate!!)
        pluginBinding = null
    }
}
