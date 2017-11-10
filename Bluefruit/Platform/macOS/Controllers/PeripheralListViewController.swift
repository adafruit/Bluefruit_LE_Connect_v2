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
    static let kFiltersPanelOpenHeight: CGFloat = 170

    // UI
    @IBOutlet weak var baseTableView: NSTableView!
    @IBOutlet weak var filtersPanelView: NSView!
    @IBOutlet weak var filtersBackgroundView: NSView!
    @IBOutlet weak var filtersPanelViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var filterTitleTextField: NSTextField!
    @IBOutlet weak var filtersDisclosureButton: NSButton!
    @IBOutlet weak var filtersNameSearchField: NSSearchField!
    @IBOutlet weak var filterRssiValueLabel: NSTextField!
    @IBOutlet weak var filtersRssiSlider: NSSlider!
    @IBOutlet weak var filtersShowUnnamed: NSButton!
    @IBOutlet weak var filtersOnlyWithUartButton: NSButton!
    @IBOutlet weak var filtersClearButton: NSButton!

    // Data
    fileprivate var peripheralList: PeripheralList! = nil
 //   fileprivate var selectedPeripheral: BlePeripheral?
    fileprivate var isUserInteractingWithTableView = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register default preferences
        //Preferences.resetDefaults()       // Debug Reset
        Preferences.registerDefaults()

        peripheralList = PeripheralList()                  // Initialize here to wait for Preferences.registerDefaults to be executed
        
        // Setup StatusManager
        StatusManager.sharedInstance.peripheralListViewController = self
        
        // Subscribe to Ble Notifications
        registerNotifications(enabled: true)
        
        // Appearance
        filtersBackgroundView.wantsLayer = true
        filtersBackgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.05).cgColor
    }

    deinit {
        registerNotifications(enabled: false)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()

        // Filters
        openFiltersPanel(isOpen: Preferences.scanFilterIsPanelOpen, animated: false)
        updateFiltersTitle()
        filtersNameSearchField.stringValue = peripheralList.filterName ?? ""
        setRssiSliderValue(peripheralList.rssiFilterValue)
        filtersShowUnnamed.state = peripheralList.isUnnamedEnabled ? NSOnState:NSOffState
        filtersOnlyWithUartButton.state = peripheralList.isOnlyUartEnabled ? NSOnState:NSOffState
    }

    // MARK: - BLE Notifications
    private weak var didDiscoverPeripheralObserver: NSObjectProtocol?
    private weak var didUnDiscoverPeripheralObserver: NSObjectProtocol?
    private weak var didDisconnectFromPeripheralObserver: NSObjectProtocol?
    private weak var peripheralDidUpdateNameObserver: NSObjectProtocol?

    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            didDiscoverPeripheralObserver = notificationCenter.addObserver(forName: .didDiscoverPeripheral, object: nil, queue: .main, using: didDiscoverPeripheral)
            didUnDiscoverPeripheralObserver = notificationCenter.addObserver(forName: .didUnDiscoverPeripheral, object: nil, queue: .main, using: didDiscoverPeripheral)
            didDisconnectFromPeripheralObserver = notificationCenter.addObserver(forName: .didDisconnectFromPeripheral, object: nil, queue: .main, using: didDisconnectFromPeripheral)
            peripheralDidUpdateNameObserver = notificationCenter.addObserver(forName: .peripheralDidUpdateName, object: nil, queue: .main, using: peripheralDidUpdateName)

        } else {
            if let didDiscoverPeripheralObserver = didDiscoverPeripheralObserver {notificationCenter.removeObserver(didDiscoverPeripheralObserver)}
            if let didUnDiscoverPeripheralObserver = didUnDiscoverPeripheralObserver {notificationCenter.removeObserver(didUnDiscoverPeripheralObserver)}
            if let didDisconnectFromPeripheralObserver = didDisconnectFromPeripheralObserver {notificationCenter.removeObserver(didDisconnectFromPeripheralObserver)}
            if let peripheralDidUpdateNameObserver = peripheralDidUpdateNameObserver {notificationCenter.removeObserver(peripheralDidUpdateNameObserver)}

        }
    }
    
    private func didDiscoverPeripheral(notification: Notification) {
        reloadBaseTable()
    }
    
    private func didDisconnectFromPeripheral(notification: Notification) {
        /*
        let peripheral = BleManager.sharedInstance.peripheral(from: notification)
        let currentlyConnectedPeripheralsCount = BleManager.sharedInstance.connectedPeripherals().count

        guard let selectedPeripheral = selectedPeripheral, selectedPeripheral.identifier == peripheral?.identifier || currentlyConnectedPeripheralsCount == 0 else {        // If selected peripheral is disconnected or if there not any peripherals connected (after a failed dfu update)
            return
        }
        
        // Clear selected peripheral
        self.selectedPeripheral = nil
*/
        
        
        // Reload after dispatch (because at this point the peripheral has not been removed from BleManager)
        DispatchQueue.main.async { [weak self] in
            // Reload table
            self?.reloadBaseTable()
        }
        
        /*
        if BleManager.sharedInstance.blePeripheralConnected == nil && self.baseTableView.selectedRow >= 0 {
            
            // Unexpected disconnect if the row is still selected but the connected peripheral is nil and the time since the user selected a new peripheral is bigger than kMinTimeSinceUserSelection seconds
            let kMinTimeSinceUserSelection = 1.0    // in secs
            if self.peripheralList.elapsedTimeSinceSelection > kMinTimeSinceUserSelection {
                self.baseTableView.deselectAll(nil)
                
                let localizationManager = LocalizationManager.sharedInstance
                let alert = NSAlert()
                alert.messageText = localizationManager.localizedString("scanner_peripheraldisconnected")
                alert.addButton(withTitle: localizationManager.localizedString("dialog_ok"))
                alert.alertStyle = .warning
                alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
            }
        }*/
    }
    
    private func peripheralDidUpdateName(notification: Notification) {
        let name = notification.userInfo?[BlePeripheral.NotificationUserInfoKey.name.rawValue] as? String
        DLog("centralManager peripheralDidUpdateName: \(name ?? "<unknown>")")
        
        // Reload table
        reloadBaseTable()
    }
    
    
    // MARK: - UI
    fileprivate func reloadBaseTable() {
        guard !isUserInteractingWithTableView else { DLog("User interacting with tableview. Postpone reload..."); return }
        
        let peripherals = peripheralList.filteredPeripherals(forceUpdate: true)     // Refresh the peripherals
        baseTableView.reloadData()
        
        // Select the previously selected row
        // scanningWaitView.isHidden = peripherals.count > 0
        /*
        if let selectedPeripheral = selectedPeripheral, let selectedRow = peripherals.index(of: selectedPeripheral) {
            baseTableView.selectRowIndexes([selectedRow], byExtendingSelection: false)
        }*/
        
        let selectedPeripherals = BleManager.sharedInstance.connectedOrConnectingPeripherals()
        let selectedIndexes = selectedPeripherals.map({peripherals.index(of: $0)})
        let selectedNotNilIndexes = selectedIndexes.filter{ $0 != nil }.map { $0! }
        baseTableView.selectRowIndexes(IndexSet(selectedNotNilIndexes), byExtendingSelection: false)
    }
    
    // MARK: -
    func selectRowForPeripheral(identifier: UUID?) {
        var found = false
        
        if let index = peripheralList.filteredPeripherals(forceUpdate: false).index(where: {$0.identifier == identifier}) {
            baseTableView.selectRowIndexes([index], byExtendingSelection: false)
            found = true
        }
        
        if !found {
            baseTableView.deselectAll(nil)
        }
    }
    
    // MARK: - Filters
    private func openFiltersPanel(isOpen: Bool, animated: Bool) {
        
        Preferences.scanFilterIsPanelOpen = isOpen
        self.filtersDisclosureButton.state = isOpen ? NSOnState:NSOffState
        
        NSAnimationContext.runAnimationGroup({ [unowned self] context in
            
            context.duration = animated ? 0.3:0
            self.filtersPanelViewHeightConstraint.animator().constant = isOpen ? PeripheralListViewController.kFiltersPanelOpenHeight:PeripheralListViewController.kFiltersPanelClosedHeight
            
            }, completionHandler: nil)
    }

    private func updateFiltersTitle() {
        let filtersTitle = peripheralList.filtersDescription()
        filterTitleTextField.stringValue = filtersTitle != nil ? "Filter: \(filtersTitle!)" : "No filter selected"
        
        filtersClearButton.isHidden = !peripheralList.isAnyFilterEnabled()
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
    
    private func setRssiSliderValue(_ value: Int?) {
        filtersRssiSlider.integerValue = value != nil ? -value! : 100
    }
    
    private func updateRssiValueLabel() {
        filterRssiValueLabel.stringValue = "\(-filtersRssiSlider.integerValue) dBM"
    }
    
    // MARK: - Advertising Packet
    fileprivate func showAdverisingPacketData(for blePeripheral: BlePeripheral) {
        let localizationManager = LocalizationManager.sharedInstance
        var advertisementString = ""

        if let localName = blePeripheral.advertisement.localName {
            advertisementString += "\(localizationManager.localizedString("scanresult_advertisement_localname"): \(localName)\n"
        }
        if let manufacturerString = blePeripheral.advertisement.manufacturerString {
            advertisementString += "\(localizationManager.localizedString("scanresult_advertisement_manufacturer"): \(manufacturerString)\n"
        }
        if let services = blePeripheral.advertisement.services, !services.isEmpty {
            advertisementString += "\(localizationManager.localizedString("scanresult_advertisement_servicesuuids"):\n"
            advertisementString += servicesDescription(services)
        }
        if let servicesOverflow =  blePeripheral.advertisement.servicesOverflow, !servicesOverflow.isEmpty {
            advertisementString += "\(localizationManager.localizedString("scanresult_advertisement_overflowservices"):\n"
            advertisementString += servicesDescription(servicesOverflow)
        }
        if let serviceData =  blePeripheral.advertisement.serviceData, !serviceData.isEmpty {
            advertisementString += "\(localizationManager.localizedString("scanresult_advertisement_servicesdata"):\n"
            for (cbuuid, data) in serviceData {
                advertisementString += "\t\(localizationManager.localizedString("scanresult_advertisement_servicesdata_uuid"): \(cbuuid.uuidString) \(localizationManager.localizedString("scanresult_advertisement_servicesdata_data"): \(hexDescription(data: data))\n"
            }
        }
        if let servicesSolicited = blePeripheral.advertisement.servicesSolicited, !servicesSolicited.isEmpty {
            advertisementString += "\(localizationManager.localizedString("scanresult_advertisement_servicessolicited"):\n"
            advertisementString += servicesDescription(servicesSolicited)
        }
        if let txPower = blePeripheral.advertisement.txPower {
            advertisementString += "\(localizationManager.localizedString("scanresult_advertisement_txpower"): \(txPower)\n"
        }
        let isConnectable = blePeripheral.advertisement.isConnectable
        advertisementString += "\(localizationManager.localizedString("scanresult_advertisement_connectable"): \(isConnectable != nil ? (isConnectable! ? \(localizationManager.localizedString("scanresult_advertisement_connectable_true"):\(localizationManager.localizedString("scanresult_advertisement_connectable_false")) : \(localizationManager.localizedString("scanresult_advertisement_connectable_unknown"))\n"
        
        let alert = NSAlert()
        alert.messageText = localizationManager.localizedString("scanresult_advertisement_datapacket")
        alert.informativeText = advertisementString
        alert.addButton(withTitle: localizationManager.localizedString("dialog_ok"))
        alert.alertStyle = .warning
        alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
    }
    
    private func servicesDescription(_ services: [CBUUID]) -> String {
        var result = ""
        
        for serviceCBUUID in services {
            var identifier = serviceCBUUID.uuidString
            if let name = BleUUIDNames.sharedInstance.nameForUUID(identifier) {
                identifier = name
            }
            result += "\t\(identifier)\n"
        }
        
        return result
    }
    
    // MARK: - Connections
    fileprivate func connect(peripheral: BlePeripheral) {
        DLog("connect")
        // Connect to selected peripheral
        //selectedPeripheral = peripheral
        BleManager.sharedInstance.connect(to: peripheral)
       // reloadBaseTable()
    }
    
    fileprivate func disconnect(peripheral: BlePeripheral) {
        DLog("disconnect")
        //selectedPeripheral = nil
        BleManager.sharedInstance.disconnect(from: peripheral)
        //reloadBaseTable()
    }

    
    // MARK: - Actions
    @IBAction func onClickRefresh(_ sender: AnyObject) {
        BleManager.sharedInstance.refreshPeripherals()
    }
    
    @IBAction func onClickFilters(_ sender: AnyObject) {
        openFiltersPanel(isOpen: !Preferences.scanFilterIsPanelOpen, animated: true)
    }
    
    @IBAction func onEditFilterName(_ sender: AnyObject) {
        let text = sender.stringValue as String
        let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        peripheralList.filterName = isEmpty ? nil:text
        updateFilters()
    }
   
    @IBAction func onClickFilterNameSettings(_ sender: AnyObject) {
        filtersNameSearchField.window?.makeFirstResponder(filtersNameSearchField)           // Force first responder to the text field, so the menu is not grayed down if the text field was not previously selected
        
        let menu = NSMenu(title: "Settings")
        
        menu.addItem(withTitle: "Name contains", action: #selector(onFilterNameSettingsNameContains(sender:)), keyEquivalent: "")
        menu.addItem(withTitle: "Name equals", action: #selector(onFilterNameSettingsNameEquals(sender:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Matching case", action: #selector(onFilterNameSettingsMatchCase(sender:)), keyEquivalent: "")
        menu.addItem(withTitle: "Ignoring case", action: #selector(onFilterNameSettingsIgnoreCase(sender:)), keyEquivalent: "")
        //NSMenu.popUpContextMenu(menu, withEvent: NSEvent(), forView: view)
        
        let selectedOption0 = peripheralList.isFilterNameExact ? 1:0
        menu.item(at: selectedOption0)!.offStateImage = NSImage(named: "NSMenuOnStateTemplate")
        let selectedOption1 = peripheralList.isFilterNameCaseInsensitive ? 4:3
        menu.item(at: selectedOption1)!.offStateImage = NSImage(named: "NSMenuOnStateTemplate")
        
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation(), in: nil)
    }
    
    
    @IBAction func onFilterRssiChanged(_ sender: NSSlider) {
        let rssiValue = -sender.integerValue
        peripheralList.rssiFilterValue = rssiValue
        updateRssiValueLabel()
        updateFilters()
    }
    
    @IBAction func onFilterOnlyUartChanged(_ sender: NSButton) {
        peripheralList.isOnlyUartEnabled = sender.state == NSOnState
        updateFilters()
    }
    
    @IBAction func onFilterUnnamedChanged(_ sender: AnyObject) {
        peripheralList.isUnnamedEnabled = sender.state == NSOnState
        updateFilters()
    }
    
    @IBAction func onClickRemoveFilters(_ sender: AnyObject) {
        peripheralList.setDefaultFilters()
        filtersNameSearchField.stringValue = peripheralList.filterName ?? ""
        setRssiSliderValue(peripheralList.rssiFilterValue)
        filtersShowUnnamed.state = peripheralList.isUnnamedEnabled ? NSOnState:NSOffState
        filtersOnlyWithUartButton.state = peripheralList.isOnlyUartEnabled ? NSOnState:NSOffState
        updateFilters()
    }
}

// MARK: - NSTableViewDataSource
extension PeripheralListViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return peripheralList.filteredPeripherals(forceUpdate: false).count
    }
}

// MARK: NSTableViewDelegate
extension PeripheralListViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let cell = tableView.make(withIdentifier: "PeripheralCell", owner: self) as! PeripheralTableCellView
        
        let blePeripheral = peripheralList.filteredPeripherals(forceUpdate: false)[row]

        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral.name != nil ? blePeripheral.name! : localizationManager.localizedString("scanner_unnamed")
        cell.titleTextField.stringValue = name
        
        let isUartCapable = blePeripheral.isUartAdvertised()
        cell.hasUartView.isHidden = !isUartCapable
        cell.subtitleTextField.stringValue = ""
        cell.rssiImageView.image = RssiUI.signalImage(for: blePeripheral.rssi)
        
        cell.onDisconnect = {
            self.disconnect(peripheral: blePeripheral)
            tableView.deselectRow(row)
        }
        
        cell.onClickAdvertising = { [unowned self] in
            self.showAdverisingPacketData(for: blePeripheral)
        }

        let isDisconnectable = isPeripheralConnected(identifier: blePeripheral.identifier, includeConnecting: false)
        cell.showDisconnectButton(isDisconnectable)
        
        return cell;
    }
    
    private func isPeripheralConnected(identifier: UUID, includeConnecting: Bool) -> Bool {
        var peripherals: [BlePeripheral]
        if includeConnecting {
            peripherals = BleManager.sharedInstance.connectedOrConnectingPeripherals()
        }
        else {
            peripherals = BleManager.sharedInstance.connectedPeripherals()
        }
        return peripherals.map{$0.identifier}.contains(identifier)
    }
    
    func tableViewSelectionIsChanging(_ notification: Notification) {  // Note: used tableViewSelectionIsChanging instead of tableViewSelectionDidChange because if a didDiscoverPeripheral notification arrives while the user is changing the row but before the user releases the mouse button, then it would be cancelled (and the user would notice that something weird happened)
        
        DLog("tableViewSelectionIsChanging")
        isUserInteractingWithTableView = true
//        peripheralSelectedChanged()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        DLog("tableViewSelectionDidChange")
        isUserInteractingWithTableView = false
        peripheralSelectedChanged()
    }

    private func peripheralSelectedChanged() {
        DLog("\t peripheralSelectedChanged. selected: \(baseTableView.selectedRow)")
        
        var blePeripheral: BlePeripheral?
        let peripherals = peripheralList.filteredPeripherals(forceUpdate: false)
        if baseTableView.selectedRow >= 0 && baseTableView.selectedRow < peripherals.count {
            blePeripheral = peripherals[baseTableView.selectedRow]
        }
        
        // Disconnect previous
        let connectedPeripherals = BleManager.sharedInstance.connectedPeripherals()
        for peripheral in connectedPeripherals {
            if peripheral.identifier != blePeripheral?.identifier {
                disconnect(peripheral: peripheral)
            }
        }
        
        // Connect new
        if blePeripheral != nil, !isPeripheralConnected(identifier: blePeripheral!.identifier, includeConnecting: true) {
            self.connect(peripheral: blePeripheral!)
        }
    }
}
