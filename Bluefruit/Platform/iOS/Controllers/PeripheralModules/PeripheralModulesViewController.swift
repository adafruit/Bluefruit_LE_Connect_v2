//
//  PeripheralModulesViewController.swift
//  Bluefruit
//
//  Created by Antonio García on 05/06/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit
import MSWeakTimer

class PeripheralModulesViewController: UIViewController {
    // Config
    fileprivate static let kRssiRefreshInterval: TimeInterval = 0.3
    
    // UI
    @IBOutlet weak var baseTableView: UITableView!

    // Parameters
    enum ModuleController {
        case info
        case multiUart
    }

    var startingController = ModuleController.info
    weak var blePeripheral: BlePeripheral?

    // Data
    enum Modules: Int {
        case info = 0
        case uart
        case plotter
        case pinIO
        case controller
        case neopixel
        case calibration
        case dfu
    }

    private var emptyViewController: EmptyDetailsViewController?
    fileprivate var hasUart = false
    fileprivate var hasDFU = false
    fileprivate var hasBattery = false
    fileprivate var rssiRefreshTimer: MSWeakTimer?
    
    fileprivate var batteryLevel: Int?
    
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
            //setupMultiUart()
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
        
        // Schedule Rssi timer
        rssiRefreshTimer = MSWeakTimer.scheduledTimer(withTimeInterval: PeripheralModulesViewController.kRssiRefreshInterval, target: self, selector: #selector(rssiRefreshFired), userInfo: nil, repeats: true, dispatchQueue: DispatchQueue.global(qos: .background))
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Notifications
        registerNotifications(enabled: false)
        
        // Disable Rssi timer
        rssiRefreshTimer?.invalidate()
        rssiRefreshTimer = nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    deinit {
        DLog("PeripheralModulesViewController deinit")
    }

    
    // MARK: - BLE Notifications
    private weak var willConnectToPeripheralObserver: NSObjectProtocol?
    private weak var willDisconnectFromPeripheralObserver: NSObjectProtocol?
    private weak var peripheralDidUpdateRssiObserver: NSObjectProtocol?
    private weak var didDisconnectFromPeripheralObserver: NSObjectProtocol?
    
    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default

        if enabled {
            willConnectToPeripheralObserver = notificationCenter.addObserver(forName: .willConnectToPeripheral, object: nil, queue: .main, using: willConnectToPeripheral)
            willDisconnectFromPeripheralObserver = notificationCenter.addObserver(forName: .willDisconnectFromPeripheral, object: nil, queue: .main, using: willDisconnectFromPeripheral)
            peripheralDidUpdateRssiObserver = notificationCenter.addObserver(forName: .peripheralDidUpdateRssi, object: nil, queue: .main, using: peripheralDidUpdateRssi)
            didDisconnectFromPeripheralObserver = notificationCenter.addObserver(forName: .didDisconnectFromPeripheral, object: nil, queue: .main, using: didDisconnectFromPeripheral)
            
        } else {
            if let willConnectToPeripheralObserver = willConnectToPeripheralObserver {notificationCenter.removeObserver(willConnectToPeripheralObserver)}
            if let willDisconnectFromPeripheralObserver = willDisconnectFromPeripheralObserver {notificationCenter.removeObserver(willDisconnectFromPeripheralObserver)}
            if let peripheralDidUpdateRssiObserver = peripheralDidUpdateRssiObserver {notificationCenter.removeObserver(peripheralDidUpdateRssiObserver)}
            if let didDisconnectFromPeripheralObserver = didDisconnectFromPeripheralObserver {notificationCenter.removeObserver(didDisconnectFromPeripheralObserver)}
        }
    }

    fileprivate func willConnectToPeripheral(notification: Notification) {
        guard let identifier = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID, identifier == blePeripheral?.identifier else { return }
        
        if isInMultiUartMode() {
        } else {
            showEmpty(true)
            setConnecting(true)
        }
    }

    fileprivate func willDisconnectFromPeripheral(notification: Notification) {
        guard let identifier = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID, identifier == blePeripheral?.identifier else { return }

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
    
    
    fileprivate func peripheralDidUpdateRssi(notification: Notification) {
        guard let identifier = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID, identifier == blePeripheral?.identifier else { return }

        // Update section
        baseTableView.reloadSections([TableSection.device.rawValue], with: .none)

    }
    
    private func didDisconnectFromPeripheral(notification: Notification) {
        guard let identifier = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID, identifier == blePeripheral?.identifier else { return }

        // Disable Rssi timer
        rssiRefreshTimer?.invalidate()
        rssiRefreshTimer = nil
    }

    func setConnecting(_ isConnecting: Bool) {
        emptyViewController?.setConnecting(isConnecting)
    }

    // MARK: - MultiUart Mode
    fileprivate func isInMultiUartMode() -> Bool {
        return blePeripheral == nil && BleManager.sharedInstance.connectedPeripherals().count > 0
    }

    // MARK: - UI
    @objc private func rssiRefreshFired() {
        blePeripheral?.readRssi()
    }
    
   
    
    private func goBackToPeripheralList() {
        // Back to peripheral list
        if Config.useTabController {
            if let parentNavigationController = (self.navigationController?.parent as? UINavigationController) {
                parentNavigationController.popToRootViewController(animated: true)
            }
        } else {
            navigationController?.popToRootViewController(animated: true)
        }
    }

    func showEmpty(_ showEmpty: Bool) {

        if showEmpty {
            // Show empty view (if needed)
            if let viewController = emptyViewController, viewController.view.superview == nil {

                if let containerView = self.view, let subview = viewController.view {
                    subview.translatesAutoresizingMaskIntoConstraints = false
                    self.addChildViewController(viewController)

                    viewController.beginAppearanceTransition(true, animated: true)
                    containerView.addSubview(subview)
                    viewController.endAppearanceTransition()

                    let dictionaryOfVariableBindings = ["subview": subview]
                    containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[subview]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: dictionaryOfVariableBindings))
                    containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[subview]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: dictionaryOfVariableBindings))

                    viewController.didMove(toParentViewController: self)
                }
            }

            emptyViewController?.startAnimating()
        } else {
            emptyViewController?.stopAnimating()

            if let viewController = emptyViewController {
                viewController.willMove(toParentViewController: nil)
                viewController.view.removeFromSuperview()
                viewController.removeFromParentViewController()
            }
        }
    }

    fileprivate func setupConnectedPeripheral() {
        // Note: Services should have been discovered previously
        guard let blePeripheral = blePeripheral else { return }

        hasUart = blePeripheral.hasUart()
        hasDFU = blePeripheral.peripheral.services?.first(where: {$0.uuid == FirmwareUpdater.kDfuServiceUUID}) != nil
        hasBattery = blePeripheral.hasBattery()
        
        if hasBattery {
            blePeripheral.startReadingBatteryLevel(handler: { [weak self] batteryLevel in
                guard let context = self else { return }

                context.batteryLevel = batteryLevel
                
                DispatchQueue.main.async { [unowned context] in
                    // Update section
                    context.baseTableView.reloadSections([TableSection.device.rawValue], with: .none)

                }
            })
        }

        baseTableView.reloadData()
    }

    fileprivate func showDfu() {
        if let dfuViewController = self.storyboard!.instantiateViewController(withIdentifier: "DfuModeViewController") as? DfuModeViewController {
            dfuViewController.blePeripheral = blePeripheral

            show(dfuViewController, sender: self)
        }
    }

    fileprivate func menuItems() -> [Modules] {
        if startingController == .multiUart {
            return [.uart, .plotter]
        } else if hasUart && hasDFU {
            return [.info, .uart, .plotter, .pinIO, .controller, .neopixel, .calibration, .dfu]
        } else if hasUart {
            return [.info, .uart, .plotter, .pinIO, .controller, .calibration]
        } else if hasDFU {
            return [.info, .dfu]
        } else {
            return [.info]
        }
    }
}

// MARK: - UITableViewDataSource
extension PeripheralModulesViewController: UITableViewDataSource {

    enum TableSection: Int {
        case device = 0
        case modules = 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch TableSection(rawValue: section)! {
        case .device:
            return 1
        case .modules:
            return menuItems().count
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        var localizationKey: String!
        
        switch TableSection(rawValue: section)! {
        case .device:
            localizationKey = "peripheralmodules_sectiontitle_device"
        case .modules:
            localizationKey = "peripheralmodules_sectiontitle_modules"
        }
        
        return LocalizationManager.sharedInstance.localizedString(localizationKey)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var reuseIdentifier: String
        switch TableSection(rawValue: indexPath.section)! {
        case .device:
            reuseIdentifier = "DeviceCell"
        case .modules:
            reuseIdentifier = "ModuleCell"
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension PeripheralModulesViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        let localizationManager = LocalizationManager.sharedInstance
        
        switch TableSection(rawValue: indexPath.section)! {
        case .device:
            guard let deviceCell = cell as? PeripheralModulesDeviceTableViewCell, let peripheral = blePeripheral else { return }

            deviceCell.titleLabel.text = peripheral.name ?? localizationManager.localizedString("peripherallist_unnamed")
            deviceCell.rssiImageView.image = RssiUI.signalImage(for: peripheral.rssi)
            deviceCell.rssiLabel.text = peripheral.rssi != nil ? String(format: localizationManager.localizedString("peripheralmodules_rssi_format"), peripheral.rssi!) : localizationManager.localizedString("peripheralmodules_rssi_unavailable")
            
            deviceCell.batteryStackView.isHidden = batteryLevel == nil
            if let batteryLevel = batteryLevel {
                deviceCell.batteryLabel.text = "\(batteryLevel)%"
            }
            
        case .modules:
            guard let moduleCell = cell as? PeripheralModulesTableViewCell else { return }

            var titleId: String?
            var iconName: String?
            let items = menuItems()
            
            switch items[indexPath.row] {
            case .info:
                iconName = "tab_info_icon"
                titleId = "info_tab_title"
            case .uart:
                iconName = "tab_uart_icon"
                titleId = "uart_tab_title"
            case .plotter:
                iconName = "tab_plotter_icon"
                titleId = "plotter_tab_title"
            case .pinIO:
                iconName = "tab_pinio_icon"
                titleId = "pinio_tab_title"
            case .controller:
                iconName = "tab_controller_icon"
                titleId = "controller_tab_title"
            case .neopixel:
                iconName = "tab_neopixel_icon"
                titleId = "neopixels_tab_title"
            case .calibration:
                iconName = "tab_calibration_icon"
                titleId = "calibration_tab_title"
            case .dfu:
                iconName = "tab_dfu_icon"
                titleId = "dfu_tab_title"
            }
            
            moduleCell.iconImageView.tintColor = UIColor.darkGray
            moduleCell.iconImageView.image = iconName != nil ? UIImage(named: iconName!) : nil
            moduleCell.titleLabel.text = titleId != nil ? localizationManager.localizedString(titleId!) : nil
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch TableSection(rawValue: indexPath.section)! {
        case .device:
            return 80
        case .modules:
            return traitCollection.userInterfaceIdiom == .pad ? 66 : 44
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch TableSection(rawValue: indexPath.section)! {
        case .device:
            // Not selectable
            break
            
        case .modules:
            let items = menuItems()
            
            switch items[indexPath.row] {
            case .info:
                if let infoViewController = self.storyboard?.instantiateViewController(withIdentifier: "InfoModeViewController") as? InfoModeViewController {
                    infoViewController.blePeripheral = blePeripheral
                    show(infoViewController, sender: self)
                }
            case .uart:
                if let uartViewController = self.storyboard?.instantiateViewController(withIdentifier: "UartModeViewController") as? UartModeViewController {
                    uartViewController.blePeripheral = blePeripheral
                    show(uartViewController, sender: self)
                }
            case .plotter:
                if let plotterViewController = self.storyboard?.instantiateViewController(withIdentifier: "PlotterModeViewController") as? PlotterModeViewController {
                    plotterViewController.blePeripheral = blePeripheral
                    show(plotterViewController, sender: self)
                }
            case .pinIO:
                if let pinioViewController = self.storyboard?.instantiateViewController(withIdentifier: "PinIOModeViewController") as? PinIOModeViewController {
                    pinioViewController.blePeripheral = blePeripheral
                    show(pinioViewController, sender: self)
                }
            case .controller:
                if let controllerViewController = self.storyboard?.instantiateViewController(withIdentifier: "ControllerModeViewController") as? ControllerModeViewController {
                    controllerViewController.blePeripheral = blePeripheral
                    show(controllerViewController, sender: self)
                }
            case .neopixel:
                if let neopixelsViewController = self.storyboard?.instantiateViewController(withIdentifier: "NeopixelModeViewController") as? NeopixelModeViewController {
                    neopixelsViewController.blePeripheral = blePeripheral
                    show(neopixelsViewController, sender: self)
                }
            case .calibration:
                if let calibrationViewController = self.storyboard?.instantiateViewController(withIdentifier: "CalibrationMenuViewController") as? CalibrationMenuViewController {
                    calibrationViewController.blePeripheral = blePeripheral
                    show(calibrationViewController, sender: self)
                }
            case .dfu:
                showDfu()
            }
            
        }
        tableView.deselectRow(at: indexPath, animated: indexPath.section == 0)
    }
}
