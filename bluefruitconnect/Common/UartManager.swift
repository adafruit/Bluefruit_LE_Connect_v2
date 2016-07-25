//
//  UartManager.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation


class UartManager: NSObject {
    enum UartNotifications : String {
        case DidSendData = "didSendData"
        case DidReceiveData = "didReceiveData"
        case DidBecomeReady = "didBecomeReady"
    }
    
    // Constants
    private static let UartServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"       // UART service UUID
    private static let RxCharacteristicUUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
    private static let TxCharacteristicUUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
    private static let TxMaxCharacters = 20

    // Manager
    static let sharedInstance = UartManager()

    // Bluetooth Uart
    private var uartService : CBService?
    private var rxCharacteristic : CBCharacteristic?
    private var txCharacteristic : CBCharacteristic?
    private var txWriteType = CBCharacteristicWriteType.WithResponse
    
    var blePeripheral : BlePeripheral? {
        didSet {
            if blePeripheral?.peripheral.identifier != oldValue?.peripheral.identifier {
                // Discover UART
                resetService()
                blePeripheral?.peripheral.discoverServices([CBUUID(string: UartManager.UartServiceUUID)])
            }
        }
    }
    
    // Data
    var dataBuffer = [UartDataChunk]()
    var dataBufferEnabled = Config.uartShowAllUartCommunication

    override init() {
        super.init()

        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: #selector(didDisconnectFromPeripheral(_:)), name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
    }

    deinit {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
    }
    
    func didDisconnectFromPeripheral(notification : NSNotification) {
        blePeripheral = nil
        resetService()
    }
    
    private func resetService() {
        DLog("Uart: reset service")
        uartService = nil
        rxCharacteristic = nil
        txCharacteristic = nil
    }
    
    func sendDataWithCrc(data : NSData) {
        
        let len = data.length
        var dataBytes = [UInt8](count: len, repeatedValue: 0)
        var crc: UInt8 = 0
        data.getBytes(&dataBytes, length: len)
        
        for i in dataBytes {    //add all bytes
            crc = crc &+ i
        }
        crc = ~crc  //invert
        
        let dataWithChecksum = NSMutableData(data: data)
        dataWithChecksum.appendBytes(&crc, length: 1)
        
        sendData(dataWithChecksum)
    }

    func sendData(data: NSData) {
        let dataChunk = UartDataChunk(timestamp: CFAbsoluteTimeGetCurrent(), mode: .TX, data: data)
        sendChunk(dataChunk)
    }

    func sendChunk(dataChunk: UartDataChunk) {
        
        if let txCharacteristic = txCharacteristic, blePeripheral = blePeripheral {
            let data = dataChunk.data
            
            if dataBufferEnabled {
                blePeripheral.uartData.sentBytes += data.length
                dataBuffer.append(dataChunk)
            }
                
            // Split data  in txmaxcharacters bytes packets
            var offset = 0
            repeat {
                let chunkSize = min(data.length-offset, UartManager.TxMaxCharacters)
                let chunk = NSData(bytesNoCopy: UnsafeMutablePointer<UInt8>(data.bytes)+offset, length: chunkSize, freeWhenDone:false)
                
                if Config.uartLogSend {
                    DLog("send: \(hexString(chunk))")
                }
                
                blePeripheral.peripheral.writeValue(chunk, forCharacteristic: txCharacteristic, type: txWriteType)
                offset+=chunkSize
            }while(offset<data.length)
            
            NSNotificationCenter.defaultCenter().postNotificationName(UartNotifications.DidSendData.rawValue, object: nil, userInfo:["dataChunk" : dataChunk]);
        }
        else {
            DLog("Error: sendChunk with uart not ready")
        }
    }
    
    private func receivedData(data: NSData) {
        
        let dataChunk = UartDataChunk(timestamp: CFAbsoluteTimeGetCurrent(), mode: .RX, data: data)
        receivedChunk(dataChunk)
    }
    
    private func receivedChunk(dataChunk: UartDataChunk) {
        if Config.uartLogReceive {
            DLog("received: \(hexString(dataChunk.data))")
        }
        
        if dataBufferEnabled {
            blePeripheral?.uartData.receivedBytes += dataChunk.data.length
            dataBuffer.append(dataChunk)
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(UartNotifications.DidReceiveData.rawValue, object: nil, userInfo:["dataChunk" : dataChunk]);
    }
    
    func isReady() -> Bool {
        return txCharacteristic != nil && rxCharacteristic != nil// &&  rxCharacteristic!.isNotifying
    }
    
    func clearData() {
        dataBuffer.removeAll()
        blePeripheral?.uartData.receivedBytes = 0
        blePeripheral?.uartData.sentBytes = 0
    }
}

// MARK: - CBPeripheralDelegate
extension UartManager: CBPeripheralDelegate {
    
    
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        DLog("UartManager: resetService because didModifyServices")
        resetService()
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        
        if (uartService == nil) {
            if let services = peripheral.services {
                var found = false
                var i = 0
                while (!found && i < services.count) {
                    let service = services[i]
                    if (service.UUID.UUIDString .caseInsensitiveCompare(UartManager.UartServiceUUID) == .OrderedSame) {
                        found = true
                        uartService = service
                        
                        peripheral.discoverCharacteristics([CBUUID(string: UartManager.RxCharacteristicUUID), CBUUID(string: UartManager.TxCharacteristicUUID)], forService: service)
                    }
                    i += 1
                }
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        
        //DLog("uart didDiscoverCharacteristicsForService")
        if let uartService = uartService where rxCharacteristic == nil || txCharacteristic == nil {
            if rxCharacteristic == nil || txCharacteristic == nil {
                if let characteristics = uartService.characteristics {
                    var found = false
                    var i = 0
                    while !found && i < characteristics.count {
                        let characteristic = characteristics[i]
                        if characteristic.UUID.UUIDString .caseInsensitiveCompare(UartManager.RxCharacteristicUUID) == .OrderedSame {
                            rxCharacteristic = characteristic
                        }
                        else if characteristic.UUID.UUIDString .caseInsensitiveCompare(UartManager.TxCharacteristicUUID) == .OrderedSame {
                            txCharacteristic = characteristic
                            txWriteType = characteristic.properties.contains(.WriteWithoutResponse) ? .WithoutResponse:.WithResponse
                            DLog("Uart: detected txWriteType: \(txWriteType.rawValue)")
                        }
                        found = rxCharacteristic != nil && txCharacteristic != nil
                        i += 1
                    }
                }
            }
            
            // Check if characteristics are ready
            if (rxCharacteristic != nil && txCharacteristic != nil) {
                // Set rx enabled
                peripheral.setNotifyValue(true, forCharacteristic: rxCharacteristic!)
                
                // Send notification that uart is ready
                NSNotificationCenter.defaultCenter().postNotificationName(UartNotifications.DidBecomeReady.rawValue, object: nil, userInfo:nil)
                
                DLog("Uart: did become ready")

            }
        }
    }

    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        DLog("didUpdateNotificationStateForCharacteristic")
        /*
        if characteristic == rxCharacteristic {
            if error != nil {
                 DLog("Uart RX isNotifying error: \(error)")
            }
            else {
                if characteristic.isNotifying {
                    DLog("Uart RX isNotifying: true")
                    
                    // Send notification that uart is ready
                    NSNotificationCenter.defaultCenter().postNotificationName(UartNotifications.DidBecomeReady.rawValue, object: nil, userInfo:nil)
                }
                else {
                    DLog("Uart RX isNotifying: false")
                }
            }
        }
*/
    }

    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if characteristic == rxCharacteristic && characteristic.service == uartService {
            
            if let characteristicDataValue = characteristic.value {
                receivedData(characteristicDataValue)
            }
        }
    }
}