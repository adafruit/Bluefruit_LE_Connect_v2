//
//  UartViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 26/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class UartViewController: NSViewController {
    
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
    
    // Data
    private let uartData = UartModuleManager()
    
    // UI
    private static var dataFont = Font(name: "CourierNewPSMT", size: 13)!
    private var txColor = Preferences.uartSentDataColor
    private var rxColor = Preferences.uartReceveivedDataColor
    private let timestampDateFormatter = NSDateFormatter()
    private var tableCachedDataBuffer : [UartDataChunk]?
    private var tableModeDataMaxWidth : CGFloat = 0

    // Export
    private var exportFileDialog : NSSavePanel?

    // MARK:
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Init Data
        uartData.delegate = self
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
            mqttManager.delegate = uartData
            mqttManager.connectFromSavedSettings()
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        
        registerNotifications(true)
        mqttUpdateStatusUI()
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        registerNotifications(false)
    }
    
    deinit {
        let mqttManager = MqttManager.sharedInstance
        mqttManager.disconnect()
    }
    
    
    // MARK: - Preferences
    func registerNotifications(register : Bool) {
        
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        if (register) {
            notificationCenter.addObserver(self, selector: #selector(UartViewController.preferencesUpdated(_:)), name: Preferences.PreferencesNotifications.DidUpdatePreferences.rawValue, object: nil)
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
    
    
    // MARK: - UI Updates
    func reloadDataUI() {
        let displayMode = Preferences.uartIsDisplayModeTimestamp ? UartModuleManager.DisplayMode.Table : UartModuleManager.DisplayMode.Text
        
        baseTableVisibilityView.hidden = displayMode == .Text
        baseTextVisibilityView.hidden = displayMode == .Table
        
        switch(displayMode) {
        case .Text:
            if let textStorage = self.baseTextView.textStorage {
                
                let isScrollAtTheBottom = baseTextView.enclosingScrollView?.verticalScroller?.floatValue == 1

                textStorage.beginEditing()
                textStorage.replaceCharactersInRange(NSMakeRange(0, textStorage.length), withAttributedString: NSAttributedString())        // Clear text
                for dataChunk in uartData.dataBuffer {
                    addChunkToUIText(dataChunk)
                }
                textStorage .endEditing()
                if isScrollAtTheBottom {
                    baseTextView.scrollRangeToVisible(NSMakeRange(textStorage.length, 0))
                }
                
            }
            
        case .Table:
            //let isScrollAtTheBottom = tableCachedDataBuffer == nil || tableCachedDataBuffer!.isEmpty  || baseTableView.enclosingScrollView?.verticalScroller?.floatValue == 1
            let isScrollAtTheBottom = tableCachedDataBuffer == nil || tableCachedDataBuffer!.isEmpty || NSLocationInRange(tableCachedDataBuffer!.count-1, baseTableView.rowsInRect(baseTableView.visibleRect))

            baseTableView.sizeLastColumnToFit()
            baseTableView.reloadData()
            if isScrollAtTheBottom {
                baseTableView.scrollToEndOfDocument(nil)
            }
        }
        
        updateBytesUI()
    }
    
    func updateBytesUI() {
        if let blePeripheral = uartData.blePeripheral {
            let localizationManager = LocalizationManager.sharedInstance
            sentBytesLabel.stringValue = String(format: localizationManager.localizedString("uart_sentbytes_format"), arguments: [blePeripheral.uartData.sentBytes])
            receivedBytesLabel.stringValue = String(format: localizationManager.localizedString("uart_recievedbytes_format"), arguments: [blePeripheral.uartData.receivedBytes])
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
        uartData.clearData()
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

        uartData.sendMessageToUart(newText)
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
                mqttManager.delegate = uartData
                mqttManager.connectFromSavedSettings()
            }
            else {
                // Server address not defined
                let localizationManager = LocalizationManager.sharedInstance
                let alert = NSAlert()
                alert.messageText = localizationManager.localizedString("uart_mqtt_undefinedserver")
                alert.addButtonWithTitle(localizationManager.localizedString("dialog_ok"))
                alert.addButtonWithTitle(localizationManager.localizedString("uart_mqtt_editsettings"))
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
        
        mqttUpdateStatusUI()
    }
    
    // MARK: - Export
    private func exportData() {
        let localizationManager = LocalizationManager.sharedInstance
        
        // Check if data is empty
        guard uartData.dataBuffer.count > 0 else {
            let alert = NSAlert()
            alert.messageText = localizationManager.localizedString("uart_export_nodata")
            alert.addButtonWithTitle(localizationManager.localizedString("dialog_ok"))
            alert.alertStyle = .WarningAlertStyle
            alert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
            return
        }
        
        // Show save dialog
        exportFileDialog = NSSavePanel()
        exportFileDialog!.delegate = self
        exportFileDialog!.message = localizationManager.localizedString("uart_export_save_message")
        exportFileDialog!.prompt = localizationManager.localizedString("uart_export_save_prompt")
        exportFileDialog!.canCreateDirectories = true
        exportFileDialog!.accessoryView = saveDialogCustomView

        for exportFormat in uartData.exportFormats {
            saveDialogPopupButton.addItemWithTitle(exportFormat.rawValue)
        }

        updateSaveFileName()

        if let window = self.view.window {
            exportFileDialog!.beginSheetModalForWindow(window) {[unowned self] (result) -> Void in
                if result == NSFileHandlingPanelOKButton {
                    if let url = self.exportFileDialog!.URL {

                        // Save
                        var text : String?
                        let exportFormatSelected = self.uartData.exportFormats[self.saveDialogPopupButton.indexOfSelectedItem]

                        let dataBuffer = self.uartData.dataBuffer
                        switch(exportFormatSelected) {
                        case .txt:
                            text = UartDataExport.dataAsText(dataBuffer)
                        case .csv:
                            text = UartDataExport.dataAsCsv(dataBuffer)
                        case .json:
                            text = UartDataExport.dataAsJson(dataBuffer)
                            break
                        case .xml:
                            text = UartDataExport.dataAsXml(dataBuffer)
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
            let exportFormatSelected = uartData.exportFormats[saveDialogPopupButton.indexOfSelectedItem]
            exportFileDialog.nameFieldStringValue = "uart\(isInHexMode ? ".hex" : "").\(exportFormatSelected.rawValue)"
        }
    }
}

// MARK: - DetailTab
extension UartViewController : DetailTab {
    func tabWillAppear() {
        reloadDataUI()
        
        // Check if characteristics are ready
        let isUartReady = uartData.isReady()
        inputTextField.enabled = isUartReady
        inputTextField.backgroundColor = isUartReady ? NSColor.whiteColor() : NSColor.blackColor().colorWithAlphaComponent(0.1)
    }
    
    func tabWillDissapear() {
        if !Config.uartShowAllUartCommunication {
            uartData.dataBufferEnabled = false
        }
    }
    
    func tabReset() {
        // Peripheral should be connected
        uartData.dataBufferEnabled = true
        uartData.blePeripheral = BleManager.sharedInstance.blePeripheralConnected       // Note: this will start the service discovery
    }
}

// MARK: - NSOpenSavePanelDelegate
extension UartViewController: NSOpenSavePanelDelegate {
    
}

// MARK: - NSTableViewDataSource
extension UartViewController: NSTableViewDataSource {
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        if (Preferences.uartIsEchoEnabled)  {
            tableCachedDataBuffer = uartData.dataBuffer
        }
        else {
            tableCachedDataBuffer = uartData.dataBuffer.filter({ (dataChunk : UartDataChunk) -> Bool in
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
                let dateString = timestampDateFormatter.stringFromDate(date)
                cell!.textField!.stringValue = dateString
                
            case "DirectionColumn":
                cell = tableView.makeViewWithIdentifier("DirectionCell", owner: self) as? NSTableCellView
                
                cell!.textField!.stringValue = dataChunk.mode == .RX ? "RX" : "TX"
                
            case "DataColumn":
                cell = tableView.makeViewWithIdentifier("DataCell", owner: self) as? NSTableCellView
                
                let color = dataChunk.mode == .TX ? txColor : rxColor
                
                if let attributedText = UartModuleManager.attributeTextFromData(dataChunk.data, useHexMode: Preferences.uartIsInHexMode, color: color, font: UartViewController.dataFont) {
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

// MARK: - UartModuleDelegate
extension UartViewController: UartModuleDelegate {
    func addChunkToUI(dataChunk : UartDataChunk) {
        // Check that the view has been initialized before updating UI
        guard baseTableView != nil else {
            return;
        }
        
        let displayMode = Preferences.uartIsDisplayModeTimestamp ? UartModuleManager.DisplayMode.Table : UartModuleManager.DisplayMode.Text
        
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
            let isScrollAtTheBottom = tableCachedDataBuffer == nil || tableCachedDataBuffer!.isEmpty || NSLocationInRange(tableCachedDataBuffer!.count-1, baseTableView.rowsInRect(baseTableView.visibleRect))
            //let isScrollAtTheBottom = tableCachedDataBuffer == nil || tableCachedDataBuffer!.isEmpty  || baseTableView.enclosingScrollView?.verticalScroller?.floatValue == 1
            
            baseTableView.reloadData()
            if isScrollAtTheBottom {
                // if scroll was at the bottom then autoscroll to the new bottom
                baseTableView.scrollToEndOfDocument(nil)
            }
        }
        
        updateBytesUI()
    }
    
    private func addChunkToUIText(dataChunk : UartDataChunk) {
        
        if (Preferences.uartIsEchoEnabled || dataChunk.mode == .RX) {
            let color = dataChunk.mode == .TX ? txColor : rxColor
            
            let attributedString = UartModuleManager.attributeTextFromData(dataChunk.data, useHexMode: Preferences.uartIsInHexMode, color: color, font: UartViewController.dataFont)
            
            if let textStorage = self.baseTextView.textStorage, attributedString = attributedString {
                textStorage.appendAttributedString(attributedString)
            }
        }
    }

    func mqttUpdateStatusUI() {
        let status = MqttManager.sharedInstance.status
        
        let localizationManager = LocalizationManager.sharedInstance
        var buttonTitle = localizationManager.localizedString("uart_mqtt_status_default")
        
        switch (status) {
        case .Connecting:
            buttonTitle = localizationManager.localizedString("uart_mqtt_status_connecting")
            
            
        case .Connected:
            buttonTitle = localizationManager.localizedString("uart_mqtt_status_connected")
            
            
        default:
            buttonTitle = localizationManager.localizedString("uart_mqtt_status_disconnected")
            
        }
        
        mqttStatusButton.title = buttonTitle
    }
    
    func mqttError(message: String, isConnectionError: Bool) {
        let localizationManager = LocalizationManager.sharedInstance
        let alert = NSAlert()
        alert.messageText = isConnectionError ? localizationManager.localizedString("uart_mqtt_connectionerror_title"): message
        alert.addButtonWithTitle(localizationManager.localizedString("dialog_ok"))
        if (isConnectionError) {
            alert.addButtonWithTitle(localizationManager.localizedString("uart_mqtt_editsettings_action"))
            alert.informativeText = message
        }
        alert.alertStyle = .WarningAlertStyle
        alert.beginSheetModalForWindow(self.view.window!) { [unowned self] (returnCode) -> Void in
            if isConnectionError && returnCode == NSAlertSecondButtonReturn {
                let preferencesViewController = self.storyboard?.instantiateControllerWithIdentifier("PreferencesViewController") as! PreferencesViewController
                self.presentViewControllerAsModalWindow(preferencesViewController)
            }
        }
    }
}

// MARK: - CBPeripheralDelegate
extension UartViewController: CBPeripheralDelegate {
    // Pass peripheral callbacks to UartData
    
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        uartData.peripheral(peripheral, didModifyServices: invalidatedServices)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        uartData.peripheral(peripheral, didDiscoverServices:error)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        
        uartData.peripheral(peripheral, didDiscoverCharacteristicsForService: service, error: error)
        
        // Check if ready
        if uartData.isReady() {
            // Enable input
            dispatch_async(dispatch_get_main_queue(), { [unowned self] in
                if self.inputTextField != nil {     // could be nil if the viewdidload has not been executed yet
                    self.inputTextField.enabled = true
                    self.inputTextField.backgroundColor = NSColor.whiteColor()
                }
                });
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
      uartData.peripheral(peripheral, didUpdateValueForCharacteristic: characteristic, error: error)
    }
}

