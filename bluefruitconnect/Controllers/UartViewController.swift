//
//  UartViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 26/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class UartViewController: NSViewController, CBPeripheralDelegate, NSTableViewDataSource, NSTableViewDelegate {

    enum DisplayMode {
        case Text           // Display a TextView with all uart data as a String
        case Table          // Display a table where each data chunk is a row
    }
    
    struct DataChunk {      // A chunk of data received or sent
        var timestamp : CFAbsoluteTime
        enum TransferMode {
            case TX
            case RX
        }
        var mode : TransferMode
        var data : NSData
        
    }
    
    enum UartNotifications : String {
        case DidTransferData = "didTransferData"
    }

    // Constants
    static let UartServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"       // UART service UUID
    static let RxCharacteristicUUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
    static let TxCharacteristicUUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
    static let TxMaxCharacters = 20

    // UI Outlets
    @IBOutlet var baseTextView: NSTextView!
    @IBOutlet weak var baseTextVisibilityView: NSScrollView!
    @IBOutlet weak var baseTableView: NSTableView!
    @IBOutlet weak var baseTableVisibilityView: NSScrollView!
    
    @IBOutlet weak var inputTextField: NSTextField!
    @IBOutlet weak var echoButton: NSButton!
    @IBOutlet weak var eolButton: NSButton!
    @IBOutlet weak var hexButton: NSButton!
    
    @IBOutlet weak var sentBytesLabel: NSTextField!
    @IBOutlet weak var receivedBytesLabel: NSTextField!
    
    // Bluetooth
    private var blePeripheral : BlePeripheral?
    private var uartService : CBService?
    private var rxCharacteristic : CBCharacteristic?
    private var txCharacteristic : CBCharacteristic?

    // Current State
    private var isInHexMode = false
    private var isEchoEnabled = true;
    private var isAutomaticEolEnabled = true;
    private var displayMode = DisplayMode.Text
    private var dataBuffer = [DataChunk]()
    private var tableModeDataMaxWidth : CGFloat = 0

    // UI
    private var txColor = Preferences.uartSentDataColor
    private var rxColor = Preferences.uartReceveivedDataColor
    private let timestampDateFormatter = NSDateFormatter()
    private var tableCachedDataBuffer : [DataChunk]?
    
    // MARK:
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Init Data
        timestampDateFormatter.setLocalizedDateFormatFromTemplate("HH:mm:ss:SSSS")
        isInHexMode = hexButton.state == NSOnState
        isEchoEnabled = echoButton.state == NSOnState
        isAutomaticEolEnabled = eolButton.state == NSOnState
        
        // Wait till uart is ready
        inputTextField.enabled = false
        inputTextField.backgroundColor = NSColor.blackColor().colorWithAlphaComponent(0.1)
        
        // Peripheral should be connected
        blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        blePeripheral?.peripheral.delegate = self
        
        // Discover UART
        blePeripheral?.peripheral.discoverServices([CBUUID(string: UartViewController.UartServiceUUID)])
        
        // UI
        baseTableVisibilityView.scrollerStyle = NSScrollerStyle.Legacy      // To avoid autohide behaviour
        reloadDataUI()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // Peripheral should be connected
        blePeripheral?.peripheral.delegate = self
        
        registerNotifications(true)
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        registerNotifications(false)
    }
    
  
    // MARK: - Preferences
    func registerNotifications(register : Bool) {
        
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        if (register) {
            notificationCenter.addObserver(self, selector: "preferencesUpdated:", name: Preferences.PreferencesNotifications.DidUpdatePreferences.rawValue, object: nil)
        }
        else {
            notificationCenter.removeObserver(self, name: Preferences.PreferencesNotifications.DidUpdatePreferences.rawValue, object: nil)
        }
    }
    
    func preferencesUpdated(notification : NSNotification) {
        txColor = Preferences.uartSentDataColor
        rxColor = Preferences.uartReceveivedDataColor
        reloadDataUI()
    }

    
    // MARK: - Uart
    func sendUserText(text: String) {
        
        var newText = text
        
        // Eol
        if (isAutomaticEolEnabled)  {
            newText += "\n"
        }
        
        // Create data and send to Uart
        if let data = newText.dataUsingEncoding(NSUTF8StringEncoding) {
            blePeripheral?.uartData.sentBytes += data.length
            registerDataSent(data)
            sendDataToUart(data)
        }
    }
    
    func sendDataToUart(data:  NSData) {
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

    func registerDataSent(data : NSData) {
        let dataChunk = DataChunk(timestamp: CFAbsoluteTimeGetCurrent(), mode: .TX, data: data)
        dataBuffer.append(dataChunk)

        dispatch_async(dispatch_get_main_queue(), {[unowned self] in
            self.addChunkToUI(dataChunk)
            })
        
        NSNotificationCenter.defaultCenter().postNotificationName(UartNotifications.DidTransferData.rawValue, object: nil);
    }
        
    func registerDataReceived(data : NSData) {
        let dataChunk = DataChunk(timestamp: CFAbsoluteTimeGetCurrent(), mode: .RX, data: data)
        blePeripheral?.uartData.receivedBytes += dataChunk.data.length
        dataBuffer.append(dataChunk)
            
        dispatch_async(dispatch_get_main_queue(), {[unowned self] in
            self.addChunkToUI(dataChunk)
        })
        
        NSNotificationCenter.defaultCenter().postNotificationName(UartNotifications.DidTransferData.rawValue, object: nil);
    }
    
    
    
    // MARK: - UI updates
    
    func addChunkToUI(dataChunk : DataChunk) {
        switch(displayMode) {
        case .Text:
            if let textStorage = self.baseTextView.textStorage {
                addChunkToUIText(dataChunk)
                baseTextView.scrollRangeToVisible(NSMakeRange(textStorage.length, 0))
            }
            
        case .Table:
            baseTableView.reloadData()
            baseTableView.scrollToEndOfDocument(nil)
            
        }
        
        updateBytesUI()
    }
    
    func addChunkToUIText(dataChunk : DataChunk) {
        
        if (isEchoEnabled || dataChunk.mode == .RX) {
            let color = dataChunk.mode == .TX ? txColor : rxColor
            
            let attributedString = attributeTextFromData(dataChunk.data, useHexMode: isInHexMode, color: color)
            
            if let textStorage = self.baseTextView.textStorage, attributedString = attributedString {
                textStorage.appendAttributedString(attributedString)
            }
        }
    }
    
    func attributeTextFromData(data : NSData, useHexMode : Bool, color : NSColor) -> NSAttributedString? {
        var attributedString : NSAttributedString?

        if (useHexMode) {
            let hexValue = hexString(data)
            attributedString = NSAttributedString(string: hexValue, attributes: [NSForegroundColorAttributeName: color])
        }
        else {
            let utf8Value = NSString(data:data, encoding: NSUTF8StringEncoding) as String?
            if let utf8Value = utf8Value {
                attributedString = NSAttributedString(string: utf8Value, attributes: [NSForegroundColorAttributeName: color])
            }
        }
 
        return attributedString
    }
    
    func reloadDataUI() {
        baseTableVisibilityView.hidden = displayMode == .Text
        baseTextVisibilityView.hidden = displayMode == .Table
        
        switch(displayMode) {
        case .Text:
            if let textStorage = self.baseTextView.textStorage {
                
                textStorage.beginEditing()
                textStorage.replaceCharactersInRange(NSMakeRange(0, textStorage.length), withAttributedString: NSAttributedString())        // Clear text
                for dataChunk in dataBuffer {
                    addChunkToUIText(dataChunk)
                }
                textStorage .endEditing()
                baseTextView.scrollRangeToVisible(NSMakeRange(textStorage.length, 0))

            }
            
        case .Table:
            baseTableView.sizeLastColumnToFit()
            baseTableView.reloadData()
            baseTableView.scrollToEndOfDocument(nil)
        }
        
        updateBytesUI()
    }
    
    func updateBytesUI() {
        if let blePeripheral = blePeripheral {
            sentBytesLabel.stringValue = "Sent: \(blePeripheral.uartData.sentBytes) bytes"
            receivedBytesLabel.stringValue = "Received: \(blePeripheral.uartData.receivedBytes) bytes"
        }
    }
  
    
    // MARK: - UI Actions
    @IBAction func onClickEcho(sender: NSButton) {
        isEchoEnabled = echoButton.state == NSOnState
        reloadDataUI()
    }
    
    @IBAction func onClickEol(sender: NSButton) {
        isAutomaticEolEnabled = eolButton.state == NSOnState
    }
    
    @IBAction func onClickHex(sender: NSButton) {
        isInHexMode = hexButton.state == NSOnState
        reloadDataUI()
    }
    
    @IBAction func onClickTimestamp(sender: NSButton) {
        displayMode = sender.state == NSOnState ? .Table : .Text
        reloadDataUI()
    }
    
    @IBAction func onClickClear(sender: NSButton) {
        dataBuffer.removeAll()
        blePeripheral?.uartData.receivedBytes = 0
        blePeripheral?.uartData.sentBytes = 0
        tableModeDataMaxWidth = 0
        reloadDataUI()
    }
    
    @IBAction func onClickSend(sender: AnyObject) {
        let text = inputTextField.stringValue
        sendUserText(text)
        inputTextField.stringValue = ""
    }
    
    @IBAction func onClickExport(sender: AnyObject) {
        
        // Check if data is empty
        guard dataBuffer.count > 0 else {
            let alert = NSAlert()
            alert.messageText = "No data to export"
            alert.addButtonWithTitle("Ok")
            alert.alertStyle = .WarningAlertStyle
            alert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
            return
        }
        
        // Show save dialog
        let saveFileDialog = NSSavePanel()
        saveFileDialog.canCreateDirectories = true
        if (displayMode == .Text) {
            saveFileDialog.nameFieldStringValue = isInHexMode ? "uart.hex.txt" : "uart.txt"
        }
        else {
            saveFileDialog.nameFieldStringValue = isInHexMode ? "uart.hex.csv" : "uart.csv"
        }
        
        if let window = self.view.window {
            saveFileDialog.beginSheetModalForWindow(window) {[unowned self] (result) -> Void in
                if result == NSFileHandlingPanelOKButton {
                    if let url = saveFileDialog.URL {
                        
                        // Save
                        var text : String?
                        if (self.displayMode == .Text) {
                            text = self.dataAsText(url)
                        }
                        else {
                            text = self.dataAsCvs(url)
                        }
                        
                        // Write data
                        do {
                            try text?.writeToURL(url, atomically: true, encoding: NSUTF8StringEncoding)
                        }
                        catch let error {
                            DLog("Error exporting file \(url.absoluteString): \(error)")
                        }

                    }
                }
            }
        }
    }
    
    
    // MARK: - Export to file

    func dataAsText(url : NSURL) -> String? {
        // Compile all data
        let data = NSMutableData()
        for dataChunk in self.dataBuffer {
            data.appendData(dataChunk.data)
        }
        
        var text : String?
        if (self.isInHexMode) {
            text = hexString(data)
        }
        else {
            text = NSString(data:data, encoding: NSUTF8StringEncoding) as String?
        }
    
        return text
    }
    
    func dataAsCvs(url : NSURL)  -> String? {
        var text = "Timestamp,Mode,Data\r\n"        // csv Header

        // Compile all data
        for dataChunk in self.dataBuffer {
            let date = NSDate(timeIntervalSinceReferenceDate: dataChunk.timestamp)
            let dateString = timestampDateFormatter.stringFromDate(date).stringByReplacingOccurrencesOfString(",", withString: ".")         //  comma messes with csv, so replace it by point
            let mode = dataChunk.mode == .RX ? "RX" : "TX"
            var dataString : String?
            if (self.isInHexMode) {
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
    
    
     // MARK: - CBPeripheralDelegate
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
            
            if let characteristicDataValue = characteristic.value {
                registerDataReceived(characteristicDataValue)
            }
        }
    }
    
    // MARK: - NSTableViewDataSource
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        if (isEchoEnabled)  {
            tableCachedDataBuffer = dataBuffer
        }
        else {
            tableCachedDataBuffer = dataBuffer.filter({ (dataChunk : DataChunk) -> Bool in
                dataChunk.mode == .RX
            })
        }

        return tableCachedDataBuffer!.count
    }
    
    
    // MARK: NSTableViewDelegate
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        var cell : NSTableCellView?
        
        let dataChunk = tableCachedDataBuffer![row]
        
        if let columnIdentifier = tableColumn?.identifier {
            switch(columnIdentifier) {
            case "TimestampColumn":
                cell = tableView.makeViewWithIdentifier("TimestampCell", owner: self) as? NSTableCellView
                
                let date = NSDate(timeIntervalSinceReferenceDate: dataChunk.timestamp)
                let dateString = timestampDateFormatter.stringFromDate(date)//.stringByReplacingOccurrencesOfString(",", withString: ".")
                cell!.textField!.stringValue = dateString
                
            case "DirectionColumn":
                cell = tableView.makeViewWithIdentifier("DirectionCell", owner: self) as? NSTableCellView

                cell!.textField!.stringValue = dataChunk.mode == .RX ? "RX" : "TX"
                
            case "DataColumn":
                cell = tableView.makeViewWithIdentifier("DataCell", owner: self) as? NSTableCellView
                
                let color = dataChunk.mode == .TX ? txColor : rxColor

                if let attributedText = attributeTextFromData(dataChunk.data, useHexMode: isInHexMode, color: color) {
                    DLog("row \(row): \(attributedText.string)")

                    // Display
                    cell!.textField!.attributedStringValue = attributedText
                    
                    // Update column width (if needed)
                    let width = attributedText.size().width
                    tableModeDataMaxWidth = max(tableColumn!.width, width)
                    dispatch_async(dispatch_get_main_queue(), {     // Important: Execute async. This change should be done outside the delegate method to avoid weird reuse cell problems (reused cell shows old data and cant be changed).
                        if (tableColumn!.width < self.tableModeDataMaxWidth) {
                            tableColumn!.width = self.tableModeDataMaxWidth
                        }
                    });
                }
                else {
                    DLog("row \(row): <empty>")
                    cell!.textField!.attributedStringValue = NSAttributedString()
                }
                
                
            default:
                cell = nil
            }
        }
        
        
        return cell;
    }
    
    func tableViewSelectionDidChange(notification: NSNotification) {
        

    }
    
    func tableViewColumnDidResize(notification: NSNotification) {
        if let tableColumn = notification.userInfo?["NSTableColumn"] as? NSTableColumn {
            if (tableColumn.identifier == "DataColumn") {
                // If the window is resized, maintain the column width
                if (tableColumn.width < tableModeDataMaxWidth) {
                    tableColumn.width = tableModeDataMaxWidth
                }
                DLog("column: \(tableColumn), width: \(tableColumn.width)")
            }
        }
        
    }

}
