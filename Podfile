source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

target 'Bluefruit' do
  platform :ios, '13.0'
  
  pod 'CocoaMQTT', '~> 2.1.1'
  pod 'MSWeakTimer', '~> 1.1.0'
  pod 'SwiftyXML', '~> 2.0.0'
  pod 'iOSDFULibrary', '~> 4.11.1'
  pod 'Charts', '~> 3.4.0'      #Note: careful when updating because the source code has been modified to improve performance
  pod 'VectorMath', '~> 0.4.1'
  pod 'UIColor+Hex', '~> 1.0.1'
  #  pod 'iOS-color-wheel', :inhibit_warnings => true
end


# https://stackoverflow.com/questions/54704207/the-ios-simulator-deployment-targets-is-set-to-7-0-but-the-range-of-supported-d
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
    end
  end
end
