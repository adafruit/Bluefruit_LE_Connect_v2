source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

target 'Bluefruit' do
  platform :ios, '11.3'
  
  pod 'CocoaMQTT', '~> 1.2.5'
  pod 'MSWeakTimer', '~> 1.1.0'
  pod 'SwiftyXML', '~> 2.0.0'
  pod 'iOSDFULibrary', '~> 4.6.1'
  pod 'Charts', '~> 3.4.0'
  pod 'VectorMath', '~> 0.4.1'
  pod 'UIColor+Hex', '~> 1.0.1'
  #  pod 'iOS-color-wheel', :inhibit_warnings => true
end

# Remove "Too many symbols" warning when submitting app
# https://stackoverflow.com/questions/25755240/too-many-symbol-files-after-successfully-submitting-my-apps
post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf'
        end
    end
end
