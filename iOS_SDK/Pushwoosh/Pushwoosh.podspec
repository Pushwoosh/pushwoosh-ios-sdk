#
#  Be sure to run `pod spec lint Pushwoosh.podspec' to ensure this is a
#

Pod::Spec.new do |s|

  s.name         = "Pushwoosh"
  s.version      = "6.7.11"
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

  s.subspec 'Core' do |core|
    core.ios.vendored_frameworks  = 'Framework/PushwooshFramework.framework'
    core.library  = 'c++', 'z'
    core.frameworks  = 'Security', 'StoreKit'
  end

  s.subspec 'Geozones' do |geozones|
    geozones.ios.vendored_frameworks  = 'Framework/PushwooshGeozones.framework'
    geozones.frameworks  = 'CoreLocation'
    geozones.dependency 'Pushwoosh/Core'
  end

end
