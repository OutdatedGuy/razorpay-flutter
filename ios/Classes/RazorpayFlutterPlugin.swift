import Flutter
import Razorpay

public class RazorpayFlutterPlugin: NSObject, FlutterPlugin {

    private var razorpayDelegate = RazorpayDelegate()
    private static var CHANNEL_NAME = "razorpay_flutter";

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: CHANNEL_NAME, binaryMessenger: registrar.messenger())
        let instance = RazorpayFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "open":
            let options = call.arguments as! Dictionary<String, Any>
            razorpayDelegate.open(options: options, result: result);
            break;
        case "resync":
            razorpayDelegate.resync(result: result)
            break
        default:
            print("no method")
        }
    }
}
