package com.razorpay.razorpay_flutter

import android.app.Activity
import android.content.Intent

import com.razorpay.Checkout
import com.razorpay.CheckoutActivity
import com.razorpay.ExternalWalletListener
import com.razorpay.PaymentData
import com.razorpay.PaymentResultWithDataListener

import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener

import java.lang.reflect.Method

import org.json.JSONException
import org.json.JSONObject

class RazorpayDelegate(private val activity: Activity) :
    ActivityResultListener,
    ExternalWalletListener,
    PaymentResultWithDataListener {

    private var pendingResult: Result? = null
    private var pendingReply: Map<String, Any>? = null
    private var packageName: String? = null

    companion object {
        // Response codes for communicating with plugin
        private const val CODE_PAYMENT_SUCCESS = 0
        private const val CODE_PAYMENT_ERROR = 1
        private const val CODE_PAYMENT_EXTERNAL_WALLET = 2

        // Payment error codes for communicating with plugin
        private const val NETWORK_ERROR = 0
        private const val INVALID_OPTIONS = 1
        private const val PAYMENT_CANCELLED = 2
        private const val TLS_ERROR = 3
        private const val INCOMPATIBLE_PLUGIN = 3
        private const val UNKNOWN_ERROR = 100
    }

    fun setPackageName(packageName: String) {
        this.packageName = packageName
    }

    fun openCheckout(arguments: Map<String, Any>, result: Result) {
        pendingResult = result
        val options = JSONObject(arguments)
        if (activity.packageName.equals(packageName, ignoreCase = true)) {
            val intent = Intent(activity, CheckoutActivity::class.java).apply {
                putExtra("OPTIONS", options.toString())
                putExtra("FRAMEWORK", "flutter")
            }
            activity.startActivityForResult(intent, Checkout.RZP_REQUEST_CODE)
        }
    }

    private fun sendReply(data: Map<String, Any>) {
        pendingResult?.success(data) ?: run { pendingReply = data }
    }

    fun resync(result: Result) {
        result.success(pendingReply)
        pendingReply = null
    }

    private fun translateRzpPaymentError(errorCode: Int): Int = when (errorCode) {
        Checkout.NETWORK_ERROR -> NETWORK_ERROR
        Checkout.INVALID_OPTIONS -> INVALID_OPTIONS
        Checkout.PAYMENT_CANCELED -> PAYMENT_CANCELLED
        Checkout.TLS_ERROR -> TLS_ERROR
        Checkout.INCOMPATIBLE_PLUGIN -> INCOMPATIBLE_PLUGIN
        else -> UNKNOWN_ERROR
    }

    override fun onPaymentError(code: Int, message: String, paymentData: PaymentData) {
        val data = mutableMapOf<String, Any>("code" to translateRzpPaymentError(code))
        try {
            val response = JSONObject(message)
            val errorObj = response.getJSONObject("error")
            data["message"] = errorObj.getString("description")
            val metadata = errorObj.getJSONObject("metadata")
            val metadataHash = mutableMapOf<String, String>()
            for (key in metadata.keys()) {
                metadataHash[key] = metadata.getString(key)
            }
            errorObj.remove("metadata")
            val resp = mutableMapOf<String, Any>()
            for (key in errorObj.keys()) {
                resp[key] = errorObj.get(key)
            }
            resp["metadata"] = metadataHash
            resp["email"] = paymentData.userEmail ?: ""
            resp["contact"] = paymentData.userContact ?: ""
            data["responseBody"] = resp
        } catch (e: JSONException) {
            data["message"] = message
            data["responseBody"] = message
        }
        sendReply(mapOf("type" to CODE_PAYMENT_ERROR, "data" to data))
    }

    override fun onPaymentSuccess(paymentId: String, paymentData: PaymentData) {
        val data = mutableMapOf(
            "razorpay_payment_id" to paymentData.paymentId,
            "razorpay_order_id" to paymentData.orderId,
            "razorpay_signature" to paymentData.signature
        )
        paymentData.data?.optString("razorpay_subscription_id")?.let {
            data["razorpay_subscription_id"] = it
        }
        sendReply(mapOf("type" to CODE_PAYMENT_SUCCESS, "data" to data))
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return try {
            val merchantActivityResult: Method = Checkout::class.java.getMethod(
                "merchantActivityResult", Activity::class.java, Int::class.java,
                Int::class.java, Intent::class.java, PaymentResultWithDataListener::class.java,
                ExternalWalletListener::class.java
            )
            merchantActivityResult.invoke(null, activity, requestCode, resultCode, data, this, this)
            true
        } catch (e: Exception) {
            Checkout.handleActivityResult(activity, requestCode, resultCode, data, this, this)
            true
        }
    }

    override fun onExternalWalletSelected(walletName: String, paymentData: PaymentData) {
        sendReply(mapOf("type" to CODE_PAYMENT_EXTERNAL_WALLET, "data" to mapOf("external_wallet" to walletName)))
    }
}
