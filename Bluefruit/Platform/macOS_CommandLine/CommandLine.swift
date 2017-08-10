//
//  CommandLine.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 17/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

class CommandLine: NSObject {
    // Scanning
    fileprivate var discoveredPeripheralsIdentifiers = [UUID]()
    fileprivate var scanResultsShowIndex = false

    // DFU
    fileprivate var dfuSemaphore = DispatchSemaphore(value: 0)
    fileprivate let firmwareUpdater = FirmwareUpdater()
    fileprivate let dfuUpdateProcess = DfuUpdateProcess()
    fileprivate var dfuPeripheral: BlePeripheral?
    fileprivate var hexUrl: URL?
    fileprivate var iniUrl: URL?
    fileprivate var zipUrl: URL?
    fileprivate var releases: [AnyHashable: Any]?
    fileprivate var dFUIgnorePrechecks = false
    
    // MARK: - Bluetooth Status
    func checkBluetoothErrors() -> String? {
        var errorMessage: String?
        let bleManager = BleManager.sharedInstance
        if let state = bleManager.centralManager?.state {
            switch state {
            case .unsupported:
                errorMessage = "This computer doesn't support Bluetooth Low Energy"
            case .unauthorized:
                errorMessage = "The application is not authorized to use the Bluetooth Low Energy"
            case .poweredOff:
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
        print("\tCustom firmware:    dfu --zip <filename> [--uuid <uuid>]")
        print("\tShow this screen:   --help")
        print("\tShow version:       --version")
        print("")
        print("Options:")
        print("\t--uuid <uuid>      If present the peripheral with that uuid is used. If not present a list of peripherals is displayed")
        print("\t--enable-beta      If not present only stable versions are used")
        print("\t--ignore-warnings  Ignore any warnings and continue the update process")

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

    fileprivate func appName() -> String {
        let name = (Swift.CommandLine.arguments[0] as NSString).lastPathComponent
        return name
    }

    func showVersion() {
        let appInfo = Bundle.main.infoDictionary!
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

    private weak var didDiscoverPeripheralObserver: NSObjectProtocol?

    private func startScanningAndShowIndex(_ scanResultsShowIndex: Bool) {
        self.scanResultsShowIndex = scanResultsShowIndex

        // Subscribe to Ble Notifications
        didDiscoverPeripheralObserver = NotificationCenter.default.addObserver(forName: .didDiscoverPeripheral, object: nil, queue: .main, using: didDiscoverPeripheral)

        BleManager.sharedInstance.startScan()
    }

    private func stopScanning() {
        if let didDiscoverPeripheralObserver = didDiscoverPeripheralObserver {NotificationCenter.default.removeObserver(didDiscoverPeripheralObserver)}

        BleManager.sharedInstance.stopScan()
//        BleManager.sharedInstance.reset()
    }

    private func didDiscoverPeripheral(notification: Notification) {

        guard let uuid = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID else { return }

        if let peripheral = BleManager.sharedInstance.peripheral(with: uuid) {

            if !discoveredPeripheralsIdentifiers.contains(uuid) {
                discoveredPeripheralsIdentifiers.append(uuid)

                let name = peripheral.name != nil ? peripheral.name! : "<Unknown>"
                if scanResultsShowIndex {
                    if let index  = discoveredPeripheralsIdentifiers.index(of: uuid) {
                        print("\(index) -> \(uuid) - \(name)")
                    }
                } else {
                    print("\(uuid): \(name)")
                }
            }
        }
    }

    // MARK: - Ask user
    func askUserForPeripheral() -> UUID? {
        print("Scanning... Select a peripheral: ")
        var peripheralIdentifier: UUID? = nil

        startScanningAndShowIndex(true)
        let peripheralIndexString = readLine(strippingNewline: true)
        //DLog("selected: \(peripheralIndexString)")
        if let peripheralIndexString = peripheralIndexString, let peripheralIndex = Int(peripheralIndexString), peripheralIndex>=0 && peripheralIndex < discoveredPeripheralsIdentifiers.count {
            peripheralIdentifier = discoveredPeripheralsIdentifiers[peripheralIndex]

            //print("Selected UUID: \(peripheralUuid!)")
            stopScanning()

            print("")
            //            print("Peripheral selected")

        }

        return peripheralIdentifier
    }

    // MARK: - DFU
    private weak var didConnectToPeripheralObserver: NSObjectProtocol?

    func dfuPeripheral(uuid peripheralUUID: UUID, hexUrl: URL? = nil, iniUrl: URL? = nil, releases: [AnyHashable: Any]? = nil, ignorePreChecks: Bool) {

        self.hexUrl = hexUrl
        self.iniUrl = iniUrl
        self.dFUIgnorePrechecks = ignorePreChecks

        startDfuPeripheral(uuid: peripheralUUID, releases: releases)
    }
    
    func dfuPeripheral(uuid peripheralUUID: UUID, zipUrl: URL, releases: [AnyHashable: Any]? = nil, ignorePreChecks: Bool) {
        self.zipUrl = zipUrl
        self.dFUIgnorePrechecks = ignorePreChecks
        
        startDfuPeripheral(uuid: peripheralUUID, releases: releases)
    }
    
    private func startDfuPeripheral(uuid peripheralUUID: UUID, releases: [AnyHashable: Any]? = nil) {
        guard let centralManager = BleManager.sharedInstance.centralManager else { DLog("centralManager is nil"); return }
        if let peripheral = centralManager.retrievePeripherals(withIdentifiers: [peripheralUUID]).first {
            dfuPeripheral = BlePeripheral(peripheral: peripheral, advertisementData: nil, rssi: nil)
            self.releases = releases
            print("Connecting...")
            
            // Connect to peripheral and discover characteristics. This should not be needed but the Dfu library will fail if a previous characteristics discovery has not been done
            
            // Subscribe to didConnect notifications
            didConnectToPeripheralObserver = NotificationCenter.default.addObserver(forName: .didConnectToPeripheral, object: nil, queue: .main, using: didConnectToPeripheral)
            
            // Connect to peripheral and wait
            BleManager.sharedInstance.connect(to: dfuPeripheral!)
            let _ = dfuSemaphore.wait(timeout: .distantFuture)
            
        } else {
            print("Error. No peripheral found with UUID: \(peripheralUUID.uuidString)")
            dfuPeripheral = nil
        }
    }
    
    private func didConnectToPeripheral(notification: Notification) {
        // Unsubscribe from didConnect notifications
        if let didConnectToPeripheralObserver = didConnectToPeripheralObserver { NotificationCenter.default.removeObserver(didConnectToPeripheralObserver) }

        // Check connected
        guard let dfuPeripheral = dfuPeripheral  else {
            DLog("dfuDidConnectToPeripheral dfuPeripheral is nil")
            dfuFinished()
            return
        }

        // Read services / characteristics
        print("Reading services and characteristics...")
        firmwareUpdater.checkUpdatesForPeripheral(dfuPeripheral, delegate: self, shouldDiscoverServices: true, shouldRecommendBetaReleases: true, versionToIgnore: nil)
    }

    fileprivate func dfuFinished() {
        dfuSemaphore.signal()
    }

    func downloadFirmwareUpdatesDatabase(url dataUrl: URL, showBetaVersions: Bool, completionHandler: (([AnyHashable: Any]?) -> Void)?) {

        FirmwareUpdater.refreshSoftwareUpdatesDatabase(url: dataUrl) { [unowned self] success in
            let boardsInfo = self.firmwareUpdater.releases(showBetaVersions: showBetaVersions)
            completionHandler?(boardsInfo)
        }
        /*
        DataDownloader.downloadDataFromURL(dataUrl) { (data) in
            let boardsInfo = ReleasesParser.parse(data, showBetaVersions: showBetaVersions)
            completionHandler?(boardsInfo)
        }
 */
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

    func onUpdateProcessError(errorMessage: String, infoMessage: String?) {
        BleManager.sharedInstance.restoreCentralManager()

        print(errorMessage)
        dfuFinished()
    }

    func onUpdateProgressText(_ message: String) {
        print("\t"+message)
    }

    func onUpdateProgressValue(_ progress: Double) {
        print(".", terminator: "")
        fflush(__stdoutp)
    }
}

// MARK: - FirmwareUpdaterDelegate
extension CommandLine: FirmwareUpdaterDelegate {

    func onFirmwareUpdateAvailable(isUpdateAvailable: Bool, latestRelease: FirmwareInfo?, deviceInfo: DeviceInformationService?) {

        // Info received
        DLog("onFirmwareUpdatesAvailable: \(isUpdateAvailable)")
        
        if let deviceInfo = deviceInfo {
            print("Peripheral info:")
            print("\tManufacturer: \(deviceInfo.manufacturer ?? "{unknown}")")
            print("\tModel:        \(deviceInfo.modelNumber ?? "{unknown}")")
            print("\tSoftware:     \(deviceInfo.softwareRevision ?? "{unknown}")")
            print("\tFirmware:     \(deviceInfo.firmwareRevision ?? "{unknown}")")
            print("\tBootlader:    \(deviceInfo.bootloaderVersion ?? "{unknown}")")
        }
        
        if !dFUIgnorePrechecks {
            guard deviceInfo != nil else {
                print("DIS characteristic not found")
                dfuFinished()
                return
            }
            
            guard deviceInfo?.hasDefaultBootloaderVersion == false else {
                print("The legacy bootloader on this device is not compatible with this application")
                dfuFinished()
                return
            }
        }

        // Determine final hex and init (depending if is a custom firmware selected by the user, or an automatic update comparing the peripheral version with the update server xml)
        var hexUrl: URL?
        var iniUrl: URL?
        var zipUrl: URL?

        if self.releases != nil {  // Use automatic-update

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
            hexUrl = latestRelease.hexFileUrl
            iniUrl = latestRelease.iniFileUrl
            zipUrl = latestRelease.zipFileUrl
            
        } else {      // is a custom update selected by the user
            hexUrl = self.hexUrl
            iniUrl = self.iniUrl
            zipUrl = self.zipUrl
        }

        // Check update parameters
        guard let dfuPeripheral = dfuPeripheral  else {
            DLog("dfuDidConnectToPeripheral dfuPeripheral is nil")
            dfuFinished()
            return
        }

        guard hexUrl != nil || zipUrl != nil else {
            DLog("dfuDidConnectToPeripheral no update file defined")
            dfuFinished()
            return
        }

        // Start update
        print("Start Update")
        dfuUpdateProcess.delegate = self
        
        if let zipUrl = zipUrl {
            dfuUpdateProcess.startUpdateForPeripheral(peripheral: dfuPeripheral.peripheral, zipUrl: zipUrl)
        }
        else {
            dfuUpdateProcess.startUpdateForPeripheral(peripheral: dfuPeripheral.peripheral, hexUrl: hexUrl!, iniUrl: iniUrl)
        }
    }

    func onDfuServiceNotFound() {
        print("DFU service not found")
             dfuFinished()
    }
}
