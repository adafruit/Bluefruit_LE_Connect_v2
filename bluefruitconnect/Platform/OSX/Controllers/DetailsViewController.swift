//
//  DetailsViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 25/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa
import CoreBluetooth

// Protocol that should implement viewControllers used as tabs
protocol DetailTab {
    func tabWillAppear()
    func tabReset()
}

class DetailsViewController: NSViewController {

    // Configuration
    static private let kNeopixelsEnabled = false
    
    // UI
    @IBOutlet weak var emptyView: NSTabView!
    @IBOutlet weak var emptyLabel: NSTextField!
    
    @IBOutlet weak var modeTabView: NSTabView!

    @IBOutlet weak var infoView: NSView!
    @IBOutlet weak var infoNameLabel: NSTextField!
    @IBOutlet weak var infoRssiImageView: NSImageView!
    @IBOutlet weak var infoRssiLabel: NSTextField!
    @IBOutlet weak var infoUartImageView: NSImageView!
    @IBOutlet weak var infoUartLabel: NSTextField!
    @IBOutlet weak var infoDsiImageView: NSImageView!
    @IBOutlet weak var infoDsiLabel: NSTextField!
    @IBOutlet weak var infoDfuImageView: NSImageView!
    @IBOutlet weak var infoDfuLabel: NSTextField!
    
    // Rssi
    private static let kRssiUpdateInterval = 2.0       // in seconds
    private var rssiTimer : MSWeakTimer?
    
    //
    override func viewDidLoad() {
        super.viewDidLoad()
        
        infoView.wantsLayer = true
        infoView.layer?.borderWidth = 1
        infoView.layer?.borderColor = NSColor.lightGrayColor().CGColor
        
        showEmpty(true)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // Subscribe to Ble Notifications
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "willConnectToPeripheral:", name: BleManager.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)
        notificationCenter.addObserver(self, selector: "didConnectToPeripheral:", name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        notificationCenter.addObserver(self, selector: "willDisconnectFromPeripheral:", name: BleManager.BleNotifications.WillDisconnectFromPeripheral.rawValue, object: nil)
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: BleManager.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)
        notificationCenter.removeObserver(self, name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        notificationCenter.removeObserver(self, name: BleManager.BleNotifications.WillDisconnectFromPeripheral.rawValue, object: nil)
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

        let blePeripheral = BleManager.sharedInstance.blePeripheralConnected!
        blePeripheral.peripheral.delegate = self

        // UI
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.showEmpty(false)
            
            for tabViewItem in self.modeTabView.tabViewItems {
                self.modeTabView.removeTabViewItem(tabViewItem)
            }
            
            // UI: Info
            self.infoNameLabel.stringValue = blePeripheral.name
            self.updateRssiUI()
            
            self.cancelRssiTimer()
            let privateQueue = dispatch_queue_create("private_queue", DISPATCH_QUEUE_CONCURRENT);
            self.rssiTimer = MSWeakTimer.scheduledTimerWithTimeInterval(DetailsViewController.kRssiUpdateInterval, target: self, selector: "requestUpdateRssi", userInfo: nil, repeats: true, dispatchQueue: privateQueue)
            
            // UI: Add Info tab
            let infoViewController = self.storyboard?.instantiateControllerWithIdentifier("InfoViewController") as! InfoViewController
            
            infoViewController.onServicesDiscovered = { [weak self] in
                // optimization: wait till info discover services to continue, instead of discovering services by myself
                self?.servicesDiscovered()
            }

            let infoTabViewItem = NSTabViewItem(viewController: infoViewController)
            self.modeTabView.addTabViewItem(infoTabViewItem)
            infoViewController.tabReset()
            
            self.modeTabView.selectFirstTabViewItem(nil)
        })
    }
    
    func requestUpdateRssi() {
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            //DLog("request rssi for \(blePeripheral.name)")
            blePeripheral.peripheral.readRSSI()
        }
    }
    
    func willDisconnectFromPeripheral(notification : NSNotification) {
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.showEmpty(true)
            self.cancelRssiTimer()
            
            for tabViewItem in self.modeTabView.tabViewItems {
                self.modeTabView.removeTabViewItem(tabViewItem)
            }
            })
        
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
                
                dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
                    
                    var currentTabIndex = 1     // 0 is Info
                    
                    // Uart Tab
                    let kUartServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"                       // UART service UUID
                    let hasUart = services.contains({ (service : CBService) -> Bool in
                        service.UUID.isEqual(CBUUID(string: kUartServiceUUID))
                    })
                    
                    self.infoUartImageView.image = NSImage(named: hasUart ?"NSStatusAvailable":"NSStatusNone")
                    //infoUartLabel.toolTip = "UART Service \(hasUart ? "" : "not ")available"
                    
                    if (hasUart) {
                        var uartTabIndex = self.indexForTabWithClass("UartViewController")
                        if uartTabIndex < 0 {
                            // Add Uart tab
                            let uartViewController = self.storyboard?.instantiateControllerWithIdentifier("UartViewController") as! UartViewController
                            let uartTabViewItem = NSTabViewItem(viewController: uartViewController)
                            uartTabIndex = currentTabIndex++
                            self.modeTabView.insertTabViewItem(uartTabViewItem, atIndex: uartTabIndex)
                        }
                        
                        let uartViewController = self.modeTabView.tabViewItems[uartTabIndex].viewController as! UartViewController
                        uartViewController.tabReset()
                    }
                    
                    // DFU Tab
                    let kNordicDeviceFirmwareUpdateService = "00001530-1212-EFDE-1523-785FEABCD123"    // DFU service UUID
                    let hasDFU = services.contains({ (service : CBService) -> Bool in
                        service.UUID.isEqual(CBUUID(string: kNordicDeviceFirmwareUpdateService))
                    })
                    
                    self.infoDfuImageView.image = NSImage(named: hasDFU ?"NSStatusAvailable":"NSStatusNone")
                    
                    if (hasDFU) {
                        var dfuTabIndex = self.indexForTabWithClass("FirmwareUpdateViewController")
                        if dfuTabIndex < 0 {
                            // Add Firmware Update tab
                            let updateViewController = self.storyboard?.instantiateControllerWithIdentifier("FirmwareUpdateViewController") as! FirmwareUpdateViewController
                            let updateTabViewItem = NSTabViewItem(viewController: updateViewController)
                            dfuTabIndex = currentTabIndex++
                            self.modeTabView.insertTabViewItem(updateTabViewItem, atIndex: dfuTabIndex)
                        }
                        
                        let updateViewController = self.modeTabView.tabViewItems[dfuTabIndex].viewController as! FirmwareUpdateViewController
                        updateViewController.tabReset()

                    }
                    
                    // DIS Indicator
                    let kDisServiceUUID = "180A"    // DIS service UUID
                    let hasDIS = services.contains({ (service : CBService) -> Bool in
                        service.UUID.isEqual(CBUUID(string: kDisServiceUUID))
                    })
                    self.infoDsiImageView.image = NSImage(named: hasDIS ?"NSStatusAvailable":"NSStatusNone")
                    
                    // Neopixel Tab
                    if (DetailsViewController.kNeopixelsEnabled && hasUart) {
                        var neopixelTabIndex = self.indexForTabWithClass("NeopixelViewController")
                        if neopixelTabIndex < 0 {
                            // Add Neopixel tab
                            let neopixelViewController = self.storyboard?.instantiateControllerWithIdentifier("NeopixelViewController") as! NeopixelViewController
                            let neopixelTabViewItem = NSTabViewItem(viewController: neopixelViewController)
                            neopixelTabIndex = currentTabIndex++
                            self.modeTabView.insertTabViewItem(neopixelTabViewItem, atIndex: neopixelTabIndex)
                        }
                        
                        let neopixelViewController = self.modeTabView.tabViewItems[neopixelTabIndex].viewController as! NeopixelViewController
                        neopixelViewController.tabReset()
                    }
                    })
            }
        }
    }
    
    private func indexForTabWithClass(tabClassName : String) -> Int {
        var index = -1
        for i in 0..<modeTabView.tabViewItems.count {
            let className = String(modeTabView.tabViewItems[i].viewController!.dynamicType)
            if className == tabClassName {
                index = i
                break
            }
        }
        
        return index
    }
    
    func updateRssiUI() {
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            let rssi = blePeripheral.rssi
            //DLog("rssi: \(rssi)")
            infoRssiLabel.stringValue = "\(rssi) dBm"
            infoRssiImageView.image = signalImageForRssi(rssi)
        }
    }
}

// MARK: - CBPeripheralDelegate
extension DetailsViewController : CBPeripheralDelegate {
    
    // Send peripheral delegate methods to tab active (each tab will handle these methods)
    func peripheralDidUpdateName(peripheral: CBPeripheral) {
        for tabViewItem in modeTabView.tabViewItems {
            (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheralDidUpdateName?(peripheral)
        }
    }
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        for tabViewItem in modeTabView.tabViewItems {
            (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didModifyServices: invalidatedServices)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        for tabViewItem in modeTabView.tabViewItems {

                (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didDiscoverServices: error)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        
        for tabViewItem in modeTabView.tabViewItems {
            (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didDiscoverCharacteristicsForService: service, error: error)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        for tabViewItem in modeTabView.tabViewItems {
            (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didDiscoverDescriptorsForCharacteristic: characteristic, error: error)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        /*
        if let characteristicDataValue = characteristic.value {
            if let utf8Value = NSString(data:characteristicDataValue, encoding: NSUTF8StringEncoding) as String? {
                DLog("received: \(utf8Value)")
            }
        }
*/

        for tabViewItem in modeTabView.tabViewItems {
            (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didUpdateValueForCharacteristic: characteristic, error: error)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        if let viewController = modeTabView.selectedTabViewItem?.viewController {
            (viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didUpdateValueForDescriptor: descriptor, error: error)
        }
    }
    
    func peripheralDidUpdateRSSI(peripheral: CBPeripheral, error: NSError?) {

        // Update peripheral rssi
        let identifierString = peripheral.identifier.UUIDString
        if let existingPeripheral = BleManager.sharedInstance.blePeripheralsFound[identifierString], rssi =  peripheral.RSSI?.integerValue {
            existingPeripheral.rssi = rssi
//            DLog("received rssi for \(existingPeripheral.name): \(rssi)")
            
            // Update UI
            dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
                self.updateRssiUI()
                })
            
            for tabViewItem in modeTabView.tabViewItems {
                (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheralDidUpdateRSSI?(peripheral, error: error)
            }
        }
    }
}

// MARK: - NSTabViewDelegate
extension DetailsViewController: NSTabViewDelegate {
    
    func tabView(tabView: NSTabView, didSelectTabViewItem tabViewItem: NSTabViewItem?) {
        
        let detailTabViewController = tabViewItem?.viewController as! DetailTab     // Note: all tab viewcontrollers should conform to protocol DetailTab
        detailTabViewController.tabWillAppear()
        
    }
}
