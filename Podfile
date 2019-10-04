install! 'cocoapods',
         :integrate_targets => false
use_frameworks!

def shared_pods
    pod "ReactiveSwift", "~> 6.0"
end

target "Example" do
  platform :ios, "8.0"
  pod "Kingfisher"
  shared_pods
end

target "ReactiveFeedback" do
    platform :ios, "8.0"
    shared_pods
end

target "ReactiveFeedbackTests" do
    platform :ios, "8.0"
    shared_pods
    pod "Nimble", "~> 8.0"
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '5.0'
    end
  end
end
