//
//  UartViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 26/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class UartViewController: NSViewController, CBPeripheralDelegate {

    static let UartServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"       // UART service UUID
    static let RxCharacteristicUUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
    static let TxCharacteristicUUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
    static let TxMaxCharacters = 20
    
    @IBOutlet var baseTextView: NSTextView!
    @IBOutlet weak var inputTextField: NSTextField!
    @IBOutlet weak var echoButton: NSButton!
    @IBOutlet weak var eolButton: NSButton!
    @IBOutlet weak var hexButton: NSButton!
    
    private var blePeripheral : BlePeripheral?
    private var uartService : CBService?
    private var rxCharacteristic : CBCharacteristic?
    private var txCharacteristic : CBCharacteristic?
    
    private var utf8Text = NSMutableAttributedString()
    private var hexText = NSMutableAttributedString()
    
    private let txColor = NSColor.blueColor()
    private let rxColor = NSColor.redColor()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        inputTextField.enabled = false
        inputTextField.backgroundColor = NSColor.blackColor().colorWithAlphaComponent(0.1)

        // Peripheral should be connected
        blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        blePeripheral?.peripheral.delegate = self
        
        // Discover UART
        blePeripheral?.peripheral.discoverServices([CBUUID(string: UartViewController.UartServiceUUID)])
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // Peripheral should be connected
        blePeripheral?.peripheral.delegate = self
    }
    
    @IBAction func onClickSend(sender: AnyObject) {
        let text = inputTextField.stringValue
        sendText(text)
        inputTextField.stringValue = ""
    }
    
    func sendText(text: String) {
        
        var newText = text
        
        // Eol
        if (eolButton.state == NSOnState)  {
            newText += "\n"
        }
        
        if let data = newText.dataUsingEncoding(NSUTF8StringEncoding) {

            // Echo
            if (echoButton.state == NSOnState) {
                addDataToBuffers(data, color:txColor)
            }
            
            
            sendData(data)
        }
    }
    
    func sendData(data:  NSData) {
        if let txCharacteristic = txCharacteristic {
            
            // Split data  in txmaxcharacters bytes
            var offset = 0
            repeat {
                let chunkSize = min(data.length, UartViewController.TxMaxCharacters)
                let chunk = NSData(bytesNoCopy: UnsafeMutablePointer<UInt8>(data.bytes)+offset, length: chunkSize, freeWhenDone:false)
                
                blePeripheral?.peripheral.writeValue(chunk, forCharacteristic: txCharacteristic, type: CBCharacteristicWriteType.WithoutResponse)
                offset+=chunkSize
            }while(offset<data.length)
            
        }
    }

    func addDataToBuffers(data : NSData, color : NSColor) {
        let hexValue = hexString(data)
        let utf8Value = NSString(data:data, encoding: NSUTF8StringEncoding) as String?
        
        // Add values to text buffers
        var utf8AttributedValue = NSAttributedString()
        if let utf8Value = utf8Value {
            utf8AttributedValue = NSAttributedString(string: utf8Value, attributes: [NSForegroundColorAttributeName: color])
            utf8Text.appendAttributedString(utf8AttributedValue)
        }
        
        let hexAttributedValue = NSAttributedString(string: hexValue, attributes: [NSForegroundColorAttributeName: color])
        hexText.appendAttributedString(hexAttributedValue)
        
        dispatch_async(dispatch_get_main_queue(), {[unowned self] in
            let text = self.hexButton.state == NSOnState ?hexAttributedValue:utf8AttributedValue
            
            if let textStorage = self.baseTextView.textStorage {
                textStorage.beginEditing()
                textStorage.appendAttributedString(text)
                textStorage .endEditing()
                self.baseTextView.scrollRangeToVisible(NSMakeRange(textStorage.length, 0))
            }
            });
    }
    
    
  
    
    func updateTextView() {
        let text = hexButton.state == NSOnState ?hexText:utf8Text
        baseTextView.textStorage?.setAttributedString(text)
    }
    
    
    @IBAction func onClickEcho(sender: NSButton) {
        updateTextView()
    }
    
    @IBAction func onClickEol(sender: NSButton) {
        updateTextView()
    }
    
    @IBAction func onClickHex(sender: NSButton) {
        updateTextView()
    }
    
    @IBAction func onClickClear(sender: NSButton) {
        utf8Text = NSMutableAttributedString()
        hexText = NSMutableAttributedString()
        updateTextView()
    }
    
     // MARK - CBPeripheralDelegate
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
        
        if let uartService = uartService {
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
                
                // Enable input
                dispatch_async(dispatch_get_main_queue(), {
                    self.inputTextField.enabled = true
                    self.inputTextField.backgroundColor = NSColor.whiteColor()
                });
            }
            
        }
    }

    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        if characteristic == rxCharacteristic && characteristic.service == uartService {
            
            if let characteristicValue = characteristic.value {
                addDataToBuffers(characteristicValue, color:rxColor)
            }
        }
    }

}
