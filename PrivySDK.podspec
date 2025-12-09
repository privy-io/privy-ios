Pod::Spec.new do |s|
  s.name             = 'PrivySDK'
  s.version          = '2.7.1'
  s.summary          = 'Privy Flutter SDK for authentication and wallet management.'
  s.description      = <<-DESC
			The Privy SDK allows you to easily integrate authentication and wallet functionality into your iOS applications.
  		       DESC
  s.homepage         = 'https://github.com/privy-io/privy-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Privy Team' => 'support@privy.io' }

  # Platform and Swift version
  s.platform         = :ios, '17.0'
  s.swift_version    = '5.0'

  s.source           = { :git => 'https://github.com/privy-io/privy-ios.git', :tag => '2.7.1' }
  s.vendored_frameworks = 'PrivySDK.xcframework'
  # Frameworks to link with the project

  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end