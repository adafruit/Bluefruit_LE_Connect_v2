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
    private var dfuSemaphore = dispatch_semaphore_create(0)
    private let firmwareUpdater = FirmwareUpdater()
    private let dfuUpdateProcess = DfuUpdateProcess()
    private var dfuPeripheral: CBPeripheral?
    private var hexUrl: NSURL?
    private var iniUrl: NSURL?
    private var releases:  [NSObject : AnyObject]? = nil
    
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
        showVersion()
        print("Usage:")
        print( "\t\(appName()) <command> [options...]")
        print("")
        print("Commands:")
        print("\tScan peripherals:   scan")
        print("\tAutomatic update:   update [--enable-beta] [--uuid <uuid>]")
        print("\tCustom firmware:    dfu --hex <filename> [--init <filename>] [--uuid <uuid>]")
        print("\tShow this screen:   --help")
        print("\tShow version:       --version")
        print("")
        print("Options:")
        print("\t--uuid <uuid>    If present the peripheral with that uuid is used. If not present a list of peripherals is displayed")
        print("\t--enable-beta    If not present only stable versions are used")
        print("")
        print("Short syntax:")
        print("\t-u = --uuid, -b = --enable-beta, -h = --hex, -i = --init, -v = --version, -? = --help")
        /*
        print("\t--uuid -u")
        print("\t--enable-beta -b")
        print("\t--hex -h")
        print("\t--init -i")
        print("\t--help -h")
        print("\t--version -v")
        */
        
        print("")
        
        /*
         print("\tscan                                                       Scan peripherals")
         print("\tupdate [--uuid <uuid>] [--enable-beta]                     Automatic update")
         print("\tdfu -hex <filename> [-init <filename>] [--uuid <uuid>]     Custom firmware update")
         print("\t-h --help                                                  Show this screen")
         print("\t-v --version                                               Show version")
      
         */
    }
    
    private func appName() -> String {
        let name = (Process.arguments[0] as NSString).lastPathComponent
        return name
    }
    
    func showVersion() {
        let appInfo = NSBundle.mainBundle().infoDictionary!
        let releaseVersionNumber = appInfo["CFBundleShortVersionString"] as! String
        let appInfoString = "\(appName()) v\(releaseVersionNumber)"
        //let buildVersionNumber =  appInfo["CFBundleVersion"] as! String
        //let appInfoString = "\(appname()) v\(releaseVersionNumber)b\(buildVersionNumber)"
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
    
    func stopScanning() {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        
        BleManager.sharedInstance.stopScan()
    }
    
    func didDiscoverPeripheral(notification : NSNotification) {
        
        if let uuid = notification.userInfo?["uuid"] as? String {
            
            if let peripheral = BleManager.sharedInstance.blePeripherals()[uuid] {
                
                if !discoveredPeripheralsIdentifiers.contains(uuid) {
                    discoveredPeripheralsIdentifiers.append(uuid)
                    
                    let name = peripheral.name != nil ? peripheral.name! : "{No Name}"
                    if scanResultsShowIndex {
                        if let index  = discoveredPeripheralsIdentifiers.indexOf(uuid) {
                            print("\(index) -> \(uuid) - \(name)")
                        }
                    }
                    else {
                        print("\(uuid): \(name)")
                    }
                }
            }
        }
    }
    
    // MARK: - Ask user
    func askUserForPeripheral() -> String? {
        print("Scanning... Select a peripheral: ")
        var peripheralUuid: String? = nil
        
        startScanningAndShowIndex(true)
        let peripheralIndexString = readLine(stripNewline: true)
        //DLog("selected: \(peripheralIndexString)")
        if let peripheralIndexString = peripheralIndexString, peripheralIndex = Int(peripheralIndexString) where peripheralIndex>=0 && peripheralIndex < discoveredPeripheralsIdentifiers.count {
            peripheralUuid = discoveredPeripheralsIdentifiers[peripheralIndex]
            
            //print("Selected UUID: \(peripheralUuid!)")
            stopScanning()
            
            print("")
            //            print("Peripheral selected")
            
        }
        
        return peripheralUuid
    }

    // MARK: - DFU
    func dfuPeripheralWithUUIDString(UUIDString: String, hexUrl: NSURL? = nil, iniUrl: NSURL? = nil, releases: [NSObject : AnyObject]? = nil) {
        
        // If hexUrl is nil, then uses releases to auto-update to the lastest release available
        
        guard let centralManager = BleManager.sharedInstance.centralManager else {
            DLog("centralManager is nil")
            return
        }
        
        if let peripheralUUID = NSUUID(UUIDString: UUIDString) {
            if let peripheral = centralManager.retrievePeripheralsWithIdentifiers([peripheralUUID]).first {
                
                dfuPeripheral = peripheral
                self.hexUrl = hexUrl
                self.iniUrl = iniUrl
                self.releases = releases
                print("Connecting...")
                
                // Connect to peripheral and discover characteristics. This should not be needed but the Dfu library will fail if a previous characteristics discovery has not been done
                
                // Subscribe to DidConnect notifications
                NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(dfuDidConnectToPeripheral(_:)), name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
                
                // Connect to peripheral and wait
                let blePeripheral = BlePeripheral(peripheral: peripheral, advertisementData: [:], RSSI: 0)
                BleManager.sharedInstance.connect(blePeripheral)
                dispatch_semaphore_wait(dfuSemaphore, DISPATCH_TIME_FOREVER)
            }
        }
        else {
            print("Error. No peripheral found with UUID: \(UUIDString)")
            dfuPeripheral = nil
        }
    }
    
    func dfuDidConnectToPeripheral(notification: NSNotification) {
        // Unsubscribe from DidConnect notifications
         NSNotificationCenter.defaultCenter().removeObserver(self, name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        
        // Check connected
        guard let dfuPeripheral = dfuPeripheral  else {
            DLog("dfuDidConnectToPeripheral dfuPeripheral is nil")
            dfuFinished()
            return
        }
        
        // Read services / characteristics
        print("Reading services and characteristics...");        
        self.firmwareUpdater.checkUpdatesForPeripheral(dfuPeripheral, delegate: self, shouldDiscoverServices: true, releases: releases, shouldRecommendBetaReleases: true)
    }

    private func dfuFinished() {
        dispatch_semaphore_signal(dfuSemaphore)
    }
    
    func downloadFirmwareUpdatesDatabaseFromUrl(dataUrl: NSURL, showBetaVersions: Bool, completionHandler: (([NSObject : AnyObject]?)->())?){
        
        DataDownloader.downloadDataFromURL(dataUrl) { (data) in
            let boardsInfo = ReleasesParser.parse(data, showBetaVersions: showBetaVersions)
            completionHandler?(boardsInfo)
        }
    }
}

// MARK: - DfuUpdateProcessDelegate
extension CommandLine: DfuUpdateProcessDelegate {
    func onUpdateProcessSuccess() {
        BleManager.sharedInstance.restoreCentralManager()        
        
        print("")
        print("Update completed successfully")
        dfuFinished()
    }

    func onUpdateProcessError(errorMessage : String, infoMessage: String?) {
        BleManager.sharedInstance.restoreCentralManager()
        
        print(errorMessage)
        dfuFinished()
    }

    func onUpdateProgressText(message: String) {
        print("\t"+message)
    }

    func onUpdateProgressValue(progress : Double) {
        print(".", terminator: "")
        fflush(__stdoutp)        
    }
}

// MARK: - FirmwareUpdaterDelegate
extension CommandLine: FirmwareUpdaterDelegate {
    
    func onFirmwareUpdatesAvailable(isUpdateAvailable: Bool, latestRelease: FirmwareInfo?, deviceInfoData: DeviceInfoData!, allReleases: [NSObject : AnyObject]?) {
        
        // Info received
        DLog("onFirmwareUpdatesAvailable: \(isUpdateAvailable)")
        
        print("Peripheral info:")
        print("\tManufacturer: \(deviceInfoData.manufacturer != nil ? deviceInfoData.manufacturer : "{unknown}")")
        print("\tModel:        \(deviceInfoData.modelNumber != nil ? deviceInfoData.modelNumber : "{unknown}")")
        print("\tSoftware:     \(deviceInfoData.softwareRevision != nil ? deviceInfoData.softwareRevision : "{unknown}")")
        print("\tFirmware:     \(deviceInfoData.firmwareRevision != nil ? deviceInfoData.firmwareRevision : "{unknown}")")
        print("\tBootlader:    \(deviceInfoData.bootloaderVersion() != nil ? deviceInfoData.bootloaderVersion() : "{unknown}")")
        
        guard deviceInfoData.hasDefaultBootloaderVersion() == false else {
            print("The legacy bootloader on this device is not compatible with this application")
            dfuFinished()
            return
        }

        // Determine final hex and init (depending if is a custom firmware selected by the user, or an automatic update comparing the peripheral version with the update server xml)
        var hexUrl: NSURL?
        var iniUrl: NSURL?
        
        if allReleases != nil {  // Use automatic-update
            
            guard let latestRelease = latestRelease else {
                print("No updates available")
                dfuFinished()
                return
            }
            
            guard isUpdateAvailable else {
                print("Latest available version is: \(latestRelease.version)")
                print("No updates available")
                dfuFinished()
                return
            }
            
            print("Auto-update to version: \(latestRelease.version)")
            hexUrl = NSURL(string: latestRelease.hexFileUrl)!
            iniUrl =  NSURL(string: latestRelease.iniFileUrl)
            
            
        }
        else {      // is a custom update selected by the user
            hexUrl = self.hexUrl
            iniUrl = self.iniUrl
        }
        
        // Check update parameters
        guard let dfuPeripheral = dfuPeripheral  else {
            DLog("dfuDidConnectToPeripheral dfuPeripheral is nil")
            dfuFinished()
            return
        }
        
        guard hexUrl != nil else {
            DLog("dfuDidConnectToPeripheral hexPath is nil")
            dfuFinished()
            return
        }

        
        // Start update
        print("Start Update")
        dfuUpdateProcess.delegate = self
        dfuUpdateProcess.startUpdateForPeripheral(dfuPeripheral, hexUrl: hexUrl!, iniUrl: iniUrl, deviceInfoData: deviceInfoData)
    }
    
    func onDfuServiceNotFound() {
        print("DFU service not found")
             dfuFinished()
    }
}

