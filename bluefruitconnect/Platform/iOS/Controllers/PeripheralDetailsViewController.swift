//
//  PeripheralDetailsViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class PeripheralDetailsViewController: UITabBarController {
    
    var selectedBlePeripheral : BlePeripheral?
    private var isObservingBle = false

    private var emptyViewController : EmptyDetailsViewController!
    private var emptyNavigationController : UINavigationController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        emptyViewController = storyboard!.instantiateViewControllerWithIdentifier("EmptyDetailsViewController") as! EmptyDetailsViewController
        emptyNavigationController = UINavigationController(rootViewController: emptyViewController)
        
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
            // Back to peripheral list
    //        self.navigationController?.popToRootViewControllerAnimated(false)
            return;
        }
        
        // Subscribe to Ble Notifications
        let notificationCenter = NSNotificationCenter.defaultCenter()
        if !isFullScreen {       // For compact mode, the connection is managed by the peripheral list
            notificationCenter.addObserver(self, selector: "willConnectToPeripheral:", name: BleManager.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)
            notificationCenter.addObserver(self, selector: "didConnectToPeripheral:", name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        }
        notificationCenter.addObserver(self, selector: "willDisconnectFromPeripheral:", name: BleManager.BleNotifications.WillDisconnectFromPeripheral.rawValue, object: nil)
        notificationCenter.addObserver(self, selector: "didDisconnectFromPeripheral:", name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
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
        
        self.setViewControllers([infoViewController], animated: false)        
        self.selectedIndex = 0
    }
    
    func willDisconnectFromPeripheral(notification : NSNotification) {
        DLog("detail: peripheral willDisconnect")
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.showEmpty(true)
            self.emptyViewController.setConnecting(false)
            //self.cancelRssiTimer()
            })
        
        let blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        blePeripheral?.peripheral.delegate = nil
    }

    func didDisconnectFromPeripheral(notification : NSNotification) {
        let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
//        if isFullScreen {
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
                    // Back to peripheral list
                    self.navigationController?.popToRootViewControllerAnimated(true)
                })
                alertController.addAction(okAction)
                self.presentViewController(alertController, animated: true, completion: nil)
                })
 //       }
    }
    
    func showEmpty(isEmpty : Bool) {
        
        self.tabBar.hidden = isEmpty
        if isEmpty {
            // Show empty view (if needed)
            if self.viewControllers?.count != 1 || self.viewControllers?.first != emptyNavigationController {
                self.viewControllers = [emptyNavigationController]
            }
        }
        else {
            // Remove empty view
            //self.viewControllers?.removeAll()
        }
    }
    
    func servicesDiscovered() {
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            if let services = blePeripheral.peripheral.services {
                dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
                    
                    let localizationManager = LocalizationManager.sharedInstance
                    
                    // Uart Modules
                    let kUartServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"                       // UART service UUID
                    let hasUart = services.contains({ (service : CBService) -> Bool in
                        service.UUID.isEqual(CBUUID(string: kUartServiceUUID))
                    })
                    
                    if (hasUart) {
                        // Uart Tab
                        let uartViewController = self.storyboard!.instantiateViewControllerWithIdentifier("UartModuleViewController") as! UartModuleViewController
                        uartViewController.tabBarItem.title = localizationManager.localizedString("uart_tab_title")      // Tab title
                        uartViewController.tabBarItem.image = UIImage(named: "tab_uart_icon")
                        
                        self.viewControllers?.append(uartViewController)
                        
                        // PinIO
                        let pinioViewController = self.storyboard!.instantiateViewControllerWithIdentifier("PinIOModuleViewController") as! PinIOModuleViewController
                        
                        pinioViewController.tabBarItem.title = localizationManager.localizedString("pinio_tab_title")      // Tab title
                        pinioViewController.tabBarItem.image = UIImage(named: "tab_pinio_icon")
                        
                        self.viewControllers?.append(pinioViewController)

                        
                        // Controller Tab
                        let controllerViewController = self.storyboard!.instantiateViewControllerWithIdentifier("ControllerModuleViewController") as! ControllerModuleViewController
                        
                        controllerViewController.tabBarItem.title = localizationManager.localizedString("controller_tab_title")      // Tab title
                        controllerViewController.tabBarItem.image = UIImage(named: "tab_controller_icon")
                        
                        self.viewControllers?.append(controllerViewController)
                    }

                    // DFU Tab
                    let kNordicDeviceFirmwareUpdateService = "00001530-1212-EFDE-1523-785FEABCD123"    // DFU service UUID
                    let hasDFU = services.contains({ (service : CBService) -> Bool in
                        service.UUID.isEqual(CBUUID(string: kNordicDeviceFirmwareUpdateService))
                    })
                    
                    if (hasDFU) {
                        
                        let dfuViewController = self.storyboard!.instantiateViewControllerWithIdentifier("DfuModuleViewController") as! DfuModuleViewController
                        dfuViewController.tabBarItem.title = localizationManager.localizedString("dfu_tab_title")      // Tab title
                        dfuViewController.tabBarItem.image = UIImage(named: "tab_dfu_icon")
                        self.viewControllers?.append(dfuViewController)

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
        
        /*
        if let characteristicDataValue = characteristic.value {
        if let utf8Value = NSString(data:characteristicDataValue, encoding: NSUTF8StringEncoding) as String? {
        DLog("received: \(utf8Value)")
        }
        }
        */
        
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
        if var tabViewController = selectedViewController {
            if let childViewController = (tabViewController as? UINavigationController)?.viewControllers.last {
                tabViewController = childViewController
            }
            
            (tabViewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didUpdateValueForDescriptor: descriptor, error: error)
        }
    }
    
    
    func peripheral(peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: NSError?) {
    
        // Update peripheral rssi
        let identifierString = peripheral.identifier.UUIDString
        if let existingPeripheral = BleManager.sharedInstance.blePeripheralsFound[identifierString] {
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
