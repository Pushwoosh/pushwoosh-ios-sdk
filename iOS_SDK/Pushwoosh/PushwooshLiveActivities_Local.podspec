#
#  Be sure to run `pod spec lint Pushwoosh.podspec' to ensure this is a
#

Pod::Spec.new do |s|
  s.name         = 'PushwooshLiveActivities_Local'
  s.version      = '6.8.1'
  s.summary      = 'Pushwoosh SDK'
  s.description  = 'Local podspec for Pushwoosh iOS SDK.'
  s.homepage     = 'https://www.pushwoosh.com'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'André Kis' => 'akiselev@pushwoosh.com' }
  s.source       = { :path => '.' } 
  s.platform     = :ios, '11.0'
  s.requires_arc = true

  s.ios.vendored_frameworks = "PushwooshLiveActivities.framework"
  s.public_header_files = 'PushwooshLiveActivities.framework/Headers/*.h'
end

