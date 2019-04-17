install! 'cocoapods'
use_frameworks!

def shared_pods
    pod "ReactiveSwift", "~> 5.0"
end

def nimble
    pod "Nimble", "~> 8.0"
end

target "ReactiveFeedback-iOS" do
    platform :ios, '8.0'
    shared_pods
    target "ReactiveFeedbackTests-iOS" do
        nimble
    end
end

target "ReactiveFeedback-macOS" do
    platform :osx, '10.10'
    shared_pods

    target "ReactiveFeedbackTests-macOS" do
        nimble
    end
end

target "ReactiveFeedback-tvOS" do
    platform :tvos, '9.0'
    shared_pods

    target "ReactiveFeedbackTests-tvOS" do
        nimble
    end
end

target "Example" do
    platform :ios, "10.0"
    shared_pods
    pod "Kingfisher", "~> 4.0"
    pod "ReactiveCocoa", "~> 9.0.0"
end
