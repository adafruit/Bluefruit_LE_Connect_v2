//
//  PeripheralListViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 22/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa
import CoreBluetooth

class PeripheralListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var baseTableView: NSTableView!
    
    private var currentSelectedRow = -1
    private var lastUserSelection = CFAbsoluteTimeGetCurrent()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Background
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor.whiteColor().CGColor
        
        
        // Subscribe to Ble Notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didDiscoverPeripheral:", name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
                NSNotificationCenter.defaultCenter().addObserver(self, selector: "didDisconnectFromPeripheral:", name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func didDiscoverPeripheral(notification : NSNotification) {
        dispatch_async(dispatch_get_main_queue(), {[unowned self] in
            // Save selected identifier
            var selectedPeripheralIdentifier : String? = nil
            let selectedRow = self.baseTableView.selectedRow
            if (selectedRow >= 0) {
                selectedPeripheralIdentifier = self.blePeripheralFoundAlphabeticKeys()[selectedRow]
            }
            
            // Reload data
            self.baseTableView.reloadData()
            
            
            // Select identifier if still available
            if (selectedPeripheralIdentifier != nil) {
                var i = 0
                for identifier in self.blePeripheralFoundAlphabeticKeys() {
                    if (identifier == selectedPeripheralIdentifier) {
                        self.baseTableView.selectRowIndexes(NSIndexSet(index: i), byExtendingSelection: false)
                        break;
                    }
                    i++
                }
            }
            })
    }
    
    func didDisconnectFromPeripheral(notification : NSNotification) {
        if (BleManager.sharedInstance.blePeripheralConnected == nil && baseTableView.selectedRow >= 0) {
            // Unexpected disconnect if the row is still selected but the connected peripheral is nil and the time since the user selected a new peripheral is bigger than 1 second
            
            
            if (CFAbsoluteTimeGetCurrent() - lastUserSelection > 1) {
                baseTableView.deselectAll(nil)
                
                let alert = NSAlert()
                alert.messageText = "Peripheral disconnected"
                alert.addButtonWithTitle("Ok")
                alert.alertStyle = .WarningAlertStyle
                alert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)

            }
        }
    }
    
    func isUartAdvertised(advertisementData: [String : AnyObject]) -> Bool {
        let kUartServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"       // UART service UUID
        
        var isUartAdvertised = false
        if let serviceUUIds = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            isUartAdvertised = serviceUUIds.contains(CBUUID(string: kUartServiceUUID))
        }
        return isUartAdvertised
    }
    
    func signalImageForRssi(rssi:Int) -> NSImage {
        
        var index : Int
        
        if rssi == 127 {     // value of 127 reserved for RSSI not available
            index = 0
        }
        else if rssi <= -84 {
            index = 0
        }
        else if rssi <= -72 {
            index = 1
        }
        else if rssi <= -60 {
            index = 2
        }
        else if rssi <= -48 {
            index = 3
        }
        else {
            index = 4
        }
        
        return NSImage(named: "signalstrength\(index)")!
    }
    
    func blePeripheralFoundAlphabeticKeys() -> [String] {
        // Sort blePeripheralsFound keys alphabetically and return them as an array
        let dict = BleManager.sharedInstance.blePeripheralsFound
        let sortedKeys = Array(dict.keys).sort({[unowned self] in self.blePeripheralName(dict[$0]) < self.blePeripheralName(dict[$1])})
        return sortedKeys
    }
    
    func blePeripheralName(blePeripheral : BlePeripheral?) -> String {
        if let name = blePeripheral?.peripheral.name {
            return name
        }
        else {
            return "<Unknown>"
        }
    }
    
    func connectToPeripheral(blePeripheral : BlePeripheral) {
        BleManager.sharedInstance.connect(blePeripheral)
    }
    
    // MARK: - NSTableViewDataSource
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return BleManager.sharedInstance.blePeripheralsFound.count
    }
    
    // MARK: NSTableViewDelegate
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let cell = tableView.makeViewWithIdentifier("DeviceCell", owner: self) as! PeripheralTableCellView
        
        let blePeripheralsFound = BleManager.sharedInstance.blePeripheralsFound
        let selectedBlePeripheralIdentifier = blePeripheralFoundAlphabeticKeys()[row];
        let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier]!
        cell.titleTextField.stringValue = blePeripheralName(blePeripheral)
        
        let isUartCapable = isUartAdvertised(blePeripheral.advertisementData)
        cell.subtitleTextField.stringValue = isUartCapable ?"Uart capable":"No Uart detected"
        cell.rssiImageView.image = signalImageForRssi(blePeripheral.rssi)
        
        return cell;
    }
    
    func tableViewSelectionDidChange(notification: NSNotification) {
        
        let blePeripheralsFound = BleManager.sharedInstance.blePeripheralsFound
        let selectedRow = baseTableView.selectedRow
        if (selectedRow != currentSelectedRow) {
            
            lastUserSelection = CFAbsoluteTimeGetCurrent()
            // Disconnect from previous
            if (currentSelectedRow >= 0) {
                let selectedBlePeripheralIdentifier = blePeripheralFoundAlphabeticKeys()[currentSelectedRow];
                let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier]!
                
                BleManager.sharedInstance.disconnect(blePeripheral)
            }
            
            // Connect to new peripheral
            if (selectedRow >= 0) {
                
                let selectedBlePeripheralIdentifier = blePeripheralFoundAlphabeticKeys()[selectedRow];
                let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier]!
                let selectedPeripheralIdentifier = blePeripheral.peripheral.identifier.UUIDString
                if (BleManager.sharedInstance.blePeripheralConnected?.peripheral.identifier != selectedPeripheralIdentifier) {
                   // DLog("connect to new peripheral: \(selectedPeripheralIdentifier)")
                    
                    BleManager.sharedInstance.connect(blePeripheral)
                }
                
            }
           
            currentSelectedRow = selectedRow
        }
    }
    
   
}
