source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

def shared_pods
	pod 'CocoaMQTT', '~> 1.0.19'
	pod 'MSWeakTimer', '~> 1.1.0'
    pod 'SwiftyXML', '~> 1.4.0'
    pod 'iOSDFULibrary', '~> 4.0.2'
    pod 'Charts', '~> 3.0.4'
end

target 'iOS' do
    platform :ios, '9.0'
    shared_pods
    pod 'UIColor+Hex', '~> 1.0.1'
    #  pod 'iOS-color-wheel', :inhibit_warnings => true
end

target 'macOS' do
	platform :osx, '10.11'
	shared_pods
end

#target 'Bluefruit' do       # command line tool
#    platform :osx, "10.11"
    #    pod 'SwiftyXML', '~> 1.1.0'
    #pod 'iOSDFULibrary'
    #pod 'MSWeakTimer', '~> 1.1.0'
#end

#target 'watchOS' do
#	platform :watchos, '3.0'
#end
