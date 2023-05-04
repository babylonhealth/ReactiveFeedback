Pod::Spec.new do |s|

  s.name          = "ReactiveFeedback"
  s.version       = "0.10.0"
  s.summary       = "Unidirectional reactive architecture"

  s.description   = <<-DESC
                    A unidirectional data flow µframework, built on top of ReactiveSwift.
                    DESC

  s.homepage      = "https://github.com/Babylonpartners/ReactiveFeedback/"
  s.license       = { :type => "MIT", :file => "LICENSE" }
  s.author        = { "Babylon iOS" => "ios.development@babylonhealth.com" }
  s.ios.deployment_target = '12.0'
  s.source        = { :git => "https://github.com/Babylonpartners/ReactiveFeedback.git", :tag => "#{s.version}" }
  s.source_files  = "ReactiveFeedback/*.{swift}"

  s.cocoapods_version = ">= 1.11.3"
  s.swift_versions = ["5.0", "5.1"]

  s.dependency "ReactiveSwift", "~> 7.1.1"
end
