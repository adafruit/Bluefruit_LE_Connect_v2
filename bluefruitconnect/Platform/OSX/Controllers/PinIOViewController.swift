//
//  PinIOViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 16/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Cocoa

class PinIOViewController: NSViewController {

    // UI
    @IBOutlet weak var baseTableView: NSOutlineView!
    @IBOutlet weak var statusLabel: NSTextField!
    private var queryCapabilitiesAlert: NSAlert?

    // Data
    private let pinIO = PinIOModuleManager()
    private var isQueryingFinished = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Init
        pinIO.delegate = self
    }
    
    func uartIsReady(notification: NSNotification) {
        DLog("Uart is ready")
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: UartManager.UartNotifications.DidBecomeReady.rawValue, object: nil)
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.setupFirmata()
            })
    }
    
    private func setupFirmata() {
        // Reset Firmata and query capabilities
        pinIO.reset()
        baseTableView.reloadData()
        startQueryCapabilitiesProcess()
    }
    
    private func startQueryCapabilitiesProcess() {
        guard !pinIO.isQueryingCapabilities() else {
            DLog("error: queryCapabilities called while querying capabilities")
            return
        }
        
        if queryCapabilitiesAlert != nil {
            DLog("Warning: Trying to create a new queryCapabilitiesAlert while the current one is not nil")
        }
        
        isQueryingFinished = false
        statusLabel.stringValue = "Querying capabilities..."
        
        // Show dialog
        let localizationManager = LocalizationManager.sharedInstance
        let alert = NSAlert()
        alert.messageText = localizationManager.localizedString("pinio_capabilityquery_querying_title")
        alert.addButtonWithTitle(localizationManager.localizedString("dialog_cancel"))
        alert.alertStyle = .WarningAlertStyle
        alert.beginSheetModalForWindow(self.view.window!) { [unowned self] (returnCode) -> Void in
            if returnCode == NSAlertFirstButtonReturn {
                self.pinIO.endPinQuery(true)
            }
        }
        queryCapabilitiesAlert = alert
        self.pinIO.queryCapabilities()
    }

    func defaultCapabilitiesAssumedDialog() {
        
        DLog("QueryCapabilities not found")
        let localizationManager = LocalizationManager.sharedInstance
        let alert = NSAlert()
        alert.messageText = localizationManager.localizedString("pinio_capabilityquery_expired_title")
        alert.informativeText = localizationManager.localizedString("pinio_capabilityquery_expired_message")
        alert.addButtonWithTitle(localizationManager.localizedString("dialog_ok"))
        alert.alertStyle = .WarningAlertStyle
        alert.beginSheetModalForWindow(self.view.window!) { (returnCode) -> Void in
            if returnCode == NSAlertFirstButtonReturn {
            }
        }
    }

    @IBAction func onClickQuery(sender: AnyObject) {
        setupFirmata()
    }
}

// MARK: - DetailTab
extension PinIOViewController : DetailTab {
    func tabWillAppear() {
        pinIO.start()

        if !isQueryingFinished {
            // Start Uart Manager
            UartManager.sharedInstance.blePeripheral = BleManager.sharedInstance.blePeripheralConnected       // Note: this will start the service discovery
            
            if (UartManager.sharedInstance.isReady()) {
                setupFirmata()
            }
            else {
                DLog("Wait for uart to be ready to start PinIO setup")
                
                let notificationCenter =  NSNotificationCenter.defaultCenter()
                notificationCenter.addObserver(self, selector: "uartIsReady:", name: UartManager.UartNotifications.DidBecomeReady.rawValue, object: nil)
            }
        }
    }
    
    func tabWillDissapear() {
        pinIO.stop()
    }
    
    func tabReset() {
    }
}


// MARK: - NSOutlineViewDataSource
extension PinIOViewController : NSOutlineViewDataSource {
    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        return item == nil ? pinIO.pins.count : 0
    }

    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        return true      // only root objects are expandable
    }
    
    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if item == nil {
            return pinIO.pins[index]
        }
        else {
            return item!     // TODO: fix this
        }
    }
    /*
    func outlineView(outlineView: NSOutlineView, dataCellForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSCell? {
        if tableColumn == nil {
        
        if let currentItem = item as? PinIOModuleManager.PinData {
            
        }
        else {
            let currentItem = (item as! [PinIOModuleManager.PinData]).first
        }
        }
    }
*/
    
    
}

// MARK: NSOutlineViewDelegate

extension PinIOViewController: NSOutlineViewDelegate {
    func outlineView(outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
        
        let pin = item as! PinIOModuleManager.PinData
        
        var cell = NSTableCellView()
        
        if let columnIdentifier = tableColumn?.identifier {
            switch(columnIdentifier) {
       
            case "DescriptionColumn":
                cell = outlineView.makeViewWithIdentifier("DescriptionCell", owner: self) as! NSTableCellView

                let analogName = pin.isAnalog ?", Analog \(pin.analogPinId)":""
                let fullName = "Pin \(pin.digitalPinId)\(analogName)"

                cell.textField?.stringValue = fullName
            
            case "ModeColumn":
                cell = outlineView.makeViewWithIdentifier("ModeCell", owner: self) as! NSTableCellView

                cell.textField?.stringValue = PinIOModuleManager.stringForPinMode(pin.mode)
                
            default:
                cell.textField?.stringValue = ""
            }
        }

        return cell
    }
}


// MARK: - PinIOModuleManagerDelegate

extension PinIOViewController: PinIOModuleManagerDelegate {
    func onPinIODidEndPinQuery(isDefaultConfigurationAssumed: Bool) {
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            
            self.isQueryingFinished = true
            self.baseTableView.reloadData()
            
            // Dismiss current alert
            if let window = self.view.window, queryCapabilitiesAlert = self.queryCapabilitiesAlert {
                window.endSheet(queryCapabilitiesAlert.window)
                self.queryCapabilitiesAlert = nil
            }
            
            if isDefaultConfigurationAssumed {
                self.statusLabel.stringValue = "Default Arduino capabilities"
                self.defaultCapabilitiesAssumedDialog()
            }
            else {
                self.statusLabel.stringValue = "\(self.pinIO.digitalPinCount) digital pins. \(self.pinIO.analogPinCount) analog pins"
            }
            
            })
    }
    
    func onPinIODidReceivePinState() {
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.baseTableView.reloadData()
            })
    }
}
