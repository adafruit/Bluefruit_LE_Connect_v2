//
//  PeripheralTableViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 28/01/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class PeripheralTableViewController: UIViewController {
    // Config
    static let kFiltersPanelClosedHeight: CGFloat = 44
    static let kFiltersPanelOpenHeight: CGFloat = 226

    // UI
    @IBOutlet var baseTableView: UITableView!
    @IBOutlet weak var filtersPanelView: UIView!
    @IBOutlet weak var filtersPanelViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var filtersDisclosureButton: UIButton!
    @IBOutlet weak var filtersTitleLabel: UILabel!
    @IBOutlet weak var filtersClearButton: UIButton!
    @IBOutlet weak var filtersNameTextField: UITextField!
    @IBOutlet weak var filtersRssiSlider: UISlider!
    @IBOutlet weak var filterRssiValueLabel: UILabel!
    @IBOutlet weak var filtersUnnamedSwitch: UISwitch!
    @IBOutlet weak var filtersUartSwitch: UISwitch!
    
    // Data
    private let refreshControl = UIRefreshControl()
    private var peripheralList: PeripheralList!
    private var tableRowOpen: Int?
    private var tableRowOpenPeripheralIdentifier: String?
    private var cachedNumOfTableItems = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        peripheralList = PeripheralList()                  // Initialize here to wait for Preferences.registerDefaults to be executed
        
        // Setup filters
        filtersNameTextField.leftViewMode = .Always
        let searchImageView = UIImageView(image: UIImage(named: "ic_search_18pt"))
        searchImageView.contentMode = UIViewContentMode.Right
        searchImageView.frame = CGRectMake(0.0, 0.0, searchImageView.image!.size.width + 6.0, searchImageView.image!.size.height)
        filtersNameTextField.leftView = searchImageView
        
        // Setup table refresh
        refreshControl.addTarget(self, action: #selector(onTableRefresh(_:)), forControlEvents: UIControlEvents.ValueChanged)
        baseTableView.addSubview(refreshControl)
        baseTableView.sendSubviewToBack(refreshControl)
        
        // Setup table view
        baseTableView.estimatedRowHeight = 66
        baseTableView.rowHeight = UITableViewAutomaticDimension
        
        // Start scanning
        BleManager.sharedInstance.startScan()
        
        // Title
        let localizationManager = LocalizationManager.sharedInstance
        self.title = localizationManager.localizedString("peripherallist_splitmasterbutton")
        self.navigationItem.title = LocalizationManager.sharedInstance.localizedString("peripherallist_title")
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: localizationManager.localizedString("peripherallist_backbutton"), style: .Plain, target: nil, action: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        //self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
        
        // Filters
        openFiltersPanel(Preferences.scanFilterIsPanelOpen, animated: false)
        updateFiltersTitle()
        filtersNameTextField.text = peripheralList.filterName ?? ""
        setRssiSliderValue(peripheralList.rssiFilterValue)
        filtersUnnamedSwitch.on = peripheralList.isUnnamedEnabled
        filtersUartSwitch.on = peripheralList.isOnlyUartEnabled
        
        // Ble State error check
        didUpdateBleState(nil)      // Force update state to show any pending errors
        
        // Subscribe to Ble Notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didDiscoverPeripheral(_:)), name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didDiscoverPeripheral(_:)), name: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didDisconnectFromPeripheral(_:)), name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didConnectToPeripheral(_:)), name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(willConnectToPeripheral(_:)), name: BleManager.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didUpdateBleState(_:)), name: BleManager.BleNotifications.DidUpdateBleState.rawValue, object: nil)
        
        
        let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
        if isFullScreen {
            peripheralList.connectToPeripheral(nil)
        }
        
        // Check that the peripheral is still connected
        if BleManager.sharedInstance.blePeripheralConnected == nil {
            peripheralList.disconnected()
        }
        
        // Reload
        reloadData()
        
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidUpdateBleState.rawValue, object: nil)
        
    }
    
    private func reloadData() {
        //
        synchronize(self) { [unowned self] in
            self.baseTableView.reloadData()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // MARK: - Notifications
    func didDiscoverPeripheral(notification: NSNotification) {
        dispatch_async(dispatch_get_main_queue(), {[weak self] in
            
            if let context = self {
                
                // Reload data
                let filteredPeripherals = context.peripheralList.filteredPeripherals(true)
                let currentPeripheralsCount = filteredPeripherals.count
                // DLog("discover count: \(currentPeripheralsCount)")
                if currentPeripheralsCount != context.cachedNumOfTableItems {

                    // Update row open if still available
                    if let tableRowOpenPeripheralIdentifier = context.tableRowOpenPeripheralIdentifier {
                        context.tableRowOpen = filteredPeripherals.indexOf(tableRowOpenPeripheralIdentifier)
                    }
                    else {
                        context.tableRowOpen = nil
                    }

                    context.baseTableView.reloadData()
                    
                    // Select identifier if still available
                    if let selectedPeripheralRow = self?.peripheralList.selectedPeripheralRow {
                        context.baseTableView.selectRowAtIndexPath(NSIndexPath(forRow: selectedPeripheralRow, inSection: 0), animated: false, scrollPosition: .None)
                    }
                    
                    
                }
                
                
            }
            })
    }
    
    func willConnectToPeripheral(notification: NSNotification) {
        let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
        if isFullScreen {
            dispatch_async(dispatch_get_main_queue(), {[unowned self] in
                let localizationManager = LocalizationManager.sharedInstance
                let alertController = UIAlertController(title: nil, message: localizationManager.localizedString("peripheraldetails_connecting"), preferredStyle: .Alert)
                
                alertController.addAction(UIAlertAction(title: localizationManager.localizedString("dialog_cancel"), style: .Cancel, handler: { (_) -> Void in
                    if let peripheral = BleManager.sharedInstance.blePeripheralConnecting {
                        BleManager.sharedInstance.disconnect(peripheral)
                    }
                    else if let peripheral = BleManager.sharedInstance.blePeripheralConnected {
                        BleManager.sharedInstance.disconnect(peripheral)
                    }
                }))
                self.presentViewController(alertController, animated: true, completion:nil)
                })
        }
    }
    
    func didConnectToPeripheral(notification: NSNotification) {
        // Watch
        WatchSessionManager.sharedInstance.updateApplicationContext(.Connected)
        
        // Connection is managed here if the device is in compact mode
        let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
        if isFullScreen {
            DLog("list: connection on compact mode detected")
            
            let kTimeToWaitForPeripheralConnectionError: Double = 0.5
            let time = dispatch_time(dispatch_time_t(DISPATCH_TIME_NOW), Int64(kTimeToWaitForPeripheralConnectionError * Double(NSEC_PER_SEC)))
            dispatch_after(time, dispatch_get_main_queue()) { [unowned self] in
                
                if BleManager.sharedInstance.blePeripheralConnected != nil {
                    
                    // Deselect current row
                    if let indexPathForSelectedRow = self.baseTableView.indexPathForSelectedRow {
                        self.baseTableView.deselectRowAtIndexPath(indexPathForSelectedRow, animated: true)
                    }
                    
                    // Dismiss current dialog
                    if self.presentedViewController != nil {
                        self.dismissViewControllerAnimated(true, completion: { [unowned self] () -> Void in
                            self.performSegueWithIdentifier("showDetailSegue", sender: self)
                            })
                    }
                    else {
                        self.performSegueWithIdentifier("showDetailSegue", sender: self)
                    }
                }
                else {
                    DLog("cancel push detail because peripheral was disconnected")
                }
            }
        }
    }
    
    func didUpdateBleState(notification: NSNotification?) {
        guard let state = BleManager.sharedInstance.centralManager?.state else {
            return
        }
        
        // Check if there is any error
        var errorMessage: String?
        switch state {
        case .Unsupported:
            errorMessage = "This device doesn't support Bluetooth Low Energy"
        case .Unauthorized:
            errorMessage = "This app is not authorized to use the Bluetooth Low Energy"
        case.PoweredOff:
            errorMessage = "Bluetooth is currently powered off"
            
        default:
            errorMessage = nil
        }
        
        // Show alert if error found
        if let errorMessage = errorMessage {
            let localizationManager = LocalizationManager.sharedInstance
            let alertController = UIAlertController(title: localizationManager.localizedString("dialog_error"), message: errorMessage, preferredStyle: .Alert)
            let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .Default, handler: { (_) -> Void in
                if let navController = self.splitViewController?.viewControllers[0] as? UINavigationController {
                    navController.popViewControllerAnimated(true)
                }
            })
            
            alertController.addAction(okAction)
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    override func shouldPerformSegueWithIdentifier(identifier: String, sender: AnyObject?) -> Bool {
        if identifier == "showDetailSegue" {
            let isPeripheralStillConnected = BleManager.sharedInstance.blePeripheralConnected != nil  // peripheral should still be connected
            //DLog("shouldPerformSegueWithIdentifier: \(isPeripheralStillConnected)")
            return isPeripheralStillConnected
        }
        return true
    }
    
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetailSegue" {
            //DLog("destination: \(segue.destinationViewController)")
            let peripheralDetailsViewController = (segue.destinationViewController as! UINavigationController).topViewController as! PeripheralDetailsViewController
            peripheralDetailsViewController.selectedBlePeripheral = BleManager.sharedInstance.blePeripheralConnected
        }
        else  if segue.identifier == "filterNameSettingsSegue"  {
            if let controller = segue.destinationViewController.popoverPresentationController {
                controller.delegate = self
                
                let filterNameSettingsViewController = segue.destinationViewController as! FilterTextSettingsViewController
                filterNameSettingsViewController.peripheralList = peripheralList
                filterNameSettingsViewController.onSettingsChanged = { [unowned self] in
                    self.updateFilters()
                }
            }
        }
    }
    
    func didDisconnectFromPeripheral(notification : NSNotification) {
        // Watch
        WatchSessionManager.sharedInstance.updateApplicationContext(.Scan)
        
        //
        dispatch_async(dispatch_get_main_queue(), {[unowned self] in
            DLog("list: disconnection detected a")
            self.peripheralList.disconnected()
            
            let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
            
            if BleManager.sharedInstance.blePeripheralConnected == nil, let indexPathForSelectedRow = self.baseTableView.indexPathForSelectedRow {
                DLog("list: disconnection detected b")
                
                // Unexpected disconnect if the row is still selected but the connected peripheral is nil and the time since the user selected a new peripheral is bigger than kMinTimeSinceUserSelection second
                // let kMinTimeSinceUserSelection = 1.0    // in secs
                // if self.peripheralList.elapsedTimeSinceSelection > kMinTimeSinceUserSelection {
                self.baseTableView.deselectRowAtIndexPath(indexPathForSelectedRow, animated: true)
                
                DLog("list: disconnection detected c")
                
                if isFullScreen {
                    
                    DLog("list: compact mode show alert")
                    if self.presentedViewController != nil {
                        self.dismissViewControllerAnimated(true, completion: { () -> Void in
                            self.showPeripheralDisconnectedDialog()
                        })
                    }
                    else {
                        self.showPeripheralDisconnectedDialog()
                    }
                    //   }
                }
                
            }
            
            if !isFullScreen {
                self.reloadData()
            }
            
            })
    }
    
    private func showPeripheralDisconnectedDialog() {
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: nil, message: localizationManager.localizedString("peripherallist_peripheraldisconnected"), preferredStyle: .Alert)
        let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .Default, handler: { (_) -> Void in
            if let navController = self.splitViewController?.viewControllers[0] as? UINavigationController {
                navController.popViewControllerAnimated(true)
            }
        })
        
        alertController.addAction(okAction)
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    
    // MARK: - Filters
    private func openFiltersPanel(isOpen: Bool, animated: Bool) {
        
        Preferences.scanFilterIsPanelOpen = isOpen
        self.filtersDisclosureButton.selected = isOpen
        
        self.filtersPanelViewHeightConstraint.constant = isOpen ? PeripheralTableViewController.kFiltersPanelOpenHeight:PeripheralTableViewController.kFiltersPanelClosedHeight
        UIView.animateWithDuration(animated ? 0.3:0) { [unowned self] in
            self.view.layoutIfNeeded()
        }
    }
    
    private func updateFiltersTitle() {
        let filtersTitle = peripheralList.filtersDescription()
        filtersTitleLabel.text = filtersTitle != nil ? "Filter: \(filtersTitle!)" : "No filter selected"
        
        filtersClearButton.hidden = !peripheralList.isAnyFilterEnabled()
    }
    
    private func updateFilters() {
        updateFiltersTitle()
        baseTableView.reloadData()
    }
    
    private func setRssiSliderValue(value: Int?) {
        filtersRssiSlider.value = value != nil ? Float(-value!) : 100.0
        updateRssiValueLabel()
    }
    
    private func updateRssiValueLabel() {
        filterRssiValueLabel.text = "\(Int(-filtersRssiSlider.value)) dBM"
    }

    // MARK: - Actions
    func onTableRefresh(sender: AnyObject) {
        tableRowOpen = nil
        tableRowOpenPeripheralIdentifier = nil
        BleManager.sharedInstance.refreshPeripherals()
        refreshControl.endRefreshing()
    }
    
    @IBAction func onClickExpandFilters(sender: AnyObject) {
        openFiltersPanel(!Preferences.scanFilterIsPanelOpen, animated: true)
    }
    
    @IBAction func onFilterNameChanged(sender: UITextField) {
        let isEmpty = sender.text?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).isEmpty ?? true
        peripheralList.filterName = isEmpty ? nil:sender.text
        updateFilters()
    }
    
    @IBAction func onRssiSliderChanged(sender: UISlider) {
        let rssiValue = Int(-sender.value)
        peripheralList.rssiFilterValue = rssiValue
        updateRssiValueLabel()
        updateFilters()
    }
    
    @IBAction func onFilterSettingsUnnamedChanged(sender: UISwitch) {
        peripheralList.isUnnamedEnabled = sender.on
        updateFilters()
    }
    
    @IBAction func onFilterSettingsUartChanged(sender: UISwitch) {
        peripheralList.isOnlyUartEnabled = sender.on
        updateFilters()
    }
    
    @IBAction func onClickRemoveFilters(sender: AnyObject) {
        peripheralList.setDefaultFilters()
        filtersNameTextField.text = peripheralList.filterName ?? ""
        setRssiSliderValue(peripheralList.rssiFilterValue)
        filtersUnnamedSwitch.on = peripheralList.isUnnamedEnabled
        filtersUartSwitch.on = peripheralList.isOnlyUartEnabled
        updateFilters()
    }
}

// MARK: - UITableViewDataSource
extension PeripheralTableViewController: UITableViewDataSource {
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    /*
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return LocalizationManager.sharedInstance.localizedString("peripherallist_subtitle")
    }
    */
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Hack to update watch when the cell count changes
        WatchSessionManager.sharedInstance.updateApplicationContext(.Scan)
        
        // Calculate num cells
        cachedNumOfTableItems = peripheralList.filteredPeripherals(true).count
        return cachedNumOfTableItems
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("PeripheralCell", forIndexPath: indexPath)
        
        let row = indexPath.row
        let bleManager = BleManager.sharedInstance
        let blePeripheralsFound = bleManager.blePeripherals()
        let filteredPeripherals = peripheralList.filteredPeripherals(false)
        
        if row < filteredPeripherals.count {      // To avoid problems with peripherals disconnecting
            let selectedBlePeripheralIdentifier = filteredPeripherals[row];
            if let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier] {
                let localizationManager = LocalizationManager.sharedInstance
                
                let peripheralCell =  cell as! PeripheralTableViewCell
                peripheralCell.titleLabel.text = blePeripheral.name ?? localizationManager.localizedString("peripherallist_unnamed")
                
                let isUartCapable = blePeripheral.isUartAdvertised()
                peripheralCell.subtitleLabel.text = localizationManager.localizedString(isUartCapable ? "peripherallist_uartavailable" : "peripherallist_uartunavailable")
                peripheralCell.rssiImageView.image = signalImageForRssi(blePeripheral.rssi)
                
                // Show either a disconnect button or a disclosure indicator depending on the UISplitViewController displayMode
                let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
                // peripheralCell.accessoryType = isFullScreen ? .DisclosureIndicator : .None
                
                let showConnect = isFullScreen || peripheralList.selectedPeripheralRow == nil
                let showDisconnect = !isFullScreen && row == peripheralList.selectedPeripheralRow
                peripheralCell.disconnectButton.hidden = !showDisconnect
                peripheralCell.connectButton.hidden = !showConnect // showDisconnect
                peripheralCell.onDisconnect = { [unowned self] in
                    tableView.deselectRowAtIndexPath(indexPath, animated: true)
                    self.peripheralList.selectRow(-1)
                    self.reloadData()
                }
                peripheralCell.onConnect = { [unowned self] in
                    
                    self.peripheralList.selectRow(indexPath.row)
                    //self.baseTableView.reloadData()
                    self.reloadData()
                }
                
                // Detail Subview
                let isDetailViewOpen = row == tableRowOpen
                peripheralCell.baseStackView.subviews[1].hidden = !isDetailViewOpen
                if isDetailViewOpen {
                    setupPeripheralExtendedView(peripheralCell, advertisementData: blePeripheral.advertisementData)
                }
            }
        }
        
        return cell
    }
    
    private func setupPeripheralExtendedView(peripheralCell: PeripheralTableViewCell, advertisementData: [String : AnyObject]) {
        let detailBaseStackView = peripheralCell.detailBaseStackView
        
        var currentIndex = 0
        
        // Local Name 
        var isLocalNameAvailable = false
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            
            peripheralCell.localNameValueLabel.text = localName
            isLocalNameAvailable = true
        }
        detailBaseStackView.subviews[currentIndex].hidden = !isLocalNameAvailable
        currentIndex = currentIndex+1

        
        // Manufacturer Name
        var isManufacturerAvailable = false
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? NSData, manufacturerString = String(data: manufacturerData, encoding: NSUTF8StringEncoding) {
            
            peripheralCell.manufacturerValueLabel.text = manufacturerString
            isManufacturerAvailable = true
        }
        else {
            peripheralCell.manufacturerValueLabel.text = nil
        }
        detailBaseStackView.subviews[currentIndex].hidden = !isManufacturerAvailable
        currentIndex = currentIndex+1
        
        // Services
        var areServicesAvailable = false
        if let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            //DLog("services: \(services.count)")
            let stackView = peripheralCell.servicesStackView
    
            addServiceNames(stackView, services: services)
            
            areServicesAvailable = services.count > 0
        }
        detailBaseStackView.subviews[currentIndex].hidden = !areServicesAvailable
        currentIndex = currentIndex+1

        // Services Overflow
        var areServicesOverflowAvailable = false
        if let servicesOverflow = advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] {
            let stackView = peripheralCell.servicesOverflowStackView

            addServiceNames(stackView, services: servicesOverflow)
            
            areServicesOverflowAvailable = servicesOverflow.count > 0
        }
        detailBaseStackView.subviews[currentIndex].hidden = !areServicesOverflowAvailable
        currentIndex = currentIndex+1
        
        // Solicited Services
        var areSolicitedServicesAvailable = false
        if let servicesSolicited = advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID] {
            let stackView = peripheralCell.servicesOverflowStackView
            
            addServiceNames(stackView, services: servicesSolicited)
            
            areSolicitedServicesAvailable = servicesSolicited.count > 0
        }
        detailBaseStackView.subviews[currentIndex].hidden = !areSolicitedServicesAvailable
        currentIndex = currentIndex+1

        
        // Tx Power
        var isTxPowerAvailable: Bool
        if let txpower = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber {
            peripheralCell.txPowerLevelValueLabel.text = String(txpower)
            isTxPowerAvailable = true
        }
        else {
            isTxPowerAvailable = false
        }
        detailBaseStackView.subviews[currentIndex].hidden = !isTxPowerAvailable
        currentIndex = currentIndex+1

        
        // Connectable
        var isConnectable: Bool?
        if let connectableNumber = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber {
            isConnectable = connectableNumber.boolValue
        }
        peripheralCell.connectableValueLabel.text = isConnectable != nil ? "\(isConnectable! ? "true":"false")":"unknown"
        currentIndex = currentIndex+1

    }
    
    private func addServiceNames(stackView: UIStackView, services: [CBUUID]) {
        let styledLabel = stackView.arrangedSubviews.first! as! UILabel
        styledLabel.hidden = true     // The first view is only to define style in InterfaceBuilder. Hide it
        
        // Clear current subviews
        for arrangedSubview in stackView.arrangedSubviews {
            if arrangedSubview != stackView.arrangedSubviews.first {
                arrangedSubview.removeFromSuperview()
                stackView.removeArrangedSubview(arrangedSubview)
            }
        }
        
        // Add services as subviews
        for serviceCBUUID in services {
            let label = UILabel()
            var identifier = serviceCBUUID.UUIDString
            if let name = BleUUIDNames.sharedInstance.nameForUUID(identifier) {
                identifier = name
            }
            label.text = identifier
            label.font = styledLabel.font
            label.minimumScaleFactor = styledLabel.minimumScaleFactor
            label.adjustsFontSizeToFitWidth = styledLabel.adjustsFontSizeToFitWidth
            stackView.addArrangedSubview(label)
        }

    }
}

// MARK: - UITableViewDelegate
extension PeripheralTableViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        //peripheralList.selectRow(indexPath.row)
        let row = indexPath.row
        let previousTableRowOpen = tableRowOpen
        tableRowOpen = row == tableRowOpen ? nil: row
        
        synchronize(self) { [unowned self] in
            let filteredPeripherals = self.peripheralList.filteredPeripherals(false)
            self.tableRowOpenPeripheralIdentifier = self.tableRowOpen != nil && self.tableRowOpen! < filteredPeripherals.count ?  filteredPeripherals[self.tableRowOpen!] : nil

            // Animate if the number the items have not changed
            if filteredPeripherals.count == self.cachedNumOfTableItems  {
                
                // Reload data
                var reloadPaths = [indexPath]
                if let previousTableRowOpen = previousTableRowOpen {
                    reloadPaths.append(NSIndexPath(forRow: previousTableRowOpen, inSection: indexPath.section))
                }
                self.baseTableView.reloadRowsAtIndexPaths(reloadPaths, withRowAnimation: .None)
                
                // Animate changes
                self.baseTableView.beginUpdates()
                tableView.deselectRowAtIndexPath(indexPath, animated: false)
                self.baseTableView.endUpdates()
            }
            else {
                self.baseTableView.reloadData()
            }
        }
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension PeripheralTableViewController: UIPopoverPresentationControllerDelegate {
    
    func adaptivePresentationStyleForPresentationController(PC: UIPresentationController) -> UIModalPresentationStyle {
        // This *forces* a popover to be displayed on the iPhone
        if traitCollection.verticalSizeClass != .Compact {
            return .None
        }
        else {
            return .FullScreen
        }
    }
    
    func popoverPresentationControllerDidDismissPopover(popoverPresentationController: UIPopoverPresentationController) {
        DLog("selector dismissed")
    }
}
