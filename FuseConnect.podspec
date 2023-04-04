Pod::Spec.new do |spec|
    spec.name         = "FuseConnect"
    spec.version      = "1.0.2"
    spec.summary      = "FuseConnect iOS SDK"
    spec.description  = <<-DESC
    With just a few simple steps, you can use Fuse Connect SDK to display a list of institutions, 
    handle the user's selection, and obtain an access token that can be used to authenticate requests 
    to the Fuse API.
    DESC
    spec.homepage     = "https://github.com/Cluttr-eng/ios-fuse-connect"
    spec.license      = { :type => "MIT", :file => "LICENSE" }
    spec.author             = { "letsfuse" => "support@letsfuse.com" }
    spec.documentation_url = "https://letsfuse.readme.io/docs/ios"
    spec.platforms = { :ios => "13.0" }
    spec.source       = { :git => "https://github.com/Cluttr-eng/ios-fuse-connect.git", :tag => "#{spec.version}" }
    spec.source_files  = "Sources/onboarding-kit/**/*.swift"
    spec.dependency 'Plaid', '~> 3.1.1'
    spec.swift_version = "5.6.1"
    spec.xcconfig = { "SWIFT_VERSION" => "5.6.1" }
end
