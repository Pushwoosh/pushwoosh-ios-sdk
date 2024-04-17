#
#  Be sure to run `pod spec lint PushwooshVisionXCFramework.podspec' to ensure this is a
#

Pod::Spec.new do |s|

  s.name         = "PushwooshVisionXCFramework"
  s.version      = "1.0.0"
  s.summary      = "Push notifications library by Pushwoosh."
  s.platform     = :visionos

  s.description  = "Push notifications visionOS library by Pushwoosh - cross platform push notifications service. " \
                   "http://www.pushwoosh.com "

  s.homepage     = "http://www.pushwoosh.com"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }

  s.author       = { "Andrew Kiselev" => "akiselev@pushwoosh.com" }
  s.source       = { :git => "https://github.com/Pushwoosh/pushwoosh-vision-sdk.git", :tag => s.version }

  s.requires_arc = true
  s.xcconfig = { 'OTHER_LDFLAGS' => '-ObjC' }
  s.default_subspec = 'Core'
  s.visionos.deployment_target = "1.1"

  s.subspec 'Core' do |core|
    core.visionos.vendored_frameworks  = 'XCFramework/Pushwoosh.xcframework'
    core.library  = 'c++', 'z'
    core.frameworks  = 'Security', 'StoreKit'
  end

end
