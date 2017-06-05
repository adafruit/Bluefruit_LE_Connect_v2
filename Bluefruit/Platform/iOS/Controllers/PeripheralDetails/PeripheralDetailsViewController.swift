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

    var startingController = ModuleController.info
    weak var blePeripheral: BlePeripheral?

    // Data
    private var emptyViewController: EmptyDetailsViewController?
    private var dfuTabIndex = -1

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // UI
        if let splitViewController = self.splitViewController {
            navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
            navigationItem.leftItemsSupplementBackButton = true
        }

        emptyViewController = storyboard?.instantiateViewController(withIdentifier: "EmptyDetailsViewController") as? EmptyDetailsViewController

        // Init for iPhone
        if blePeripheral != nil {
            setupConnectedPeripheral()
        } else if startingController == .multiUart {
            setupMultiUart()
        } else {
            let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
            if !isFullScreen {
                showEmpty(true)
                setConnecting(false)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Notifications
        registerNotifications(enabled: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Notifications
        registerNotifications(enabled: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    deinit {
        DLog("PeripheralDetails deinit")

    }

    // MARK: - BLE Notifications
    private weak var willConnectToPeripheralObserver: NSObjectProtocol?
    private weak var willDisconnectFromPeripheralObserver: NSObjectProtocol?

    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default

        if enabled {
            willConnectToPeripheralObserver = notificationCenter.addObserver(forName: .willConnectToPeripheral, object: nil, queue: .main, using: willConnectToPeripheral)
            willDisconnectFromPeripheralObserver = notificationCenter.addObserver(forName: .willDisconnectFromPeripheral, object: nil, queue: .main, using: willDisconnectFromPeripheral)

        } else {
            if let willConnectToPeripheralObserver = willConnectToPeripheralObserver {notificationCenter.removeObserver(willConnectToPeripheralObserver)}
            if let willDisconnectFromPeripheralObserver = willDisconnectFromPeripheralObserver {notificationCenter.removeObserver(willDisconnectFromPeripheralObserver)}
        }
    }

    fileprivate func willConnectToPeripheral(notification: Notification) {
        if isInMultiUartMode() {
        } else {
            showEmpty(true)
            setConnecting(true)
        }
    }

    fileprivate func willDisconnectFromPeripheral(notification: Notification) {
        DLog("detail: peripheral willDisconnect")
        let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
        if isFullScreen {       // executed when bluetooth is stopped

            // Back to peripheral list
            goBackToPeripheralList()
        } else {
            if startingController != .multiUart {
                blePeripheral = nil
            }
            showEmpty(true)
            setConnecting(false)
        }
    }

    func setConnecting(_ isConnecting: Bool) {
        emptyViewController?.setConnecting(isConnecting)
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

    func showEmpty(_ showEmpty: Bool) {

        hideTabBar(showEmpty)
        if showEmpty {
            // Show empty view (if needed)
            if let emptyViewController = emptyViewController, viewControllers?.count != 1 || viewControllers?.first != emptyViewController {
                viewControllers = [emptyViewController]
            }

            emptyViewController?.startAnimating()
        } else {
            emptyViewController?.stopAnimating()
        }
    }

    fileprivate func setupConnectedPeripheral() {
        // Note: Services should have been discovered previously
        guard let blePeripheral = blePeripheral else { return }

        var viewControllers = [PeripheralModeViewController]()
        let localizationManager = LocalizationManager.sharedInstance

        // UI: Add Info tab
        if let infoViewController = self.storyboard?.instantiateViewController(withIdentifier: "InfoModeViewController") as? InfoModeViewController {
            infoViewController.blePeripheral = blePeripheral
            infoViewController.tabBarItem.title = localizationManager.localizedString("info_tab_title")      // Tab title
            infoViewController.tabBarItem.image = UIImage(named: "tab_info_icon")
            viewControllers.append(infoViewController)
        }

        // Uart Modules
        let hasUart = blePeripheral.hasUart()
        let hasDFU = blePeripheral.peripheral.services?.first(where: {$0.uuid == FirmwareUpdater.kDfuServiceUUID}) != nil
        if hasUart {
            // Uart Tab
            if let uartViewController = self.storyboard?.instantiateViewController(withIdentifier: "UartModeViewController") as? UartModeViewController {
                uartViewController.blePeripheral = blePeripheral
                uartViewController.tabBarItem.title = localizationManager.localizedString("uart_tab_title")      // Tab title
                uartViewController.tabBarItem.image = UIImage(named: "tab_uart_icon")
                viewControllers.append(uartViewController)
            }

            // Plotter Tab
            if let plotterViewController = self.storyboard?.instantiateViewController(withIdentifier: "PlotterModeViewController") as? PlotterModeViewController {
                plotterViewController.blePeripheral = blePeripheral
                plotterViewController.tabBarItem.title = localizationManager.localizedString("plotter_tab_title")      // Tab title
                plotterViewController.tabBarItem.image = UIImage(named: "tab_plotter_icon")
                viewControllers.append(plotterViewController)
            }

            // PinIO
            if let pinioViewController = self.storyboard?.instantiateViewController(withIdentifier: "PinIOModeViewController") as? PinIOModeViewController {
                pinioViewController.blePeripheral = blePeripheral
                pinioViewController.tabBarItem.title = localizationManager.localizedString("pinio_tab_title")      // Tab title
                pinioViewController.tabBarItem.image = UIImage(named: "tab_pinio_icon")
                viewControllers.append(pinioViewController)
            }

            // Controller Tab
            if let controllerViewController = self.storyboard?.instantiateViewController(withIdentifier: "ControllerModeViewController") as? ControllerModeViewController {
                controllerViewController.blePeripheral = blePeripheral
                controllerViewController.tabBarItem.title = localizationManager.localizedString("controller_tab_title")      // Tab title
                controllerViewController.tabBarItem.image = UIImage(named: "tab_controller_icon")
                viewControllers.append(controllerViewController)
            }

            // Neopixel Tab
            if hasDFU {
                if let neopixelsViewController = self.storyboard?.instantiateViewController(withIdentifier: "NeopixelModeViewController") as? NeopixelModeViewController {
                    neopixelsViewController.blePeripheral = blePeripheral
                    neopixelsViewController.tabBarItem.title = localizationManager.localizedString("neopixels_tab_title")      // Tab title
                    neopixelsViewController.tabBarItem.image = UIImage(named: "tab_neopixel_icon")
                    viewControllers.append(neopixelsViewController)
                }
            }

            // Calibration Tab
            if let calibrationViewController = self.storyboard?.instantiateViewController(withIdentifier: "CalibrationMenuViewController") as? CalibrationMenuViewController {
                calibrationViewController.blePeripheral = blePeripheral
                calibrationViewController.tabBarItem.title = localizationManager.localizedString("calibration_tab_title")      // Tab title
                calibrationViewController.tabBarItem.image = UIImage(named: "tab_calibration_icon")
                viewControllers.append(calibrationViewController)
            }
        }

        // DFU Tab
        if hasDFU {
            if let dfuViewController = self.storyboard!.instantiateViewController(withIdentifier: "DfuModeViewController") as? DfuModeViewController {
                dfuViewController.blePeripheral = blePeripheral
                dfuViewController.tabBarItem.title = localizationManager.localizedString("dfu_tab_title")      // Tab title
                dfuViewController.tabBarItem.image = UIImage(named: "tab_dfu_icon")
                viewControllers.append(dfuViewController)
                self.dfuTabIndex = viewControllers.count-1
            }
        }

        setViewControllers(viewControllers, animated: false)
        selectedIndex = startingController == .update ? dfuTabIndex : 0
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
