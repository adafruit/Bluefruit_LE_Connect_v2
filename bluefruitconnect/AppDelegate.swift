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
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
    let statusMenu = NSMenu();
    var isMenuOpen = false

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        
        // Register default preferences
        //Preferences.resetDefaults()       // Debug Reset
        Preferences.registerDefaults()
        
        // Check if there is any update to the fimware database
        FirmwareUpdater.refreshSoftwareUpdatesDatabaseWithCompletionHandler(nil)
        
        // Add system status button
        setupStatusButton()
        
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
        
        releaseStatusButton()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication) -> Bool {
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

        let notificationCenter =  NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "updateStatus:", name: UartViewController.UartNotifications.DidTransferData.rawValue, object: nil)
        notificationCenter.addObserver(self, selector: "updateStatus:", name: StatusManager.StatusNotifications.DidUpdateStatus.rawValue, object: nil)
    }
    
    func releaseStatusButton() {
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: UartViewController.UartNotifications.DidTransferData.rawValue, object: nil)
        notificationCenter.removeObserver(self, name: StatusManager.StatusNotifications.DidUpdateStatus.rawValue, object: nil)
    }

    
    func statusGeneralAction(sender: AnyObject?) {
        
    }
    
    func updateStatus(nofitication : NSNotification?) {
        updateStatusTitle()
        if isMenuOpen {
            updateStatusContent(nil)
        }
    }
    
    func updateStatusTitle() {
        var title : String?
        
        let bleManager = BleManager.sharedInstance
        if let featuredPeripheral = bleManager.blePeripheralConnected {
            if featuredPeripheral.isUartAdvertised() {
                let receivedBytes = featuredPeripheral.uartData.receivedBytes
                let sentBytes = featuredPeripheral.uartData.sentBytes
                
                title = "\(sentBytes)/\(receivedBytes)"
            }
        }
        
        statusItem.title = title

    }
 
    func updateStatusContent(notification : NSNotification?) {
        let bleManager = BleManager.sharedInstance

        let statusText = StatusManager.sharedInstance.statusDescription()

        statusMenu.removeAllItems()

        // Main Area
        let descriptionItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        descriptionItem.enabled = false
        statusMenu.addItem(descriptionItem)
//        statusMenu.addItem(NSMenuItem(title: isScanning ?"Stop Scanning":"Start Scanning", action: "statusGeneralAction:", keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem.separatorItem())

        // Connecting/Connected Peripheral
        var featuredPeripheral = bleManager.blePeripheralConnected
        if (featuredPeripheral == nil) {
            featuredPeripheral = bleManager.blePeripheralConnecting
        }
        if let featuredPeripheral = featuredPeripheral {
            let menuItem = addPeripheralToSystemMenu(featuredPeripheral)
            menuItem.offStateImage = NSImage(named: "NSMenuOnStateTemplate")
        }
        
        // Discovered Peripherals
        for identifier in bleManager.blePeripheralFoundAlphabeticKeys() {
            if (identifier != featuredPeripheral?.peripheral.identifier.UUIDString) {
                let blePeripheral = bleManager.blePeripheralsFound[identifier]!
                addPeripheralToSystemMenu(blePeripheral)
            }
        }
        
        // Uart data
        if let featuredPeripheral = featuredPeripheral {
            // Separator
            statusMenu.addItem(NSMenuItem.separatorItem())
            
            // Uart title
            let uartTitleMenuItem = NSMenuItem(title: "\(featuredPeripheral.name) Stats:", action: nil, keyEquivalent: "")
            uartTitleMenuItem.enabled = false
            statusMenu.addItem(uartTitleMenuItem)

            // Stats
            let receivedBytes = featuredPeripheral.uartData.receivedBytes
            let sentBytes = featuredPeripheral.uartData.sentBytes

            let uartSentMenuItem = NSMenuItem(title: "Uart Sent: \(sentBytes) bytes", action: nil, keyEquivalent: "")
            let uartReceivedMenuItem = NSMenuItem(title: "Uart Received: \(receivedBytes) bytes", action: nil, keyEquivalent: "")
            
            uartSentMenuItem.indentationLevel = 1
            uartReceivedMenuItem.indentationLevel = 1
            uartSentMenuItem.enabled = false
            uartReceivedMenuItem.enabled = false
            statusMenu.addItem(uartSentMenuItem)
            statusMenu.addItem(uartReceivedMenuItem)
        }
    }

    func addPeripheralToSystemMenu(blePeripheral : BlePeripheral) -> NSMenuItem {
        let menuItem = NSMenuItem(title: blePeripheral.name, action: "onClickPeripheralMenuItem:", keyEquivalent: "")
        let identifier = blePeripheral.peripheral.identifier.UUIDString
        menuItem.representedObject = identifier
        statusMenu.addItem(menuItem)
        
        return menuItem
    }
    
    func onClickPeripheralMenuItem(sender : NSMenuItem) {
        let identifier = sender.representedObject as! String
        StatusManager.sharedInstance.startConnectionToPeripheral(identifier)
        
    }

    // MARK: - NSMenuDelegate
    func menuWillOpen(menu: NSMenu) {
        isMenuOpen = true
        updateStatusContent(nil)
    }
    
    func menuDidClose(menu: NSMenu) {
        isMenuOpen = false
    }
    
    
    /* launch app from menuitem
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [_window makeKeyAndOrderFront:self];
*/
}

