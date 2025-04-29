import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

/// JS interop for Razorpay
@JS('Razorpay')
external JSRazorpay _razorpayFactory(JSAny options);

@JS()
@staticInterop
class JSRazorpay {}

extension JSRazorpayExt on JSRazorpay {
  external void on(String event, JSFunction handler);
  external void open();
}

class RazorpayFlutterPlugin {
  // Response codes from platform
  static const _codePaymentSuccess = 0;
  static const _codePaymentError = 1;

  // Payment error codes
  static const networkError = 0;
  static const invalidOptions = 1;
  static const paymentCancelled = 2;
  static const tlsError = 3;
  static const incompatiblePlugin = 4;
  static const unknownError = 100;

  static void registerWith(Registrar registrar) {
    final methodChannel = MethodChannel(
      'razorpay_flutter',
      const StandardMethodCodec(),
      registrar,
    );
    final instance = RazorpayFlutterPlugin();
    methodChannel.setMethodCallHandler(instance.handleMethodCall);
  }

  /// Handles method calls from the platform channel.
  Future<Map<dynamic, dynamic>> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'open':
        return await startPayment(call.arguments as Map<dynamic, dynamic>);
      case 'resync':
        // Web does not persist payment state, so always return null for resync
        return {'type': null, 'data': null};
      default:
        return {'status': 'Not implemented on web'};
    }
  }

  Future<Map<dynamic, dynamic>> startPayment(
    Map<dynamic, dynamic> options,
  ) async {
    final completer = Completer<Map<dynamic, dynamic>>();
    final returnMap = <dynamic, dynamic>{};
    final dataMap = <dynamic, dynamic>{};

    // Ensure Razorpay script is loaded only once
    if (web.document.getElementById('rzp-jssdk') == null) {
      final script =
          web.document.createElement('script') as web.HTMLScriptElement;
      script.id = 'rzp-jssdk';
      script.src = 'https://checkout.razorpay.com/v1/checkout.js';
      script.async = true;
      script.addEventListener(
        'load',
        (JSAny? event) {
          _launchRazorpay(options, completer, returnMap, dataMap);
        }.toJS,
      );
      script.addEventListener(
        'error',
        (JSAny? event) {
          if (!completer.isCompleted) {
            returnMap['type'] = _codePaymentError;
            dataMap['code'] = networkError;
            dataMap['message'] = 'Failed to load Razorpay SDK';
            returnMap['data'] = dataMap;
            completer.complete(returnMap);
          }
        }.toJS,
      );
      web.document.head!.appendChild(script);
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
    // Handler for payment success
    options['handler'] = (JSAny response) {
      final responseMap =
          Map<String, dynamic>.from(response.dartify() as Map? ?? {});
      returnMap['type'] = _codePaymentSuccess;
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
        dataMap['code'] = paymentCancelled;
        dataMap['message'] = 'Payment processing cancelled by user';
        returnMap['data'] = dataMap;
        completer.complete(returnMap);
      }
    }.toJS;

    // Retry logic
    final retry = options['retry'];
    if (retry is Map && retry['enabled'] == true) {
      options['retry'] = true;
    } else {
      options['retry'] = false;
    }

    final jsOptions = options.jsify();
    final razorpay = _razorpayFactory(jsOptions!);

    // Payment failed handler
    razorpay.on(
      'payment.failed',
      ((JSAny response) {
        returnMap['type'] = _codePaymentError;
        final responseMap =
            Map<String, dynamic>.from(response.dartify() as Map? ?? {});
        final error = responseMap['error'];
        dataMap['code'] = error['code'];
        dataMap['message'] = error['description'];
        dataMap['metadata'] = {
          'order_id': error['metadata']?['order_id'],
          'payment_id': error['metadata']?['payment_id'],
        };
        dataMap['source'] = error['source'];
        dataMap['step'] = error['step'];
        returnMap['data'] = dataMap;
        if (!completer.isCompleted) completer.complete(returnMap);
      }).toJS,
    );

    razorpay.open();
  }
}
