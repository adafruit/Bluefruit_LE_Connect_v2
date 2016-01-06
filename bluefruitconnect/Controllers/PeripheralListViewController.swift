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
    private var currentSelectedPeripheralIdentifier : String?
    private var lastUserSelection = CFAbsoluteTimeGetCurrent()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup StatusManager
        StatusManager.sharedInstance.peripheralListViewController = self
        
        // Subscribe to Ble Notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didDiscoverPeripheral:", name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didDiscoverPeripheral:", name: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didDisconnectFromPeripheral:", name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
    }
    
    func didDiscoverPeripheral(notification : NSNotification) {
        dispatch_async(dispatch_get_main_queue(), {[unowned self] in

            // Reload data
            self.baseTableView.reloadData()
            
            // Select identifier if still available
            if let selectedPeripheralIdentifier = self.currentSelectedPeripheralIdentifier {
                if let index = BleManager.sharedInstance.blePeripheralFoundAlphabeticKeys().indexOf(selectedPeripheralIdentifier) {
//                    DLog("discover row: \(index)");
                    self.baseTableView.selectRowIndexes(NSIndexSet(index: index), byExtendingSelection: false)
                }
            }
        })
    }

    func didDisconnectFromPeripheral(notification : NSNotification) {
        dispatch_async(dispatch_get_main_queue(), {[unowned self] in
            
            if (BleManager.sharedInstance.blePeripheralConnected == nil && self.baseTableView.selectedRow >= 0) {
                
                // Unexpected disconnect if the row is still selected but the connected peripheral is nil and the time since the user selected a new peripheral is bigger than 1 second
                if (CFAbsoluteTimeGetCurrent() - self.lastUserSelection > 1) {
                    self.baseTableView.deselectAll(nil)
                    
                    let alert = NSAlert()
                    alert.messageText = "Peripheral disconnected"
                    alert.addButtonWithTitle("Ok")
                    alert.alertStyle = .WarningAlertStyle
                    alert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
                }
            }
            })
    }

    // MARK: - NSTableViewDataSource
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return BleManager.sharedInstance.blePeripheralsFound.count
    }

    // MARK: NSTableViewDelegate
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let cell = tableView.makeViewWithIdentifier("DeviceCell", owner: self) as! PeripheralTableCellView

        let bleManager = BleManager.sharedInstance
        let blePeripheralsFound = bleManager.blePeripheralsFound
        let selectedBlePeripheralIdentifier = bleManager.blePeripheralFoundAlphabeticKeys()[row];
        let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier]!
        cell.titleTextField.stringValue = blePeripheral.name
        
        let isUartCapable = blePeripheral.isUartAdvertised()
        cell.subtitleTextField.stringValue = isUartCapable ?"Uart capable":"No Uart detected"
        cell.rssiImageView.image = signalImageForRssi(blePeripheral.rssi)
        
        cell.onDisconnect = {
            tableView.deselectAll(nil)
        }
        
        cell.showDisconnectButton(row == currentSelectedRow)
        
        return cell;
    }
    
    func tableViewSelectionIsChanging(notification: NSNotification) {   // Note: used tableViewSelectionIsChanging instead of tableViewSelectionDidChange because if a didDiscoverPeripheral notification arrives when the user is changing the row but before the user releases the mouse button, then it would be cancelled (and the user would notice that something weird happened)

        peripheralSelectedChanged()
    }
    
    func tableViewSelectionDidChange(notification: NSNotification) {
        peripheralSelectedChanged()
    }
    
    func peripheralSelectedChanged() {
        let newSelectedRow = baseTableView.selectedRow
        //        DLog("tableViewSelectionDidChange: \(newSelectedRow)")
        if (newSelectedRow != currentSelectedRow) {
            DLog("Peripheral selected row: \(newSelectedRow)")
            let bleManager = BleManager.sharedInstance
            connectToPeripheral(newSelectedRow >= 0 ? bleManager.blePeripheralFoundAlphabeticKeys()[newSelectedRow] : nil)
            currentSelectedRow = newSelectedRow
        }
    }
    
    // MARK: -
    func selectRowForPeripheralIdentifier(identifier : String?) {
        var found = false
        
        if let identifier = identifier {
            if let index = BleManager.sharedInstance.blePeripheralFoundAlphabeticKeys().indexOf(identifier) {
                baseTableView.selectRowIndexes(NSIndexSet(index: index), byExtendingSelection: false)
                found = true
            }
        }
        
        if (!found) {
            baseTableView.deselectAll(nil)
        }
    }
   
    func connectToPeripheral(identifier : String?) {
        let bleManager = BleManager.sharedInstance

        if (identifier != bleManager.blePeripheralConnected?.peripheral.identifier.UUIDString || identifier == nil) {
            
            //
            let blePeripheralsFound = bleManager.blePeripheralsFound
            lastUserSelection = CFAbsoluteTimeGetCurrent()

            // Disconnect from previous
            if (currentSelectedRow >= 0) {
                
                let blePeripherals = bleManager.blePeripheralFoundAlphabeticKeys()
                if currentSelectedRow < blePeripherals.count {      // To avoid problems with peripherals disconnecting
                    let selectedBlePeripheralIdentifier = blePeripherals[currentSelectedRow];
                    let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier]!
                    
                    BleManager.sharedInstance.disconnect(blePeripheral)
                }
                currentSelectedPeripheralIdentifier = nil
            }
            
            // Connect to new peripheral
            if let selectedBlePeripheralIdentifier = identifier {
                
                let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier]!
                if (BleManager.sharedInstance.blePeripheralConnected?.peripheral.identifier != selectedBlePeripheralIdentifier) {
                    // DLog("connect to new peripheral: \(selectedPeripheralIdentifier)")
                    
                    BleManager.sharedInstance.connect(blePeripheral)
                    
                    currentSelectedPeripheralIdentifier = selectedBlePeripheralIdentifier
                }
            }
            else {
                currentSelectedPeripheralIdentifier = nil;
            }
        }
    }
    
    // MARK - Actions
    @IBAction func onClickRefresh(sender: AnyObject) {
        BleManager.sharedInstance.refreshPeripherals()
    }
    
    
}
