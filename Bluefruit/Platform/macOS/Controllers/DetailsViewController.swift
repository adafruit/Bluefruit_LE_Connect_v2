//
//  DetailsViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 25/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa
import CoreBluetooth
import MSWeakTimer

// Protocol that should implement viewControllers used as tabs
protocol DetailTab {
    func tabWillAppear()
    func tabWillDissapear()
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

    // Parameters
    enum ModuleController {
        case info
        case update
        case multiUart
    }
    
    var startingController = ModuleController.info
    weak var blePeripheral: BlePeripheral?
    
    /* TODO: restore
    // Modules
    private var pinIOViewController: PinIOViewController?
    private var updateViewController: FirmwareUpdateViewController?
    */
//    
    // Rssi
    private static let kRssiUpdateInterval = 2.0       // in seconds
    private var rssiTimer: MSWeakTimer?
    
    // Software upate autocheck
    private let firmwareUpdater = FirmwareUpdater()
    
    //
    override func viewDidLoad() {
        super.viewDidLoad()
        
        infoView.wantsLayer = true
        infoView.layer?.borderWidth = 1
        infoView.layer?.borderColor = NSColor.lightGray.cgColor
        
        showEmpty(true)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // Subscribe to Ble Notifications
        registerNotifications(enabled: true)
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        registerNotifications(enabled: false)
    }
    
    deinit {
        cancelRssiTimer()
    }
    
    // MARK: - BLE Notifications
    private weak var willConnectToPeripheralObserver: NSObjectProtocol?
    private weak var didConnectToPeripheralObserver: NSObjectProtocol?
    private weak var willDisconnectFromPeripheralObserver: NSObjectProtocol?

    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            willConnectToPeripheralObserver = notificationCenter.addObserver(forName: .willConnectToPeripheral, object: nil, queue: .main, using: willConnectToPeripheral)
            didConnectToPeripheralObserver = notificationCenter.addObserver(forName: .didConnectToPeripheral, object: nil, queue: .main, using: didConnectToPeripheral)
            willDisconnectFromPeripheralObserver = notificationCenter.addObserver(forName: .willDisconnectFromPeripheral, object: nil, queue: .main, using: willDisconnectFromPeripheral)
        } else {
          if let willConnectToPeripheralObserver = willConnectToPeripheralObserver {notificationCenter.removeObserver(willConnectToPeripheralObserver)}
            if let didConnectToPeripheralObserver = didConnectToPeripheralObserver {notificationCenter.removeObserver(didConnectToPeripheralObserver)}
            if let willDisconnectFromPeripheralObserver = willDisconnectFromPeripheralObserver {notificationCenter.removeObserver(willDisconnectFromPeripheralObserver)}
        }
    }
    
    func willConnectToPeripheral(notification: Notification) {
        showEmpty(true)
        emptyLabel.stringValue = LocalizationManager.sharedInstance.localizedString("peripheraldetails_connecting")
    }
    
    func didConnectToPeripheral(notification: Notification) {
        guard let peripheral = BleManager.sharedInstance.peripheral(from: notification) else { return }
        self.blePeripheral = peripheral

        emptyLabel.stringValue = LocalizationManager.sharedInstance.localizedString("peripheraldetails_discoveringservices")
        
        /* TODO: restore
        // UI
        showEmpty(false)
        
        for tabViewItem in modeTabView.tabViewItems {
            modeTabView.removeTabViewItem(tabViewItem)
        }
 
        startUpdatesCheck()
 */
    }
    
    func willDisconnectFromPeripheral(notification: Notification) {
        guard let selectedPeripheral = blePeripheral, let identifier = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID, selectedPeripheral.identifier == identifier else {
            DLog("Disconnected from an unexpected peripheral")
            return
        }
        
        showEmpty(true)
        cancelRssiTimer()
        
        for tabViewItem in modeTabView.tabViewItems {
            modeTabView.removeTabViewItem(tabViewItem)
        }
    }
    
/*  TODO: restore
    
    // MARK: -
    private func startUpdatesCheck(peripheral: BlePeripheral) {
        DLog("Check firmware updates")
        
        // Refresh updates available
        firmwareUpdater.checkUpdatesForPeripheral(peripheral, delegate: self, shouldDiscoverServices: false, shouldRecommendBetaReleases: false, versionToIgnore: Preferences.softwareUpdateIgnoredVersion)
    }
*/
    private func setupConnectedPeripheral() {
/* TODO: restore

 
        guard let blePeripheral = BleManager.sharedInstance.blePeripheralConnected else { return }
        
        // UI: Info
        let name = blePeripheral.name != nil ? blePeripheral.name! : LocalizationManager.sharedInstance.localizedString("scanner_unnamed")
        self.infoNameLabel.stringValue = name
        self.updateRssiUI()
        
        self.cancelRssiTimer()
        let privateQueue = dispatch_queue_create("private_queue", DISPATCH_QUEUE_CONCURRENT);
        self.rssiTimer = MSWeakTimer.scheduledTimerWithTimeInterval(DetailsViewController.kRssiUpdateInterval, target: self, selector: #selector(requestUpdateRssi), userInfo: nil, repeats: true, dispatchQueue: privateQueue)
        
        // UI: Add Info tab
        let infoViewController = self.storyboard?.instantiateControllerWithIdentifier("InfoViewController") as! InfoViewController
        
        infoViewController.onServicesDiscovered = { [weak self] in
            // optimization: wait till info discover services to continue, instead of discovering services by myself
            self?.servicesDiscovered()
        }
        
        infoViewController.onInfoScanFinished = { [weak self] in
            // tell the pinio that can start querying without problems
            self?.pinIOViewController?.infoFinishedScanning = true
            self?.updateViewController?.infoFinishedScanning = true
        }
        
        let infoTabViewItem = NSTabViewItem(viewController: infoViewController)
        self.modeTabView.addTabViewItem(infoTabViewItem)
        infoViewController.tabReset()
        
        self.modeTabView.selectFirstTabViewItem(nil)
 */
    }
    
    func requestUpdateRssi() {
        /* TODO: restore
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            //DLog("request rssi for \(blePeripheral.name)")
            blePeripheral.peripheral.readRSSI()
        }
 */
    }
    
    func cancelRssiTimer() {
        rssiTimer?.invalidate()
        rssiTimer = nil
    }
    
    func showEmpty(_ isEmpty: Bool) {
        infoView.isHidden = isEmpty
        modeTabView.isHidden = isEmpty
        emptyView.isHidden = !isEmpty
        if isEmpty {
            emptyLabel.stringValue = LocalizationManager.sharedInstance.localizedString("peripheraldetails_select")
        }
    }
    
     /* TODO: restore
    func servicesDiscovered() {
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            if let services = blePeripheral.peripheral.services {
                
                dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
                    
                    var currentTabIndex = 1     // 0 is Info
                    
                    let hasUart = blePeripheral.hasUart()
                    self.infoUartImageView.image = NSImage(named: hasUart ?"NSStatusAvailable":"NSStatusNone")
                    //infoUartLabel.toolTip = "UART Service \(hasUart ? "" : "not ")available"
                    
                    if (hasUart) {
                        // Uart Tab
                        if Config.isUartModuleEnabled {
                            var uartTabIndex = self.indexForTabWithClass("UartViewController")
                            if uartTabIndex < 0 {
                                // Add Uart tab
                                let uartViewController = self.storyboard?.instantiateControllerWithIdentifier("UartViewController") as! UartViewController
                                let uartTabViewItem = NSTabViewItem(viewController: uartViewController)
                                uartTabIndex = currentTabIndex
                                currentTabIndex += 1
                                self.modeTabView.insertTabViewItem(uartTabViewItem, atIndex: uartTabIndex)
                            }
                            
                            let uartViewController = self.modeTabView.tabViewItems[uartTabIndex].viewController as! UartViewController
                            uartViewController.tabReset()
                        }
                        
                        // PinIO
                        if Config.isPinIOModuleEnabled {
                            var pinIOTabIndex = self.indexForTabWithClass("PinIOViewController")
                            if pinIOTabIndex < 0 {
                                // Add PinIO tab
                                self.pinIOViewController = self.storyboard?.instantiateControllerWithIdentifier("PinIOViewController") as? PinIOViewController
                                let pinIOTabViewItem = NSTabViewItem(viewController: self.pinIOViewController!)
                                pinIOTabIndex = currentTabIndex
                                currentTabIndex += 1
                                self.modeTabView.insertTabViewItem(pinIOTabViewItem, atIndex: pinIOTabIndex)
                            }

                            let pinIOViewController = self.modeTabView.tabViewItems[pinIOTabIndex].viewController as! PinIOViewController
                            pinIOViewController.tabReset()
                        }
                    }
                    
                    // DFU Tab
                    let kNordicDeviceFirmwareUpdateService = "00001530-1212-EFDE-1523-785FEABCD123"    // DFU service UUID
                    let hasDFU = services.contains({ (service : CBService) -> Bool in
                        service.UUID.isEqual(CBUUID(string: kNordicDeviceFirmwareUpdateService))
                    })
                    
                    self.infoDfuImageView.image = NSImage(named: hasDFU ?"NSStatusAvailable":"NSStatusNone")
                    
                    if (hasDFU) {
                        if Config.isDfuModuleEnabled {
                            var dfuTabIndex = self.indexForTabWithClass("FirmwareUpdateViewController")
                            if dfuTabIndex < 0 {
                                // Add Firmware Update tab
                                self.updateViewController = self.storyboard?.instantiateControllerWithIdentifier("FirmwareUpdateViewController") as? FirmwareUpdateViewController
                                let updateTabViewItem = NSTabViewItem(viewController: self.updateViewController!)
                                dfuTabIndex = currentTabIndex
                                currentTabIndex += 1
                                self.modeTabView.insertTabViewItem(updateTabViewItem, atIndex: dfuTabIndex)
                            }
                            
                            let updateViewController = (self.modeTabView.tabViewItems[dfuTabIndex].viewController as! FirmwareUpdateViewController)
                            updateViewController.tabReset()
                        }
                        
                    }
                    
                    // DIS Indicator
                    let kDisServiceUUID = "180A"    // DIS service UUID
                    let hasDIS = services.contains({ (service : CBService) -> Bool in
                        service.UUID.isEqual(CBUUID(string: kDisServiceUUID))
                    })
                    self.infoDsiImageView.image = NSImage(named: hasDIS ?"NSStatusAvailable":"NSStatusNone")
                    
                    
                    // Neopixel Tab
                    if (hasUart && Config.isNeoPixelModuleEnabled) {
                        
                        var neopixelTabIndex = self.indexForTabWithClass("NeopixelViewControllerOSX")
                        if neopixelTabIndex < 0 {
                            // Add Neopixel tab
                            let neopixelViewController = self.storyboard?.instantiateControllerWithIdentifier("NeopixelViewControllerOSX") as! NeopixelViewControllerOSX
                            let neopixelTabViewItem = NSTabViewItem(viewController: neopixelViewController)
                            neopixelTabIndex = currentTabIndex
                            currentTabIndex += 1
                            self.modeTabView.insertTabViewItem(neopixelTabViewItem, atIndex: neopixelTabIndex)
                        }
                        
                        let neopixelViewController = self.modeTabView.tabViewItems[neopixelTabIndex].viewController as! NeopixelViewControllerOSX
                        neopixelViewController.tabReset()
                        
                    }
                    
                    })
            }
        }
    }
    */
    
    private func indexForTabWithClass(tabClassName: String) -> Int {
        var index = -1
        for i in 0..<modeTabView.tabViewItems.count {
            let className = String(describing: type(of: modeTabView.tabViewItems[i].viewController!))
            if className == tabClassName {
                index = i
                break
            }
        }
        
        return index
    }
    
    func updateRssiUI() {
        /* TODO: restore
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            let rssi = blePeripheral.rssi
            //DLog("rssi: \(rssi)")
            infoRssiLabel.stringValue = String(format:LocalizationManager.sharedInstance.localizedString("peripheraldetails_rssi_format"), arguments:[rssi]) // "\(rssi) dBm"
            infoRssiImageView.image = RssiUI.signalImage(for: rssi)
        }
 */
    }
    
    private func showUpdateAvailableForRelease(latestRelease: FirmwareInfo!) {
        if let window = self.view.window {
            let alert = NSAlert()
            alert.messageText = "Update available"
            alert.informativeText = "Software version \(latestRelease.version) is available"
            alert.addButton(withTitle: "Go to updates")
            alert.addButton(withTitle: "Ask later")
            alert.addButton(withTitle: "Ignore")
            alert.alertStyle = .warning
            alert.beginSheetModal(for: window, completionHandler: { modalResponse in
                if modalResponse == NSAlertFirstButtonReturn {
                    self.modeTabView.selectLastTabViewItem(nil)
                }
                else if modalResponse == NSAlertThirdButtonReturn {
                     Preferences.softwareUpdateIgnoredVersion = latestRelease.version
                }
            })
        }
        else {
            DLog("onUpdateDialogSuccess: window not defined")
        }        
        
    }

}
/* TODO: restore
// MARK: - CBPeripheralDelegate
extension DetailsViewController: CBPeripheralDelegate {
    
    // Send peripheral delegate methods to tab active (each tab will handle these methods)
    func peripheralDidUpdateName(peripheral: CBPeripheral) {
        for tabViewItem in modeTabView.tabViewItems {
            (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheralDidUpdateName?(peripheral)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
        // Services needs to be discovered again
        pinIOViewController?.infoFinishedScanning = false
        updateViewController?.infoFinishedScanning = false
        
        //
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

        for tabViewItem in modeTabView.tabViewItems {
            (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didUpdateValueForCharacteristic: characteristic, error: error)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
 
        for tabViewItem in modeTabView.tabViewItems {
            (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didUpdateValueForDescriptor: descriptor, error: error)
        }
    }
    
    func peripheralDidUpdateRSSI(peripheral: CBPeripheral, error: NSError?) {

        // Update peripheral rssi
        let identifierString = peripheral.identifier.UUIDString
        if let existingPeripheral = BleManager.sharedInstance.blePeripherals()[identifierString], rssi =  peripheral.RSSI?.integerValue {
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
    
    func tabView(tabView: NSTabView, willSelectTabViewItem tabViewItem: NSTabViewItem?) {
        
        if modeTabView.selectedTabViewItem != tabViewItem {
            if let detailTabViewController = modeTabView.selectedTabViewItem?.viewController as? DetailTab {     // Note: all tab viewcontrollers should conform to protocol
                detailTabViewController.tabWillDissapear()
            }
        }
    }
    
    func tabView(tabView: NSTabView, didSelectTabViewItem tabViewItem: NSTabViewItem?) {
        guard BleManager.sharedInstance.blePeripheralConnected != nil else {
            DLog("didSelectTabViewItem while disconnecting")
            return
        }
        
        let detailTabViewController = tabViewItem?.viewController as! DetailTab     // Note: all tab viewcontrollers should conform to protocol DetailTab
        detailTabViewController.tabWillAppear()
    }
    
}
*/

/* TODO: restore
// MARK: - FirmwareUpdaterDelegate
extension DetailsViewController: FirmwareUpdaterDelegate {
    func onFirmwareUpdateAvailable(isUpdateAvailable: Bool, latestRelease: FirmwareInfo?, deviceInfo: DeviceInformationService?) {
        DLog("FirmwareUpdaterDelegate isUpdateAvailable: \(isUpdateAvailable)")
        
        DispatchQueue.main.async { [weak self] in
            guard let context = self else { return }
            
            context.setupConnectedPeripheral()
            if isUpdateAvailable {
                self?.showUpdateAvailableForRelease(latestRelease)
            }
        }
    }
}
 
*/

