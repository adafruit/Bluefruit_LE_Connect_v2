//
//  BlePeripheral+Uart.swift
//  Calibration
//
//  Created by Antonio García on 19/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

extension BlePeripheral {
    
    // Config
    private static let kDebugLog = false
    
    // Costants
    static let kUartServiceUUID =           CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    static let kUartTxCharacteristicUUID =  CBUUID(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    static let kUartRxCharacteristicUUID =  CBUUID(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    fileprivate static let kUartTxMaxBytes = 20
    static let kUartReplyDefaultTimeout = 2.0               // seconds
    
    // MARK: - Custom properties
    fileprivate struct CustomPropertiesKeys {
        static var uartRxCharacteristic: CBCharacteristic?
        static var uartTxCharacteristic: CBCharacteristic?
        static var uartTxCharacteristicWriteType: CBCharacteristicWriteType?
    }
    
    fileprivate var uartRxCharacteristic: CBCharacteristic? {
        get {
            return objc_getAssociatedObject(self, &CustomPropertiesKeys.uartRxCharacteristic) as! CBCharacteristic?
        }
        set {
            objc_setAssociatedObject(self, &CustomPropertiesKeys.uartRxCharacteristic, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    fileprivate var uartTxCharacteristic: CBCharacteristic? {
        get {
            return objc_getAssociatedObject(self, &CustomPropertiesKeys.uartTxCharacteristic) as! CBCharacteristic?
        }
        set {
            objc_setAssociatedObject(self, &CustomPropertiesKeys.uartTxCharacteristic, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    fileprivate var uartTxCharacteristicWriteType: CBCharacteristicWriteType? {
        get {
            return objc_getAssociatedObject(self, &CustomPropertiesKeys.uartTxCharacteristicWriteType) as! CBCharacteristicWriteType?
        }
        set {
            objc_setAssociatedObject(self, &CustomPropertiesKeys.uartTxCharacteristicWriteType, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    // MARK: -
    enum UartError: Error {
        case invalidCharacteristic
        case enableNotifyFailed
        case timeout
    }
    
    // MARK: - Initialization
    func uartEnable(uartRxHandler: ((Data?, Error?) -> Void)?, completion: ((Error?) -> Void)?) {
        
        // Get uart communications characteristic
        characteristic(uuid: BlePeripheral.kUartTxCharacteristicUUID, serviceUuid: BlePeripheral.kUartServiceUUID) { [unowned self] (characteristic, error) in
            guard let characteristic = characteristic, error == nil else {
                completion?(error != nil ? error : UartError.invalidCharacteristic)
                return
            }
            
            self.uartTxCharacteristic = characteristic
            self.uartTxCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse:.withResponse
            
            self.characteristic(uuid: BlePeripheral.kUartRxCharacteristicUUID, serviceUuid: BlePeripheral.kUartServiceUUID) { [unowned self] (characteristic, error) in
                guard let characteristic = characteristic, error == nil else {
                    completion?(error != nil ? error : UartError.invalidCharacteristic)
                    return
                }
                
                // Get characteristic info
                self.uartRxCharacteristic = characteristic
                
                // Enable notifications
                self.setNotify(for: characteristic, enabled: true, handler: { (error) in
                    
                    let value = characteristic.value
                    if let value = value, BlePeripheral.kDebugLog == true, error == nil {
                        UartLogManager.log(data: value, type: .uartRx)
                    }
                    
                    uartRxHandler?(value, error)
                }, completion: { error in
                    completion?(error != nil ? error : (characteristic.isNotifying ? nil : UartError.enableNotifyFailed))
                })
            }
        }
    }
    
    func uartDisable() {
        // Clear all Uart specific data
        defer {
            uartRxCharacteristic = nil
            uartTxCharacteristic = nil
            uartTxCharacteristicWriteType = nil
        }
        
        // Disable notify
        guard let characteristic = uartRxCharacteristic else {
            return
        }
        
        setNotify(for: characteristic, enabled: false)
    }
    
    
    // MARK: - Send
    func uartSend(data: Data?, completion: ((Error?) -> Void)? = nil) {
        guard let data = data else {
            return
        }
        
        guard let uartTxCharacteristic = uartTxCharacteristic, let uartTxCharacteristicWriteType = uartTxCharacteristicWriteType else {
            DLog("Command Error: characteristic no longer valid")
            completion?(UartError.invalidCharacteristic)
            return
        }
        
        // Split data in kUartTxMaxBytes bytes packets
        var offset = 0
        repeat {
            let chunkSize = min(data.count-offset, BlePeripheral.kUartTxMaxBytes)
            let chunk = data.subdata(in: offset..<offset+chunkSize)
            offset += chunkSize
            write(data: chunk, for: uartTxCharacteristic, type: uartTxCharacteristicWriteType) { error in
                if let error = error {
                    DLog("write chunk at offset: \(offset) error: \(error)")
                }
                else {
                    DLog("uart tx write: \(hexDescription(data: chunk))")
                    DLog("uart tx write (dec): \(decimalDescription(data: chunk))")
                    DLog("uart tx write (utf8): \(String(data: chunk, encoding: .utf8) ?? "<invalid>")")
                    
                    if BlePeripheral.kDebugLog {
                        UartLogManager.log(data: chunk, type: .uartTx)
                    }
                }
                
                if offset >= data.count {
                    completion?(error)
                }
            }
            
        } while offset < data.count
    }
    
    func uartSendWithAndWaitReply(data: Data?, writeCompletion: ((Error?) -> Void)? = nil, readTimeout: Double? = BlePeripheral.kUartReplyDefaultTimeout, readCompletion: @escaping CapturedReadCompletionHandler) {
        guard let data = data else {
            return
        }
        
        guard let uartTxCharacteristic = uartTxCharacteristic, let uartTxCharacteristicWriteType = uartTxCharacteristicWriteType, let uartRxCharacteristic = uartRxCharacteristic else {
            DLog("Command Error: characteristic no longer valid")
            writeCompletion?(UartError.invalidCharacteristic)
            return
        }
        
        // Split data  in kUartTxMaxBytes bytes packets
        var offset = 0
        repeat {
            let chunkSize = min(data.count-offset, BlePeripheral.kUartTxMaxBytes)
            let chunk = data.subdata(in: offset..<offset+chunkSize)
            offset += chunkSize
            
            writeAndCaptureNotify(data: chunk, for: uartTxCharacteristic, type: uartTxCharacteristicWriteType, writeCompletion: { (error) in
                if let error = error {
                    DLog("write chunk at offset: \(offset) error: \(error)")
                }
                else {
                    DLog("uart tx writeAndWait (hex): \(hexDescription(data: chunk))")
                    DLog("uart tx writeAndWait (dec): \(decimalDescription(data: chunk))")
                    DLog("uart tx writeAndWait (utf8): \(String(data: chunk, encoding: .utf8) ?? "<invalid>")")
                }
                
                if offset >= data.count {
                    writeCompletion?(error)
                }
            }, readCharacteristic: uartRxCharacteristic, readTimeout: readTimeout, readCompletion: readCompletion)
            
        } while offset < data.count
    }
    
    // MARK: - Utils
    func isUartAdvertised() -> Bool {
        return advertisement.services?.contains(BlePeripheral.kUartServiceUUID) ?? false
    }
    
    func hasUart() -> Bool {
        return peripheral.services?.first(where: {$0.uuid == BlePeripheral.kUartServiceUUID}) != nil
    }
}

// MARK: - Data + CRC
extension Data {
    mutating func appendCrc() {
        var dataBytes = [UInt8](repeating: 0, count: count)
        copyBytes(to: &dataBytes, count: count)
        
        var crc: UInt8 = 0
        for i in dataBytes {    //add all bytes
            crc = crc &+ i
        }
        crc = ~crc  //invert
        
        append(&crc, count: 1)
    }
}

