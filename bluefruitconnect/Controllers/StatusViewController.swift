//
//  StatusViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 23/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class StatusViewController: NSViewController {

    @IBOutlet weak var statusTextField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didUpdateState:", name: BleManager.BleNotifications.DidUpdateState.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didStartScanning:", name: BleManager.BleNotifications.DidStartScanning.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "willConnectToPeripheral:", name: BleManager.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didConnectToPeripheral:", name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "willDisconnectFromPeripheral:", name: BleManager.BleNotifications.WillDisconnectFromPeripheral.rawValue, object: nil)

        
//        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didStopScanning:", name: BleManager.BleNotifications.DidStopScanning.rawValue, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func didUpdateState(notification : NSNotification) {
        if let state = CBCentralManagerState(rawValue: notification.object as! Int) {
            
            var message = ""
            var errorMessage : String?
            
            switch(state) {
            case .Unknown:
                message = "State unknown, update imminent"
            case .Resetting:
                message = "The connection with the system service was momentarily lost, update imminent"
            case .Unsupported:
                errorMessage = "This computer doesn't support Bluetooth Low Energy"
                message = "Bluetooth Low Energy unsupported"
            case .Unauthorized:
                errorMessage = "The application is not authorized to use the Bluetooth Low Energy"
                message = "Unathorized to use Bluetooth Low Energy"
            case .PoweredOff:
                errorMessage = "Bluetooth is currently powered off"
                message = errorMessage!
            case .PoweredOn:
                message = "Status: Scanning..."
                
            }
            
            setText(message)
            
            if let errorMessage = errorMessage {
                let alert = NSAlert()
                alert.messageText = errorMessage
                alert.addButtonWithTitle("Ok")
                alert.alertStyle = .WarningAlertStyle
                alert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)

            }
        }
    }

    
    func didStartScanning(notification : NSNotification) {
        setText("Status: Scanning...")
    }
    
    /*
    func didStopScanning(notification : NSNotification) {
        statusTextField.stringValue = "Status:"
    }
*/
    
    func willConnectToPeripheral(notification : NSNotification) {
        setText("Status: Connecting...")
    }
    
    
    func didConnectToPeripheral(notification : NSNotification) {
        var hasName = false
        
        let identifier = notification.object as! String
        if let blePeripheral = BleManager.sharedInstance.blePeripheralsFound[identifier] {
            if let name = blePeripheral.peripheral.name {
                setText("Status: Connected to \(name)")
                hasName = true
            }
        }

        if (!hasName) {
            setText("Status: Connected ")
        }
    }
    
    func willDisconnectFromPeripheral(notification : NSNotification) {
        setText("Status: Scanning...")
    }
    


    func setText(text : String) {
        statusTextField.stringValue = text
    }
    
}
