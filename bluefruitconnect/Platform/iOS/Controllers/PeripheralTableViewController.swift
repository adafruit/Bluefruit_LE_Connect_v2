//
//  PeripheralTableViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 28/01/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class PeripheralTableViewController: UITableViewController {
    
    // UI
    @IBOutlet var baseTableView: UITableView!
    
    // Data
    private var peripheralList = PeripheralList()
    private var tableRowOpen: Int?
    private var cachedNumOfTableItems = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup table refresh
        self.refreshControl?.addTarget(self, action: #selector(PeripheralTableViewController.onTableRefresh(_:)), forControlEvents: UIControlEvents.ValueChanged)
        
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
        
        // Subscribe to Ble Notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didDiscoverPeripheral(_:)), name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didDiscoverPeripheral(_:)), name: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didDisconnectFromPeripheral(_:)), name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didConnectToPeripheral(_:)), name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(willConnectToPeripheral(_:)), name: BleManager.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)
        
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
    
    func didDiscoverPeripheral(notification : NSNotification) {
        dispatch_async(dispatch_get_main_queue(), {[weak self] in
            
            // Reload data
            if  BleManager.sharedInstance.blePeripheralsCount() != self?.cachedNumOfTableItems  {
                self?.tableView.reloadData()
            }
            
            // Select identifier if still available
            if let selectedPeripheralRow = self?.peripheralList.selectedPeripheralRow {
                self?.tableView.selectRowAtIndexPath(NSIndexPath(forRow: selectedPeripheralRow, inSection: 0), animated: false, scrollPosition: .None)
            }
            })
    }
    
    func willConnectToPeripheral(notification : NSNotification) {
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
    
    func didConnectToPeripheral(notification : NSNotification) {
        // Watch
        WatchSessionManager.sharedInstance.updateApplicationContext(.Connected)
        
        // Connection is managed here if the device is in compact mode
        let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
        if isFullScreen {
            DLog("list: connection on compact mode detected")
            
            let kTimeToWaitForPeripheralConnectionError : Double = 0.5
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
    override func shouldPerformSegueWithIdentifier(identifier: String, sender: AnyObject?) -> Bool {
        if identifier == "showDetailSegue" {
            let isPeripheralStillConnected =  BleManager.sharedInstance.blePeripheralConnected != nil  // peripheral should still be connected
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
    }
    
    func didDisconnectFromPeripheral(notification : NSNotification) {
        // Watch
        WatchSessionManager.sharedInstance.updateApplicationContext(.Scan)

        //
        dispatch_async(dispatch_get_main_queue(), {[unowned self] in
            DLog("list: disconnection detected a")
            self.peripheralList.disconnected()
            if BleManager.sharedInstance.blePeripheralConnected == nil, let indexPathForSelectedRow = self.tableView.indexPathForSelectedRow {
                DLog("list: disconnection detected b")
                
                // Unexpected disconnect if the row is still selected but the connected peripheral is nil and the time since the user selected a new peripheral is bigger than kMinTimeSinceUserSelection second
                // let kMinTimeSinceUserSelection = 1.0    // in secs
                // if self.peripheralList.elapsedTimeSinceSelection > kMinTimeSinceUserSelection {
                self.tableView.deselectRowAtIndexPath(indexPathForSelectedRow, animated: true)
                
                DLog("list: disconnection detected c")
                
                let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
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
                else {
                    self.reloadData()
                }
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
    
    // MARK - Actions
    func onTableRefresh(sender: AnyObject) {
        tableRowOpen = nil
        BleManager.sharedInstance.refreshPeripherals()
        self.refreshControl?.endRefreshing()
    }
    
    // MARK: - Table View
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return LocalizationManager.sharedInstance.localizedString("peripherallist_subtitle")
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Hack to update watch when the cell count changes
        WatchSessionManager.sharedInstance.updateApplicationContext(.Scan)
        
        // Calculate num cells
        cachedNumOfTableItems = BleManager.sharedInstance.blePeripheralsCount()
        return cachedNumOfTableItems
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("PeripheralCell", forIndexPath: indexPath)
        
        let row = indexPath.row
        let bleManager = BleManager.sharedInstance
        let blePeripheralsFound = bleManager.blePeripherals()
        if row < peripheralList.blePeripherals.count {      // To avoid problems with peripherals disconnecting
            let selectedBlePeripheralIdentifier = peripheralList.blePeripherals[row]
            if let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier] {
                
                let peripheralCell =  cell as! PeripheralTableViewCell
                peripheralCell.titleLabel.text = blePeripheral.name ?? "{No Name}"
                
                let isUartCapable = blePeripheral.isUartAdvertised()
                peripheralCell.subtitleLabel.text = isUartCapable ?"Uart capable":"No Uart detected"
                peripheralCell.rssiImageView.image = signalImageForRssi(blePeripheral.rssi)
                
                // Show either a disconnect button or a disclosure indicator depending on the UISplitViewController displayMode
                let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
                // peripheralCell.accessoryType = isFullScreen ? .DisclosureIndicator : .None
                
                let showConnect = isFullScreen || peripheralList.selectedPeripheralRow == nil
                let showDisconnect = !isFullScreen && row == peripheralList.selectedPeripheralRow
                peripheralCell.disconnectButton.hidden = !showDisconnect
                peripheralCell.connectButton.hidden = !showConnect // showDisconnect
                peripheralCell.onDisconnect = { [unowned self] in
                    if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
                        tableView.deselectRowAtIndexPath(indexPathForSelectedRow, animated: true)
                        self.peripheralList.selectRow(-1)
                        self.reloadData()
                    }
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
        
        // Manufacturer Name
        var isManufacturerAvailable = false
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? NSData, manufacturerString = String(data: manufacturerData, encoding: NSUTF8StringEncoding) {
            
            peripheralCell.manufacturerValueLabel.text = manufacturerString
            isManufacturerAvailable = true
        }
        else {
            peripheralCell.manufacturerValueLabel.text = nil
        }
        detailBaseStackView.subviews[0].hidden = !isManufacturerAvailable
        
        // Services
        let stackView = peripheralCell.servicesStackView
        let styledLabel = stackView.arrangedSubviews.first! as! UILabel
        styledLabel.hidden = true     // The first view is only to define style in InterfaceBuilder. Hide it
        
        var areServicesAvailable = false
        if let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? NSArray {
            //DLog("services: \(services.count)")
            
            // Clear current subviews
            for arrangedSubview in stackView.arrangedSubviews {
                if arrangedSubview != stackView.arrangedSubviews.first {
                    arrangedSubview.removeFromSuperview()
                    stackView.removeArrangedSubview(arrangedSubview)
                }
            }
            
            // Add services as subviews
            for serviceUUID in services {
                if let serviceCBUUID = serviceUUID as? CBUUID {
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
            
            areServicesAvailable = services.count > 0
        }
        detailBaseStackView.subviews[1].hidden = !areServicesAvailable
        
        // Tx Power
        if let txpower = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber {
            peripheralCell.txPowerLevelValueLabel.text = String(txpower)
        }
        else {
            peripheralCell.txPowerLevelValueLabel.text = nil
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        //peripheralList.selectRow(indexPath.row)
        let row = indexPath.row
        let previousTableRowOpen = tableRowOpen
        tableRowOpen = row == tableRowOpen ? nil: row
        
        synchronize(self) { [unowned self] in
            // Animate if the nubmer the items have not changed
            if BleManager.sharedInstance.blePeripheralsCount() == self.cachedNumOfTableItems  {
                
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

