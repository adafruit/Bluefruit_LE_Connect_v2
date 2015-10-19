//
//  DetailsViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 25/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa
import CoreBluetooth

class DetailsViewController: NSViewController, CBPeripheralDelegate {
    
    @IBOutlet weak var emptyView: NSTabView!
    @IBOutlet weak var emptyLabel: NSTextField!
    
    @IBOutlet weak var modeTabView: NSTabView!

    @IBOutlet weak var infoView: NSView!
    @IBOutlet weak var infoNameLabel: NSTextField!
    @IBOutlet weak var infoRssiImageView: NSImageView!
    @IBOutlet weak var infoRssiLabel: NSTextField!
    @IBOutlet weak var infoUartImageView: NSImageView!
    @IBOutlet weak var infoDisImageView: NSImageView!
    @IBOutlet weak var infoDfuImageView: NSImageView!
    
    let kRssiUpdateInterval = 0.5       // in seconds
    var rssiTimer : NSTimer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /*
        infoView.wantsLayer = true
        infoView.layer?.backgroundColor = NSColor.blueColor().CGColor
        infoView.layer?.backgroundColor = NSColor.whiteColor().CGColor
        infoView.layer?.cornerRadius = 4
        */
        
        /*
        infoView.wantsLayer = true
        infoView.layer?.borderWidth = 1
        infoView.layer?.borderColor = NSColor.lightGrayColor().CGColor
        */
        
        showEmpty(true)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // Subscribe to Ble Notifications
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "willConnectToPeripheral:", name: BleManager.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)
        notificationCenter.addObserver(self, selector: "didConnectToPeripheral:", name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        notificationCenter.addObserver(self, selector: "willDisconnectFromPeripheral:", name: BleManager.BleNotifications.WillDisconnectFromPeripheral.rawValue, object: nil)
//        notificationCenter.addObserver(self, selector: "didDiscoverPeripheral:", name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: BleManager.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)
        notificationCenter.removeObserver(self, name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        notificationCenter.removeObserver(self, name: BleManager.BleNotifications.WillDisconnectFromPeripheral.rawValue, object: nil)
   //     notificationCenter.removeObserver(self, name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
    }
    
    deinit {
        cancelRssiTimer()
    }
    
    func willConnectToPeripheral(notification : NSNotification) {
        showEmpty(true)
        emptyLabel.stringValue = "Connecting..."
    }
    
    func didConnectToPeripheral(notification : NSNotification) {

        guard BleManager.sharedInstance.blePeripheralConnected != nil else {
            DLog("Warning: didConnectToPeripheral with empty blePeripheralConnected");
            return;
        }

        showEmpty(false)

        let blePeripheral = BleManager.sharedInstance.blePeripheralConnected!;
        blePeripheral.peripheral.delegate = self

        for tabViewItem in modeTabView.tabViewItems {
            modeTabView.removeTabViewItem(tabViewItem)
        }

        // Info
        infoNameLabel.stringValue = blePeripheral.name
        updateRssi()

        cancelRssiTimer()
        rssiTimer = NSTimer.scheduledTimerWithTimeInterval(kRssiUpdateInterval, target: self, selector: "updateRssi", userInfo: nil, repeats: true)

        // Add Info tab
        let infoViewController = self.storyboard?.instantiateControllerWithIdentifier("InfoViewController") as! InfoViewController
        infoViewController.onServicesDiscovered = { [unowned self] in
            self.servicesDiscovered()
        }
        let infoTabViewItem = NSTabViewItem(viewController: infoViewController)
        modeTabView.addTabViewItem(infoTabViewItem)

        modeTabView.selectFirstTabViewItem(nil)
    }

    func willDisconnectFromPeripheral(notification : NSNotification) {
        showEmpty(true)
        cancelRssiTimer()
        
        for tabViewItem in modeTabView.tabViewItems {
            modeTabView.removeTabViewItem(tabViewItem)
        }
        
        let blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        blePeripheral?.peripheral.delegate = nil
    }
    
    func cancelRssiTimer() {
        rssiTimer?.invalidate()
        rssiTimer = nil
    }
    
    func showEmpty(isEmpty : Bool) {
        infoView.hidden = isEmpty
        modeTabView.hidden = isEmpty
        emptyView.hidden = !isEmpty
        if (isEmpty) {
            emptyLabel.stringValue = "Select a peripheral"
        }
    }

    func servicesDiscovered() {
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            if let services = blePeripheral.peripheral.services {
                
                // Clear old ones (not 0 that is Info)
                if (modeTabView.tabViewItems.count > 1) {
                    for i in 1...(modeTabView.tabViewItems.count-1) {
                        modeTabView.removeTabViewItem(modeTabView.tabViewItems[i])
                    }
                }
                
                // Check Uart
                let kUartServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"                       // UART service UUID
                let hasUart = services.contains({ (service : CBService) -> Bool in
                      service.UUID.isEqual(CBUUID(string: kUartServiceUUID))
                })
                
                infoUartImageView.image = NSImage(named: hasUart ?"NSStatusAvailable":"NSStatusNone")
                if (hasUart) {
                    // Add Uart tab
                    let uartViewController = self.storyboard?.instantiateControllerWithIdentifier("UartViewController") as! UartViewController
                    let uartTabViewItem = NSTabViewItem(viewController: uartViewController)
                    modeTabView.addTabViewItem(uartTabViewItem)
                }
                
                // Check DFU
                let kNordicDeviceFirmwareUpdateService = "00001530-1212-EFDE-1523-785FEABCD123"    // DFU service UUID
                let hasDFU = services.contains({ (service : CBService) -> Bool in
                    service.UUID.isEqual(CBUUID(string: kNordicDeviceFirmwareUpdateService))
                })
                
                infoDfuImageView.image = NSImage(named: hasDFU ?"NSStatusAvailable":"NSStatusNone")
                if (hasDFU) {
                    // Add Firmware Update tab
                    let updateViewController = self.storyboard?.instantiateControllerWithIdentifier("FirmwareUpdateViewController") as! FirmwareUpdateViewController
                    let updateTabViewItem = NSTabViewItem(viewController: updateViewController)
                    modeTabView.addTabViewItem(updateTabViewItem)
                }
                
                // Check DIS
                let kDisServiceUUID = "180A"    // DIS service UUID
                let hasDIS = services.contains({ (service : CBService) -> Bool in
                    service.UUID.isEqual(CBUUID(string: kDisServiceUUID))
                })
                
                infoDisImageView.image = NSImage(named: hasDIS ?"NSStatusAvailable":"NSStatusNone")
            }
        }
    }
    /*
    func didDiscoverPeripheral(notification : NSNotification) {
        let userInfo = notification.userInfo as! [String : String]
        let identifier = userInfo["uuid"]
        let connectedPeripheralIdentifier = BleManager.sharedInstance.blePeripheralConnected?.peripheral.identifier.UUIDString
        //DLog("discover: \(identifier), connected: \(connectedPeripheralIdentifier)");
        if (identifier == connectedPeripheralIdentifier) {
            updateRssi()
        }
    }
*/
    
    func updateRssi() {
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            let rssi = blePeripheral.rssi
            //DLog("rssi: \(rssi)")
            infoRssiLabel.stringValue = "\(rssi) dBm"
            infoRssiImageView.image = signalImageForRssi(rssi)
        }
    }
    
    // MARK - CBPeripheralDelegate
    // Send peripheral delegate methods to tab active (each tab will handle these methods)
    func peripheralDidUpdateName(peripheral: CBPeripheral) {
        if let viewController = modeTabView.selectedTabViewItem?.viewController {
            (viewController as? CBPeripheralDelegate)?.peripheralDidUpdateName?(peripheral);
        }
    }
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        if let viewController = modeTabView.selectedTabViewItem?.viewController {
            (viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didModifyServices: invalidatedServices)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        if let viewController = modeTabView.selectedTabViewItem?.viewController {
            (viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didDiscoverServices: error)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if let viewController = modeTabView.selectedTabViewItem?.viewController {
            (viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didDiscoverCharacteristicsForService: service, error: error)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if let viewController = modeTabView.selectedTabViewItem?.viewController {
            (viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didDiscoverDescriptorsForCharacteristic: characteristic, error: error)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if let viewController = modeTabView.selectedTabViewItem?.viewController {
            (viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didUpdateValueForCharacteristic: characteristic, error: error)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        if let viewController = modeTabView.selectedTabViewItem?.viewController {
            (viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didUpdateValueForDescriptor: descriptor, error: error)
        }
    }
    
    func peripheralDidUpdateRSSI(peripheral: CBPeripheral, error: NSError?) {
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.updateRssi()
        })
        
        if let viewController = modeTabView.selectedTabViewItem?.viewController {
            (viewController as? CBPeripheralDelegate)?.peripheralDidUpdateRSSI?(peripheral, error: error)
            
        }
    }

}
