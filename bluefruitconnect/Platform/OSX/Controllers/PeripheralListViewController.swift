//
//  PeripheralListViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 22/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa
import CoreBluetooth

class PeripheralListViewController: NSViewController {
    
    @IBOutlet weak var baseTableView: NSTableView!

    private let peripheralList = PeripheralList()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup StatusManager
        StatusManager.sharedInstance.peripheralListViewController = self
        
        // Subscribe to Ble Notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(PeripheralListViewController.didDiscoverPeripheral(_:)), name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(PeripheralListViewController.didDiscoverPeripheral(_:)), name: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(PeripheralListViewController.didDisconnectFromPeripheral(_:)), name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
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
            if let selectedPeripheralRow = self.peripheralList.selectedPeripheralRow {
                self.baseTableView.selectRowIndexes(NSIndexSet(index: selectedPeripheralRow), byExtendingSelection: false)
            }
        })
    }

    func didDisconnectFromPeripheral(notification : NSNotification) {
        dispatch_async(dispatch_get_main_queue(), {[unowned self] in
            
            if (BleManager.sharedInstance.blePeripheralConnected == nil && self.baseTableView.selectedRow >= 0) {
                
                // Unexpected disconnect if the row is still selected but the connected peripheral is nil and the time since the user selected a new peripheral is bigger than kMinTimeSinceUserSelection seconds
                let kMinTimeSinceUserSelection = 1.0    // in secs
                if self.peripheralList.elapsedTimeSinceSelection > kMinTimeSinceUserSelection {
                    self.baseTableView.deselectAll(nil)
                    
                    let localizationManager = LocalizationManager.sharedInstance
                    let alert = NSAlert()
                    alert.messageText = localizationManager.localizedString("peripherallist_peripheraldisconnected")
                    alert.addButtonWithTitle(localizationManager.localizedString("dialog_ok"))
                    alert.alertStyle = .WarningAlertStyle
                    alert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
                }
            }
            })
    }
    
    // MARK: -
    func selectRowForPeripheralIdentifier(identifier : String?) {
        var found = false
        
        if let index = peripheralList.indexOfPeripheralIdentifier(identifier) {
            baseTableView.selectRowIndexes(NSIndexSet(index: index), byExtendingSelection: false)
            found = true
        }
        
        if (!found) {
            baseTableView.deselectAll(nil)
        }
    }
    
    // MARK - Actions
    @IBAction func onClickRefresh(sender: AnyObject) {
        BleManager.sharedInstance.refreshPeripherals()
    }
}

// MARK: - NSTableViewDataSource
extension PeripheralListViewController : NSTableViewDataSource {
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return BleManager.sharedInstance.blePeripheralsCount()
    }
}

// MARK: NSTableViewDelegate
extension PeripheralListViewController : NSTableViewDelegate {
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let cell = tableView.makeViewWithIdentifier("PeripheralCell", owner: self) as! PeripheralTableCellView
        
        let bleManager = BleManager.sharedInstance
        let blePeripheralsFound = bleManager.blePeripherals()
        let selectedBlePeripheralIdentifier = peripheralList.blePeripherals[row];
        let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier]!
        let name = blePeripheral.name != nil ? blePeripheral.name! : LocalizationManager.sharedInstance.localizedString("peripherallist_unnamed")
        cell.titleTextField.stringValue = name
        
        let isUartCapable = blePeripheral.isUartAdvertised()
        cell.subtitleTextField.stringValue = LocalizationManager.sharedInstance.localizedString(isUartCapable ? "peripherallist_uartavailable" : "peripherallist_uartunavailable")
        cell.rssiImageView.image = signalImageForRssi(blePeripheral.rssi)
        
        cell.onDisconnect = {
            tableView.deselectAll(nil)
        }
        
        cell.showDisconnectButton(row == peripheralList.selectedPeripheralRow)
        
        return cell;
    }
    
    func tableViewSelectionIsChanging(notification: NSNotification) {   // Note: used tableViewSelectionIsChanging instead of tableViewSelectionDidChange because if a didDiscoverPeripheral notification arrives when the user is changing the row but before the user releases the mouse button, then it would be cancelled (and the user would notice that something weird happened)
        
        peripheralSelectedChanged()
    }

    func tableViewSelectionDidChange(notification: NSNotification) {
        peripheralSelectedChanged()
    }

    func peripheralSelectedChanged() {
        peripheralList.selectRow(baseTableView.selectedRow)
    }
}
