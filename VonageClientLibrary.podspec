Pod::Spec.new do |spec|
    spec.name         = "VonageClientLibrary"
    spec.version      = "1.0.3-beta1"
    spec.summary      = "A library to support using the Vonage APIs on iOS"
    spec.homepage     = "https://github.com/Vonage/vonage-ios-client-library"
    spec.license      = { :type => "Apache 2.0", :file => "LICENSE" }
    spec.author             = { "author" => "devrel@vonage.com" }
    spec.documentation_url = "https://github.com/Vonage/vonage-ios-client-library/blob/main/README.md"
    spec.platforms = { :ios => "13.0" }
    spec.swift_version = "5.9"
    spec.source       = { :git => "https://github.com/Vonage/vonage-ios-client-library.git", :tag => "#{spec.version}" }
    spec.source_files  = "Sources/VonageClientLibrary/**/*.swift"
    spec.xcconfig = { "SWIFT_VERSION" => "5.9" }
end
