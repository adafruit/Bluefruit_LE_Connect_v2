//
//  AppDelegate.swift
//  bluefruitconnect
//
//  Created by Antonio García on 22/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)

    // UI
    @IBOutlet weak var peripheralsMenu: NSMenu!
    @IBOutlet weak var startScanningMenuItem: NSMenuItem!
    @IBOutlet weak var stopScanningMenuItem: NSMenuItem!

    // Status Menu
    let statusMenu = NSMenu()
    var isMenuOpen = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        // Init
        peripheralsMenu.delegate = self
        peripheralsMenu.autoenablesItems = false

        // Check if there is any update to the fimware database
        FirmwareUpdater.refreshSoftwareUpdatesDatabase(url: Preferences.updateServerUrl, completion: nil)

        // Add system status button
        setupStatusButton()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application

        releaseStatusButton()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        /*
         let appInSystemStatusBar = Preferences.appInSystemStatusBar
         return appInSystemStatusBar ? false : true
         */
        return true
    }

    // MARK: System status button
    func setupStatusButton() {

        statusItem.image = NSImage(named: "sytemstatusicon")
        statusItem.alternateImage = NSImage(named: "sytemstatusicon_selected")
        statusItem.highlightMode = true
        updateStatusTitle()

        statusMenu.delegate = self

        // Setup contents
        statusItem.menu = statusMenu
        updateStatusContent(nil)

        /* TODO: restore
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(updateStatus(_:)), name: UartDataManager.UartNotifications.DidReceiveData.rawValue, object: nil)
        notificationCenter.addObserver(self, selector: #selector(updateStatus(_:)), name: UartDataManager.UartNotifications.DidSendData.rawValue, object: nil)
        notificationCenter.addObserver(self, selector: #selector(updateStatus(_:)), name: StatusManager.StatusNotifications.DidUpdateStatus.rawValue, object: nil)
 */
    }

    func releaseStatusButton() {
        /* TODO: restore
        let notificationCenter =  NotificationCenter.default
        notificationCenter.removeObserver(self, name: UartDataManager.UartNotifications.DidReceiveData.rawValue, object: nil)
        notificationCenter.removeObserver(self, name: UartDataManager.UartNotifications.DidSendData.rawValue, object: nil)
        notificationCenter.removeObserver(self, name: StatusManager.StatusNotifications.DidUpdateStatus.rawValue, object: nil)
 */
    }

    func statusGeneralAction(_ sender: AnyObject?) {

    }

    func updateStatus(_ nofitication: Notification?) {
        updateStatusTitle()
        if isMenuOpen {
            updateStatusContent(nil)
        }
    }

    func updateStatusTitle() {
        /*TODO: restore
        var title: String?

        let bleManager = BleManager.sharedInstance
        if let featuredPeripheral = bleManager.connectedPeripherals().first {
            if featuredPeripheral.isUartAdvertised() {
                let receivedBytes = featuredPeripheral.uartData.receivedBytes
                let sentBytes = featuredPeripheral.uartData.sentBytes

                title = "\(sentBytes)/\(receivedBytes)"
            }
        }

        statusItem.title = title
 */
    }

    func updateStatusContent(_ notification: Notification?) {
        let bleManager = BleManager.sharedInstance

        let statusText = StatusManager.sharedInstance.statusDescription()

        DispatchQueue.main.async(execute: { [unowned self] in            // Execute on main thrad to avoid flickering on macOS Sierra

            self.statusMenu.removeAllItems()

            // Main Area
            let descriptionItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
            descriptionItem.isEnabled = false
            self.statusMenu.addItem(descriptionItem)
            self.statusMenu.addItem(NSMenuItem.separator())

            // Connecting/Connected Peripheral
            var featuredPeripheralIds = [UUID]()
            for connectedPeripheral in bleManager.connectedPeripherals() {
                let menuItem = self.addPeripheralToSystemMenu(connectedPeripheral)
                menuItem.offStateImage = NSImage(named: "NSMenuOnStateTemplate")
                featuredPeripheralIds.append(connectedPeripheral.identifier)
            }
            for connectingPeripheral in bleManager.connectingPeripherals() {
                if !featuredPeripheralIds.contains(connectingPeripheral.identifier) {
                    let menuItem = self.addPeripheralToSystemMenu(connectingPeripheral)
                    menuItem.offStateImage = NSImage(named: "NSMenuOnStateTemplate")
                    featuredPeripheralIds.append(connectingPeripheral.identifier)
                }
            }
            
            // Discovered Peripherals
            let blePeripheralsFound = bleManager.peripherals().sorted(by: {$0.name ?? "" <= $1.name ?? ""})     // Alphabetical order
            for blePeripheral in blePeripheralsFound {
                if !featuredPeripheralIds.contains(blePeripheral.identifier) {
                    self.addPeripheralToSystemMenu(blePeripheral)
                }
            }

            /*TODO: restore
            // Uart data
            if let featuredPeripheral = featuredPeripheral {
                // Separator
                self.statusMenu.addItem(NSMenuItem.separator())

                // Uart title
                let title = featuredPeripheral.name != nil ? "\(featuredPeripheral.name!) Stats:" : "Stats:"
                let uartTitleMenuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                uartTitleMenuItem.enabled = false
                self.statusMenu.addItem(uartTitleMenuItem)

                // Stats
                let receivedBytes = featuredPeripheral.uartData.receivedBytes
                let sentBytes = featuredPeripheral.uartData.sentBytes

                let uartSentMenuItem = NSMenuItem(title: "Uart Sent: \(sentBytes) bytes", action: nil, keyEquivalent: "")
                let uartReceivedMenuItem = NSMenuItem(title: "Uart Received: \(receivedBytes) bytes", action: nil, keyEquivalent: "")

                uartSentMenuItem.indentationLevel = 1
                uartReceivedMenuItem.indentationLevel = 1
                uartSentMenuItem.enabled = false
                uartReceivedMenuItem.enabled = false
                self.statusMenu.addItem(uartSentMenuItem)
                self.statusMenu.addItem(uartReceivedMenuItem)
            }
 */
        })
    }

    @discardableResult
    func addPeripheralToSystemMenu(_ blePeripheral: BlePeripheral) -> NSMenuItem {
        let name = blePeripheral.name != nil ? blePeripheral.name! : LocalizationManager.sharedInstance.localizedString("scanner_unnamed")
        let menuItem = NSMenuItem(title: name, action: #selector(onClickPeripheralMenuItem(_:)), keyEquivalent: "")
        let identifier = blePeripheral.peripheral.identifier
        menuItem.representedObject = identifier
        statusMenu.addItem(menuItem)

        return menuItem
    }

    func onClickPeripheralMenuItem(_ sender: NSMenuItem) {
        let identifier = sender.representedObject as! UUID
        StatusManager.sharedInstance.startConnectionToPeripheral(identifier)

    }

    // MARK: - NSMenuDelegate
    func menuWillOpen(_ menu: NSMenu) {
        if menu == statusMenu {
            isMenuOpen = true
            updateStatusContent(nil)
        } else if menu == peripheralsMenu {
            let isScanning = BleManager.sharedInstance.isScanning
            startScanningMenuItem.isEnabled = !isScanning
            stopScanningMenuItem.isEnabled = isScanning
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        if menu == statusMenu {
            isMenuOpen = false
        }
    }

    // MARK: - Main Menu

    @IBAction func onStartScanning(_ sender: AnyObject) {
        BleManager.sharedInstance.startScan()
    }

    @IBAction func onStopScanning(_ sender: AnyObject) {
        BleManager.sharedInstance.stopScan()
    }

    @IBAction func onRefreshPeripherals(_ sender: AnyObject) {
        BleManager.sharedInstance.refreshPeripherals()
    }

    /* launch app from menuitem
     [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
     [_window makeKeyAndOrderFront:self];
     */
}
