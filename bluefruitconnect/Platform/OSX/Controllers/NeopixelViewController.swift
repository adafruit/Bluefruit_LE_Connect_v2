//
//  NeopixelViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 10/01/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Cocoa

class NeopixelViewController: NSViewController {

    // Constants
    static let UartServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"       // UART service UUID
    static let RxCharacteristicUUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
    static let TxCharacteristicUUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"

    // UI
    @IBOutlet weak var statusImageView: NSImageView!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var sendButton: NSButton!
    
    // Bluetooth Uart
    private var blePeripheral : BlePeripheral?
    private var uartService : CBService?
    private var rxCharacteristic : CBCharacteristic?
    private var txCharacteristic : CBCharacteristic?
   
    private var uartResponseDelegate : ((NSData)->Void)?
    
    
    // Neopixel
    private var isNeopixelSketchAvailable : Bool?
    private var isSendingData = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    private func checkNeopixelSketch() {
        
        // Send version command and check if returns a valid response
        
        DLog("Ask Version...")
        let text = "V"
        if let data = text.dataUsingEncoding(NSUTF8StringEncoding) {
            sendDataToUart(data) { [unowned self] responseData in
                var isNeopixelSketchAvailable = false
                if let result = NSString(data:responseData, encoding: NSUTF8StringEncoding) as? String {
                    isNeopixelSketchAvailable = result.hasPrefix("Neopixel")
                }
 
                DLog("isNeopixelAvailable: \(isNeopixelSketchAvailable)")
                self.isNeopixelSketchAvailable = isNeopixelSketchAvailable
                
                dispatch_async(dispatch_get_main_queue(), { [unowned self] in
                    self.updateUI()
                    });
            }
        }
    }
    
    private func updateUI() {
        
        var statusText = "Connecting..."
        statusImageView.image = NSImage(named: "NSStatusNone")
        if let isNeopixelSketchAvailable = isNeopixelSketchAvailable {
            statusText = isNeopixelSketchAvailable ? "Neopixel: Ready" : "Neopixel: Not available"
            
            statusImageView.image = NSImage(named: isNeopixelSketchAvailable ?"NSStatusAvailable":"NSImageNameStatusUnavailable")
        }

        statusLabel.stringValue = statusText
        sendButton.enabled = isNeopixelSketchAvailable == true && !isSendingData
    }
    
    private func sendDataToUart(data: NSData, completionHandler: (response: NSData)->Void) {
        guard uartResponseDelegate == nil else {
            DLog("sendDataToUart error: waiting for a previous response")
            return
        }
        
        uartResponseDelegate = completionHandler
        sendDataToUart(data)
    }
    
    private func sendDataToUart(data:  NSData) {
        if let txCharacteristic = txCharacteristic {
            
            // Split data  in txmaxcharacters bytes
            var offset = 0
            repeat {
                let chunkSize = min(data.length-offset, UartViewController.TxMaxCharacters)
                let chunk = NSData(bytesNoCopy: UnsafeMutablePointer<UInt8>(data.bytes)+offset, length: chunkSize, freeWhenDone:false)
                
                blePeripheral?.peripheral.writeValue(chunk, forCharacteristic: txCharacteristic, type: CBCharacteristicWriteType.WithoutResponse)
                offset+=chunkSize
            }while(offset<data.length)
        }
    }
    
    @IBAction func onClickSend(sender: AnyObject) {
        let data = NSMutableData()
        /*
        if let command = "C".dataUsingEncoding(NSUTF8StringEncoding) {
            data.appendData(command)
        }*/
        
        let width : UInt8 = 8
        let height : UInt8 = 8
        let command : [UInt8] = [0x44, width, height ]           // Command: 'D', Width: 8, Height: 8
        data.appendBytes(command, length: command.count)

        let redPixel : [UInt8] = [32, 1, 1 ]
        let blackPixel : [UInt8] = [0, 0, 0 ]
        
        var imageData : [UInt8] = []
        let imageLength = width * height
        for i in 0..<imageLength {
            imageData.appendContentsOf(i%2==0 ? redPixel : blackPixel)
        }
        data.appendBytes(imageData, length: imageData.count)
        
        DLog("Send data: \(hexString(data))")
        /*
        if let message = NSString(data: data, encoding: NSUTF8StringEncoding) {
            DLog("Send data: \(message)")
        }
*/
        
        isSendingData = true
        sendDataToUart(data) { [unowned self] responseData in
            var success = false
            if let result = NSString(data:responseData, encoding: NSUTF8StringEncoding) as? String {
                success = result.hasPrefix("OK")
                }
            
            DLog("configured: \(success)")
            self.isSendingData = false
            dispatch_async(dispatch_get_main_queue(), { [unowned self] in
                self.updateUI()
                });
        }
    }
}

// MARK: - DetailTab
extension NeopixelViewController : DetailTab {
    func tabWillAppear() {
        if uartService == nil {
            blePeripheral?.peripheral.discoverServices([CBUUID(string: UartViewController.UartServiceUUID)])
        }
        
        updateUI()
    }
    
    func tabReset() {
        // Peripheral should be connected
        blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        
        if (blePeripheral == nil) {
            DLog("Error UART started without connected peripheral")
        }
        
        // Discover UART
        uartService = nil
        rxCharacteristic = nil
        txCharacteristic = nil
    }
}

// MARK: - CBPeripheralDelegate
extension NeopixelViewController: CBPeripheralDelegate {
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        
        if (uartService == nil) {
            if let services = peripheral.services {
                var found = false
                var i = 0
                while (!found && i < services.count) {
                    let service = services[i]
                    if (service.UUID.UUIDString .caseInsensitiveCompare(UartViewController.UartServiceUUID) == .OrderedSame) {
                        found = true
                        uartService = service
                        
                        peripheral.discoverCharacteristics([CBUUID(string: UartViewController.RxCharacteristicUUID), CBUUID(string: UartViewController.TxCharacteristicUUID)], forService: service)
                    }
                    i++
                }
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        
        if let uartService = uartService where rxCharacteristic == nil || txCharacteristic == nil {
            if (rxCharacteristic == nil || txCharacteristic == nil) {
                if let characteristics = uartService.characteristics {
                    var found = false
                    var i = 0
                    while (!found && i < characteristics.count) {
                        let characteristic = characteristics[i]
                        if (characteristic.UUID.UUIDString .caseInsensitiveCompare(UartViewController.RxCharacteristicUUID) == .OrderedSame) {
                            rxCharacteristic = characteristic
                        }
                        else if (characteristic.UUID.UUIDString .caseInsensitiveCompare(UartViewController.TxCharacteristicUUID) == .OrderedSame) {
                            txCharacteristic = characteristic
                        }
                        found = rxCharacteristic != nil && txCharacteristic != nil
                        i++
                    }
                }
            }
            
            // Check if characteristics are ready
            if (rxCharacteristic != nil && txCharacteristic != nil) {
                // Set rx enabled
                peripheral.setNotifyValue(true, forCharacteristic: rxCharacteristic!)
                //DLog("Neopixel subscribed to uart rx")
                
                checkNeopixelSketch()
                
                /*
                dispatch_async(dispatch_get_main_queue(), { [unowned self] in
                    if self.inputTextField != nil {     // could be nil if the viewdidload has not been executed yet
                        self.inputTextField.enabled = true
                        self.inputTextField.backgroundColor = NSColor.whiteColor()
                    }
                    });
                */
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        if characteristic == rxCharacteristic && characteristic.service == uartService {
            if let characteristicDataValue = characteristic.value {
                if let uartResponseDelegate = uartResponseDelegate {
                    self.uartResponseDelegate = nil
                    uartResponseDelegate(characteristicDataValue)
                }
            }
        }
    }

}