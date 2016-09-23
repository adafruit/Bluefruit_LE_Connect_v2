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
    // Config
    static let kFiltersPanelClosedHeight: CGFloat = 55
    static let kFiltersPanelOpenHeight: CGFloat = 150

    // UI
    @IBOutlet weak var baseTableView: NSTableView!
    @IBOutlet weak var filtersPanelView: NSView!
    @IBOutlet weak var filtersPanelViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var filterTitleTextField: NSTextField!
    @IBOutlet weak var filtersDisclosureButton: NSButton!
    @IBOutlet weak var filtersNameSearchField: NSSearchField!
    @IBOutlet weak var filterRssiValueLabel: NSTextField!
    @IBOutlet weak var filtersRssiSlider: NSSlider!
    @IBOutlet weak var filtersOnlyWithUartButton: NSButton!
    @IBOutlet weak var filtersClearButton: NSButton!

    // Data
    private let peripheralList = PeripheralList()
    private var isFilterPanelOpen = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup StatusManager
        StatusManager.sharedInstance.peripheralListViewController = self
        
        // Subscribe to Ble Notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didDiscoverPeripheral(_:)), name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didDiscoverPeripheral(_:)), name: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didDisconnectFromPeripheral(_:)), name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()

        // Filters
        peripheralList.setDefaultFilters()
        openFiltersPanel(false, animated: false)
        updateFiltersTitle()        
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
                    alert.alertStyle = .Warning
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
    
    // MARK: - Filters
    private func openFiltersPanel(isOpen: Bool, animated: Bool) {
        
        self.filtersDisclosureButton.state = isOpen ? NSOnState:NSOffState
        
        NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
            
            context.duration = animated ? 0.3:0
            self.filtersPanelViewHeightConstraint.animator().constant = isOpen ? PeripheralListViewController.kFiltersPanelOpenHeight:PeripheralListViewController.kFiltersPanelClosedHeight
            
            }, completionHandler: nil)
    }

    private func updateFiltersTitle() {
        var filtersTitle: String?
        if let filterName = peripheralList.filterName {
            filtersTitle = filterName
        }
        
        if let rssiFilterValue = peripheralList.rssiFilterValue {
            let rssiString = "Rssi >= \(rssiFilterValue)"
            if filtersTitle != nil {
                filtersTitle!.appendContentsOf(", \(rssiString)")
            }
            else {
                filtersTitle = rssiString
            }
        }
        
        if peripheralList.isOnlyUartEnabled {
            let uartString = "with Uart"
            if filtersTitle != nil {
                filtersTitle!.appendContentsOf(", \(uartString)")
            }
            else {
                filtersTitle = uartString
            }
        }
        
        filterTitleTextField.stringValue = filtersTitle ?? "No filter selected"
        
        filtersClearButton.hidden = !peripheralList.isAnyFilterEnabled()
    }

    
    func onFilterNameSettingsNameContains(sender: NSMenuItem) {
        peripheralList.isFilterNameExact = false
        updateFilters()
    }
    
    func onFilterNameSettingsNameEquals(sender: NSMenuItem) {
        peripheralList.isFilterNameExact = true
        updateFilters()
    }
    
    func onFilterNameSettingsMatchCase(sender: NSMenuItem) {
        peripheralList.isFilterNameCaseInsensitive = false
        updateFilters()
    }
    
    func onFilterNameSettingsIgnoreCase(sender: NSMenuItem) {
        peripheralList.isFilterNameCaseInsensitive = true
        updateFilters()
    }
    
    private func updateFilters() {
        updateFiltersTitle()
        baseTableView.reloadData()
    }
    
    
    // MARK - Actions
    @IBAction func onClickRefresh(sender: AnyObject) {
        BleManager.sharedInstance.refreshPeripherals()
    }
    
    @IBAction func onClickFilters(sender: AnyObject) {
        isFilterPanelOpen = !isFilterPanelOpen
        openFiltersPanel(isFilterPanelOpen, animated: true)
    }
    
    
    @IBAction func onEditFilterName(sender: AnyObject) {
        let isEmpty = (sender.stringValue as String).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).characters.count == 0
        peripheralList.filterName = isEmpty ? nil:sender.stringValue
        updateFilters()
    }
   
    @IBAction func onClickFilterNameSettings(sender: AnyObject) {
        let menu = NSMenu(title: "Settings")
        
        menu.addItemWithTitle("Name contains", action: #selector(onFilterNameSettingsNameContains(_:)), keyEquivalent: "")
        menu.addItemWithTitle("Name equals", action: #selector(onFilterNameSettingsNameEquals(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separatorItem())
        menu.addItemWithTitle("Matching case", action: #selector(onFilterNameSettingsMatchCase(_:)), keyEquivalent: "")
        menu.addItemWithTitle("Ignoring case", action: #selector(onFilterNameSettingsIgnoreCase(_:)), keyEquivalent: "")
        //NSMenu.popUpContextMenu(menu, withEvent: NSEvent(), forView: view)
        
        let selectedOption0 = peripheralList.isFilterNameExact ? 1:0
        menu.itemAtIndex(selectedOption0)!.offStateImage = NSImage(named: "NSMenuOnStateTemplate")
        let selectedOption1 = peripheralList.isFilterNameCaseInsensitive ? 4:3
        menu.itemAtIndex(selectedOption1)!.offStateImage = NSImage(named: "NSMenuOnStateTemplate")
        
        menu.popUpMenuPositioningItem(nil, atLocation: NSEvent.mouseLocation(), inView: nil)
    }
    
    
    @IBAction func onFilterRssiChanged(sender: NSSlider) {
        let rssiValue = -sender.integerValue
        peripheralList.rssiFilterValue = rssiValue
        filterRssiValueLabel.stringValue = "\(rssiValue) dBM"
        updateFilters()
    }
    
    @IBAction func onFilterOnlyUartChanged(sender: NSButton) {
        peripheralList.isOnlyUartEnabled = sender.state == NSOnState
        updateFilters()
    }
    
    @IBAction func onClickRemoveFilters(sender: AnyObject) {
        peripheralList.setDefaultFilters()
        filtersNameSearchField.stringValue = peripheralList.filterName ?? ""
        filtersRssiSlider.integerValue = peripheralList.rssiFilterValue != nil ? -peripheralList.rssiFilterValue! : 100
        filtersOnlyWithUartButton.state = peripheralList.isOnlyUartEnabled ? NSOnState:NSOffState
        updateFilters()
    }
    
}

// MARK: - NSTableViewDataSource
extension PeripheralListViewController : NSTableViewDataSource {
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return peripheralList.filteredPeripherals(true).count
    }
}

// MARK: NSTableViewDelegate
extension PeripheralListViewController : NSTableViewDelegate {
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let cell = tableView.makeViewWithIdentifier("PeripheralCell", owner: self) as! PeripheralTableCellView
        
        let bleManager = BleManager.sharedInstance
        let blePeripheralsFound = bleManager.blePeripherals()
        let filteredPeripherals = peripheralList.filteredPeripherals(false)
        
        if row < filteredPeripherals.count {        // Check to avoid race conditions
            let selectedBlePeripheralIdentifier = filteredPeripherals[row];
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
        }
        
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
