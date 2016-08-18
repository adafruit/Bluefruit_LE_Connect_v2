//
//  PeripheralDetailsViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class PeripheralDetailsViewController: ScrollingTabBarViewController {
    
    var selectedBlePeripheral : BlePeripheral?
    private var isObservingBle = false

    private var emptyViewController : EmptyDetailsViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let splitViewController = self.splitViewController {
            navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem()
            navigationItem.leftItemsSupplementBackButton = true
        }

        emptyViewController = storyboard!.instantiateViewControllerWithIdentifier("EmptyDetailsViewController") as! EmptyDetailsViewController
        
        if selectedBlePeripheral != nil {
            didConnectToPeripheral()
        }
        else {
            
            let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
            if !isFullScreen {
                showEmpty(true)
                self.emptyViewController.setConnecting(false)
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        let isFullScreen =  UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
        guard !isFullScreen || selectedBlePeripheral != nil else {
            DLog("detail: peripheral disconnected by viewWillAppear. Abort")
            return;
        }
        
        // Subscribe to Ble Notifications
        let notificationCenter = NSNotificationCenter.defaultCenter()
        if !isFullScreen {       // For compact mode, the connection is managed by the peripheral list
            notificationCenter.addObserver(self, selector: #selector(willConnectToPeripheral(_:)), name: BleManager.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)
            notificationCenter.addObserver(self, selector: #selector(didConnectToPeripheral(_:)), name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        }
        notificationCenter.addObserver(self, selector: #selector(willDisconnectFromPeripheral(_:)), name: BleManager.BleNotifications.WillDisconnectFromPeripheral.rawValue, object: nil)
        notificationCenter.addObserver(self, selector: #selector(didDisconnectFromPeripheral(_:)), name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
        isObservingBle = true
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        if isObservingBle {
            let notificationCenter = NSNotificationCenter.defaultCenter()
            let isFullScreen =  UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
            if !isFullScreen {
                notificationCenter.removeObserver(self, name: BleManager.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)
                notificationCenter.removeObserver(self, name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
            }
            notificationCenter.removeObserver(self, name: BleManager.BleNotifications.WillDisconnectFromPeripheral.rawValue, object: nil)
            notificationCenter.removeObserver(self, name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
            isObservingBle = false
        }
    }
    
    func willConnectToPeripheral(notification : NSNotification) {
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.showEmpty(true)
            self.emptyViewController.setConnecting(true)
            })
    }

    func didConnectToPeripheral(notification : NSNotification) {
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.didConnectToPeripheral()
            })
    }
    
    func didConnectToPeripheral() {
        guard BleManager.sharedInstance.blePeripheralConnected != nil else {
            DLog("Warning: didConnectToPeripheral with empty blePeripheralConnected");
            return
        }
        
        let blePeripheral = BleManager.sharedInstance.blePeripheralConnected!
        blePeripheral.peripheral.delegate = self
        
        // UI
        self.showEmpty(false)
        
        // UI: Add Info tab
        let infoViewController = self.storyboard!.instantiateViewControllerWithIdentifier("InfoModuleViewController") as! InfoModuleViewController
        
        infoViewController.onServicesDiscovered = { [weak self] in
            // optimization: wait till info discover services to continue, instead of discovering services by myself
            self?.servicesDiscovered()
        }
        
        let localizationManager = LocalizationManager.sharedInstance
        infoViewController.tabBarItem.title = localizationManager.localizedString("info_tab_title")      // Tab title
        infoViewController.tabBarItem.image = UIImage(named: "tab_info_icon")

        setViewControllers([infoViewController], animated: false)
        selectedIndex = 0
    }
    
    func willDisconnectFromPeripheral(notification : NSNotification) {
        DLog("detail: peripheral willDisconnect")
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
            if isFullScreen {       // executed when bluetooth is stopped
                // Back to peripheral list
                if let parentNavigationController = (self.navigationController?.parentViewController as? UINavigationController) {
                    parentNavigationController.popToRootViewControllerAnimated(true)
                }
            }
            else {
                self.showEmpty(true)
                self.emptyViewController.setConnecting(false)
            }
            //self.cancelRssiTimer()
            })
        
        let blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        blePeripheral?.peripheral.delegate = nil
    }
    
    func didDisconnectFromPeripheral(notification : NSNotification) {
        let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            DLog("detail: disconnection")
            
            if !isFullScreen {
                DLog("detail: show empty")
                self.showEmpty(true)
                self.emptyViewController.setConnecting(false)
            }
            
            let localizationManager = LocalizationManager.sharedInstance
            let alertController = UIAlertController(title: nil, message: localizationManager.localizedString("peripherallist_peripheraldisconnected"), preferredStyle: .Alert)
            let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .Default, handler: { (_) -> Void in
                if isFullScreen {
                    // Back to peripheral list
                    if let parentNavigationController = (self.navigationController?.parentViewController as? UINavigationController) {
                        parentNavigationController.popToRootViewControllerAnimated(true)
                    }
                }
            })
            alertController.addAction(okAction)
            self.presentViewController(alertController, animated: true, completion: nil)
            })
    }
    
    func showEmpty(showEmpty : Bool) {
        
        hideTabBar(showEmpty)
        if showEmpty {
            // Show empty view (if needed)
            if viewControllers?.count != 1 || viewControllers?.first != emptyViewController {
                viewControllers = [emptyViewController]
            }
            
            emptyViewController.startAnimating()
        }
        else {
            emptyViewController.stopAnimating()
        }
    }
    
    func servicesDiscovered() {
        
        DLog("PeripheralDetailsViewController servicesDiscovered")
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            
            if let services = blePeripheral.peripheral.services {
                dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
                    
                    let localizationManager = LocalizationManager.sharedInstance
                    
                    // Uart Modules
                    let hasUart = blePeripheral.hasUart()
                    var viewControllersToAppend: [UIViewController] = []
                    if (hasUart) {
                        // Uart Tab
                        if Config.isUartModuleEnabled {
                            let uartViewController = self.storyboard!.instantiateViewControllerWithIdentifier("UartModuleViewController") as! UartModuleViewController
                            uartViewController.tabBarItem.title = localizationManager.localizedString("uart_tab_title")      // Tab title
                            uartViewController.tabBarItem.image = UIImage(named: "tab_uart_icon")
                            
                            viewControllersToAppend.append(uartViewController)
                        }
                        
                        // PinIO
                        if Config.isPinIOModuleEnabled {
                            let pinioViewController = self.storyboard!.instantiateViewControllerWithIdentifier("PinIOModuleViewController") as! PinIOModuleViewController
                            
                            pinioViewController.tabBarItem.title = localizationManager.localizedString("pinio_tab_title")      // Tab title
                            pinioViewController.tabBarItem.image = UIImage(named: "tab_pinio_icon")
                            
                            viewControllersToAppend.append(pinioViewController)
                        }
                        
                        // Controller Tab
                        if Config.isControllerModuleEnabled {
                            let controllerViewController = self.storyboard!.instantiateViewControllerWithIdentifier("ControllerModuleViewController") as! ControllerModuleViewController
                            
                            controllerViewController.tabBarItem.title = localizationManager.localizedString("controller_tab_title")      // Tab title
                            controllerViewController.tabBarItem.image = UIImage(named: "tab_controller_icon")
                            
                            viewControllersToAppend.append(controllerViewController)
                        }
                    }
                    
                    // DFU Tab
                    let kNordicDeviceFirmwareUpdateService = "00001530-1212-EFDE-1523-785FEABCD123"    // DFU service UUID
                    let hasDFU = services.contains({ (service : CBService) -> Bool in
                        service.UUID.isEqual(CBUUID(string: kNordicDeviceFirmwareUpdateService))
                    })
                    
                    if Config.isNeoPixelModuleEnabled && hasUart && hasDFU {        // Neopixel is not available on old boards (those without DFU)
                        // Neopixel Tab
                        let neopixelsViewController = self.storyboard!.instantiateViewControllerWithIdentifier("NeopixelModuleViewController") as! NeopixelModuleViewController
                        
                        neopixelsViewController.tabBarItem.title = localizationManager.localizedString("neopixels_tab_title")      // Tab title
                        neopixelsViewController.tabBarItem.image = UIImage(named: "tab_neopixel_icon")
                        
                        viewControllersToAppend.append(neopixelsViewController)
                    }
                    
                    if (hasDFU) {
                        if Config.isDfuModuleEnabled {
                            let dfuViewController = self.storyboard!.instantiateViewControllerWithIdentifier("DfuModuleViewController") as! DfuModuleViewController
                            dfuViewController.tabBarItem.title = localizationManager.localizedString("dfu_tab_title")      // Tab title
                            dfuViewController.tabBarItem.image = UIImage(named: "tab_dfu_icon")
                            viewControllersToAppend.append(dfuViewController)
                        }
                    }
                    
                    if self.viewControllers != nil {
                        let numViewControllers = self.viewControllers!.count
                        if  numViewControllers > 1 {      // if we already have viewcontrollers, remove all except info (to avoud duplicates)
                            self.viewControllers!.removeRange(Range(1..<numViewControllers))
                        }
                        
                        // Append viewcontrollers (do it here all together to avoid deleting/creating addchilviewcontrollers)
                        if viewControllersToAppend.count > 0 {
                            self.viewControllers!.appendContentsOf(viewControllersToAppend)
                        }
                    }
                    
                    })
            }
        }
    }

    func updateRssiUI() {
        /*
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            let rssi = blePeripheral.rssi
            //DLog("rssi: \(rssi)")
            infoRssiLabel.stringValue = String.format(LocalizationManager.sharedInstance.localizedString("peripheraldetails_rssi_format"), rssi) // "\(rssi) dBm"
            infoRssiImageView.image = signalImageForRssi(rssi)
        }
*/
    }
}

// MARK: - CBPeripheralDelegate
extension PeripheralDetailsViewController : CBPeripheralDelegate {
    
    // Send peripheral delegate methods to tab active (each tab will handle these methods)
    func peripheralDidUpdateName(peripheral: CBPeripheral) {
        
        if let viewControllers = viewControllers {
            for tabViewController in viewControllers {
                (tabViewController as? CBPeripheralDelegate)?.peripheralDidUpdateName?(peripheral)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
        if let viewControllers = viewControllers {
            for tabViewController in viewControllers {
                (tabViewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didModifyServices: invalidatedServices)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        if let viewControllers = viewControllers {
            for var tabViewController in viewControllers {
                if let childViewController = (tabViewController as? UINavigationController)?.viewControllers.last {
                    tabViewController = childViewController
                }
                
                (tabViewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didDiscoverServices: error)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if let viewControllers = viewControllers {
            for var tabViewController in viewControllers {
                if let childViewController = (tabViewController as? UINavigationController)?.viewControllers.last {
                    tabViewController = childViewController
                }
                
                (tabViewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didDiscoverCharacteristicsForService: service, error: error)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if let viewControllers = viewControllers {
            for var tabViewController in viewControllers {
                if let childViewController = (tabViewController as? UINavigationController)?.viewControllers.last {
                    tabViewController = childViewController
                }
                
                (tabViewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didDiscoverDescriptorsForCharacteristic: characteristic, error: error)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {

        if let viewControllers = viewControllers {
            for var tabViewController in viewControllers {
                if let childViewController = (tabViewController as? UINavigationController)?.viewControllers.last {
                    tabViewController = childViewController
                }
                
                (tabViewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didUpdateValueForCharacteristic: characteristic, error: error)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForDescriptor descriptor: CBDescriptor, error: NSError?) {

        
        if let viewControllers = viewControllers {
            for var tabViewController in viewControllers {
                if let childViewController = (tabViewController as? UINavigationController)?.viewControllers.last {
                    tabViewController = childViewController
                }
                
                (tabViewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didUpdateValueForDescriptor: descriptor, error: error)
            }
        }
    }
    
    
    func peripheral(peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: NSError?) {
        
        // Update peripheral rssi
        let identifierString = peripheral.identifier.UUIDString
        if let existingPeripheral = BleManager.sharedInstance.blePeripherals()[identifierString] {
            existingPeripheral.rssi = RSSI.integerValue
            //            DLog("received rssi for \(existingPeripheral.name): \(rssi)")
            
            // Update UI
            dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
                self.updateRssiUI()
                })
            
            if let viewControllers = viewControllers {
                for var tabViewController in viewControllers {
                    if let childViewController = (tabViewController as? UINavigationController)?.viewControllers.last {
                        tabViewController = childViewController
                    }
                    
                    (tabViewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didReadRSSI: RSSI, error: error)
                }
            }
        }
    }
    
}
