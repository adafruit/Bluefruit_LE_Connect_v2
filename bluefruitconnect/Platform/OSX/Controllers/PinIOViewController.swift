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
    @IBOutlet weak var baseTableView: NSTableView!
    @IBOutlet weak var statusLabel: NSTextField!
    private var queryCapabilitiesAlert: NSAlert?

    // Data
    private let pinIO = PinIOModuleManager()
    private var tableRowOpen: Int?
    private var isQueryingFinished = false
    private var isTabVisible = false

    private var waitingDiscoveryAlert: NSAlert?
    var infoFinishedScanning = false {
        didSet {
            if infoFinishedScanning != oldValue {
                DLog("pinio infoFinishedScanning: \(infoFinishedScanning)")
                if infoFinishedScanning && waitingDiscoveryAlert != nil {
                    view.window?.endSheet(waitingDiscoveryAlert!.window)
                    waitingDiscoveryAlert = nil
                    startPinIo()
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Init
        pinIO.delegate = self
        baseTableView.rowHeight = 52
    }
    
    func uartIsReady(notification: NSNotification) {
        DLog("Uart is ready")
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: UartManager.UartNotifications.DidBecomeReady.rawValue, object: nil)
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.setupFirmata()
            })
    }
    
    private func setupFirmata() {
        // Reset Firmata and query capabilities
        pinIO.reset()
        tableRowOpen = nil
        baseTableView.reloadData()
        startQueryCapabilitiesProcess()
    }
    
    private func startQueryCapabilitiesProcess() {
        guard isTabVisible else {
            return
        }
        
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
        if let window = self.view.window {
            let localizationManager = LocalizationManager.sharedInstance
            let alert = NSAlert()
            alert.messageText = localizationManager.localizedString("pinio_capabilityquery_querying_title")
            alert.addButtonWithTitle(localizationManager.localizedString("dialog_cancel"))
            alert.alertStyle = .WarningAlertStyle
            alert.beginSheetModalForWindow(window) { [unowned self] (returnCode) -> Void in
                if returnCode == NSAlertFirstButtonReturn {
                    self.pinIO.endPinQuery(true)
                }
            }
            queryCapabilitiesAlert = alert
        }
        self.pinIO.queryCapabilities()
    }
    
    func defaultCapabilitiesAssumedDialog() {
        guard isTabVisible else {
            return
        }
        
        DLog("QueryCapabilities not found")
        
        if let window = self.view.window {
            let localizationManager = LocalizationManager.sharedInstance
            let alert = NSAlert()
            alert.messageText = localizationManager.localizedString("pinio_capabilityquery_expired_title")
            alert.informativeText = localizationManager.localizedString("pinio_capabilityquery_expired_message")
            alert.addButtonWithTitle(localizationManager.localizedString("dialog_ok"))
            alert.alertStyle = .WarningAlertStyle
            alert.beginSheetModalForWindow(window) { (returnCode) -> Void in
                if returnCode == NSAlertFirstButtonReturn {
                }
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

        // Hack: wait a moment because a disconnect could call tabWillAppear just before disconnecting
        let dispatchTime: dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(0.2 * Double(NSEC_PER_SEC)))
        dispatch_after(dispatchTime, dispatch_get_main_queue(), { [weak self] in
            self?.startPinIo()
        })
    }
    
    func tabWillDissapear() {
        isTabVisible = false
        pinIO.stop()
    }
    
    func tabReset() {
        
    }

    private func startPinIo() {
        
        guard BleManager.sharedInstance.blePeripheralConnected != nil else {
            DLog("trying to make pionio tab visible while disconnecting")
            isTabVisible = false
            return
        }
        
        isTabVisible = true
        
        if !isQueryingFinished {
            // Start Uart Manager
            UartManager.sharedInstance.blePeripheral = BleManager.sharedInstance.blePeripheralConnected       // Note: this will start the service discovery
            
            if !infoFinishedScanning {
                DLog("pinio: waiting for info scanning...")
                if let window = view.window {
                    let localizationManager = LocalizationManager.sharedInstance
                    waitingDiscoveryAlert = NSAlert()
                    waitingDiscoveryAlert!.messageText = "Waiting for discovery to finish..."
                    waitingDiscoveryAlert!.addButtonWithTitle(localizationManager.localizedString("dialog_cancel"))
                    waitingDiscoveryAlert!.alertStyle = .WarningAlertStyle
                    waitingDiscoveryAlert!.beginSheetModalForWindow(window) { [unowned self] (returnCode) -> Void in
                        if returnCode == NSAlertFirstButtonReturn {
                            self.waitingDiscoveryAlert = nil
                            self.pinIO.endPinQuery(true)
                        }
                    }
                }
            }
            else if (UartManager.sharedInstance.isReady()) {
                setupFirmata()
            }
            else {
                DLog("Wait for uart to be ready to start PinIO setup")
                
                let notificationCenter =  NSNotificationCenter.defaultCenter()
                notificationCenter.addObserver(self, selector: #selector(PinIOViewController.uartIsReady(_:)), name: UartManager.UartNotifications.DidBecomeReady.rawValue, object: nil)
            }
        }
    }
}


// MARK: - NSOutlineViewDataSource
extension PinIOViewController : NSTableViewDataSource {
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return pinIO.pins.count
    }
    
}

// MARK: NSOutlineViewDelegate

extension PinIOViewController: NSTableViewDelegate {
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let pin = pinIO.pins[row]
        
        let cell = tableView.makeViewWithIdentifier("PinCell", owner: self) as! PinTableCellView
        
        cell.setPin(pin, pinIndex:row)
        cell.delegate = self
        
        return cell;
    }

    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if let tableRowOpen = tableRowOpen where row == tableRowOpen {
            let pinOpen = pinIO.pins[tableRowOpen]
            return pinOpen.mode == .Input || pinOpen.mode == .Analog ? 106 : 130
        }
        else {
            return 52
        }
    }
    
    /*
    func tableViewSelectionDidChange(notification: NSNotification) {
        onPinToggleCell(baseTableView.selectedRow)
    }*/
}

// MARK:  PinTableCellViewDelegate
extension PinIOViewController : PinTableCellViewDelegate {
    func onPinToggleCell(pinIndex: Int) {
        // Change open row
        let previousTableRowOpen = tableRowOpen
        tableRowOpen = pinIndex == tableRowOpen ? nil: pinIndex
        
        // Animate changes
        NSAnimationContext.beginGrouping()
        NSAnimationContext.currentContext().duration = 0.25
        baseTableView.noteHeightOfRowsWithIndexesChanged(NSIndexSet(index: pinIndex))
        if let previousTableRowOpen = previousTableRowOpen where previousTableRowOpen >= 0 {
            baseTableView.noteHeightOfRowsWithIndexesChanged(NSIndexSet(index: previousTableRowOpen))
        }
        let rowRect = baseTableView.rectOfRow(pinIndex)
        baseTableView.scrollRectToVisible(rowRect)
        NSAnimationContext.endGrouping()

    }
    func onPinModeChanged(mode: PinIOModuleManager.PinData.Mode, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        pinIO.setControlMode(pin, mode: mode)

        //DLog("pin \(pin.digitalPinId): mode: \(pin.mode.rawValue)")
        
        // Animate changes
        NSAnimationContext.beginGrouping()
        NSAnimationContext.currentContext().duration = 0.25
        baseTableView.reloadDataForRowIndexes(NSIndexSet(index: pinIndex), columnIndexes: NSIndexSet(index: 0))
        baseTableView.noteHeightOfRowsWithIndexesChanged(NSIndexSet(index: pinIndex))
        let rowRect = baseTableView.rectOfRow(pinIndex)
        baseTableView.scrollRectToVisible(rowRect)
        NSAnimationContext.endGrouping()
        
    }
    func onPinDigitalValueChanged(value: PinIOModuleManager.PinData.DigitalValue, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        pinIO.setDigitalValue(pin, value: value)

        baseTableView.reloadDataForRowIndexes(NSIndexSet(index: pinIndex), columnIndexes: NSIndexSet(index: 0))
    }
    func onPinAnalogValueChanged(value: Double, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        if pinIO.setPMWValue(pin, value: Int(value)) {
            baseTableView.reloadDataForRowIndexes(NSIndexSet(index: pinIndex), columnIndexes: NSIndexSet(index: 0))
        }
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
