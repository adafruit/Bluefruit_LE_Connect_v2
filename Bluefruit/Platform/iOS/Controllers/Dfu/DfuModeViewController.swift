//
//  DfuModeViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class DfuModeViewController: PeripheralModeViewController {

    // UI
    @IBOutlet weak var firmwareTableView: UITableView!

    // Data
    fileprivate let firmwareUpdater = FirmwareUpdater()
    fileprivate let dfuUpdateProcess = DfuUpdateProcess()
    fileprivate var dfuDialogViewController: DfuDialogViewController!

    fileprivate var boardRelease: BoardInfo?
    fileprivate var dis: DeviceInformationService?
    fileprivate var allReleases: [String: BoardInfo]?

    fileprivate var isCheckingUpdates = false
    fileprivate var isFirsRun = true

    override func viewDidLoad() {
        super.viewDidLoad()

        assert(blePeripheral != nil)

        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral?.name ?? LocalizationManager.sharedInstance.localizedString("scanner_unnamed")
        self.title = traitCollection.horizontalSizeClass == .regular ? String(format: localizationManager.localizedString("dfu_navigation_title_format"), arguments: [name]) : localizationManager.localizedString("dfu_tab_title")
    
        // Init Data
        isCheckingUpdates = false
        boardRelease = nil
        dis = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if isFirsRun {
            isFirsRun = false
            // Check updates
            startUpdatesCheck()
        }

        // Notifications
        registerNotifications(enabled: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Notifications
        registerNotifications(enabled: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - BLE Notifications
    private weak var didUpdatePreferencesObserver: NSObjectProtocol?

    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            didUpdatePreferencesObserver = notificationCenter.addObserver(forName: .didUpdatePreferences, object: nil, queue: .main, using: didUpdatePreferences)
        } else {
            if let didUpdatePreferencesObserver = didUpdatePreferencesObserver {notificationCenter.removeObserver(didUpdatePreferencesObserver)}
        }
    }

    private func didUpdatePreferences(notification: Notification) {
        startUpdatesCheck()
    }

    // MARK: - Updates
    func startUpdatesCheck() {
        guard let blePeripheral = blePeripheral, !isCheckingUpdates else { return }

        // Refresh updates available
        isCheckingUpdates = true
        firmwareUpdater.checkUpdatesForPeripheral(blePeripheral, delegate: self, shouldDiscoverServices: false, shouldRecommendBetaReleases: false, versionToIgnore: nil)
    }

    // MARK: - Actions
    @IBAction func onClickHelp(_ sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("dfu_help_text"), title: localizationManager.localizedString("dfu_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender

        present(helpNavigationController, animated: true, completion: nil)
    }

    // MARK: - DFU update
    func confirmDfuUpdateWithFirmware(_ firmwareInfo: FirmwareInfo) {
        guard let dis = dis, let firmwareBootloaderVersion = firmwareInfo.minBootloaderVersion else {
            DLog("Error: Not ready to update")
            return
        }

        let localizationManager = LocalizationManager.sharedInstance

        let compareBootloader = dis.bootloaderVersion?.caseInsensitiveCompare(firmwareBootloaderVersion)
        if compareBootloader == .orderedDescending || compareBootloader == .orderedSame {        // Requeriments met

            let alertTitle = String(format: localizationManager.localizedString("dfu_install_action_title_format"), arguments: [firmwareInfo.version])
            let alertController = UIAlertController(title: alertTitle, message: localizationManager.localizedString("dfu_install_action_message"), preferredStyle: .alert)
            let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default) { (action) in
                 self.startDfuUpdateWithFirmware(firmwareInfo)
            }
            alertController.addAction(okAction)
            let cancelAction = UIAlertAction(title: localizationManager.localizedString("dialog_cancel"), style: .cancel, handler: nil)
            alertController.addAction(cancelAction)
            self.present(alertController, animated: true, completion: nil)
        } else {      // Requeriments not met
            let message = String(format: localizationManager.localizedString("dfu_unabletoupdate_bootloader_format"), arguments: [firmwareInfo.version])
            let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)

            let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler: nil)
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }

    func startDfuUpdateWithFirmware(_ firmwareInfo: FirmwareInfo) {
        guard let hexUrl = firmwareInfo.hexFileUrl else { return }
        let iniUrl = firmwareInfo.iniFileUrl
        startDfuUpdate(hexUrl: hexUrl, iniUrl: iniUrl)
    }

    func startDfuUpdate(hexUrl: URL, iniUrl: URL?) {
        guard let blePeripheral = blePeripheral else {
            onUpdateProcessError(errorMessage: "No peripheral conected. Abort update", infoMessage: nil)
            return
        }

        // Show dialog
        dfuDialogViewController = self.storyboard!.instantiateViewController(withIdentifier: "DfuDialogViewController") as! DfuDialogViewController
        dfuDialogViewController.delegate = self
        self.present(dfuDialogViewController, animated: true, completion: { [unowned self] () -> Void in
            // Setup update process
            self.dfuUpdateProcess.delegate = self
            self.dfuUpdateProcess.startUpdateForPeripheral(peripheral: blePeripheral.peripheral, hexUrl: hexUrl, iniUrl:iniUrl)
        })
    }
}

// MARK: - FirmwareUpdaterDelegate
extension DfuModeViewController: FirmwareUpdaterDelegate {

    func onFirmwareUpdateAvailable(isUpdateAvailable: Bool, latestRelease: FirmwareInfo?, deviceInfo: DeviceInformationService?) {
        DLog("onFirmwareUpdatesAvailable")

        self.dis = deviceInfo
        self.allReleases = nil
        self.boardRelease = nil

        if self.dis != nil {
            self.allReleases = firmwareUpdater.releases(showBetaVersions: Preferences.showBetaVersions)

            if let allReleases = allReleases {
                if let modelNumber = deviceInfo?.modelNumber {
                    boardRelease = allReleases[modelNumber]
                } else {
                    DLog("Warning: no releases found for this board")
                    boardRelease = nil
                }
            } else {
                DLog("Warning: no releases found")
            }
        }

        // Update UI
        DispatchQueue.main.async { [unowned self] in
            if self.dis == nil {
                showErrorAlert(from: self, title: LocalizationManager.sharedInstance.localizedString("dialog_error"), message: "Device Information Service not found. Unable to peform an OTA DFU update")
            } else if let dis = self.dis, dis.hasDefaultBootloaderVersion {
                showErrorAlert(from: self, title: LocalizationManager.sharedInstance.localizedString("dialog_error"), message: LocalizationManager.sharedInstance.localizedString("dfu_legacybootloader"))
            }

            // Refresh
            self.firmwareTableView.reloadData()
        }
    }

    func onDfuServiceNotFound() {

        onUpdateProcessError(errorMessage: LocalizationManager.sharedInstance.localizedString("dfu_dfunotavailable"), infoMessage: nil)
    }

    fileprivate func onUpdateDialogError(_ errorMessage: String) {
        guard presentedViewController == nil else { return }

        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: nil, message: errorMessage, preferredStyle: .alert)

        let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler: nil)
        alertController.addAction(okAction)

        self.present(alertController, animated: true, completion: nil)
    }
}

// MARK: - UITableViewDataSource
extension DfuModeViewController: UITableViewDataSource {

    enum DfuSection: Int {
        case currentVersion = 0
        case firmwareReleases = 1
        case bootloaderReleases = 2
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch DfuSection(rawValue: section)! {
        case .currentVersion:
            return 1
        case .firmwareReleases:
            var numRows = 1      // at least a custom firmware button
            if let firmwareReleases = boardRelease?.firmwareReleases {
                numRows += firmwareReleases.count
            } else {              // Show all releases
                if let allReleases = allReleases {
                    for (_, boardInfo) in allReleases {
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
        case .currentVersion:
            localizationKey = "dfu_currentversion_title"
        case .firmwareReleases:
            localizationKey = "dfu_firmwarereleases_title"
        default:
            localizationKey = "dfu_bootloaderreleases_title"
        }

        return LocalizationManager.sharedInstance.localizedString(localizationKey)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell!

        switch DfuSection(rawValue: indexPath.section)! {
        case .currentVersion:
            let reuseIdentifier = "PeripheralCell"
            cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .subtitle, reuseIdentifier: reuseIdentifier)
            }

        default:
            let isLastRow = indexPath.row == tableView.numberOfRows(inSection: indexPath.section)-1
            if isLastRow {
                let reuseIdentifier = "FilesPickerCell"
                cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)

            } else {
                let reuseIdentifier = "FirmwareCell"
                cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
                if cell == nil {
                    cell = UITableViewCell(style: .subtitle, reuseIdentifier: reuseIdentifier)
                }
            }
        }

        return cell
    }
}

// MARK: UITableViewDelegate
extension DfuModeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let localizationManager = LocalizationManager.sharedInstance
        
        switch DfuSection(rawValue: indexPath.section)! {
        case .currentVersion:
            var firmwareString: String?
            if let softwareRevision = dis?.softwareRevision {
                firmwareString = String(format: localizationManager.localizedString("dfu_firmware_format"), arguments: [softwareRevision])
            }
            cell.textLabel!.text = blePeripheral?.name
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
            } else {
                let firmwareInfo = firmwareInfoForRow(indexPath.row)
                let versionFormat = localizationManager.localizedString(firmwareInfo.isBeta ? "dfu_betaversion_format" : "dfu_version_format")
                cell.textLabel!.text = String(format: versionFormat, arguments: [firmwareInfo.version])
                cell.detailTextLabel!.text = firmwareInfo.boardName
            }
            
            cell.contentView.backgroundColor = UIColor.white
            cell.selectionStyle = isLastRow ? .none:.blue
            
        }
    }
    
    private func firmwareInfoForRow(_ row: Int) -> FirmwareInfo {
        var firmwareInfo: FirmwareInfo!
        
        if let firmwareReleases = boardRelease?.firmwareReleases {     // If showing releases for a specific board
            firmwareInfo = firmwareReleases[row]
        } else {      // If showing all available releases
            var currentRow = 0
            var currentBoardIndex = 0
            while currentRow <= row {
                
                let sortedKeys = allReleases!.keys.sorted(by: <)        // Order alphabetically
                let currentKey = sortedKeys[currentBoardIndex]
                let boardRelease = allReleases![currentKey]
                
                // order versions numerically
                let firmwareReleases = boardRelease!.firmwareReleases.sorted(by: { (firmwareA, firmwareB) -> Bool in
                    let versionA = (firmwareA ).version
                    let versionB = (firmwareB ).version
                    return versionA.compare(versionB, options: .numeric) == .orderedAscending
                })
                
                let numReleases = firmwareReleases.count
                let remaining = row - currentRow
                if remaining < numReleases {
                    firmwareInfo = firmwareReleases[remaining]
                } else {
                    currentBoardIndex += 1
                }
                currentRow += numReleases
            }
        }
        
        return firmwareInfo
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let dis = dis else {
            showErrorAlert(from: self, title: LocalizationManager.sharedInstance.localizedString("dialog_error"), message: "Device Information Service not found. Unable to peform an OTA DFU update")
            return
        }

        let selectedRow = indexPath.row

        switch DfuSection(rawValue: indexPath.section)! {

        case .firmwareReleases:
            if selectedRow >= 0 {
                if dis.hasDefaultBootloaderVersion {
                    showErrorAlert(from: self, title: LocalizationManager.sharedInstance.localizedString("dialog_error"), message: LocalizationManager.sharedInstance.localizedString("dfu_legacybootloader"))
                    //onUpdateProcessError(errorMessage: LocalizationManager.sharedInstance.localizedString("dialog_error"), infoMessage: LocalizationManager.sharedInstance.localizedString("dfu_legacybootloader"))
                } else {
                    let firmwareInfo = firmwareInfoForRow(indexPath.row)
                    confirmDfuUpdateWithFirmware(firmwareInfo)
                }
            }

        default:
            break
        }

        tableView .deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - UpdateDialogViewControlerDelegate
extension DfuModeViewController: DfuDialogViewControllerDelegate {

    func onUpdateDialogCancel() {
        dfuUpdateProcess.cancel()
        //BleManager.sharedInstance.restoreCentralManager()
        restoreCentralManager()
    }
}

// MARK: - DfuUpdateProcessDelegate
extension  DfuModeViewController: DfuUpdateProcessDelegate {
    func onUpdateProcessSuccess() {
        if let dfuDialogViewController = self.dfuDialogViewController {
            dfuDialogViewController.dismiss(animated: false, completion: nil)
        }
        //BleManager.sharedInstance.restoreCentralManager()

        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: nil, message: localizationManager.localizedString("dfu_udaptedcompleted_message"), preferredStyle: .alert)

        let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default) { [unowned self] _ in
            //self.gotoScanController()
            self.restoreCentralManager()
        }
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }

    fileprivate func restoreCentralManager() {
        DLog("Restoring Central Manager from DFU")
        BleManager.sharedInstance.restoreCentralManager()

        // Check if we are no longer connected
        let currentlyConnectedPeripherals = BleManager.sharedInstance.connectedPeripherals()
        DLog("currentlyConnectedPeripherals: \(currentlyConnectedPeripherals.count)")
        if currentlyConnectedPeripherals.count == 0 {
            // Simulate disconnection to trigger the go back to scanning
            DLog("Simulate disconnection")
            NotificationCenter.default.post(name: .didDisconnectFromPeripheral, object: nil)
        }
    }

    func onUpdateProcessError(errorMessage: String, infoMessage: String?) {
        //BleManager.sharedInstance.restoreCentralManager()

        if let dfuDialogViewController = self.dfuDialogViewController {
            dfuDialogViewController.dismiss(animated: false, completion: nil)
        }

        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: (infoMessage != nil ? errorMessage:nil), message: (infoMessage != nil ? infoMessage : errorMessage), preferredStyle: .alert)

        let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default) { [weak self] _ in
            //self?.gotoScanController()
            self?.restoreCentralManager()
        }
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }

    func onUpdateProgressText(_ message: String) {
        DispatchQueue.main.async { [unowned self] in
            self.dfuDialogViewController?.setProgressText(message)
        }
    }

    func onUpdateProgressValue(_ progress: Double) {
        DispatchQueue.main.async { [unowned self] in
            self.dfuDialogViewController?.setProgress(progress)
        }
    }
}

// MARK: - DfuUpdateProcessDelegate
extension DfuModeViewController: DfuFilesPickerDialogViewControllerDelegate {

    func onFilesPickerStartUpdate(hexUrl: URL?, iniUrl: URL?) {
        if let hexUrl = hexUrl {
            // Show dialog
            dfuDialogViewController = self.storyboard!.instantiateViewController(withIdentifier: "DfuDialogViewController") as! DfuDialogViewController
            self.present(dfuDialogViewController, animated: true, completion: { [unowned self] () -> Void in
                // Setup update process
                self.dfuUpdateProcess.delegate = self
                self.dfuUpdateProcess.startUpdateForPeripheral(peripheral: self.blePeripheral!.peripheral, hexUrl: hexUrl, iniUrl:iniUrl)
                })
        } else {
            let localizationManager = LocalizationManager.sharedInstance
            let alertController = UIAlertController(title: nil, message: "At least an Hex file should be selected", preferredStyle: .alert)

            let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler: nil)
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }

    func onFilesPickerCancel() {
    }
}
