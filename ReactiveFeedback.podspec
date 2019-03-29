Pod::Spec.new do |s|

  s.name          = "ReactiveFeedback"
  s.version       = "0.5.1"
  s.summary       = "Unidirectional reactive architecture"

  s.description   = <<-DESC
                    A unidirectional data flow µframework, built on top of ReactiveSwift.
                    DESC

  s.homepage      = "https://github.com/Babylonpartners/ReactiveFeedback/"
  s.license       = { :type => "MIT", :file => "LICENSE" }
  s.author        = { "Babylon iOS" => "ios.development@babylonhealth.com" }
  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.9'
  s.watchos.deployment_target = '2.0'
  s.tvos.deployment_target = '9.0'
  s.source        = { :git => "https://github.com/Babylonpartners/ReactiveFeedback.git", :tag => "#{s.version}" }
  s.source_files  = "ReactiveFeedback/*.{swift}"
  s.cocoapods_version = '>= 1.5.0'
  s.swift_version = "4.2"
  s.swift_versions = ['4.2', '5.0']

  s.dependency "ReactiveSwift", "~> 5.0"
end
