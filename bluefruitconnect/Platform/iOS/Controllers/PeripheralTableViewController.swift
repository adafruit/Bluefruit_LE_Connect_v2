//
//  PeripheralTableViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 28/01/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class PeripheralTableViewController: UITableViewController {

    var detailViewController: DetailViewController? = nil

    private var currentSelectedRow = -1
    private var currentSelectedPeripheralIdentifier : String?
    private var lastUserSelection = CFAbsoluteTimeGetCurrent()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup SpliView
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
        
        // Subscribe to Ble Notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didDiscoverPeripheral:", name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didDiscoverPeripheral:", name: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didDisconnectFromPeripheral:", name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)

        // Start scanning
        BleManager.sharedInstance.startScan()

    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
    }

    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
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
            if let selectedPeripheralIdentifier = self.currentSelectedPeripheralIdentifier {
                if let index = BleManager.sharedInstance.blePeripheralFoundAlphabeticKeys().indexOf(selectedPeripheralIdentifier) {
                    //                    DLog("discover row: \(index)");
                    
                    self.tableView.selectRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0), animated: false, scrollPosition: .None)
                }
            }
            })
    }

    func didDisconnectFromPeripheral(notification : NSNotification) {
        dispatch_async(dispatch_get_main_queue(), {[unowned self] in
            
            
            if BleManager.sharedInstance.blePeripheralConnected == nil, let indexPathForSelectedRow = self.tableView.indexPathForSelectedRow {
                
                // Unexpected disconnect if the row is still selected but the connected peripheral is nil and the time since the user selected a new peripheral is bigger than 1 second
                if (CFAbsoluteTimeGetCurrent() - self.lastUserSelection > 1) {
                    self.tableView.deselectRowAtIndexPath(indexPathForSelectedRow, animated: true)
                    
                    let alertController = UIAlertController(title: nil, message: "Peripheral disconnected", preferredStyle: .Alert)
                    let okAction = UIAlertAction(title: "Ok", style: .Default, handler: nil)
                    alertController.addAction(okAction)
                    self.presentViewController(alertController, animated: true, completion: nil)
                }
            }
            })
    }
    
    // MARK: - Segues

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
                
                let bleManager = BleManager.sharedInstance
                let blePeripheralsFound = bleManager.blePeripheralsFound
                let selectedBlePeripheralIdentifier = bleManager.blePeripheralFoundAlphabeticKeys()[indexPath.row];
                let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier]!
                
                let controller = (segue.destinationViewController as! UINavigationController).topViewController as! DetailViewController
                controller.detailItem = blePeripheral
                controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }

    // MARK: - Table View

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return BleManager.sharedInstance.blePeripheralsFound.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("PeripheralCell", forIndexPath: indexPath) as! PeripheralTableViewCell

        let row = indexPath.row
        let bleManager = BleManager.sharedInstance
        let blePeripheralsFound = bleManager.blePeripheralsFound
        let selectedBlePeripheralIdentifier = bleManager.blePeripheralFoundAlphabeticKeys()[row];
        let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier]!

        cell.titleLabel.text = blePeripheral.name
        
        let isUartCapable = blePeripheral.isUartAdvertised()
        cell.subtitleLabel.text = isUartCapable ?"Uart capable":"No Uart detected"
        cell.rssiImageView.image = signalImageForRssi(blePeripheral.rssi)
        
        cell.onDisconnect = {
            if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
                tableView.deselectRowAtIndexPath(indexPathForSelectedRow, animated: true)
            }
        }
        
        cell.showDisconnectButton(row == currentSelectedRow)
        
        return cell
    }
}

