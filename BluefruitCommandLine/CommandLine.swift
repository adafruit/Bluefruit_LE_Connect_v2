//
//  CommandLine.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 17/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

class CommandLine {
    
    private var discoveredPeripheralsIdentifiers = [String]()
    
    
    // MARK: - Help
    
    func showHelp() {
        // App name
        /*
        let bundleInfo = NSBundle.mainBundle().infoDictionary!
        let appName = bundleInfo["CFBundleName"] as? String
        */
        //let shortVersion = NSBundle.mainBundle().infoDictionary!["CFBundleShortVersionString"]  as! String
        //let appInfoString = String(format: "Bluefruit v.%@", shortVersion)
        let appInfoString = "Bluefruit"
        print(appInfoString)
    }
    
    // MARK: - Scan 
    func startScanning() {
        // Subscribe to Ble Notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didDiscoverPeripheral(_:)), name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        
        BleManager.sharedInstance.startScan()
    }
    
    @objc func didDiscoverPeripheral(notification : NSNotification) {
        
        if let uuid = notification.userInfo?["uuid"] as? String {
            
            if let peripheral = BleManager.sharedInstance.blePeripherals()[uuid] {
                
                if !discoveredPeripheralsIdentifiers.contains(uuid) {
                    discoveredPeripheralsIdentifiers.append(uuid)
                    
                    let name = peripheral.name != nil ? peripheral.name! : "{No Name}"
                    print("\(uuid): \(name)")
                }
            }
        }
    }
    
    // MARK: - DFU
    func dfu(deviceInfoData: DeviceInfoData, hexUrl: NSURL, iniUrl: NSURL) {
        guard let blePeripheral = BleManager.sharedInstance.blePeripheralConnected else {
            DLog("DFU Error: No peripheral connected")
            return
        }
        
        let dfuUpdateProcess = DfuUpdateProcess()
        
        // Setup update process
        dfuUpdateProcess.setUpdateParameters(blePeripheral.peripheral, hexUrl: hexUrl, iniUrl:iniUrl, deviceInfoData: deviceInfoData)
        dfuUpdateProcess.delegate = self
    }
}

// MARK: - DfuUpdateProcessDelegate
extension CommandLine : DfuUpdateProcessDelegate {
    func onUpdateProcessSuccess() {
        BleManager.sharedInstance.restoreCentralManager()
        
        print("Update completed successfully")
    }
    
    func onUpdateProcessError(errorMessage : String, infoMessage: String?) {
        BleManager.sharedInstance.restoreCentralManager()
        
         print(errorMessage)
        
    }
    
    func onUpdateProgressText(message: String) {
        dispatch_async(dispatch_get_main_queue(),{
             print("\t"+message)
            })
    }
    
    func onUpdateProgressValue(progress : Double) {
        dispatch_async(dispatch_get_main_queue(),{
            print(".", terminator: "")
        })
    }
}