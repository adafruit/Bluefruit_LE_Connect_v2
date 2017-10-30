source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

def shared_pods
  pod 'CocoaMQTT'
end

target 'OSX' do
	platform :osx, "10.10"
	shared_pods	
end

target 'iOS' do
	platform :ios, '9.0'
	shared_pods
	pod 'UIColor+Hex'
	pod 'SSZipArchive'
	
end

target 'watchOS' do
	platform :watchos, '2.0'

end
