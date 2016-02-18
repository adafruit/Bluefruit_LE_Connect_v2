//
//  UartDataExport.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 10/01/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

class UartDataExport {
    
    // MARK: - Export formatters
    static func dataAsText(dataBuffer : [UartDataChunk]) -> String? {
        // Compile all data
        let data = NSMutableData()
        for dataChunk in dataBuffer {
            data.appendData(dataChunk.data)
        }
        
        var text : String?
        if (Preferences.uartIsInHexMode) {
            text = hexString(data)
        }
        else {
            text = NSString(data:data, encoding: NSUTF8StringEncoding) as String?
        }
        
        return text
    }
    
    static func dataAsCsv(dataBuffer : [UartDataChunk])  -> String? {
        var text = "Timestamp,Mode,Data\r\n"        // csv Header
        
        let timestampDateFormatter = NSDateFormatter()
        timestampDateFormatter.setLocalizedDateFormatFromTemplate("HH:mm:ss:SSSS")
        
        for dataChunk in dataBuffer {
            let date = NSDate(timeIntervalSinceReferenceDate: dataChunk.timestamp)
            let dateString = timestampDateFormatter.stringFromDate(date).stringByReplacingOccurrencesOfString(",", withString: ".")         //  comma messes with csv, so replace it by point
            let mode = dataChunk.mode == .RX ? "RX" : "TX"
            var dataString : String?
            if (Preferences.uartIsInHexMode) {
                dataString = hexString(dataChunk.data)
            }
            else {
                dataString = NSString(data:dataChunk.data, encoding: NSUTF8StringEncoding) as String?
            }
            if (dataString == nil) {
                dataString = ""
            }
            else {
                // Remove newline characters from data (it messes with the csv format and Excel wont recognize it)
                dataString = (dataString! as NSString).stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet())
            }
            
            text += "\(dateString),\(mode),\"\(dataString!)\"\r\n"
        }
        
        return text
    }
    
    static func dataAsJson(dataBuffer : [UartDataChunk])  -> String? {
        
        var jsonItemsDictionary : [AnyObject] = []
        
        for dataChunk in dataBuffer {
            let date = NSDate(timeIntervalSinceReferenceDate: dataChunk.timestamp)
            let unixDate = date.timeIntervalSince1970
            let mode = dataChunk.mode == .RX ? "RX" : "TX"
            var dataString : String?
            if (Preferences.uartIsInHexMode) {
                dataString = hexString(dataChunk.data)
            }
            else {
                dataString = NSString(data:dataChunk.data, encoding: NSUTF8StringEncoding) as String?
            }
            
            if let dataString = dataString {
                let jsonItemDictionary : [String : AnyObject] = [
                    "timestamp" : unixDate,
                    "mode" : mode,
                    "data" : dataString
                ]
                jsonItemsDictionary.append(jsonItemDictionary)
            }
        }
        
        let jsonRootDictionary : [String : AnyObject] = [
            "items": jsonItemsDictionary
        ]
        
        // Create Json NSData
        var data : NSData?
        do {
            data = try NSJSONSerialization.dataWithJSONObject(jsonRootDictionary, options: .PrettyPrinted)
        } catch  {
            DLog("Error serializing json data")
        }
        
        // Create Json String
        var result : String?
        if let data = data {
            result = NSString(data: data, encoding: NSUTF8StringEncoding) as? String
        }
        
        return result
    }

    static func dataAsXml(dataBuffer : [UartDataChunk])  -> String? {
        
        #if os(OSX)
        let xmlRootElement = NSXMLElement(name: "uart")
        
        for dataChunk in dataBuffer {
            let date = NSDate(timeIntervalSinceReferenceDate: dataChunk.timestamp)
            let unixDate = date.timeIntervalSince1970
            let mode = dataChunk.mode == .RX ? "RX" : "TX"
            var dataString : String?
            if (Preferences.uartIsInHexMode) {
                dataString = hexString(dataChunk.data)
            }
            else {
                dataString = NSString(data:dataChunk.data, encoding: NSUTF8StringEncoding) as String?
            }
            
            if let dataString = dataString {
                
                let xmlItemElement = NSXMLElement(name: "item")
                xmlItemElement.addChild(NSXMLElement(name: "timestamp", stringValue:"\(unixDate)"))
                xmlItemElement.addChild(NSXMLElement(name: "mode", stringValue:mode))
                let dataNode = NSXMLElement(kind: .TextKind, options: NSXMLNodeIsCDATA)
                dataNode.name = "data"
                dataNode.stringValue = dataString
                xmlItemElement.addChild(dataNode)
                
                xmlRootElement.addChild(xmlItemElement)
            }
        }
        
        let xml = NSXMLDocument(rootElement: xmlRootElement)
        let result = xml.XMLStringWithOptions(NSXMLNodePrettyPrint)
        
        return result

        #else
            // TODO: implement for iOS
            
            
            return nil
            
        #endif
    }
}