source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

def shared_pods
  pod 'CocoaMQTT', '~> 1.1.2'
  pod 'MSWeakTimer', '~> 1.1.0'
  pod 'SwiftyXML', '~> 2.0.0'
  pod 'iOSDFULibrary', '~> 4.5.1'
  pod 'Charts', '~> 3.3.0'
  pod 'VectorMath', '~> 0.3.3', :inhibit_warnings => true
end

target 'iOS' do
    platform :ios, '11.3'
    shared_pods
    pod 'UIColor+Hex', '~> 1.0.1'
    #  pod 'iOS-color-wheel', :inhibit_warnings => true
end

target 'macOS' do
	platform :osx, '10.14'
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
