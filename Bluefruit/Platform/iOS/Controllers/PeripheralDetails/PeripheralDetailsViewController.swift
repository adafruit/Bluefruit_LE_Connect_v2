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
    
    // Parameters
    enum ModuleController {
        case info
        case update
        case multiUart
    }
    
    weak var blePeripheral: BlePeripheral?
    var startingController = ModuleController.info
    
    // Data
    private var emptyViewController: EmptyDetailsViewController!
    private var dfuTabIndex = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // UI
        if let splitViewController = self.splitViewController {
            navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
            navigationItem.leftItemsSupplementBackButton = true
        }

        emptyViewController = storyboard!.instantiateViewController(withIdentifier: "EmptyDetailsViewController") as! EmptyDetailsViewController

        // Init for iPhone
        if let _ = blePeripheral {
            setupConnectedPeripheral()
        }
        else if startingController == .multiUart {
            setupMultiUart()
        }
        else {
            let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
            if !isFullScreen {
                showEmpty(true)
                self.emptyViewController.setConnecting(false)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Subscribe to Ble Notifications
        registerNotifications(enabled: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        registerNotifications(enabled: false)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // MARK: - BLE Notifications
    private var willConnectToPeripheralObserver: NSObjectProtocol?
    private var willDisconnectFromPeripheralObserver: NSObjectProtocol?
    private var didDisconnectFromPeripheralObserver: NSObjectProtocol?
    
    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        
        if enabled {
            willConnectToPeripheralObserver = notificationCenter.addObserver(forName: .willConnectToPeripheral, object: nil, queue: OperationQueue.main, using: willConnectToPeripheral)
            willDisconnectFromPeripheralObserver = notificationCenter.addObserver(forName: .willDisconnectFromPeripheral, object: nil, queue: OperationQueue.main, using: willDisconnectFromPeripheral)
            didDisconnectFromPeripheralObserver = notificationCenter.addObserver(forName: .didDisconnectFromPeripheral, object: nil, queue: OperationQueue.main, using: didDisconnectFromPeripheral)
        }
        else {
            if let willConnectToPeripheralObserver = willConnectToPeripheralObserver {notificationCenter.removeObserver(willConnectToPeripheralObserver)}
            if let willDisconnectFromPeripheralObserver = willDisconnectFromPeripheralObserver {notificationCenter.removeObserver(willDisconnectFromPeripheralObserver)}
            if let didDisconnectFromPeripheralObserver = didDisconnectFromPeripheralObserver {notificationCenter.removeObserver(didDisconnectFromPeripheralObserver)}
        }
    }
    
    fileprivate func willConnectToPeripheral(notification: Notification) {
        
        if isInMultiUartMode() {
            
        }
        else {
            showEmpty(true)
            emptyViewController.setConnecting(true)
        }
    }

    
    fileprivate func willDisconnectFromPeripheral(notification: Notification) {
        DLog("detail: peripheral willDisconnect")
        let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
        if isFullScreen {       // executed when bluetooth is stopped
            
            // Back to peripheral list
            if let parentNavigationController = (self.navigationController?.parent as? UINavigationController) {
                    parentNavigationController.popToRootViewController(animated: true)
            }
        }
        else {
            if startingController != .multiUart {
                blePeripheral = nil
            }
            showEmpty(true)
            emptyViewController.setConnecting(false)
        }
    }
    
    fileprivate func didDisconnectFromPeripheral(notification: Notification) {
        let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
        let isLastConnectedPeripheral = BleManager.sharedInstance.connectedPeripherals().count == 0
        
        DLog("detail: disconnection")
        
        if !isFullScreen && isLastConnectedPeripheral {
            DLog("detail: show empty")
            navigationController?.popToRootViewController(animated: false)       // pop any viewcontrollers (like ControlPad)
            showEmpty(true)
            emptyViewController.setConnecting(false)
        }
        
        // Show disconnected alert (if no previous alert is shown)
        if self.presentedViewController == nil {
            let localizationManager = LocalizationManager.sharedInstance
            let alertController = UIAlertController(title: nil, message: localizationManager.localizedString("peripherallist_peripheraldisconnected"), preferredStyle: .alert)
            let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler: { (_) -> Void in
                let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
                
                if isFullScreen && isLastConnectedPeripheral {
                    self.goBackToPeripheralList()
                }
            })
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        }
        else {
            DLog("disconnection detected but cannot go to periperalList because there is a presentedViewController on screen")
        }
    }
    
    // MARK: - MultiUart Mode
    fileprivate func isInMultiUartMode() -> Bool {
        return blePeripheral == nil && BleManager.sharedInstance.connectedPeripherals().count > 0
    }
    
    // MARK: - UI
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
    
    fileprivate func setupConnectedPeripheral() {
        // Note: Services should have been discovered previously
        guard let blePeripheral = blePeripheral else { return }
        
        var viewControllers = [PeripheralModeViewController]()
        
        // UI: Add Info tab
        let infoViewController = self.storyboard!.instantiateViewController(withIdentifier: "InfoModeViewController") as! InfoModeViewController
        infoViewController.blePeripheral = blePeripheral
        
        let localizationManager = LocalizationManager.sharedInstance
        infoViewController.tabBarItem.title = localizationManager.localizedString("info_tab_title")      // Tab title
        infoViewController.tabBarItem.image = UIImage(named: "tab_info_icon")
        viewControllers.append(infoViewController)
        
        // Uart Modules
        let hasUart = blePeripheral.hasUart()
        if hasUart {
            // Uart Tab
            let uartViewController = self.storyboard!.instantiateViewController(withIdentifier: "UartModeViewController") as! UartModeViewController
            uartViewController.blePeripheral = blePeripheral
            uartViewController.tabBarItem.title = localizationManager.localizedString("uart_tab_title")      // Tab title
            uartViewController.tabBarItem.image = UIImage(named: "tab_uart_icon")
            viewControllers.append(uartViewController)

            // Plotter Tab
            let plotterViewController = self.storyboard!.instantiateViewController(withIdentifier: "PlotterModeViewController") as! PlotterModeViewController
            plotterViewController.blePeripheral = blePeripheral
            plotterViewController.tabBarItem.title = localizationManager.localizedString("plotter_tab_title")      // Tab title
            plotterViewController.tabBarItem.image = UIImage(named: "tab_plotter_icon")
            viewControllers.append(plotterViewController)
            
            // PinIO
            let pinioViewController = self.storyboard!.instantiateViewController(withIdentifier: "PinIOModeViewController") as! PinIOModeViewController
            pinioViewController.blePeripheral = blePeripheral
            pinioViewController.tabBarItem.title = localizationManager.localizedString("pinio_tab_title")      // Tab title
            pinioViewController.tabBarItem.image = UIImage(named: "tab_pinio_icon")
            viewControllers.append(pinioViewController)
            
            // Controller Tab
            let controllerViewController = self.storyboard!.instantiateViewController(withIdentifier: "ControllerModeViewController") as! ControllerModeViewController
            controllerViewController.blePeripheral = blePeripheral
            controllerViewController.tabBarItem.title = localizationManager.localizedString("controller_tab_title")      // Tab title
            controllerViewController.tabBarItem.image = UIImage(named: "tab_controller_icon")
            viewControllers.append(controllerViewController)
        }
        
        let hasDFU = blePeripheral.peripheral.services?.first(where: {$0.uuid == FirmwareUpdater.kDfuServiceUUID}) != nil
        
        // Neopixel Tab
        if hasUart && hasDFU {
            let neopixelsViewController = self.storyboard!.instantiateViewController(withIdentifier: "NeopixelModeViewController") as! NeopixelModeViewController
            neopixelsViewController.blePeripheral = blePeripheral
            neopixelsViewController.tabBarItem.title = localizationManager.localizedString("neopixels_tab_title")      // Tab title
            neopixelsViewController.tabBarItem.image = UIImage(named: "tab_neopixel_icon")
            viewControllers.append(neopixelsViewController)
        }
        
        // DFU Tab
       if hasDFU {
            let dfuViewController = self.storyboard!.instantiateViewController(withIdentifier: "DfuModeViewController") as! DfuModeViewController
            dfuViewController.blePeripheral = blePeripheral
            dfuViewController.tabBarItem.title = localizationManager.localizedString("dfu_tab_title")      // Tab title
            dfuViewController.tabBarItem.image = UIImage(named: "tab_dfu_icon")
            viewControllers.append(dfuViewController)
            self.dfuTabIndex = viewControllers.count-1
        }
        
        setViewControllers(viewControllers, animated: false)
        selectedIndex = 0
    }
    
    fileprivate func setupMultiUart() {
        let localizationManager = LocalizationManager.sharedInstance

//        hideTabBar(false)
        // Uart Tab
        let uartViewController = self.storyboard!.instantiateViewController(withIdentifier: "UartModeViewController") as! UartModeViewController
        uartViewController.blePeripheral = nil
        uartViewController.tabBarItem.title = localizationManager.localizedString("uart_tab_title")      // Tab title
        uartViewController.tabBarItem.image = UIImage(named: "tab_uart_icon")

        // Plotter Tab
        let plotterViewController = self.storyboard!.instantiateViewController(withIdentifier: "PlotterModeViewController") as! PlotterModeViewController
        plotterViewController.blePeripheral = nil
        plotterViewController.tabBarItem.title = localizationManager.localizedString("plotter_tab_title")      // Tab title
        plotterViewController.tabBarItem.image = UIImage(named: "tab_plotter_icon")
        
        setViewControllers([uartViewController, plotterViewController], animated: false)
        selectedIndex = 0
        
    }

    fileprivate func updateRssiUI() {
        /*
        if let rssi = peripheral?.rssi {
            //DLog("rssi: \(rssi)")
            infoRssiLabel.stringValue = String.format(LocalizationManager.sharedInstance.localizedString("peripheraldetails_rssi_format"), rssi) // "\(rssi) dBm"
            infoRssiImageView.image = signalImageForRssi(rssi)
        }*/
    }

}

