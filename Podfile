# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'ReactiveFeedback' do

  use_frameworks!
  pod 'ReactiveSwift'
  pod 'ReactiveCocoa'
  pod 'Kingfisher'

end

target 'Example' do
    use_frameworks!
    pod 'ReactiveSwift'
    pod 'ReactiveCocoa'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.3'
        end
    end
end
