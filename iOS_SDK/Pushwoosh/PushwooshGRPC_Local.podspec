Pod::Spec.new do |s|
  s.name         = "PushwooshGRPC_Local"
  s.version      = "1.0.0"
  s.summary      = "gRPC transport module for Pushwoosh SDK"
  s.description  = <<-DESC
                   Optional gRPC transport module for Pushwoosh iOS SDK.
                   When linked, SDK can use gRPC instead of REST for network requests.
                   DESC
  s.homepage     = "https://www.pushwoosh.com"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Pushwoosh" => "support@pushwoosh.com" }

  s.ios.deployment_target = "13.0"
  s.swift_version = "5.0"

  s.source       = { :git => ".", :tag => s.version.to_s }
  s.source_files = "PushwooshGRPC/**/*.{h,m,swift}"

  s.dependency "PushwooshCore_Local"
  s.dependency "PushwooshBridge_Local"
  s.dependency "SwiftProtobuf", "~> 1.0"

  s.frameworks = "Foundation"
end
