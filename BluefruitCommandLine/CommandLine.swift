//
//  CommandLine.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 17/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

class CommandLine: NSObject {

    // Scanning
    var discoveredPeripheralsIdentifiers = [String]()
    private var scanResultsShowIndex = false
    
    // DFU
//    private var boardRelease : BoardInfo?
//    private var deviceInfoData : DeviceInfoData?
    private var dfuSemaphore = dispatch_semaphore_create(0)
    
    
    // MARK: - Bluetooth Status
    func checkBluetoothErrors() -> String? {
        var errorMessage : String?
        let bleManager = BleManager.sharedInstance
        if let state = bleManager.centralManager?.state {
            switch(state) {
            case .Unsupported:
                errorMessage = "This computer doesn't support Bluetooth Low Energy"
            case .Unauthorized:
                errorMessage = "The application is not authorized to use the Bluetooth Low Energy"
            case .PoweredOff:
                errorMessage = "Bluetooth is currently powered off"
            default:
                errorMessage = nil
            }
        }
        
        return errorMessage
    }
    
    // MARK: - Help
    func showHelp() {
        // App name
        /*
        let bundleInfo = NSBundle.mainBundle().infoDictionary
        let appName = bundleInfo["CFBundleName"] as? String
        */
        //let shortVersion = NSBundle.mainBundle().infoDictionary!["CFBundleShortVersionString"]  as! String
        //let appInfoString = String(format: "Bluefruit v.%@", shortVersion)
        let appInfoString = "Bluefruit"
        print(appInfoString)
    }
    
    // MARK: - Scan 
    func startScanning() {
        startScanningAndShowIndex(false)
    }
    
    func startScanningAndShowIndex(scanResultsShowIndex: Bool) {
        self.scanResultsShowIndex = scanResultsShowIndex
        
        // Subscribe to Ble Notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didDiscoverPeripheral(_:)), name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        
        BleManager.sharedInstance.startScan()
    }
    
    func didDiscoverPeripheral(notification : NSNotification) {
        
        if let uuid = notification.userInfo?["uuid"] as? String {
            
            if let peripheral = BleManager.sharedInstance.blePeripherals()[uuid] {
                
                if !discoveredPeripheralsIdentifiers.contains(uuid) {
                    discoveredPeripheralsIdentifiers.append(uuid)
                    
                    let name = peripheral.name != nil ? peripheral.name! : "{No Name}"
                    if scanResultsShowIndex {
                        if let index  = discoveredPeripheralsIdentifiers.indexOf(uuid) {
                            print("\(index) -> \(uuid): \(name)")
                        }
                    }
                    else {
                        print("\(uuid): \(name)")
                    }
                }
            }
        }
    }
    
    // MARK: - DFU
    func dfuPeripheralWithUUIDString(UUIDString: String, hexPath: String, iniPath: String?) {
        
        guard let centralManager = BleManager.sharedInstance.centralManager else {
            DLog("centralManager is nil")
            return
        }
        
        
        
        if let peripheralUUID = NSUUID(UUIDString: UUIDString) {
            if let peripheral = centralManager.retrievePeripheralsWithIdentifiers([peripheralUUID]).first {
                

                // Connect to peripheral and discover characteristics. This should not be needed but the Dfu library will fail if a previous characteristics discovery has not been done
                let firmwareUpdater = FirmwareUpdater()
                firmwareUpdater.checkUpdatesForPeripheral(peripheral, delegate: self)
                
                
            }
        }
    }

    private func dfuWithPeripheral(peripheral: CBPeripheral, hexPath: String, iniPath: String?) {
        
        // Setup
        let dfuUpdateProcess = DfuUpdateProcess()
        dfuUpdateProcess.delegate = self
        
        // Read hex
        guard let hexData = NSFileManager.defaultManager().contentsAtPath(hexPath) else {
            print("File not found: \(hexPath)")
            return
        }
        
        // Read ini
        var iniData: NSData? = nil
        if let iniPath = iniPath {
            iniData = NSFileManager.defaultManager().contentsAtPath(iniPath)
            guard iniData != nil else {
                print("File not found: \(iniPath)")
                return
            }
        }
        
        // Start dfu
        let isOperationInProgress = dfuUpdateProcess.startDfuOperationBypassingChecksWithPeripheral(peripheral, hexData: hexData, iniData: iniData)
        
        if isOperationInProgress {
            // Wait till completion
            dispatch_semaphore_wait(dfuSemaphore, DISPATCH_TIME_FOREVER)
        }
    }
    
    private func dfuFinished() {
         dispatch_semaphore_signal(dfuSemaphore)
    }

}

// MARK: - DfuUpdateProcessDelegate
extension CommandLine: DfuUpdateProcessDelegate {
    func onUpdateProcessSuccess() {
        BleManager.sharedInstance.restoreCentralManager()
        
       
        print("Update completed successfully")
        dfuFinished()
    }
    
    func onUpdateProcessError(errorMessage : String, infoMessage: String?) {
        BleManager.sharedInstance.restoreCentralManager()
        
        print(errorMessage)
        dfuFinished()
        
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


// MARK: - FirmwareUpdaterDelegate
extension CommandLine: FirmwareUpdaterDelegate {
    
    func onFirmwareUpdatesAvailable(isUpdateAvailable: Bool, latestRelease: FirmwareInfo!, deviceInfoData: DeviceInfoData!, allReleases: [NSObject : AnyObject]!) {
    
        DLog("onFirmwareUpdatesAvailable: \(isUpdateAvailable)")
        //dfuWithPeripheral(peripheral, hexPath: hexPath, iniPath: iniPath)

    }
    
    func onDfuServiceNotFound() {
        print("DFU service not found")
        dfuFinished()
    }
    
}

