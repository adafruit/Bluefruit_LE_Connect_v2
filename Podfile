source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

def shared_pods
	pod 'CocoaMQTT', '~> 1.0.0'
#	pod 'MSWeakTimer', '~> 1.1.0' 		// Already included in CocoaMQTT
end

target 'OSX' do
	platform :osx, "10.10"
	shared_pods	
end

target 'iOS' do
	platform :ios, '9.0'
	shared_pods
	pod 'UIColor+Hex', '~> 1.0.1'
	pod 'SSZipArchive', '~> 1.2'
	
end

target 'watchOS' do
	platform :watchos, '2.0'

end