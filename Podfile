install! 'cocoapods',
         :integrate_targets => false
use_frameworks!

def shared_pods
    pod "ReactiveSwift", "~> 5.0"
end

target "ReactiveFeedback-macOS" do
    platform :ios, "9.0"
    shared_pods
end

target "ReactiveFeedback-iOS" do
    platform :ios, "9.0"
    shared_pods
end

target "ReactiveFeedback-tvOS" do
    platform :ios, "9.0"
    shared_pods
end

target "ReactiveFeedbackTests-macOS" do
    platform :ios, "9.0"
    shared_pods
    pod "Nimble", "~> 8.0"
end

target "ReactiveFeedbackTests-iOS" do
    platform :ios, "9.0"
    shared_pods
    pod "Nimble", "~> 8.0"
end

target "ReactiveFeedbackTests-tvOS" do
    platform :ios, "9.0"
    shared_pods
    pod "Nimble", "~> 8.0"
end

target "Example" do
    platform :ios, "10.0"
    shared_pods
    pod "Kingfisher", "~> 5.2"
    pod "ReactiveCocoa", "~> 9.0"
end
