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
    static func packetsAsText(_ packets: [UartPacket]) -> String? {
        // Compile all data
        var data = Data()
        for packet in packets {
            data.append(packet.data)
        }

        var text: String?
        if Preferences.uartIsInHexMode {
            text = hexDescription(data: data)
        } else {
            text = String(data:data, encoding: .utf8)
        }

        return text
    }

    static func packetsAsCsv(_ packets: [UartPacket]) -> String? {
        var text = "Timestamp,Mode,Data\r\n"        // csv Header

        let timestampDateFormatter = DateFormatter()
        timestampDateFormatter.setLocalizedDateFormatFromTemplate("HH:mm:ss:SSS")

        for packet in packets {
            let date = Date(timeIntervalSinceReferenceDate: packet.timestamp)

            let dateString = timestampDateFormatter.string(from: date).replacingOccurrences(of: ",", with: ".")     //  comma messes with csv, so replace it by a point
            let mode = packet.mode == .rx ? "RX" : "TX"
            var dataString: String?
            if Preferences.uartIsInHexMode {
                dataString = hexDescription(data: packet.data)
            } else {
                dataString = String(data: packet.data, encoding: .utf8)
            }

            // Remove newline characters from data (it messes with the csv format and Excel wont recognize it)
            dataString = dataString?.trimmingCharacters(in: CharacterSet.newlines) ?? ""
            text += "\(dateString),\(mode),\"\(dataString!)\"\r\n"
        }

        return text
    }

    static func packetsAsJson(_ packets: [UartPacket]) -> String? {

        var jsonItemsArray: [Any] = []

        for packet in packets {
            let date = Date(timeIntervalSinceReferenceDate: packet.timestamp)
            let unixDate = date.timeIntervalSince1970
            let mode = packet.mode == .rx ? "RX" : "TX"

            var dataString: String?
            if Preferences.uartIsInHexMode {
                dataString = hexDescription(data: packet.data)
            } else {
                dataString = String(data: packet.data, encoding: .utf8)
            }

            if let dataString = dataString {
                let jsonItemDictionary: [String: Any] = [
                    "timestamp": unixDate,
                    "mode": mode,
                    "data": dataString
                ]
                jsonItemsArray.append(jsonItemDictionary)
            }
        }

        let jsonRootDictionary: [String: Any] = [
            "items": jsonItemsArray
        ]

        // Create Json Data
        var data: Data?
        do {
            data = try JSONSerialization.data(withJSONObject: jsonRootDictionary, options: .prettyPrinted)
        } catch {
            DLog("Error serializing json data")
        }

        // Create Json String
        var result: String?
        if let data = data {
            result = String(data: data, encoding: .utf8)
        }

        return result
    }

    static func packetsAsXml(_ packets: [UartPacket]) -> String? {

        #if os(OSX)
        let xmlRootElement = XMLElement(name: "uart")

        for packet in packets {
            let date = Date(timeIntervalSinceReferenceDate: packet.timestamp)
            let unixDate = date.timeIntervalSince1970
            let mode = packet.mode == .rx ? "RX" : "TX"

            var dataString: String?
            if Preferences.uartIsInHexMode {
                dataString = hexDescription(data: packet.data)
            } else {
                dataString = String(data: packet.data, encoding: .utf8)
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
        let result = xml.xmlString(withOptions: Int(XMLNode.Options.nodePrettyPrint.rawValue))

        return result

        #else
            // TODO: implement for iOS

            return nil

        #endif
    }

    static func packetsAsBinary(_ packets: [UartPacket]) -> Data? {
        guard !packets.isEmpty else {
            return nil
        }

        var result = Data()
        for packet in packets {
            result.append(packet.data)
        }

        return result
    }
}
