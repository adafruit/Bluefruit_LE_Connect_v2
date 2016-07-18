//
//  InfoModuleManager.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 18/07/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation


class InfoModuleManager: NSObject {
    
    
    static func parseDescriptorValue(descriptor: CBDescriptor) -> NSData? {
        var result: NSData?
        
        let identifier = descriptor.UUID.UUIDString
        switch identifier {
        case CBUUIDCharacteristicExtendedPropertiesString, CBUUIDClientCharacteristicConfigurationString, CBUUIDServerCharacteristicConfigurationString:      // is an NSNumber
            // Note: according to the docs this should be an NSNumber, but it seems that is recognized as an NSData. So an NSData check is performed if the NSNumber check fails
            if let value = descriptor.value as? NSNumber {
                result = value.stringValue.dataUsingEncoding(NSUTF8StringEncoding)
            }
            else if let value = descriptor.value as? NSData {
                result = value
            }
        case CBUUIDCharacteristicUserDescriptionString:         // is an NSString
            if let value = descriptor.value as? String {
                result = value.dataUsingEncoding(NSUTF8StringEncoding)
            }
            
        case CBUUIDCharacteristicFormatString, CBUUIDCharacteristicAggregateFormatString:
            result = descriptor.value as? NSData
            
        default:
            break
        }
        
        return result
    }
    
}