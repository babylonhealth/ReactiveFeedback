install! 'cocoapods',
         :integrate_targets => false
use_frameworks!

def shared_pods
    pod "ReactiveSwift", "~> 3.0"
end

target "ReactiveFeedback" do
    platform :ios, "8.0"
    shared_pods
end

target "ReactiveFeedbackTests" do
    platform :ios, "8.0"
    shared_pods
    pod "Nimble", "~> 7.0"
end

target "Example" do
    platform :ios, "10.0"
    shared_pods
    pod "Kingfisher", "~> 4.0"
end
