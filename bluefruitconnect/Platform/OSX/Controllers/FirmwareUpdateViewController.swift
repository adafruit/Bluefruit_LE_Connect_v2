//
//  FirmwareUpdateViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 26/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class FirmwareUpdateViewController: NSViewController {
    
    // UI
    @IBOutlet weak var firmwareCurrentVersionLabel: NSTextField!
    @IBOutlet weak var firmwareCurrentVersionWaitView: NSProgressIndicator!
    @IBOutlet weak var firmwareTableView: NSTableView!
    @IBOutlet weak var firmwareWaitView: NSProgressIndicator!
    @IBOutlet weak var hexFileTextField: NSTextField!
    @IBOutlet weak var iniFileTextField: NSTextField!
    
    // Data
    private let firmwareUpdater = FirmwareUpdater()
    private let dfuUpdateProcess = DfuUpdateProcess()
    private var updateDialogViewController: UpdateDialogViewController?
    
    private var boardRelease: BoardInfo?
    private var deviceInfoData: DeviceInfoData?
    private var allReleases: [NSObject: AnyObject]?
    
    private var isTabVisible = false
    private var isCheckingUpdates = false
    
    var infoFinishedScanning = false {
        didSet {
            if infoFinishedScanning != oldValue {
                DLog("updates infoFinishedScanning: \(infoFinishedScanning)")
                if infoFinishedScanning && isTabVisible {
                    startUpdatesCheck()
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // UI
        firmwareWaitView.startAnimation(nil)
        firmwareCurrentVersionWaitView.startAnimation(nil)
        firmwareCurrentVersionLabel.stringValue = ""
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        registerNotifications(true)
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        registerNotifications(false)
    }

    func startUpdatesCheck() {
        // Refresh updates available
        if !isCheckingUpdates {
            if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
                isCheckingUpdates = true
                let releases = FirmwareUpdater.releasesWithBetaVersions(Preferences.showBetaVersions)
                firmwareUpdater.checkUpdatesForPeripheral(blePeripheral.peripheral, delegate: self, shouldDiscoverServices: false, releases: releases, shouldRecommendBetaReleases: false)
            }
        }
    }

    // MARK: - Preferences
    func registerNotifications(register : Bool) {
        
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        if (register) {
            notificationCenter.addObserver(self, selector: #selector(FirmwareUpdateViewController.preferencesUpdated(_:)), name: Preferences.PreferencesNotifications.DidUpdatePreferences.rawValue, object: nil)
        }
        else {
            notificationCenter.removeObserver(self, name: Preferences.PreferencesNotifications.DidUpdatePreferences.rawValue, object: nil)
        }
    }

    func preferencesUpdated(notification : NSNotification) {
        // Reload updates
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            let releases = FirmwareUpdater.releasesWithBetaVersions(Preferences.showBetaVersions)
            firmwareUpdater.checkUpdatesForPeripheral(blePeripheral.peripheral, delegate: self, shouldDiscoverServices: false, releases: releases, shouldRecommendBetaReleases: false)
        }
    }

    // MARK: - 
    
    @IBAction func onClickChooseInitFile(sender: AnyObject) {
        chooseFile(false)
    }
    
    @IBAction func onClickChooseHexFile(sender: AnyObject) {
        chooseFile(true)
    }
    
    func chooseFile(isHexFile : Bool) {
        let openFileDialog = NSOpenPanel()
        openFileDialog.canChooseFiles = true
        openFileDialog.canChooseDirectories = false
        openFileDialog.allowsMultipleSelection = false
        openFileDialog.canCreateDirectories = false
        
        if let window = self.view.window {
            openFileDialog.beginSheetModalForWindow(window) {[unowned self] (result) -> Void in
                if result == NSFileHandlingPanelOKButton {
                    if let url = openFileDialog.URL {
                        
                        if (isHexFile) {
                            self.hexFileTextField.stringValue = url.path!
                        }
                        else {
                            self.iniFileTextField.stringValue = url.path!
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func onClickCustomFirmwareUpdate(sender: AnyObject) {
        guard deviceInfoData != nil else {
            DLog("deviceInfoData is nil");
            return
        }
        
        guard !deviceInfoData!.hasDefaultBootloaderVersion() else {
            onUpdateProcessError("The legacy bootloader on this device is not compatible with this application", infoMessage: nil)
            return
        }

        guard !hexFileTextField.stringValue.isEmpty else {
            onUpdateProcessError("At least an Hex file should be selected", infoMessage: nil)
            return
        }
        
        let hexUrl = NSURL(fileURLWithPath: hexFileTextField.stringValue)
        var iniUrl :NSURL? = nil
        
        if !iniFileTextField.stringValue.isEmpty {
            iniUrl = NSURL(fileURLWithPath: iniFileTextField.stringValue)
        }
        
        startDfuUpdateWithHexInitFiles(hexUrl, iniUrl: iniUrl)
    }
       
    // MARK: - DFU update
    func confirmDfuUpdateWithFirmware(firmwareInfo : FirmwareInfo) {
        let compareBootloader = deviceInfoData!.bootloaderVersion().caseInsensitiveCompare(firmwareInfo.minBootloaderVersion)
        if (compareBootloader == .OrderedDescending || compareBootloader == .OrderedSame) {        // Requeriments met
            let alert = NSAlert()
            alert.messageText = "Install firmware version \(firmwareInfo.version)?"
            alert.informativeText = "The firmware will be downloaded and updated. Please wait until the process finishes before disconnecting the peripheral"
            alert.addButtonWithTitle("Ok")
            alert.addButtonWithTitle("Cancel")
            alert.alertStyle = .WarningAlertStyle
            alert.beginSheetModalForWindow(self.view.window!, completionHandler: { [unowned self](modalResponse) -> Void in
                if (modalResponse == NSAlertFirstButtonReturn) {
                    self.startDfuUpdateWithFirmware(firmwareInfo)
                }
            })
        }
        else {      // Requeriments not met
            let alert = NSAlert()
            alert.messageText = "This firmware update is not compatible with your bootloader. You need to update your bootloader to version %@ before installing this firmware release \(firmwareInfo.version)"
            alert.addButtonWithTitle("Ok")
            alert.alertStyle = .WarningAlertStyle
            alert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
        }
    }
    
    func startDfuUpdateWithFirmware(firmwareInfo : FirmwareInfo) {
        let hexUrl = NSURL(string: firmwareInfo.hexFileUrl)!
        let iniUrl =  NSURL(string: firmwareInfo.iniFileUrl)
        startDfuUpdateWithHexInitFiles(hexUrl, iniUrl: iniUrl)
    }
    
    func startDfuUpdateWithHexInitFiles(hexUrl : NSURL, iniUrl: NSURL?) {
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
     
            // Setup update process
            dfuUpdateProcess.startUpdateForPeripheral(blePeripheral.peripheral, hexUrl: hexUrl, iniUrl:iniUrl, deviceInfoData: deviceInfoData!)
            dfuUpdateProcess.delegate = self

            // Show dialog
            updateDialogViewController = (self.storyboard?.instantiateControllerWithIdentifier("UpdateDialogViewController") as! UpdateDialogViewController)
            updateDialogViewController!.delegate = self
            self.presentViewControllerAsModalWindow(updateDialogViewController!)
        }
        else {
            onUpdateProcessError("No peripheral conected. Abort update", infoMessage: nil);
        }
    }
}

// MARK: - DetailTab
extension FirmwareUpdateViewController : DetailTab {
    func tabWillAppear() {
        isTabVisible = true
        if infoFinishedScanning {
            startUpdatesCheck()
        }
    }
    
    func tabWillDissapear() {
        isTabVisible = false
    }
    
    func tabReset() {
        isCheckingUpdates = false
        boardRelease = nil
        deviceInfoData = nil
    }
}

// MARK: - FirmwareUpdaterDelegate
extension FirmwareUpdateViewController : FirmwareUpdaterDelegate {
    func onFirmwareUpdatesAvailable(isUpdateAvailable: Bool, latestRelease: FirmwareInfo!, deviceInfoData: DeviceInfoData?, allReleases: [NSObject : AnyObject]?) {
        DLog("onFirmwareUpdatesAvailable")
        
        self.deviceInfoData = deviceInfoData
        
        self.allReleases = allReleases
        if let allReleases = allReleases {
            if let modelNumber = deviceInfoData?.modelNumber {
                boardRelease = allReleases[modelNumber] as? BoardInfo
            }
            else {
                DLog("Warning: no releases found for this board")
                boardRelease = nil
            }
        }
        else {
            DLog("Warning: no releases found")
        }
        
        // Update UI
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.firmwareWaitView.stopAnimation(nil)
            self.firmwareTableView.reloadData()
            
            self.firmwareCurrentVersionLabel.stringValue = "<Unknown>"
            if let deviceInfoData = deviceInfoData {
                if (deviceInfoData.hasDefaultBootloaderVersion()) {
                    self.onUpdateProcessError("The legacy bootloader on this device is not compatible with this application", infoMessage: nil)
                }
                if (deviceInfoData.softwareRevision != nil) {
                    self.firmwareCurrentVersionLabel.stringValue = deviceInfoData.softwareRevision
                }
            }
            
            self.firmwareCurrentVersionWaitView.stopAnimation(nil)
            })
    }
    
    func onDfuServiceNotFound() {
        onUpdateProcessError("No DFU Service found on device", infoMessage: nil)
    }
}

// MARK: - NSTableViewDataSource
extension FirmwareUpdateViewController : NSTableViewDataSource {
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        if let firmwareReleases = boardRelease?.firmwareReleases {
            return firmwareReleases.count
        }
        else {
            // Show all releases
            var numReleases = 0
            if let allReleases = allReleases {
                for (_, value) in allReleases {
                    let boardInfo = value as! BoardInfo
                    numReleases += boardInfo.firmwareReleases.count
                }
            }
            return numReleases
        }
    }
}

// MARK: NSTableViewDelegate
extension FirmwareUpdateViewController : NSTableViewDelegate {
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {

        let firmwareInfo = firmwareInfoForRow(row)
        
        var cell = NSTableCellView()
        
        if let columnIdentifier = tableColumn?.identifier {
            switch columnIdentifier {
            case "VersionColumn":
                cell = tableView.makeViewWithIdentifier("FirmwareVersionCell", owner: self) as! NSTableCellView
                
                var text = firmwareInfo.version
                if text == nil {
                    text = "<unknown>"
                }
                if firmwareInfo.isBeta {
                    text! += " Beta"
                }
                cell.textField?.stringValue = text
                
            case "TypeColumn":
                cell = tableView.makeViewWithIdentifier("FirmwareTypeCell", owner: self) as! NSTableCellView
                
                cell.textField?.stringValue = firmwareInfo.boardName
                
            default:
                cell.textField?.stringValue = ""
            }
        }
        
        return cell;
    }

    func tableViewSelectionDidChange(notification: NSNotification) {
        
        let selectedRow = firmwareTableView.selectedRow
        if selectedRow >= 0 {
            if (deviceInfoData!.hasDefaultBootloaderVersion()) {
                onUpdateProcessError("The legacy bootloader on this device is not compatible with this application", infoMessage: nil)
            }
            else {
                let firmwareInfo = firmwareInfoForRow(selectedRow)
                
                confirmDfuUpdateWithFirmware(firmwareInfo)
                firmwareTableView.deselectAll(nil)
            }
        }
        
    }
    
    private func firmwareInfoForRow(row: Int) -> FirmwareInfo {
        var firmwareInfo: FirmwareInfo!
        
        if let firmwareReleases: NSArray = boardRelease?.firmwareReleases {     // If showing releases for a specific board
            let firmwareInfos = firmwareReleases as! [FirmwareInfo]
            firmwareInfo = firmwareInfos[row]
        }
        else {      // If showing all available releases
            var currentRow = 0
            var currentBoardIndex = 0
            while currentRow <= row {
                
                let sortedKeys = allReleases!.keys.sort({($0 as! String) < ($1 as! String)})        // Order alphabetically
                let currentKey = sortedKeys[currentBoardIndex]
                let boardRelease = allReleases![currentKey] as! BoardInfo
                
                        // order versions numerically
                let firmwareReleases = boardRelease.firmwareReleases.sort({ (firmwareA, firmwareB) -> Bool in
                    let versionA = (firmwareA as! FirmwareInfo).version
                    let versionB = (firmwareB as! FirmwareInfo).version
                    return versionA.compare(versionB, options: .NumericSearch) == .OrderedAscending
                })
                    
                let numReleases = firmwareReleases.count
                let remaining = row - currentRow
                if remaining < numReleases {
                    firmwareInfo = firmwareReleases[remaining] as! FirmwareInfo
                }
                else {
                    currentBoardIndex += 1
                }
                currentRow += numReleases
            }
        }

        return firmwareInfo
    }
}

// MARK: - UpdateDialogViewControlerDelegate
extension FirmwareUpdateViewController : UpdateDialogControllerDelegate {
    
    func onUpdateDialogCancel() {
        
        dfuUpdateProcess.cancel()
        BleManager.sharedInstance.restoreCentralManager()

        if let updateDialogViewController = updateDialogViewController {
            dismissViewController(updateDialogViewController);
            self.updateDialogViewController = nil
        }
        

        updateDialogViewController = nil
    }
}

// MARK: - DfuUpdateProcessDelegate
extension FirmwareUpdateViewController : DfuUpdateProcessDelegate {
    func onUpdateProcessSuccess() {
        BleManager.sharedInstance.restoreCentralManager()
        
        if let updateDialogViewController = updateDialogViewController {
            dismissViewController(updateDialogViewController);
            self.updateDialogViewController = nil
        }
        
        if let window = self.view.window {
            let alert = NSAlert()
            alert.messageText = "Update completed successfully"
            alert.addButtonWithTitle("Ok")
            alert.alertStyle = .WarningAlertStyle
            alert.beginSheetModalForWindow(window, completionHandler: nil)
        }
        else {
            DLog("onUpdateDialogSuccess: window not defined")
        }
    }
    
    func onUpdateProcessError(errorMessage : String, infoMessage: String?) {
        BleManager.sharedInstance.restoreCentralManager()
        
        if let updateDialogViewController = updateDialogViewController {
            dismissViewController(updateDialogViewController);
            self.updateDialogViewController = nil
        }
        
        if let window = self.view.window {
            let alert = NSAlert()
            alert.messageText = errorMessage
            if let infoMessage = infoMessage {
                alert.informativeText = infoMessage
            }
            alert.addButtonWithTitle("Ok")
            alert.alertStyle = .WarningAlertStyle
            alert.beginSheetModalForWindow(window, completionHandler: nil)
        }
        else {
            DLog("onUpdateDialogError: window not defined when showing dialog with message: \(errorMessage)")
        }
    }
    
    func onUpdateProgressText(message: String) {
        updateDialogViewController?.setProgressText(message)
    }
    
    func onUpdateProgressValue(progress : Double) {
        updateDialogViewController?.setProgress(progress)
    }
}
