import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'package:web/web.dart';

/// A JS interop class for Razorpay
@JS('Razorpay')
@staticInterop
class JSRazorpay {
  /// Constructor for Razorpay
  external factory JSRazorpay(JSAny options);
}

/// A utility extension to define the JS methods for Razorpay
extension JSRazorpayExt on JSRazorpay {
  /// This method is used to set the event handlers for Razorpay
  external void on(String event, JSFunction handler);

  /// This method is used to open the Razorpay checkout modal
  external void open();
}

/// This class is used to handle Razorpay payment processing on the web.
class RazorpayFlutterWeb {
  // Response codes from platform
  static const _codePaymentSuccess = 0;
  static const _codePaymentError = 1;

  // Payment error codes
  static const networkError = 0;
  static const invalidOptions = 1;
  static const paymentCancelled = 2;
  static const tlsError = 3;
  static const incompatiblePlugin = 3;
  static const unknownError = 100;

  // Translates the error codes (string) to integers
  static int _translateErrorCode(String errorCode) {
    switch (errorCode) {
      case 'NETWORK_ERROR':
        return networkError;
      case 'BAD_REQUEST_ERROR':
        return invalidOptions;
      case 'PAYMENT_CANCELLED':
        return paymentCancelled;
      case 'TLS_ERROR':
        return tlsError;
      default:
        return unknownError;
    }
  }

  static void registerWith(Registrar registrar) {
    final methodChannel = MethodChannel(
      'razorpay_flutter',
      const StandardMethodCodec(),
      registrar,
    );
    final instance = RazorpayFlutterWeb();
    methodChannel.setMethodCallHandler(instance.handleMethodCall);
  }

  /// Handles method calls from the platform channel.
  Future<Map<dynamic, dynamic>?> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'open':
        return await startPayment(call.arguments as Map<dynamic, dynamic>);
      case 'resync':
        return null;
      default:
        return {
          'type': _codePaymentError,
          'data': {
            'code': unknownError,
            'message': 'Unknown method called: ${call.method}'
          }
        };
    }
  }

  Future<Map<dynamic, dynamic>> startPayment(
    Map<dynamic, dynamic> options,
  ) async {
    final completer = Completer<Map<dynamic, dynamic>>();
    final returnMap = <dynamic, dynamic>{};
    final dataMap = <dynamic, dynamic>{};

    // Ensure Razorpay script is loaded only once
    final rzpScript = document.querySelector(
      'script[src="https://checkout.razorpay.com/v1/checkout.js"]',
    );
    if (rzpScript == null) {
      final script = document.createElement('script') as HTMLScriptElement;
      script.src = 'https://checkout.razorpay.com/v1/checkout.js';
      script.async = true;
      script.crossOrigin = 'anonymous';
      script.addEventListener(
        'load',
        (Event event) {
          _launchRazorpay(options, completer, returnMap, dataMap);
        }.toJS,
      );
      script.addEventListener(
        'error',
        (Event event) {
          if (!completer.isCompleted) {
            returnMap['type'] = _codePaymentError;
            dataMap['code'] = networkError;
            dataMap['message'] = 'Failed to load Razorpay SDK.';
            returnMap['data'] = dataMap;
            completer.complete(returnMap);
          }
        }.toJS,
      );
      document.head!.appendChild(script);
    } else {
      _launchRazorpay(options, completer, returnMap, dataMap);
    }
    return completer.future;
  }

  void _launchRazorpay(
    Map<dynamic, dynamic> options,
    Completer<Map<dynamic, dynamic>> completer,
    Map<dynamic, dynamic> returnMap,
    Map<dynamic, dynamic> dataMap,
  ) {
    // Retry logic
    final retry = options['retry'];
    if (retry is Map && retry['enabled'] == true) {
      options['retry'] = true;
    } else {
      options['retry'] = false;
    }

    // Handler for payment success
    options['handler'] = (JSAny jsRes) {
      returnMap['type'] = _codePaymentSuccess;

      final responseMap = Map<String, dynamic>.from(jsRes.dartify() as Map);

      dataMap['razorpay_payment_id'] = responseMap['razorpay_payment_id'];
      dataMap['razorpay_order_id'] = responseMap['razorpay_order_id'];
      dataMap['razorpay_signature'] = responseMap['razorpay_signature'];

      returnMap['data'] = dataMap;

      if (!completer.isCompleted) completer.complete(returnMap);
    }.toJS;

    // Handler for modal dismiss
    options['modal.ondismiss'] = () {
      if (!completer.isCompleted) {
        returnMap['type'] = _codePaymentError;

        const message = 'Payment processing cancelled by user';

        dataMap['code'] = paymentCancelled;
        dataMap['message'] = message;
        dataMap['responseBody'] = {
          'error': {
            'code': 'PAYMENT_CANCELLED',
            'description': message,
            'source': 'customer',
            'step': 'payment_authentication',
            'reason': 'payment_cancelled'
          },
          'name': '',
          'email': '',
          'contact': '',
        };

        returnMap['data'] = dataMap;

        completer.complete(returnMap);
      }
    }.toJS;

    final jsOptions = options.jsify();
    final razorpay = JSRazorpay(jsOptions!);

    // Payment failed handler
    razorpay.on(
      'payment.failed',
      (JSAny jsRes) {
        if (options['retry'] == true) return;

        returnMap['type'] = _codePaymentError;

        final responseMap = Map<String, dynamic>.from(jsRes.dartify() as Map);
        final error = Map<String, dynamic>.from(responseMap['error']);

        dataMap['code'] = _translateErrorCode(error['code']);
        dataMap['message'] = error['description'];
        dataMap['responseBody'] = {
          ...error,
          'name': '',
          'email': '',
          'contact': '',
        };

        returnMap['data'] = dataMap;

        if (!completer.isCompleted) completer.complete(returnMap);
      }.toJS,
    );

    razorpay.open();
  }
}
