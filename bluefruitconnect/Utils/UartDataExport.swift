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
    static func dataAsText(dataBuffer: [UartDataChunk]) -> String? {
        // Compile all data
        let data = NSMutableData()
        for dataChunk in dataBuffer {
            data.append(dataChunk.data as Data)
        }
        
        var text: String?
        if (Preferences.uartIsInHexMode) {
            text = hexString(data: data)
        }
        else {
            text = String(data: data as Data, encoding: .utf8)
        }
        
        return text
    }
    
    static func dataAsCsv(dataBuffer: [UartDataChunk])  -> String? {
        var text = "Timestamp,Mode,Data\r\n"        // csv Header
        
        let timestampDateFormatter = DateFormatter()
        timestampDateFormatter.setLocalizedDateFormatFromTemplate("HH:mm:ss:SSSS")
        
        for dataChunk in dataBuffer {
            let date = NSDate(timeIntervalSinceReferenceDate: dataChunk.timestamp)
            let dateString = timestampDateFormatter.string(from: date as Date).replacingOccurrences(of: ",", with: ".")  //  comma messes with csv, so replace it by point
            let mode = dataChunk.mode == .RX ? "RX" : "TX"
            var dataString: String?
            if (Preferences.uartIsInHexMode) {
                dataString = hexString(data: dataChunk.data)
            }
            else {
                dataString = String(data:dataChunk.data as Data, encoding: .utf8)
            }
            if (dataString == nil) {
                dataString = ""
            }
            else {
                // Remove newline characters from data (it messes with the csv format and Excel wont recognize it)
                dataString = dataString!.trimmingCharacters(in: NSCharacterSet.newlines)
            }
            
            text += "\(dateString),\(mode),\"\(dataString!)\"\r\n"
        }
        
        return text
    }
    
    static func dataAsJson(dataBuffer: [UartDataChunk])  -> String? {
        
        var jsonItemsDictionary : [AnyObject] = []
        
        for dataChunk in dataBuffer {
            let date = NSDate(timeIntervalSinceReferenceDate: dataChunk.timestamp)
            let unixDate = date.timeIntervalSince1970
            let mode = dataChunk.mode == .RX ? "RX" : "TX"
            var dataString: String?
            if (Preferences.uartIsInHexMode) {
                dataString = hexString(data: dataChunk.data)
            }
            else {
                dataString = String(data: dataChunk.data as Data, encoding: .utf8)
            }
            
            if let dataString = dataString {
                let jsonItemDictionary : [String : AnyObject] = [
                    "timestamp" : unixDate as AnyObject,
                    "mode" : mode as AnyObject,
                    "data" : dataString as AnyObject
                ]
                jsonItemsDictionary.append(jsonItemDictionary as AnyObject)
            }
        }
        
        let jsonRootDictionary: [String : AnyObject] = [
            "items": jsonItemsDictionary as AnyObject
        ]
        
        // Create Json NSData
        var data : NSData?
        do {
            data = try JSONSerialization.data(withJSONObject: jsonRootDictionary, options: .prettyPrinted) as NSData
        } catch  {
            DLog(message: "Error serializing json data")
        }
        
        // Create Json String
        var result : String?
        if let data = data {
            result = String(data: data as Data, encoding: .utf8)
        }
        
        return result
    }

    static func dataAsXml(dataBuffer: [UartDataChunk])  -> String? {
        
        #if os(OSX)
            let xmlRootElement = XMLElement(name: "uart")
        
        for dataChunk in dataBuffer {
            let date = NSDate(timeIntervalSinceReferenceDate: dataChunk.timestamp)
            let unixDate = date.timeIntervalSince1970
            let mode = dataChunk.mode == .RX ? "RX" : "TX"
            var dataString: String?
            if (Preferences.uartIsInHexMode) {
                dataString = hexString(data: dataChunk.data)
            }
            else {
                dataString = String(data: dataChunk.data as Data, encoding: .utf8)
            }
            
            if let dataString = dataString {
                
                let xmlItemElement = XMLElement(name: "item")
                xmlItemElement.addChild(XMLElement(name: "timestamp", stringValue:"\(unixDate)"))
                xmlItemElement.addChild(XMLElement(name: "mode", stringValue:mode))
                let dataNode = XMLElement(kind: .text, options: XMLNode.Options.nodeIsCDATA)
                dataNode.name = "data"
                dataNode.stringValue = dataString
                xmlItemElement.addChild(dataNode)
                
                xmlRootElement.addChild(xmlItemElement)
            }
        }
        
            let xml = XMLDocument(rootElement: xmlRootElement)
            let result = xml.xmlString(options: XMLNode.Options.nodePrettyPrint)
        
        return result

        #else
            // TODO: implement for iOS
            
            
            return nil
            
        #endif
    }
    
    static func dataAsBinary(dataBuffer: [UartDataChunk]) -> NSData? {
        guard dataBuffer.count > 0 else {
            return nil
        }
        
        let result = NSMutableData()
        for dataChunk in dataBuffer {
            result.append(dataChunk.data as Data)
        }
        
        return result
    }
}
