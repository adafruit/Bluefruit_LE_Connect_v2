//
//  DetailsViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 25/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa
import CoreBluetooth

class DetailsViewController: NSViewController {
    
    @IBOutlet weak var emptyView: NSTabView!
    @IBOutlet weak var emptyLabel: NSTextField!
    
    @IBOutlet weak var modeTabView: NSTabView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        modeTabView.hidden = true
        emptyView.hidden = false
        
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
    
    func willConnectToPeripheral(notification : NSNotification) {
        modeTabView.hidden = true
        emptyView.hidden = false
        emptyLabel.stringValue = "Connecting..."
    }
    
    func didConnectToPeripheral(notification : NSNotification) {
        modeTabView.hidden = false
        emptyView.hidden = true
        
        for tabViewItem in modeTabView.tabViewItems {
            modeTabView.removeTabViewItem(tabViewItem)
        }
        
        // Add Info tab
        let infoViewController = self.storyboard?.instantiateControllerWithIdentifier("InfoViewController") as! InfoViewController
        infoViewController.onServicesDiscovered = { [unowned self] in
            self.servicesDiscovered()
        }
        let infoTabViewItem = NSTabViewItem(viewController: infoViewController)
        modeTabView.addTabViewItem(infoTabViewItem)
        
        modeTabView.selectFirstTabViewItem(nil)

    }

    func willDisconnectFromPeripheral(notification : NSNotification) {
        modeTabView.hidden = true
        emptyView.hidden = false
        emptyLabel.stringValue = "Select a peripheral"
        
        for tabViewItem in modeTabView.tabViewItems {
            modeTabView.removeTabViewItem(tabViewItem)
        }
        
        let blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        blePeripheral?.peripheral.delegate = nil
    }

    func servicesDiscovered() {
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            if let services = blePeripheral.peripheral.services {
                let kUartServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"                       // UART service UUID
                let kNordicDeviceFirmwareUpdateService = "00001530-1212-EFDE-1523-785FEABCD123";    // DFU service UUID
                
                let hasUart = services.contains({ (service : CBService) -> Bool in
                    service.UUID.UUIDString.caseInsensitiveCompare(kUartServiceUUID) == .OrderedSame
                })
                
                if (hasUart) {
                    // Add Uart tab
                    let uartViewController = self.storyboard?.instantiateControllerWithIdentifier("UartViewController") as! UartViewController
                    let uartTabViewItem = NSTabViewItem(viewController: uartViewController)
                    modeTabView.addTabViewItem(uartTabViewItem)
                }
                
                let hasDFU = services.contains({ (service : CBService) -> Bool in
                    service.UUID.UUIDString.caseInsensitiveCompare(kNordicDeviceFirmwareUpdateService) == .OrderedSame
                })
                
                if (hasDFU) {
                    // Add Firmware Update tab
                    let updateViewController = self.storyboard?.instantiateControllerWithIdentifier("FirmwareUpdateViewController") as! FirmwareUpdateViewController
                    let updateTabViewItem = NSTabViewItem(viewController: updateViewController)
                    modeTabView.addTabViewItem(updateTabViewItem)
                }
                
            }
        }
    }
}
