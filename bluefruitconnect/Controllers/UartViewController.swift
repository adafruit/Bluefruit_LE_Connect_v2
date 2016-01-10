//
//  UartViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 26/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class UartViewController: NSViewController {
    
    enum DisplayMode {
        case Text           // Display a TextView with all uart data as a String
        case Table          // Display a table where each data chunk is a row
    }
    
    enum UartNotifications : String {
        case DidTransferData = "didTransferData"
    }
    
    enum ExportFormat : String {
        case txt = "txt"
        case csv = "csv"
        case json = "json"
        case xml = "xml"
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
    
    @IBOutlet weak var hexModeSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var displayModeSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var mqttStatusButton: NSButton!
    
    @IBOutlet weak var inputTextField: NSTextField!
    @IBOutlet weak var echoButton: NSButton!
    @IBOutlet weak var eolButton: NSButton!
    
    @IBOutlet weak var sentBytesLabel: NSTextField!
    @IBOutlet weak var receivedBytesLabel: NSTextField!
    
    @IBOutlet var saveDialogCustomView: NSView!
    @IBOutlet weak var saveDialogPopupButton: NSPopUpButton!
    
    // Bluetooth
    private var blePeripheral : BlePeripheral?
    private var uartService : CBService?
    private var rxCharacteristic : CBCharacteristic?
    private var txCharacteristic : CBCharacteristic?
    
    // Current State
    private var dataBuffer = [UartDataChunk]()
    private var tableModeDataMaxWidth : CGFloat = 0
    
    // UI
    private var dataFont = NSFont(name: "CourierNewPSMT", size: 13)!
    private var txColor = Preferences.uartSentDataColor
    private var rxColor = Preferences.uartReceveivedDataColor
    private let timestampDateFormatter = NSDateFormatter()
    private var tableCachedDataBuffer : [UartDataChunk]?
    
    // Export
    private var exportFileDialog : NSSavePanel?
    private let exportFormats = [ExportFormat.txt, ExportFormat.csv, ExportFormat.json, ExportFormat.xml]
    
    // MARK:
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Init Data
        timestampDateFormatter.setLocalizedDateFormatFromTemplate("HH:mm:ss:SSSS")
        
        // Init UI
        hexModeSegmentedControl.selectedSegment = Preferences.uartIsInHexMode ? 1:0
        displayModeSegmentedControl.selectedSegment = Preferences.uartIsDisplayModeTimestamp ? 1:0
        
        echoButton.state = Preferences.uartIsEchoEnabled ? NSOnState:NSOffState
        eolButton.state = Preferences.uartIsAutomaticEolEnabled ? NSOnState:NSOffState
        
        // UI
        baseTableVisibilityView.scrollerStyle = NSScrollerStyle.Legacy      // To avoid autohide behaviour
        reloadDataUI()
        
        // Mqtt init
        let mqttManager = MqttManager.sharedInstance
        if (MqttSettings.sharedInstance.isConnected) {
            mqttManager.delegate = self
            mqttManager.connectFromSavedSettings()
        }
    }
    
    func reset() {
        // Peripheral should be connected
        blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        
        if (blePeripheral == nil) {
            DLog("Error UART started without connected peripheral")
        }
        
        // Discover UART
        uartService = nil
        rxCharacteristic = nil
        txCharacteristic = nil
        blePeripheral?.peripheral.discoverServices([CBUUID(string: UartViewController.UartServiceUUID)])
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        registerNotifications(true)
        updateMqttStatusUI()
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        registerNotifications(false)
    }
    
    deinit {
        let mqttManager = MqttManager.sharedInstance
        mqttManager.disconnect()
    }
    
    func tabWillAppear() {
        reloadDataUI()
        
        // Check if characteristics are ready
        let isUartReady = rxCharacteristic != nil && txCharacteristic != nil
        inputTextField.enabled = isUartReady
        inputTextField.backgroundColor = isUartReady ? NSColor.whiteColor() : NSColor.blackColor().colorWithAlphaComponent(0.1)
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
    func sendMessageToUart(text: String, wasReceivedFromMqtt: Bool) {
        
        // Mqtt publish to TX
        let mqttSettings = MqttSettings.sharedInstance
        if(mqttSettings.isPublishEnabled) {
            if let topic = mqttSettings.getPublishTopic(MqttSettings.PublishFeed.TX.rawValue) {
                let qos = mqttSettings.getPublishQos(MqttSettings.PublishFeed.TX.rawValue)
                MqttManager.sharedInstance.publish(text, topic: topic, qos: qos)
            }
        }

        // Create data and send to Uart
        if let data = text.dataUsingEncoding(NSUTF8StringEncoding) {
            blePeripheral?.uartData.sentBytes += data.length
            registerDataSent(data, wasReceivedFromMqtt: wasReceivedFromMqtt)
            
            if (!wasReceivedFromMqtt || mqttSettings.subscribeBehaviour == .Transmit) {
                sendDataToUart(data)
            }
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
    
    func registerDataSent(data : NSData, wasReceivedFromMqtt: Bool) {
        let dataChunk = UartDataChunk(timestamp: CFAbsoluteTimeGetCurrent(), mode: .TX, data: data)
        dataBuffer.append(dataChunk)

        dispatch_async(dispatch_get_main_queue(), {[unowned self] in
            self.addChunkToUI(dataChunk)
            })
        NSNotificationCenter.defaultCenter().postNotificationName(UartNotifications.DidTransferData.rawValue, object: nil);
    }
    
    func registerDataReceived(data : NSData) {
        
        // Mqtt publish to RX
        let mqttSettings = MqttSettings.sharedInstance
        if mqttSettings.isPublishEnabled {
            if let message = NSString(data: data, encoding: NSUTF8StringEncoding) {
                if let topic = mqttSettings.getPublishTopic(MqttSettings.PublishFeed.RX.rawValue) {
                    let qos = mqttSettings.getPublishQos(MqttSettings.PublishFeed.RX.rawValue)
                    MqttManager.sharedInstance.publish(message as String, topic: topic, qos: qos)
                }
            }
        }
        
        // Process received data
        let dataChunk = UartDataChunk(timestamp: CFAbsoluteTimeGetCurrent(), mode: .RX, data: data)
        blePeripheral?.uartData.receivedBytes += dataChunk.data.length
        dataBuffer.append(dataChunk)
        
        // Add to UI
        dispatch_async(dispatch_get_main_queue(), {[unowned self] in
            self.addChunkToUI(dataChunk)
            })
        
        NSNotificationCenter.defaultCenter().postNotificationName(UartNotifications.DidTransferData.rawValue, object: nil);
    }
    
    // MARK: - UI Updates
    func addChunkToUI(dataChunk : UartDataChunk) {
        // Check that the view has been initialized before updating UI
        guard baseTableView != nil else {
            return;
        }
        
        let displayMode = Preferences.uartIsDisplayModeTimestamp ? DisplayMode.Table : DisplayMode.Text
        
        switch(displayMode) {
        case .Text:
            if let textStorage = self.baseTextView.textStorage {
                let isScrollAtTheBottom = baseTextView.enclosingScrollView?.verticalScroller?.floatValue == 1
                
                addChunkToUIText(dataChunk)
                
                if isScrollAtTheBottom {
                    // if scroll was at the bottom then autoscroll to the new bottom
                    baseTextView.scrollRangeToVisible(NSMakeRange(textStorage.length, 0))
                }
            }
            
        case .Table:
            let isScrollAtTheBottom = baseTableView.enclosingScrollView?.verticalScroller?.floatValue == 1
            
            baseTableView.reloadData()
            if isScrollAtTheBottom {
                // if scroll was at the bottom then autoscroll to the new bottom
                baseTableView.scrollToEndOfDocument(nil)
            }
        }
        
        updateBytesUI()
    }
    
    func addChunkToUIText(dataChunk : UartDataChunk) {
        
        if (Preferences.uartIsEchoEnabled || dataChunk.mode == .RX) {
            let color = dataChunk.mode == .TX ? txColor : rxColor
            
            let attributedString = attributeTextFromData(dataChunk.data, useHexMode: Preferences.uartIsInHexMode, color: color)
            
            if let textStorage = self.baseTextView.textStorage, attributedString = attributedString {
                textStorage.appendAttributedString(attributedString)
            }
        }
    }
    
    func attributeTextFromData(data : NSData, useHexMode : Bool, color : NSColor) -> NSAttributedString? {
        var attributedString : NSAttributedString?
        
        let textAttributes : [String:AnyObject] = [NSFontAttributeName : dataFont, NSForegroundColorAttributeName: color]
        
        if (useHexMode) {
            let hexValue = hexString(data)
            attributedString = NSAttributedString(string: hexValue, attributes: textAttributes)
        }
        else {
            let utf8Value = NSString(data:data, encoding: NSUTF8StringEncoding) as String?
            if let utf8Value = utf8Value {
                attributedString = NSAttributedString(string: utf8Value, attributes: textAttributes)
            }
        }
        
        return attributedString
    }
    
    func reloadDataUI() {
        let displayMode = Preferences.uartIsDisplayModeTimestamp ? DisplayMode.Table : DisplayMode.Text
        
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
        Preferences.uartIsEchoEnabled = echoButton.state == NSOnState
        reloadDataUI()
    }
    
    @IBAction func onClickEol(sender: NSButton) {
        Preferences.uartIsAutomaticEolEnabled = eolButton.state == NSOnState
    }
    
    @IBAction func onChangeHexMode(sender: AnyObject) {
        Preferences.uartIsInHexMode = sender.selectedSegment == 1
        reloadDataUI()
    }
    
    @IBAction func onChangeDisplayMode(sender: NSSegmentedControl) {
        Preferences.uartIsDisplayModeTimestamp = sender.selectedSegment == 1
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
        
        var newText = text
        // Eol
        if (Preferences.uartIsAutomaticEolEnabled)  {
            newText += "\n"
        }

        sendMessageToUart(newText, wasReceivedFromMqtt: false)
        inputTextField.stringValue = ""
    }
    
    @IBAction func onClickExport(sender: AnyObject) {
        exportData()
    }
    
    @IBAction func onClickMqtt(sender: AnyObject) {
        
        let mqttManager = MqttManager.sharedInstance
        let status = mqttManager.status
        if status != .Connected && status != .Connecting {
            if let serverAddress = MqttSettings.sharedInstance.serverAddress where !serverAddress.isEmpty {
                // Server address is defined. Start connection
                mqttManager.delegate = self
                mqttManager.connectFromSavedSettings()
            }
            else {
                // Server address not defined
                let alert = NSAlert()
                alert.messageText = "Mqtt server not defined"
                alert.addButtonWithTitle("Ok")
                alert.addButtonWithTitle("Edit Mqtt Settings")
                alert.alertStyle = .WarningAlertStyle
                alert.beginSheetModalForWindow(self.view.window!) { [unowned self] (returnCode) -> Void in
                    if returnCode == NSAlertSecondButtonReturn {
                        let preferencesViewController = self.storyboard?.instantiateControllerWithIdentifier("PreferencesViewController") as! PreferencesViewController
                        self.presentViewControllerAsModalWindow(preferencesViewController)
                    }
                }
            }
        }
        else {
            mqttManager.disconnect()
        }
        
        updateMqttStatusUI()
    }
    
    // MARK: - MQTT
    
    func updateMqttStatusUI() {
        let status = MqttManager.sharedInstance.status
        
        var buttonTitle = "MQTT"
        switch (status) {
        case .Connecting:
            buttonTitle = "MQTT: connecting..."
            
        case .Connected:
            buttonTitle = "MQTT: connected"
            
        default:
            buttonTitle = "MQTT: disconnected"
        }
        
        mqttStatusButton.title = buttonTitle
    }
    
    
    // MARK: - Export
    private func exportData() {
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
        exportFileDialog = NSSavePanel()
        exportFileDialog!.delegate = self
        exportFileDialog!.message = "Export Data to File"
        exportFileDialog!.prompt = "Export"
        exportFileDialog!.canCreateDirectories = true
        exportFileDialog!.accessoryView = saveDialogCustomView
        
        for exportFormat in exportFormats {
            saveDialogPopupButton.addItemWithTitle(exportFormat.rawValue)
        }
        
        updateSaveFileName()
        
        if let window = self.view.window {
            exportFileDialog!.beginSheetModalForWindow(window) {[unowned self] (result) -> Void in
                if result == NSFileHandlingPanelOKButton {
                    if let url = self.exportFileDialog!.URL {
                        
                        // Save
                        var text : String?
                        let exportFormatSelected = self.exportFormats[self.saveDialogPopupButton.indexOfSelectedItem]

                        switch(exportFormatSelected) {
                        case .txt:
                            text = UartDataExport.dataAsText(self.dataBuffer)
                        case .csv:
                            text = UartDataExport.dataAsCsv(self.dataBuffer)
                        case .json:
                            text = UartDataExport.dataAsJson(self.dataBuffer)
                            break
                        case .xml:
                            text = UartDataExport.dataAsXml(self.dataBuffer)
                            break
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
    
    @IBAction func onExportFormatChanged(sender: AnyObject) {
        updateSaveFileName()
    }
    
    private func updateSaveFileName() {
        if let exportFileDialog = exportFileDialog {
            let isInHexMode = Preferences.uartIsInHexMode
            let exportFormatSelected = exportFormats[saveDialogPopupButton.indexOfSelectedItem]
            exportFileDialog.nameFieldStringValue = "uart\(isInHexMode ? ".hex" : "").\(exportFormatSelected.rawValue)"
        }
    }
    
   
    
}

// MARK: - NSOpenSavePanelDelegate
extension UartViewController: NSOpenSavePanelDelegate {
    
}

// MARK: - NSTableViewDataSource
extension UartViewController: NSTableViewDataSource {
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        if (Preferences.uartIsEchoEnabled)  {
            tableCachedDataBuffer = dataBuffer
        }
        else {
            tableCachedDataBuffer = dataBuffer.filter({ (dataChunk : UartDataChunk) -> Bool in
                dataChunk.mode == .RX
            })
        }
        
        return tableCachedDataBuffer!.count
    }
}

// MARK: NSTableViewDelegate
extension UartViewController: NSTableViewDelegate {
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
                
                if let attributedText = attributeTextFromData(dataChunk.data, useHexMode: Preferences.uartIsInHexMode, color: color) {
                    //DLog("row \(row): \(attributedText.string)")
                    
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
                    //DLog("row \(row): <empty>")
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
                //DLog("column: \(tableColumn), width: \(tableColumn.width)")
            }
        }
    }
}

// MARK: - CBPeripheralDelegate
extension UartViewController: CBPeripheralDelegate {
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
        
        DLog("uart didDiscoverCharacteristicsForService")
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
                dispatch_async(dispatch_get_main_queue(), { [unowned self] in
                    if self.inputTextField != nil {     // could be nil if the viewdidload has not been executed yet
                        self.inputTextField.enabled = true
                        self.inputTextField.backgroundColor = NSColor.whiteColor()
                    }
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
    
  
}

// MARK: - MqttManagerDelegate
extension UartViewController : MqttManagerDelegate {
    func onMqttConnected() {
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            self.updateMqttStatusUI()
            })
    }
    
    func onMqttDisconnected() {
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            self.updateMqttStatusUI()
            })
        
    }
    
    func onMqttMessageReceived(message : String, topic: String) {
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            self.sendMessageToUart(message, wasReceivedFromMqtt: true)
            })
    }
    
    func onMqttError(message : String) {
        let mqttManager = MqttManager.sharedInstance
        let status = mqttManager.status
        let isConnectionError = status == .Connecting

        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            let alert = NSAlert()
            alert.messageText = isConnectionError ? "Connection Error": message
            alert.addButtonWithTitle("Ok")
            if (isConnectionError) {
                alert.addButtonWithTitle("Edit Mqtt Settings")
                alert.informativeText = message
            }
            alert.alertStyle = .WarningAlertStyle
            alert.beginSheetModalForWindow(self.view.window!) { [unowned self] (returnCode) -> Void in
                if isConnectionError && returnCode == NSAlertSecondButtonReturn {
                    let preferencesViewController = self.storyboard?.instantiateControllerWithIdentifier("PreferencesViewController") as! PreferencesViewController
                     self.presentViewControllerAsModalWindow(preferencesViewController)
                }
            }
            })
    }
}