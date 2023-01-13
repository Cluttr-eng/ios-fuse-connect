Pod::Spec.new do |spec|
    spec.name         = "FuseConnect"
    spec.version      = "0.0.1"
    spec.summary      = "FuseConnect iOS SDK"
    spec.description  = <<-DESC
    FuseConnect iOS SDK
    DESC
    spec.homepage     = "https://github.com/Cluttr-eng/ios-fuse-connect"
    spec.license      = { :type => "MIT", :file => "LICENSE" }
    spec.author             = { "letsfuse" => "support@letsfuse.com" }
    spec.documentation_url = "https://letsfuse.readme.io/docs/ios"
    spec.platforms = { :ios => "13.0" }
    spec.source       = { :git => "https://github.com/Cluttr-eng/ios-fuse-connect.git", :tag => "#{spec.version}" }
    spec.source_files  = "Sources/PackageName/**/*.swift"
end
