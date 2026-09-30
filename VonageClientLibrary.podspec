Pod::Spec.new do |spec|
    version_file = File.read(File.join(__dir__, "Sources/VonageClientLibrary/SDKVersion.swift"))
    match = version_file.match(/static let current = "([^"]+)"/)
    raise "Unable to determine SDK version from SDKVersion.swift" unless match

    spec.name         = "VonageClientLibrary"
    spec.version      = match[1]
    spec.summary      = "A library to support using the Vonage APIs on iOS"
    spec.homepage     = "https://github.com/Vonage/vonage-ios-client-library"
    spec.license      = { :type => "Apache 2.0", :file => "LICENSE" }
    spec.authors             = { "author" => "devrel@vonage.com" ,
                                 "Chris Tankersley" => "chris.tankersley@vonage.com" }
    spec.documentation_url = "https://github.com/Vonage/vonage-ios-client-library/blob/main/README.md"
    spec.platforms = { :ios => "13.0" }
    spec.swift_version = "5.9"
    spec.source       = { :git => "https://github.com/Vonage/vonage-ios-client-library.git", :tag => "#{spec.version}" }
    spec.source_files  = "Sources/VonageClientLibrary/**/*.swift"
    spec.xcconfig = { "SWIFT_VERSION" => "5.9" }
end
