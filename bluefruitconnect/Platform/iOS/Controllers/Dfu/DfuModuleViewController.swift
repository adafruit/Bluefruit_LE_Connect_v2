//
//  DfuModuleViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class DfuModuleViewController: ModuleViewController {

    // UI
    @IBOutlet weak var firmwareTableView: UITableView!

    // Data
    private var blePeripheral: BlePeripheral!
    private let firmwareUpdater = FirmwareUpdater()
    private let dfuUpdateProcess = DfuUpdateProcess()
    private var dfuDialogViewController: DfuDialogViewController!
   
    private var boardRelease : BoardInfo?
    private var deviceInfoData : DeviceInfoData?
    private var allReleases: [NSObject: AnyObject]?

    private var isCheckingUpdates = false

    //private let uartManager = UartManager.sharedInstance

    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Peripheral should be connected
        blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        guard blePeripheral != nil else {
            DLog(message: "Error: peripheral must not be null");
            return
        }
        
        // Setup table
        firmwareTableView.contentInset = UIEdgeInsetsMake(44, 0, 0, 0)      // extend below navigation inset fix
        
        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral!.name != nil ? blePeripheral!.name! : localizationManager.localizedString(key: "peripherallist_unnamed")
      let title = String(format: localizationManager.localizedString(key: "dfu_navigation_title_format"), arguments: [name])
        // tabBarController?.navigationItem.title = title
        navigationController?.navigationItem.title = title

        // Init Data
        isCheckingUpdates = false
        boardRelease = nil
        deviceInfoData = nil

        // Start Uart Manager
        //uartManager.blePeripheral = BleManager.sharedInstance.blePeripheralConnected       // Note: this will start the service discovery

        // Notifications
        /*
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        if !uartManager.isReady() {
            notificationCenter.addObserver(self, selector: #selector(uartIsReady(_:)), name: UartManager.UartNotifications.DidBecomeReady.rawValue, object: nil)
        }
        else {
            startUpdatesCheck()
        }
        */
        startUpdatesCheck()
    }
    
    deinit {
        /*
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: UartManager.UartNotifications.DidBecomeReady.rawValue, object: nil)
        */
    }

    /*
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        registerNotifications(true)
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        registerNotifications(false)
    }
 */
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func startUpdatesCheck() {
        
        // Refresh updates available
        if !isCheckingUpdates {
            isCheckingUpdates = true
            let releases = FirmwareUpdater.releases(withBetaVersions: Preferences.showBetaVersions)
            firmwareUpdater.checkUpdates(for: blePeripheral.peripheral, delegate: self, shouldDiscoverServices: false, releases: releases, shouldRecommendBetaReleases: false)
        }
    }
    
    /*
    // MARK: Notifications
    func uartIsReady(notification: NSNotification) {
        DLog("Uart is ready")
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: UartManager.UartNotifications.DidBecomeReady.rawValue, object: nil)

        startUpdatesCheck()
    }*/
    
    // MARK: - Actions
    @IBAction func onClickHelp(_ sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
      helpViewController.setHelp(message: localizationManager.localizedString(key: "dfu_help_text"), title: localizationManager.localizedString(key: "dfu_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender
        
        present(helpNavigationController, animated: true, completion: nil)
    }

    /*
    // MARK: - Preferences
    func registerNotifications(register : Bool) {
        
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        if (register) {
            notificationCenter.addObserver(self, selector: #selector(DfuModuleViewController.preferencesUpdated(_:)), name: Preferences.PreferencesNotifications.DidUpdatePreferences.rawValue, object: nil)
        }
        else {
            notificationCenter.removeObserver(self, name: Preferences.PreferencesNotifications.DidUpdatePreferences.rawValue, object: nil)
        }
    }*/
    
    func preferencesUpdated(notification : NSNotification) {
        // Reload updates
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            let releases = FirmwareUpdater.releases(withBetaVersions: Preferences.showBetaVersions)
            firmwareUpdater.checkUpdates(for: blePeripheral.peripheral, delegate: self, shouldDiscoverServices: false, releases: releases, shouldRecommendBetaReleases: false)
        }
    }

    // MARK: - DFU update
    func confirmDfuUpdateWithFirmware(firmwareInfo : FirmwareInfo) {
        let localizationManager = LocalizationManager.sharedInstance

        let compareBootloader = deviceInfoData!.bootloaderVersion().caseInsensitiveCompare(firmwareInfo.minBootloaderVersion)
        if (compareBootloader == .orderedDescending || compareBootloader == .orderedSame) {        // Requeriments met
            
            let alertTitle = String(format: localizationManager.localizedString(key: "dfu_install_action_title_format"), arguments: [firmwareInfo.version])
            let alertController = UIAlertController(title: alertTitle, message: localizationManager.localizedString(key: "dfu_install_action_message"), preferredStyle: .alert)
            let okAction = UIAlertAction(title: localizationManager.localizedString(key: "dialog_ok"), style: .default) { (action) in
                self.startDfuUpdateWithFirmware(firmwareInfo: firmwareInfo)
            }
            alertController.addAction(okAction)
            let cancelAction = UIAlertAction(title: localizationManager.localizedString(key: "dialog_cancel"), style: .cancel, handler: nil)
            alertController.addAction(cancelAction)
            self.present(alertController, animated: true, completion: nil)
        }
        else {      // Requeriments not met
            let message = String(format: localizationManager.localizedString(key: "dfu_unabletoupdate_bootloader_format"), arguments: [firmwareInfo.version])
            let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                        
            let okAction = UIAlertAction(title: localizationManager.localizedString(key: "dialog_ok"), style: .default, handler: nil)
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func startDfuUpdateWithFirmware(firmwareInfo : FirmwareInfo) {
        let hexUrl = NSURL(string: firmwareInfo.hexFileUrl)!
        let iniUrl =  NSURL(string: firmwareInfo.iniFileUrl)
        startDfuUpdateWithHexInitFiles(hexUrl: hexUrl, iniUrl: iniUrl)
    }
    
    func startDfuUpdateWithHexInitFiles(hexUrl : NSURL, iniUrl: NSURL?) {
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
  
            // Show dialog
            dfuDialogViewController = self.storyboard!.instantiateViewController(withIdentifier: "DfuDialogViewController") as! DfuDialogViewController
            dfuDialogViewController.delegate = self
            self.present(dfuDialogViewController, animated: true, completion: { [unowned self] () -> Void in
                // Setup update process
                self.dfuUpdateProcess.delegate = self
                self.dfuUpdateProcess.startUpdateForPeripheral(peripheral: blePeripheral.peripheral, hexUrl: hexUrl, iniUrl:iniUrl, deviceInfoData: self.deviceInfoData!)
            })
        }
        else {
            onUpdateProcessError(errorMessage: "No peripheral conected. Abort update", infoMessage: nil);
        }
    }
}

// MARK: - FirmwareUpdaterDelegate
extension DfuModuleViewController: FirmwareUpdaterDelegate {
    
    func onFirmwareUpdatesAvailable(_ isUpdateAvailable: Bool, latestRelease: FirmwareInfo!, deviceInfoData: DeviceInfoData!, allReleases: [AnyHashable : Any]?) {
        DLog(message: "onFirmwareUpdatesAvailable")
        
        self.deviceInfoData = deviceInfoData
        
        self.allReleases = allReleases as [NSObject : AnyObject]?
        if let allReleases = allReleases {
            if deviceInfoData?.modelNumber != nil {
                boardRelease = allReleases[deviceInfoData!.modelNumber] as? BoardInfo
            }
            else {
                DLog(message: "Warning: no releases found for this board")
                boardRelease = nil
            }
        }
        else {
            DLog(message: "Warning: no releases found")
        }
        
        // Update UI
        DispatchQueue.main.async { [unowned self] in
            
            if let deviceInfoData = deviceInfoData {
                if deviceInfoData.hasDefaultBootloaderVersion() {
                    self.onUpdateDialogError(errorMessage: "The legacy bootloader on this device is not compatible with this application")
                }
            }
            
            // Refresh
            self.firmwareTableView.reloadData()
            }
    }
    
    func onDfuServiceNotFound() {
        
      onUpdateProcessError(errorMessage: LocalizationManager.sharedInstance.localizedString(key: "dfu_dfunotavailable"), infoMessage: nil)
    }
    
    private func onUpdateDialogError(errorMessage:String, exitOnDismiss: Bool = false) {
        if presentedViewController == nil {
            let localizationManager = LocalizationManager.sharedInstance
            let alertController = UIAlertController(title: nil, message: errorMessage, preferredStyle: .alert)
            
            let handler = { [unowned self] (_: UIAlertAction) -> () in
                if exitOnDismiss {
                    DLog(message: "dismiss dfu")
                    self.tabBarController?.navigationController?.popViewController(animated: true)
                }
            }
          let okAction = UIAlertAction(title: localizationManager.localizedString(key: "dialog_ok"), style: .default, handler:handler)
            alertController.addAction(okAction)
            
          self.present(alertController, animated: true, completion: nil)
        }
    }
}

// MARK: - UITableViewDataSource
extension DfuModuleViewController: UITableViewDataSource {
    
    enum DfuSection : Int  {
        case CurrentVersion = 0
        case FirmwareReleases = 1
        case BootloaderReleases = 2
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch DfuSection(rawValue: section)! {
        case .CurrentVersion:
            return 1
        case .FirmwareReleases:
            var numRows = 1      // at least a custom firmware button
            if let firmwareReleases = boardRelease?.firmwareReleases {
                numRows += firmwareReleases.count
            }
            else {              // Show all releases
                if let allReleases = allReleases {
                    for (_, value) in allReleases {
                        let boardInfo = value as! BoardInfo
                        numRows += boardInfo.firmwareReleases.count
                    }
                }
            }
            return numRows
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        var localizationKey: String!
        
        switch DfuSection(rawValue: section)! {
        case .CurrentVersion:
            localizationKey = "dfu_currentversion_title"
        case .FirmwareReleases:
            localizationKey = "dfu_firmwarereleases_title"
        default:
            localizationKey = "dfu_bootloaderreleases_title"
        }
        
      return LocalizationManager.sharedInstance.localizedString(key: localizationKey)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell!
        switch DfuSection(rawValue: indexPath.section)! {
            
        case .CurrentVersion:
            let reuseIdentifier = "PeripheralCell"
            cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .subtitle, reuseIdentifier: reuseIdentifier)
            }
            
            
        default:
            let isLastRow = indexPath.row == tableView.numberOfRows(inSection: indexPath.section)-1
            if isLastRow {
                let reuseIdentifier = "FilesPickerCell"
                cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath as IndexPath)
                
            }
            else {
                let reuseIdentifier = "FirmwareCell"
              cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
                if cell == nil {
                  cell = UITableViewCell(style: .subtitle, reuseIdentifier: reuseIdentifier)
                }
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let localizationManager = LocalizationManager.sharedInstance

        switch DfuSection(rawValue: indexPath.section)! {
        case .CurrentVersion:
            var firmwareString : String?
            if let softwareRevision = deviceInfoData?.softwareRevision {
              firmwareString = String(format: localizationManager.localizedString(key: "dfu_firmware_format"), arguments: [softwareRevision])
            }
            cell.textLabel!.text = blePeripheral.name
            cell.textLabel!.backgroundColor = UIColor.clear
            cell.detailTextLabel!.text = firmwareString
            cell.detailTextLabel!.backgroundColor = UIColor.clear
            
            cell.contentView.backgroundColor = UIColor(hex: 0xeeeeee)
            cell.selectionStyle = .none
            
        default:
          let isLastRow = indexPath.row == tableView.numberOfRows(inSection: indexPath.section)-1
            if isLastRow {  // User files
                let pickerCell = cell as! DfuFilesPickerTableViewCell
                pickerCell.onPickFiles = { [unowned self] in
                  let viewController = self.storyboard!.instantiateViewController(withIdentifier: "DfuFilesPickerDialogViewController") as! DfuFilesPickerDialogViewController
                    viewController.delegate = self
                  self.present(viewController, animated: true, completion: nil)
                }
              cell.selectionStyle = .none
            }
            else {
              let firmwareInfo = firmwareInfoForRow(row: indexPath.row)
                //let firmwareInfo = boardRelease?.firmwareReleases[indexPath.row] as! FirmwareInfo
              let versionFormat = localizationManager.localizedString(key: firmwareInfo.isBeta ? "dfu_betaversion_format" : "dfu_version_format")
                cell.textLabel!.text = String(format: versionFormat , arguments: [firmwareInfo.version])
                cell.detailTextLabel!.text = firmwareInfo.boardName
            }
            
          cell.contentView.backgroundColor = UIColor.white
          cell.selectionStyle = isLastRow ? .none: .blue

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
                
                let sortedKeys = allReleases!.keys.sorted(by: {($0 as! String) < ($1 as! String)})        // Order alphabetically
                let currentKey = sortedKeys[currentBoardIndex]
                let boardRelease = allReleases![currentKey] as! BoardInfo
                
                // order versions numerically
                let firmwareReleases = boardRelease.firmwareReleases.sorted(by: { (firmwareA, firmwareB) -> Bool in
                    let versionA = (firmwareA as! FirmwareInfo).version
                    let versionB = (firmwareB as! FirmwareInfo).version
                return versionA?.compare(versionB!, options: .numeric) == .orderedAscending
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

// MARK: UITableViewDelegate
extension DfuModuleViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedRow = indexPath.row
        
        switch DfuSection(rawValue: indexPath.section)! {
            
        case .FirmwareReleases:
            if (selectedRow >= 0) {
                if (deviceInfoData!.hasDefaultBootloaderVersion()) {
                  onUpdateProcessError(errorMessage: LocalizationManager.sharedInstance.localizedString(key: "dfu_legacybootloader"), infoMessage: nil)
                }
                else {
                  let firmwareInfo = firmwareInfoForRow(row: indexPath.row)
                    confirmDfuUpdateWithFirmware(firmwareInfo: firmwareInfo)
                }
            }
            
        default:
            break
        }
        
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    
}

// MARK: - UpdateDialogViewControlerDelegate
extension DfuModuleViewController: DfuDialogViewControllerDelegate {
    
    func onUpdateDialogCancel() {
        dfuUpdateProcess.cancel()
        BleManager.sharedInstance.restoreCentralManager()
        
    }
}

// MARK: - DfuUpdateProcessDelegate
extension  DfuModuleViewController: DfuUpdateProcessDelegate {
    func onUpdateProcessSuccess() {
        
        if let dfuDialogViewController = self.dfuDialogViewController {
            dfuDialogViewController.dismiss(animated: false, completion: nil)
        }
        
        BleManager.sharedInstance.restoreCentralManager()
        
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: nil, message: localizationManager.localizedString(key: "dfu_udaptedcompleted_message"), preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: localizationManager.localizedString(key: "dialog_ok"), style: .default) { [unowned self] _ in
            self.gotoScanController()
        }
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    private func gotoScanController() {
        // Simulate disonnection to trigger the go back to scanning
        NotificationCenter.default.post(name: .bleDidDisconnectFromPeripheral, object: nil,  userInfo: nil)
        
    }
    
    func onUpdateProcessError(errorMessage : String, infoMessage: String?) {
        BleManager.sharedInstance.restoreCentralManager()
        
        if let dfuDialogViewController = self.dfuDialogViewController {
            dfuDialogViewController.dismiss(animated: false, completion: nil)
        }
        
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: (infoMessage != nil ? errorMessage:nil), message: (infoMessage != nil ? infoMessage : errorMessage), preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: localizationManager.localizedString(key: "dialog_ok"), style: .default) { [weak self] _ in
             self?.gotoScanController()
        }
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }


    func onUpdateProgressText(message: String) {
        DispatchQueue.main.async { [unowned self] in
            self.dfuDialogViewController?.setProgressText(text: message)
            }
    }
    
    func onUpdateProgressValue(progress : Double) {
        DispatchQueue.main.async { [unowned self] in
            self.dfuDialogViewController?.setProgress(value: progress)
            }
    }
}


// MARK: - DfuUpdateProcessDelegate
extension DfuModuleViewController: DfuFilesPickerDialogViewControllerDelegate {

    func onFilesPickerStartUpdate(hexUrl: NSURL?, iniUrl: NSURL?) {
        if let hexUrl = hexUrl {
            // Show dialog
            dfuDialogViewController = self.storyboard!.instantiateViewController(withIdentifier: "DfuDialogViewController") as! DfuDialogViewController
            self.present(dfuDialogViewController, animated: true, completion: { [unowned self] () -> Void in
                // Setup update process
                self.dfuUpdateProcess.delegate = self
                self.dfuUpdateProcess.startUpdateForPeripheral(peripheral: self.blePeripheral.peripheral, hexUrl: hexUrl, iniUrl:iniUrl, deviceInfoData: self.deviceInfoData!)
                })
        }
        else {
            let localizationManager = LocalizationManager.sharedInstance
            let alertController = UIAlertController(title: nil, message: "At least an Hex file should be selected", preferredStyle: .alert)
            
            let okAction = UIAlertAction(title: localizationManager.localizedString(key: "dialog_ok"), style: .default, handler: nil)
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func onFilesPickerCancel() {
        
    }
}

/*
// MARK: - CBPeripheralDelegate
extension DfuModuleViewController: CBPeripheralDelegate {
    // Pass peripheral callbacks to UartData
    
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        uartManager.peripheral(peripheral, didModifyServices: invalidatedServices)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        uartManager.peripheral(peripheral, didDiscoverServices:error)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        
        uartManager.peripheral(peripheral, didDiscoverCharacteristicsForService: service, error: error)
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        uartManager.peripheral(peripheral, didUpdateValueForCharacteristic: characteristic, error: error)
    }
}
*/
