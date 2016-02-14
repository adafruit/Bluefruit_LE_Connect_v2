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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup table refresh
        self.refreshControl?.addTarget(self, action: "onTableRefresh:", forControlEvents: UIControlEvents.ValueChanged)
        

        // Start scanning
        BleManager.sharedInstance.startScan()

        // Title
        self.title = LocalizationManager.sharedInstance.localizedString("peripherallist_title")
    }

    deinit {
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        //self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
        
        // Subscribe to Ble Notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didDiscoverPeripheral:", name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didDiscoverPeripheral:", name: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didDisconnectFromPeripheral:", name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didConnectToPeripheral:", name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "willConnectToPeripheral:", name: BleManager.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)

        
        let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
        if isFullScreen {
            peripheralList.connectToPeripheral(nil)
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func didDiscoverPeripheral(notification : NSNotification) {
        dispatch_async(dispatch_get_main_queue(), {[unowned self] in
            
            // Reload data
            self.tableView.reloadData()

            // Select identifier if still available
            if let selectedPeripheralRow = self.peripheralList.selectedPeripheralRow {
                self.tableView.selectRowAtIndexPath(NSIndexPath(forRow: selectedPeripheralRow, inSection: 0), animated: false, scrollPosition: .None)
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
        
        // Connection is managed here if the device is in compact mode
        let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
        if isFullScreen {
            DLog("list: connection on compact mode detected")
            
           // let kTimeToWaitForPeripheralConnectionError : Double = 1.5
           // let time = dispatch_time(dispatch_time_t(DISPATCH_TIME_NOW), Int64(kTimeToWaitForPeripheralConnectionError * Double(NSEC_PER_SEC)))
           // dispatch_after(time, dispatch_get_main_queue()) { [unowned self] in

            dispatch_async(dispatch_get_main_queue(), {[unowned self] in
                
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
                })
        }
    }
    override func shouldPerformSegueWithIdentifier(identifier: String, sender: AnyObject?) -> Bool {
        if identifier == "showDetailSegue" {
            let isPeripheralStillConnected =  BleManager.sharedInstance.blePeripheralConnected != nil  // peripheral should still be connected
            DLog("shouldPerformSegueWithIdentifier: \(isPeripheralStillConnected)")
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
                    
                    let localizationManager = LocalizationManager.sharedInstance
                    let alertController = UIAlertController(title: nil, message: localizationManager.localizedString("peripherallist_peripheraldisconnected"), preferredStyle: .Alert)
                    let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .Default, handler: { (_) -> Void in
                        if let navController = self.splitViewController?.viewControllers[0] as? UINavigationController {
                            navController.popViewControllerAnimated(true)
                        }
                    })
                    
                    alertController.addAction(okAction)
                    self.presentViewController(alertController, animated: true, completion: nil)
                    //   }
                }
                else {
                    self.baseTableView.reloadData()         // To remove the "disconnect" button
                }
                
            }
            })
    }
    
    // MARK - Actions
    func onTableRefresh(sender: AnyObject) {
        BleManager.sharedInstance.refreshPeripherals()
        self.refreshControl?.endRefreshing()
    }
    
    // MARK: - Table View
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return BleManager.sharedInstance.blePeripheralsFound.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("PeripheralCell", forIndexPath: indexPath)
        return cell
    }
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        
        let row = indexPath.row
        let bleManager = BleManager.sharedInstance
        let blePeripheralsFound = bleManager.blePeripheralsFound
        let selectedBlePeripheralIdentifier = peripheralList.blePeripherals[row]
        if let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier] {
            
            let peripheralCell =  cell as! PeripheralTableViewCell
            peripheralCell.titleLabel.text = blePeripheral.name
            
            let isUartCapable = blePeripheral.isUartAdvertised()
            peripheralCell.subtitleLabel.text = isUartCapable ?"Uart capable":"No Uart detected"
            peripheralCell.rssiImageView.image = signalImageForRssi(blePeripheral.rssi)
            
            // Show either a disconnect button or a disclouse indicator depending on the UISplitViewController displayMode
            let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
            peripheralCell.accessoryType = isFullScreen ? .DisclosureIndicator : .None
            
            peripheralCell.showDisconnectButton(!isFullScreen && row == peripheralList.selectedPeripheralRow)
            peripheralCell.onDisconnect = {
                if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
                    tableView.deselectRowAtIndexPath(indexPathForSelectedRow, animated: true)
                    self.peripheralList.selectRow(-1)
                }
            }
        }
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 66
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        peripheralList.selectRow(indexPath.row)
    }
    
}

