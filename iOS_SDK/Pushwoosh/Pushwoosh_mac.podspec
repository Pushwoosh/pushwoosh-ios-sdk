#
#  Be sure to run `pod spec lint Pushwoosh_mac.podspec' to ensure this is a
#

Pod::Spec.new do |s|

  s.name         = "Pushwoosh_mac"
  s.version      = "6.2.5"
  s.summary      = "Push notifications library by Pushwoosh."
  s.platform     = :osx

  s.description  = "Push notifications OSX library by Pushwoosh - cross platform push notifications service. " \
                   "http://www.pushwoosh.com "

  s.homepage     = "http://www.pushwoosh.com"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }

  s.author       = { "Max Konev" => "max@pushwoosh.com" }
  s.source       = { :git => "https://github.com/Pushwoosh/pushwoosh-mac-sdk.git", :tag => s.version }

  s.requires_arc = true
  s.xcconfig = { 'OTHER_LDFLAGS' => '-ObjC' }
  s.default_subspec = 'Core'
  s.osx.deployment_target = "10.7"

  s.subspec 'Core' do |core|
    core.osx.vendored_frameworks  = 'Framework/Pushwoosh.framework'
    core.library  = 'c++', 'z'
    core.frameworks  = 'Security', 'StoreKit'
  end

end
