#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint razorpay_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'razorpay_flutter'
  s.version          = '1.1.10'
  s.summary          = 'Flutter plugin for Razorpay SDK.'
  s.description      = <<-DESC
Flutter plugin for Razorpay SDK. To know more about Razorpay, visit https://razorpay.com.
                       DESC
  s.homepage         = 'https://github.com/razorpay/razorpay-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Chintan Acharya' => 'chintan.acharya@razorpay.com' }
  s.source           = { :path => '.' }
  s.source_files = 'razorpay_flutter/Sources/razorpay_flutter/**/*'
  s.dependency 'Flutter'
  s.dependency 'razorpay-pod', '~> 1.4'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = {'razorpay_flutter_privacy' => ['razorpay_flutter/Sources/razorpay_flutter/PrivacyInfo.xcprivacy']}
end
