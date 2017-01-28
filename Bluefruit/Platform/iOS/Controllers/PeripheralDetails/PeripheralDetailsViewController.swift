//
//  PeripheralDetailsViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit
import CoreBluetooth

class PeripheralDetailsViewController: ScrollingTabBarViewController {
    
    /*
    var selectedBlePeripheral: BlePeripheral?

    private var emptyViewController : EmptyDetailsViewController!
    
    private let firmwareUpdater = FirmwareUpdater()
    private var dfuTabIndex = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let splitViewController = self.splitViewController {
            navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
            navigationItem.leftItemsSupplementBackButton = true
        }

        emptyViewController = storyboard!.instantiateViewController(withIdentifier: "EmptyDetailsViewController") as! EmptyDetailsViewController
        
        if selectedBlePeripheral != nil {
            didConnectToPeripheral()
        }
        else {
            let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
            if !isFullScreen {
                showEmpty(true)
                self.emptyViewController.setConnecting(false)
            }
        }

        let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
        guard !isFullScreen || selectedBlePeripheral != nil else {
            DLog("detail: peripheral disconnected by viewWillAppear. Abort")
            return
        }

        // Subscribe to Ble Notifications
        registerNotifications()

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        // Remove notifications. Note: don't do this on viewwilldissapear because connection should still work when a new viewcontroller is pushed. i.e.: ControlPad)
        registerNotifications(enabled: false)
       
    }
    
    // MARK: - BLE Notifications
    private var willConnectToPeripheralObserver: NSObjectProtocol?
    private var didConnectToPeripheralObserver: NSObjectProtocol?
    private var willDisconnectFromPeripheralObserver: NSObjectProtocol?
    private var didDisconnectFromPeripheralObserver: NSObjectProtocol?
    
    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        
        if enabled {
            willConnectToPeripheralObserver = notificationCenter.addObserver(forName: .willConnectToPeripheral, object: nil, queue: OperationQueue.main, using: willConnectToPeripheral)
            didConnectToPeripheralObserver = notificationCenter.addObserver(forName: .didConnectToPeripheral, object: nil, queue: OperationQueue.main, using: didConnectToPeripheral)
            willDisconnectFromPeripheralObserver = notificationCenter.addObserver(forName: .willDisconnectFromPeripheral, object: nil, queue: OperationQueue.main, using: willDisconnectFromPeripheral)
            didDisconnectFromPeripheralObserver = notificationCenter.addObserver(forName: .didDisconnectFromPeripheral, object: nil, queue: OperationQueue.main, using: didDisconnectFromPeripheral)
        }
        else {
            if let willConnectToPeripheralObserver = willConnectToPeripheralObserver {notificationCenter.removeObserver(willConnectToPeripheralObserver)}
            if let didConnectToPeripheralObserver = didConnectToPeripheralObserver {notificationCenter.removeObserver(didConnectToPeripheralObserver)}
            if let willDisconnectFromPeripheralObserver = willDisconnectFromPeripheralObserver {notificationCenter.removeObserver(willDisconnectFromPeripheralObserver)}
            if let didDisconnectFromPeripheralObserver = didDisconnectFromPeripheralObserver {notificationCenter.removeObserver(didDisconnectFromPeripheralObserver)}
        }
    }
    
    
    func willConnectToPeripheral(notification: Notification) {
        DispatchQueue.main.async  { [unowned self] in
            self.showEmpty(true)
            self.emptyViewController.setConnecting(true)
        }
    }
    
    func didConnectToPeripheral(notification: Notification) {
        DispatchQueue.main.async  { [unowned self] in
            self.didConnectToPeripheral()
        }
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
        
        startUpdatesCheck()
        //setupConnectedPeripheral()
    }
    
    private func setupConnectedPeripheral() {
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
    
    func willDisconnectFromPeripheral(notification: Notification) {
        DLog("detail: peripheral willDisconnect")
        let isFullScreen = UIScreen.mainScreen.traitCollection.horizontalSizeClass == .Compact
        if isFullScreen {       // executed when bluetooth is stopped
            // Back to peripheral list
            if let parentNavigationController = (self.navigationController?.parent as? UINavigationController) {
                parentNavigationController.popToRootViewController(animated: true)
            }
        }
        else {
            self.showEmpty(true)
            self.emptyViewController.setConnecting(false)
        }
        
        let blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        blePeripheral?.peripheral.delegate = nil
    }
    
    func didDisconnectFromPeripheral(notification: Notification) {
        let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
        
        DLog("detail: disconnection")
        
        if !isFullScreen {
            DLog("detail: show empty")
            self.navigationController?.popToRootViewController(animated: false)       // pop any viewcontrollers (like ControlPad)
            self.showEmpty(true)
            self.emptyViewController.setConnecting(false)
        }
        
        // Show disconnected alert (if no previous alert is shown)
        if self.presentedViewController == nil {
            let localizationManager = LocalizationManager.sharedInstance
            let alertController = UIAlertController(title: nil, message: localizationManager.localizedString("peripherallist_peripheraldisconnected"), preferredStyle: .Alert)
            let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .Default, handler: { (_) -> Void in
                let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
                
                if isFullScreen {
                    self.goBackToPeripheralList()
                }
            })
            alertController.addAction(okAction)
            self.presentViewController(alertController, animated: true, completion: nil)
        }
        else {
            DLog("disconnection detected but cannot go to periperalList because there is a presentedViewController on screen")
        }
    }

    private func goBackToPeripheralList() {
        // Back to peripheral list
        if let parentNavigationController = (self.navigationController?.parent as? UINavigationController) {
            parentNavigationController.popToRootViewController(animated: true)
        }
    }
    
    func showEmpty(_ showEmpty : Bool) {
        
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
                DispatchQueue.main.async { [unowned context] in
                    
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
                            self.dfuTabIndex = viewControllersToAppend.count         // don't -1 because index is always present and adds 1 to the index
                        }
                    }
                    
                    // Add tabs
                    if self.viewControllers != nil {
                        let numViewControllers = self.viewControllers!.count
                        if  numViewControllers > 1 {      // if we already have viewcontrollers, remove all except info (to avoud duplicates)
                            self.viewControllers!.removeSubrange(Range(1..<numViewControllers))
                        }
                        
                        // Append viewcontrollers (do it here all together to avoid deleting/creating addchilviewcontrollers)
                        if viewControllersToAppend.count > 0 {
                            self.viewControllers!.append(contentsOf: viewControllersToAppend)
                        }
                    }
                    
                }
            }
        }
    }

    private func startUpdatesCheck() {
        
        // Refresh updates available
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected  {
            let releases = FirmwareUpdater.releasesWithBetaVersions(Preferences.showBetaVersions)
            firmwareUpdater.checkUpdatesForPeripheral(blePeripheral.peripheral, delegate: self, shouldDiscoverServices: true, releases: releases, shouldRecommendBetaReleases: false)
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
    
    private func showUpdateAvailableForRelease(latestRelease: FirmwareInfo!) {
        let alert = UIAlertController(title:"Update available", message: "Software version \(latestRelease.version) is available", preferredStyle: UIAlertControllerStyle.Alert)
        
        alert.addAction(UIAlertAction(title: "Go to updates", style: UIAlertActionStyle.Default, handler: { [unowned self] _ in
            self.selectedIndex = self.dfuTabIndex
        }))
        alert.addAction(UIAlertAction(title: "Ask later", style: UIAlertActionStyle.Default, handler: {  _ in
        }))
        alert.addAction(UIAlertAction(title: "Ignore", style: UIAlertActionStyle.Cancel, handler: {  _ in
            Preferences.softwareUpdateIgnoredVersion = latestRelease.version
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }
}

// MARK: - CBPeripheralDelegate
extension PeripheralDetailsViewController: CBPeripheralDelegate {
    
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
            DispatchQueue.main.async { [unowned context] in
                self.updateRssiUI()
            }
            
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
    */
}

/*
// MARK: - FirmwareUpdaterDelegate
extension PeripheralDetailsViewController: FirmwareUpdaterDelegate {
    func onFirmwareUpdatesAvailable(isUpdateAvailable: Bool, latestRelease: FirmwareInfo!, deviceInfoData: DeviceInfoData?, allReleases: [NSObject : AnyObject]?) {
        DLog("FirmwareUpdaterDelegate isUpdateAvailable: \(isUpdateAvailable)")
        
        DispatchQueue.main.async { [weak self] in
            if let context = self {
                context.setupConnectedPeripheral()
                if isUpdateAvailable {
                    context.showUpdateAvailableForRelease(latestRelease)
                }
            }
        }
    }
    
    func onDfuServiceNotFound() {
        DLog("FirmwareUpdaterDelegate: onDfuServiceNotFound")
        
        dispatch_async(dispatch_get_main_queue(),{ [weak self] in
            self?.setupConnectedPeripheral()
            })
    }
    
    private func onUpdateDialogError(errorMessage:String, exitOnDismiss: Bool = false) {
        DLog("FirmwareUpdaterDelegate: onUpdateDialogError")
    }
}*/
