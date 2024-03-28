import 'package:flutter/services.dart';
import 'package:eventify/eventify.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;

class Razorpay {
  // Response codes from platform
  static const _codePaymentSuccess = 0;
  static const _codePaymentError = 1;
  static const _codePaymentExternalWallet = 2;

  // Event names
  static const eventPaymentSuccess = 'payment.success';
  static const eventPaymentError = 'payment.error';
  static const eventExternalWallet = 'payment.external_wallet';

  // Payment error codes
  static const networkError = 0;
  static const invalidOptions = 1;
  static const paymentCancelled = 2;
  static const tlsError = 3;
  static const incompatiblePlugin = 4;
  static const unknownError = 100;

  static const MethodChannel _channel = MethodChannel('razorpay_flutter');

  // EventEmitter instance used for communication
  late EventEmitter _eventEmitter;

  Razorpay() {
    _eventEmitter = EventEmitter();
  }

  /// Opens Razorpay checkout
  void open(Map<String, dynamic> options) async {
    Map<String, dynamic> validationResult = _validateOptions(options);

    if (!validationResult['success']) {
      _handleResult({
        'type': _codePaymentError,
        'data': {
          'code': invalidOptions,
          'message': validationResult['message'],
        },
      });
      return;
    }
    if (Platform.isAndroid) {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      _channel.invokeMethod('setPackageName', packageInfo.packageName);
    }

    var response = await _channel.invokeMethod('open', options);
    _handleResult(response);
  }

  /// Handles checkout response from platform
  void _handleResult(Map<dynamic, dynamic> response) {
    String eventName;
    Map<dynamic, dynamic>? data = response["data"];

    dynamic payload;

    switch (response['type']) {
      case _codePaymentSuccess:
        eventName = eventPaymentSuccess;
        payload = PaymentSuccessResponse.fromMap(data!);
        break;

      case _codePaymentError:
        eventName = eventPaymentError;
        payload = PaymentFailureResponse.fromMap(data!);
        break;

      case _codePaymentExternalWallet:
        eventName = eventExternalWallet;
        payload = ExternalWalletResponse.fromMap(data!);
        break;

      default:
        eventName = 'error';
        payload = PaymentFailureResponse(
          unknownError,
          'An unknown error occurred.',
          null,
        );
    }

    _eventEmitter.emit(eventName, null, payload);
  }

  /// Registers event listeners for payment events
  void on(String event, Function handler) {
    void cb(Event event, Object? cont) {
      handler(event.eventData);
    }

    _eventEmitter.on(event, null, cb);
    _resync();
  }

  /// Clears all event listeners
  void clear() {
    _eventEmitter.clear();
  }

  /// Retrieves lost responses from platform
  void _resync() async {
    var response = await _channel.invokeMethod('resync');
    if (response != null) {
      _handleResult(response);
    }
  }

  /// Validate payment options
  static Map<String, dynamic> _validateOptions(Map<String, dynamic> options) {
    var key = options['key'];
    if (key == null) {
      return {
        'success': false,
        'message':
            'Key is required. Please check if key is present in options.',
      };
    }
    return {'success': true};
  }
}

class PaymentSuccessResponse {
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final Map<dynamic, dynamic>? data;

  PaymentSuccessResponse(
    this.paymentId,
    this.orderId,
    this.signature,
    this.data,
  );

  static PaymentSuccessResponse fromMap(Map<dynamic, dynamic> map) {
    final String? paymentId = map["razorpay_payment_id"];
    final String? signature = map["razorpay_signature"];
    final String? orderId = map["razorpay_order_id"];

    final Map<dynamic, dynamic> data = map;

    return PaymentSuccessResponse(paymentId, orderId, signature, data);
  }
}

class PaymentFailureResponse {
  final int? code;
  final String? message;
  final Map<dynamic, dynamic>? error;

  PaymentFailureResponse(this.code, this.message, this.error);

  static PaymentFailureResponse fromMap(Map<dynamic, dynamic> map) {
    final int? code = map["code"];
    final String? message = map["message"];
    final dynamic responseBody = map["responseBody"];

    if (responseBody is Map<dynamic, dynamic>) {
      return PaymentFailureResponse(code, message, responseBody);
    } else {
      final errorMap = {"reason": responseBody};
      return PaymentFailureResponse(code, message, errorMap);
    }
  }
}

class ExternalWalletResponse {
  final String? walletName;

  ExternalWalletResponse(this.walletName);

  static ExternalWalletResponse fromMap(Map<dynamic, dynamic> map) {
    final String? walletName = map["external_wallet"];
    return ExternalWalletResponse(walletName);
  }
}
