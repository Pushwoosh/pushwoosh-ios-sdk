#
#  Be sure to run `pod spec lint Pushwoosh.podspec' to ensure this is a
#

Pod::Spec.new do |s|

  s.name         = "PushwooshXCFramework"
  s.version      = "6.10.0"
  s.summary      = "Push notifications library by Pushwoosh."
  s.platform     = :ios

  s.description  = "Push notifications iOS library by Pushwoosh - cross platform push notifications service. " \
                   "http://www.pushwoosh.com "

  s.homepage     = "http://www.pushwoosh.com"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }

  s.author       = { "Max Konev" => "max@pushwoosh.com" }
  s.source       = { :git => "https://github.com/Pushwoosh/pushwoosh-ios-sdk.git", :tag => s.version }

  s.requires_arc = true
  s.xcconfig = { 'OTHER_LDFLAGS' => '-ObjC' }
  s.default_subspec = 'Core'
  s.ios.deployment_target = "11.0"

  # Core Subspec 
  s.subspec 'Core' do |core|
    core.ios.vendored_frameworks  = 'XCFramework/PushwooshFramework.xcframework'
    core.library  = 'c++', 'z'
    core.frameworks  = 'Security', 'StoreKit'
    core.dependency 'PushwooshXCFramework/PushwooshCore'
    core.dependency 'PushwooshXCFramework/PushwooshBridge'
    core.dependency 'PushwooshXCFramework/PushwooshLiveActivities'
  end

  s.subspec 'PushwooshCore' do |corep|
    corep.vendored_frameworks = 'XCFramework/PushwooshCore.xcframework'
  end

  # PushwooshBridge Subspec
  s.subspec 'PushwooshBridge' do |bridge|
    bridge.dependency 'PushwooshXCFramework/PushwooshCore'
    bridge.vendored_frameworks = 'XCFramework/PushwooshBridge.xcframework'
  end

  # PushwooshLiveActivities 
  s.subspec 'PushwooshLiveActivities' do |activities|
    activities.dependency 'PushwooshXCFramework/PushwooshCore'
    activities.dependency 'PushwooshXCFramework/PushwooshBridge'
    activities.vendored_frameworks = 'XCFramework/PushwooshLiveActivities.xcframework'
  end

  # PushwooshVoIP subspec (optional)
  s.subspec 'PushwooshVoIP' do |voip|
    voip.dependency 'PushwooshXCFramework/PushwooshCore'
    voip.dependency 'PushwooshXCFramework/PushwooshBridge'
    voip.vendored_frameworks = 'XCFramework/PushwooshVoIP.xcframework'
  end

  # PushwooshForegroundPush subspec (optional)
  s.subspec 'PushwooshForegroundPush' do |foreground|
    foreground.dependency 'PushwooshXCFramework/PushwooshCore'
    foreground.dependency 'PushwooshXCFramework/PushwooshBridge'
    foreground.vendored_frameworks = 'XCFramework/PushwooshForegroundPush.xcframework'
  end

  # Geozones Subspec
  s.subspec 'Geozones' do |geozones|
    geozones.ios.vendored_frameworks  = 'XCFramework/PushwooshGeozones.xcframework'
    geozones.frameworks  = 'CoreLocation'
    geozones.dependency 'PushwooshXCFramework/Core'
  end

end
