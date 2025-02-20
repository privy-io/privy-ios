Pod::Spec.new do |s|
  s.name             = 'PrivySDK'
  s.version          = '1.8.1'
  s.summary          = 'Privy Flutter SDK for authentication and wallet management.'
  s.description      = <<-DESC
			The Privy SDK allows you to easily integrate authentication and wallet functionality into your iOS applications.
  		       DESC
  s.homepage         = 'https://github.com/privy-io/privy-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Privy Team' => 'support@privy.io' }

  # Platform and Swift version
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.0'

  s.source           = { :git => 'https://github.com/privy-io/privy-ios.git', :tag => s.version.to_s }
  s.vendored_frameworks = 'PrivySDK.xcframework'
  # Frameworks to link with the project
end