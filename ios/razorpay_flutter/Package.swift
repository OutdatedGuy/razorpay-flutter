// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "razorpay_flutter",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "razorpay-flutter", targets: ["razorpay_flutter"])
    ],
    dependencies: [
        .package(url: "https://github.com/razorpay/razorpay-pod.git", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "razorpay_flutter",
            dependencies: [
                .product(name: "RazorpayCheckout", package: "razorpay-pod"),
            ],
            resources: []
        )
    ]
)
