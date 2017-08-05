//
//  ScannerViewController.swift
//  NewtManager
//
//  Created by Antonio García on 13/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit
import CoreBluetooth

class ScannerViewController: ModeTabViewController {
    // Config
    // private static let kServicesToScan = [BlePeripheral.kUartServiceUUID]

    static let kFiltersPanelClosedHeight: CGFloat = 44
    static let kFiltersPanelOpenHeight: CGFloat = 226

    static let kMultiConnectPanelClosedHeight: CGFloat = 44
    static let kMultiConnectPanelOpenHeight: CGFloat = 90

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    @IBOutlet weak var filtersPanelView: UIView!
    @IBOutlet weak var filtersPanelViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var filtersDisclosureButton: UIButton!
    @IBOutlet weak var filtersTitleLabel: UILabel!
    @IBOutlet weak var filtersClearButton: UIButton!
    @IBOutlet weak var filtersNameTextField: UITextField!
    @IBOutlet weak var filtersRssiSlider: UISlider!
    @IBOutlet weak var filterRssiValueLabel: UILabel!
    @IBOutlet weak var filtersUnnamedSwitch: UISwitch!
    @IBOutlet weak var filtersUartSwitch: UISwitch!
    @IBOutlet weak var scanningWaitView: UIView!

    @IBOutlet weak var multiConnectPanelView: UIView!
    @IBOutlet weak var multiConnectDisclosureButton: UIButton!
    @IBOutlet weak var multiConnectPanelViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var multiConnectSwitch: UISwitch!
    @IBOutlet weak var multiConnectDetailsLabel: UILabel!
    @IBOutlet weak var multiConnectShowButton: UIButton!

    
    // Data
    fileprivate let refreshControl = UIRefreshControl()
    fileprivate var peripheralList: PeripheralList!
    fileprivate var isRowDetailOpenForPeripheral = [UUID: Bool]()          // Is the detailed info row open [PeripheralIdentifier: Bool]

    fileprivate var selectedPeripheral: BlePeripheral?

    fileprivate var isMultiConnectEnabled = false
    fileprivate let firmwareUpdater = FirmwareUpdater()
    fileprivate var infoAlertController: UIAlertController?

    fileprivate var isBaseTableScrolling = false
    fileprivate var isScannerTableWaitingForReload = false
    fileprivate var isBaseTableAnimating = false

    

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Init
        peripheralList = PeripheralList()                  // Initialize here to wait for Preferences.registerDefaults to be executed

        // Setup filters
        filtersNameTextField.leftViewMode = .always
        let searchImageView = UIImageView(image: UIImage(named: "ic_search_18pt"))
        searchImageView.contentMode = UIViewContentMode.right
        searchImageView.frame = CGRect(x: 0, y: 0, width: searchImageView.image!.size.width + 6.0, height: searchImageView.image!.size.height)
        filtersNameTextField.leftView = searchImageView

        // Setup table view
        baseTableView.estimatedRowHeight = 66
        baseTableView.rowHeight = UITableViewAutomaticDimension

        // Setup table refresh
        refreshControl.addTarget(self, action: #selector(onTableRefresh(_:)), for: UIControlEvents.valueChanged)
        baseTableView.addSubview(refreshControl)
        baseTableView.sendSubview(toBack: refreshControl)

        // Setup filters
        filtersRssiSlider.minimumValue = Float(PeripheralList.kMinRssiValue)
        filtersRssiSlider.maximumValue = Float(PeripheralList.kMaxRssiValue)

        // Setup multiconnect
        multiConnectShowButton.setBackgroundImage(UIImage(color: view.tintColor), for: .normal)
        multiConnectShowButton.setBackgroundImage(UIImage(color: UIColor.clear), for: .disabled)

        openMultiConnectPanel(isOpen: false, animated: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Filters
        openFiltersPanel(isOpen: Preferences.scanFilterIsPanelOpen, animated: false)
        updateFiltersTitle()
        filtersNameTextField.text = peripheralList.filterName ?? ""
        setRssiSlider(value: peripheralList.rssiFilterValue)
        filtersUnnamedSwitch.isOn = peripheralList.isUnnamedEnabled
        filtersUartSwitch.isOn = peripheralList.isOnlyUartEnabled

        // Flush any pending state notifications
        didUpdateBleState(notification: nil)

        // Ble Notifications
        registerNotifications(enabled: true)
        DLog("Scanner: Register notifications")

        let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact

        if isFullScreen {
            // If only connected to 1 peripheral and coming back to this
            let connectedPeripherals = BleManager.sharedInstance.connectedPeripherals()
            if connectedPeripherals.count == 1, let peripheral = connectedPeripherals.first {
                DLog("Disconnect from previously connected peripheral")
                // Disconnect from peripheral
                BleManager.sharedInstance.disconnect(from: peripheral)
            }
        }

        // Start scannning
        BleManager.sharedInstance.startScan()
//        BleManager.sharedInstance.startScan(withServices: ScannerViewController.kServicesToScan)

        // Update UI
        updateScannedPeripherals()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Stop scanning
        BleManager.sharedInstance.stopScan()

        // Ble Notifications
        registerNotifications(enabled: false)

        // Clear peripherals
        peripheralList.clear()
        isRowDetailOpenForPeripheral.removeAll()
    }

    // MARK: - BLE Notifications
    private weak var didUpdateBleStateObserver: NSObjectProtocol?
    private weak var didDiscoverPeripheralObserver: NSObjectProtocol?
    private weak var willConnectToPeripheralObserver: NSObjectProtocol?
    private weak var didConnectToPeripheralObserver: NSObjectProtocol?
    private weak var didDisconnectFromPeripheralObserver: NSObjectProtocol?
    private weak var peripheralDidUpdateNameObserver: NSObjectProtocol?

    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            didUpdateBleStateObserver = notificationCenter.addObserver(forName: .didUpdateBleState, object: nil, queue: .main, using: didUpdateBleState)
            didDiscoverPeripheralObserver = notificationCenter.addObserver(forName: .didDiscoverPeripheral, object: nil, queue: .main, using: didDiscoverPeripheral)
            willConnectToPeripheralObserver = notificationCenter.addObserver(forName: .willConnectToPeripheral, object: nil, queue: .main, using: willConnectToPeripheral)
            didConnectToPeripheralObserver = notificationCenter.addObserver(forName: .didConnectToPeripheral, object: nil, queue: .main, using: didConnectToPeripheral)
            didDisconnectFromPeripheralObserver = notificationCenter.addObserver(forName: .didDisconnectFromPeripheral, object: nil, queue: .main, using: didDisconnectFromPeripheral)
            peripheralDidUpdateNameObserver = notificationCenter.addObserver(forName: .peripheralDidUpdateName, object: nil, queue: .main, using: peripheralDidUpdateName)
       } else {
            if let didUpdateBleStateObserver = didUpdateBleStateObserver {notificationCenter.removeObserver(didUpdateBleStateObserver)}
            if let didDiscoverPeripheralObserver = didDiscoverPeripheralObserver {notificationCenter.removeObserver(didDiscoverPeripheralObserver)}
            if let willConnectToPeripheralObserver = willConnectToPeripheralObserver {notificationCenter.removeObserver(willConnectToPeripheralObserver)}
            if let didConnectToPeripheralObserver = didConnectToPeripheralObserver {notificationCenter.removeObserver(didConnectToPeripheralObserver)}
            if let didDisconnectFromPeripheralObserver = didDisconnectFromPeripheralObserver {notificationCenter.removeObserver(didDisconnectFromPeripheralObserver)}
            if let peripheralDidUpdateNameObserver = peripheralDidUpdateNameObserver {notificationCenter.removeObserver(peripheralDidUpdateNameObserver)}
        }
    }

    private func didUpdateBleState(notification: Notification?) {
        guard let state = BleManager.sharedInstance.centralManager?.state else { return }

        // Check if there is any error
        var errorMessage: String?
        switch state {
        case .unsupported:
            errorMessage = "This device doesn't support Bluetooth Low Energy"
        case .unauthorized:
            errorMessage = "This app is not authorized to use the Bluetooth Low Energy"
        case .poweredOff:
            errorMessage = "Bluetooth is currently powered off"
        default:
            errorMessage = nil
        }

        // Show alert if error found
        if let errorMessage = errorMessage {
            DLog("Error: \(errorMessage)")

            // Reload peripherals
            refreshPeripherals()

            // Show error
            let localizationManager = LocalizationManager.sharedInstance
            let alertController = UIAlertController(title: localizationManager.localizedString("dialog_error"), message: errorMessage, preferredStyle: .alert)
            let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler: { (_) -> Void in
                if let navController = self.splitViewController?.viewControllers[0] as? UINavigationController {
                    navController.popViewController(animated: true)
                }
            })

            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }

    private func didDiscoverPeripheral(notification: Notification) {
        /*
        #if DEBUG
            let peripheralUuid = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID
            let peripheral = BleManager.sharedInstance.peripherals().first(where: {$0.identifier == peripheralUuid})
            DLog("didDiscoverPeripheral: \(peripheral?.name ?? "")")
        #endif
          */

        // Update current scanning state
        updateScannedPeripherals()
    }

    private func willConnectToPeripheral(notification: Notification) {
        guard let peripheral = BleManager.sharedInstance.peripheral(from: notification) else { return }
        presentInfoDialog(title: LocalizationManager.sharedInstance.localizedString("peripherallist_connecting"), peripheral: peripheral)
    }

    private func didConnectToPeripheral(notification: Notification) {
        updateMultiConnectUI()

        guard let selectedPeripheral = selectedPeripheral, let identifier = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID, selectedPeripheral.identifier == identifier else {
            DLog("Connected to an unexpected peripheral")
            return
        }
  
        // Discover services
        infoAlertController?.message = LocalizationManager.sharedInstance.localizedString("periperhallist_discoveringservices")
        discoverServices(peripheral: selectedPeripheral)
    }

    private func didDisconnectFromPeripheral(notification: Notification) {
        updateMultiConnectUI()

        let peripheral = BleManager.sharedInstance.peripheral(from: notification)
        let currentlyConnectedPeripheralsCount = BleManager.sharedInstance.connectedPeripherals().count

        guard let selectedPeripheral = selectedPeripheral, selectedPeripheral.identifier == peripheral?.identifier || currentlyConnectedPeripheralsCount == 0 else {        // If selected peripheral is disconnected or if there not any peripherals connected (after a failed dfu update)
            return
        }

        // Clear selected peripheral
        self.selectedPeripheral = nil

        // Watch
        WatchSessionManager.sharedInstance.updateApplicationContext(mode: .scan)

        // Dismiss any info open dialogs
        infoAlertController?.dismiss(animated: true, completion: nil)
        infoAlertController = nil

        // Reload table
        reloadBaseTable()
    }

    private func peripheralDidUpdateName(notification: Notification) {
        let name = notification.userInfo?[BlePeripheral.NotificationUserInfoKey.name.rawValue] as? String
        DLog("centralManager peripheralDidUpdateName: \(name ?? "<unknown>")")

        DispatchQueue.main.async { [weak self] in
            // Reload table
            self?.reloadBaseTable()
        }
    }

    // MARK: - Navigation
    override func loadDetailRootController() {
        detailRootController = self.storyboard?.instantiateViewController(withIdentifier: "PeripheralModulesNavigationController")
    }
    
    fileprivate func showPeripheralDetails() {
        // Watch
        if !isMultiConnectEnabled {
            WatchSessionManager.sharedInstance.updateApplicationContext(mode: .connected)
        }

        // Segue
        //performSegue(withIdentifier: "showDetailSegue", sender: self)

        detailRootController = self.storyboard?.instantiateViewController(withIdentifier: "PeripheralModulesNavigationController")
        if let peripheralModulesNavigationController = detailRootController as? UINavigationController, let peripheralModulesViewController = peripheralModulesNavigationController.topViewController as? PeripheralModulesViewController {
            peripheralModulesViewController.blePeripheral = selectedPeripheral
            showDetailViewController(peripheralModulesNavigationController, sender: self)
        }
    }

    fileprivate func showPeripheralUpdate() {
        // Watch
        if !isMultiConnectEnabled {
            WatchSessionManager.sharedInstance.updateApplicationContext(mode: .connected)
        }

        // Segue
        //performSegue(withIdentifier: "showUpdateSegue", sender: self)
        
        detailRootController = self.storyboard?.instantiateViewController(withIdentifier: "PeripheralModulesNavigationController")
        if let peripheralModulesNavigationController = detailRootController as? UINavigationController, let peripheralModulesViewController = peripheralModulesNavigationController.topViewController as? PeripheralModulesViewController {
            peripheralModulesViewController.blePeripheral = selectedPeripheral
            
            if let dfuViewController = self.storyboard!.instantiateViewController(withIdentifier: "DfuModeViewController") as? DfuModeViewController {
                dfuViewController.blePeripheral = selectedPeripheral
                peripheralModulesNavigationController.viewControllers = [peripheralModulesViewController, dfuViewController]
            }
            showDetailViewController(peripheralModulesNavigationController, sender: self)
        }
    }

    fileprivate func showMultiUartMode() {
        // Segue
        //performSegue(withIdentifier: "showMultiUartSegue", sender: self)
        
        detailRootController = self.storyboard?.instantiateViewController(withIdentifier: "PeripheralModulesNavigationController")
        if let peripheralModulesNavigationController = detailRootController as? UINavigationController, let peripheralModulesViewController = peripheralModulesNavigationController.topViewController as? PeripheralModulesViewController {
            peripheralModulesViewController.blePeripheral = nil
            peripheralModulesViewController.startingController = .multiUart
            showDetailViewController(peripheralModulesNavigationController, sender: self)
        }
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return selectedPeripheral != nil
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        /*
        if segue.identifier == "showDetailSegue", let peripheralDetailsViewController = (segue.destination as? UINavigationController)?.topViewController as? PeripheralDetailsViewController {     // Note: Not used anymore. Remove when the change is permanent
            peripheralDetailsViewController.blePeripheral = selectedPeripheral
        } else if segue.identifier == "showDetailSegue", let peripheralModulesViewController = (segue.destination as? UINavigationController)?.topViewController as? PeripheralModulesViewController {
            peripheralModulesViewController.blePeripheral = selectedPeripheral
        } else if segue.identifier == "showUpdateSegue", let peripheralDetailsViewController = (segue.destination as? UINavigationController)?.topViewController as? PeripheralDetailsViewController {       // Note: Not used anymore. Remove when the change is permanent
            peripheralDetailsViewController.blePeripheral = selectedPeripheral
            peripheralDetailsViewController.startingController = .update
        } else if segue.identifier == "showUpdateSegue", let detailsNavigationController = segue.destination as? UINavigationController, let peripheralModulesViewController = detailsNavigationController.topViewController as? PeripheralModulesViewController {
            peripheralModulesViewController.blePeripheral = selectedPeripheral
            //peripheralModulesViewController.startingController = .update

            if let dfuViewController = self.storyboard!.instantiateViewController(withIdentifier: "DfuModeViewController") as? DfuModeViewController {
                dfuViewController.blePeripheral = selectedPeripheral
                detailsNavigationController.viewControllers = [peripheralModulesViewController, dfuViewController]

            }
        } else if segue.identifier == "showMultiUartSegue", let peripheralDetailsViewController = (segue.destination as? UINavigationController)?.topViewController as? PeripheralDetailsViewController {   // Note: Not used anymore. Remove when the change is permanent
            peripheralDetailsViewController.blePeripheral = nil
            peripheralDetailsViewController.startingController = .multiUart
        } else if segue.identifier == "showMultiUartSegue", let peripheralModulesViewController = (segue.destination as? UINavigationController)?.topViewController as? PeripheralModulesViewController {
            peripheralModulesViewController.blePeripheral = nil
            peripheralModulesViewController.startingController = .multiUart

        } else */if segue.identifier == "filterNameSettingsSegue", let controller = segue.destination.popoverPresentationController {
            controller.delegate = self

            if let sourceView = sender as? UIView {
                // Fix centering on iOS9, iOS10: http://stackoverflow.com/questions/30064595/popover-doesnt-center-on-button
                controller.sourceRect = sourceView.bounds
            }

            let filterNameSettingsViewController = segue.destination as! FilterTextSettingsViewController
            filterNameSettingsViewController.peripheralList = peripheralList
            filterNameSettingsViewController.onSettingsChanged = { [unowned self] in
                self.updateFilters()
            }
        }
    }

    // MARK: - Device setup
    private func discoverServices(peripheral: BlePeripheral) {
        DLog("Discovering services")

        peripheral.discover(serviceUuids: nil) { [weak self] error in
            guard let context = self else { return }

            DispatchQueue.main.async { [unowned context] in
                guard error == nil else {
                    DLog("Error initializing peripheral")
                    context.dismiss(animated: true, completion: { [weak self] () -> Void in
                        if let context = self {
                            showErrorAlert(from: context, title: "Error", message: "Error discovering peripheral services")
                            BleManager.sharedInstance.disconnect(from: peripheral)
                        }
                    })
                    return
                }

                if context.isMultiConnectEnabled {
                    context.dismissInfoDialog {
                    }
                } else {
                    // Check updates if needed
                    context.infoAlertController?.message = "Checking updates..."
                    context.startUpdatesCheck(peripheral: peripheral)
                }
            }
        }
    }

    // MARK: - Check Updates
    private func startUpdatesCheck(peripheral: BlePeripheral) {
        DLog("Check firmware updates")

        // Refresh updates available
        firmwareUpdater.checkUpdatesForPeripheral(peripheral, delegate: self, shouldDiscoverServices: false, shouldRecommendBetaReleases: false, versionToIgnore: Preferences.softwareUpdateIgnoredVersion)
    }

    fileprivate func showUpdateAvailableForRelease(_ latestRelease: FirmwareInfo) {

        let localizationManager = LocalizationManager.sharedInstance
        let alert = UIAlertController(title: localizationManager.localizedString("autoupdate_title"),
                                      message: String(format: localizationManager.localizedString("auoupadte_description_format"), latestRelease.version),
                                      preferredStyle: UIAlertControllerStyle.alert)

        alert.addAction(UIAlertAction(title: localizationManager.localizedString("autoupdate_update"), style: UIAlertActionStyle.default, handler: { [unowned self] _ in
            self.showPeripheralUpdate()
        }))
        alert.addAction(UIAlertAction(title: localizationManager.localizedString("autoupdate_later"), style: UIAlertActionStyle.default, handler: { [unowned self] _ in
            self.showPeripheralDetails()
        }))
        alert.addAction(UIAlertAction(title: localizationManager.localizedString("autoupdate_ignore"), style: UIAlertActionStyle.cancel, handler: { [unowned self] _ in
            Preferences.softwareUpdateIgnoredVersion = latestRelease.version
            self.showPeripheralDetails()
        }))
        self.present(alert, animated: true, completion: nil)
    }

    // MARK: - Filters
    private func openFiltersPanel(isOpen: Bool, animated: Bool) {

        Preferences.scanFilterIsPanelOpen = isOpen
        self.filtersDisclosureButton.isSelected = isOpen

        self.filtersPanelViewHeightConstraint.constant = isOpen ? ScannerViewController.kFiltersPanelOpenHeight:ScannerViewController.kFiltersPanelClosedHeight
        UIView.animate(withDuration: animated ? 0.3:0) { [unowned self] in
            self.view.layoutIfNeeded()
        }
    }

    private func updateFiltersTitle() {
        let filtersTitle = peripheralList.filtersDescription()
        filtersTitleLabel.text = filtersTitle != nil ? "Filter: \(filtersTitle!)" : "No filter selected"

        filtersClearButton.isHidden = !peripheralList.isAnyFilterEnabled()
    }

    private func updateFilters() {
        updateFiltersTitle()
        reloadBaseTable()
    }

    private func setRssiSlider(value: Int?) {
        filtersRssiSlider.value = value != nil ? Float(-value!) : Float(PeripheralList.kDefaultRssiValue)
        updateRssiValueLabel()
    }

    private func updateRssiValueLabel() {
        filterRssiValueLabel.text = "\(Int(-filtersRssiSlider.value)) dBM"
    }

    // MARK: - MultiConnect
    private func openMultiConnectPanel(isOpen: Bool, animated: Bool) {
        //Preferences.scanMultiConnectIsPanelOpen = isOpen
        self.multiConnectDisclosureButton.isSelected = isOpen

        self.multiConnectPanelViewHeightConstraint.constant = isOpen ? ScannerViewController.kMultiConnectPanelOpenHeight:ScannerViewController.kMultiConnectPanelClosedHeight
        UIView.animate(withDuration: animated ? 0.3:0) { [unowned self] in
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Actions
    func onTableRefresh(_ sender: AnyObject) {
        refreshPeripherals()
        refreshControl.endRefreshing()
    }

    fileprivate func refreshPeripherals() {
        isRowDetailOpenForPeripheral.removeAll()
        BleManager.sharedInstance.refreshPeripherals()
        reloadBaseTable()
    }

    @IBAction func onClickExpandFilters(_ sender: Any) {
        openFiltersPanel(isOpen: !Preferences.scanFilterIsPanelOpen, animated: true)
    }

    @IBAction func onFilterNameChanged(_ sender: UITextField) {
        let isEmpty = sender.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty ?? true
        peripheralList.filterName = isEmpty ? nil:sender.text
        updateFilters()
    }

    @IBAction func onRssiSliderChanged(_ sender: UISlider) {
        let rssiValue = Int(-sender.value)
        peripheralList.rssiFilterValue = rssiValue
        updateRssiValueLabel()
        updateFilters()
    }

    @IBAction func onFilterSettingsUnnamedChanged(_ sender: UISwitch) {
        peripheralList.isUnnamedEnabled = sender.isOn
        updateFilters()
    }

    @IBAction func onFilterSettingsUartChanged(_ sender: UISwitch) {
        peripheralList.isOnlyUartEnabled = sender.isOn
        updateFilters()
    }

    @IBAction func onClickRemoveFilters(_ sender: AnyObject) {
        peripheralList.setDefaultFilters()
        filtersNameTextField.text = peripheralList.filterName ?? ""
        setRssiSlider(value: peripheralList.rssiFilterValue)
        filtersUnnamedSwitch.isOn = peripheralList.isUnnamedEnabled
        filtersUartSwitch.isOn = peripheralList.isOnlyUartEnabled
        updateFilters()
    }

    @IBAction func onClickFilterNameSettings(_ sender: Any) {
        performSegue(withIdentifier: "filterNameSettingsSegue", sender: sender)
    }

    @IBAction func onClickInfo(_ sender: Any) {
        if let infoViewController = storyboard?.instantiateViewController(withIdentifier: "AboutNavigationController") {
            present(infoViewController, animated: true, completion: nil)
        }
    }

    @IBAction func onMultiConnectEnabled(_ sender: UISwitch) {
        enabledMulticonnect(enable: sender.isOn)
    }

    @IBAction func onClickExpandMultiConnect(_ sender: Any) {
        enabledMulticonnect(enable: !isMultiConnectEnabled)
        multiConnectSwitch.isOn = isMultiConnectEnabled
        //openMultiConnectPanel(isOpen: !Preferences.scanMultiConnectIsPanelOpen, animated: true)
    }

    @IBAction func onMultiConnectShow(_ sender: Any) {
        showMultiUartMode()
    }

    fileprivate func enabledMulticonnect(enable: Bool) {
        isMultiConnectEnabled = enable
        openMultiConnectPanel(isOpen: isMultiConnectEnabled, animated: true)

        // Disconnect from all devices if is set as off
        if isMultiConnectEnabled {
            updateMultiConnectUI()
        } else {
            let connectedPeripherals = BleManager.sharedInstance.connectedPeripherals()
            if !connectedPeripherals.isEmpty {
                for connectedPeripheral in connectedPeripherals {
                    BleManager.sharedInstance.disconnect(from: connectedPeripheral)
                }
               // BleManager.sharedInstance.refreshPeripherals()      // Force refresh because they wont reappear. Check why is this happening
            }
        }

    }

    // MARK: - Connections
    fileprivate func connect(peripheral: BlePeripheral) {
        // Dismiss keyboard
        filtersNameTextField.resignFirstResponder()

        // Connect to selected peripheral
        selectedPeripheral = peripheral
        BleManager.sharedInstance.connect(to: peripheral)
        reloadBaseTable()
    }

    fileprivate func disconnect(peripheral: BlePeripheral) {
        selectedPeripheral = nil
        BleManager.sharedInstance.disconnect(from: peripheral)
        reloadBaseTable()
    }

    // MARK: - UI
    private func updateScannedPeripherals() {

        // Reload table
        if isBaseTableScrolling || isBaseTableAnimating {
            isScannerTableWaitingForReload = true
        } else {
            reloadBaseTable()
        }
    }

    fileprivate func reloadBaseTable() {
        isBaseTableScrolling = false
        isBaseTableAnimating = false
        isScannerTableWaitingForReload = false
        let peripherals = peripheralList.filteredPeripherals(forceUpdate: true)     // Refresh the peripherals
        baseTableView.reloadData()

        // Select the previously selected row
        // scanningWaitView.isHidden = peripherals.count > 0
        if let selectedPeripheral = selectedPeripheral, let selectedRow = peripherals.index(of: selectedPeripheral) {
            baseTableView.selectRow(at: IndexPath(row: selectedRow, section: 0), animated: false, scrollPosition: .none)
        }
    }

    private func updateMultiConnectUI() {
        let numConnectedPeripherals = BleManager.sharedInstance.connectedPeripherals().count
        multiConnectDetailsLabel.text = "Connected to \(numConnectedPeripherals) \(numConnectedPeripherals == 1 ? "device":"devices")"
        multiConnectShowButton.isEnabled = numConnectedPeripherals >= 2
    }

    fileprivate func presentInfoDialog(title: String, peripheral: BlePeripheral) {
        if infoAlertController != nil {
            infoAlertController?.dismiss(animated: true, completion: nil)
        }
        
        infoAlertController = UIAlertController(title: nil, message: title, preferredStyle: .alert)
        infoAlertController!.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) -> Void in
            BleManager.sharedInstance.disconnect(from: peripheral)
            //BleManager.sharedInstance.refreshPeripherals()      // Force refresh because they wont reappear. Check why is this happening
        }))
        present(infoAlertController!, animated: true, completion:nil)
    }

    fileprivate func dismissInfoDialog(completion: (() -> Void)? = nil) {
        guard infoAlertController != nil else {
            completion?()
            return
        }
        
        infoAlertController?.dismiss(animated: true, completion: completion)
        infoAlertController = nil
    }

}

// MARK: - UITableViewDataSource
extension ScannerViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Hack to update watch when the cell count changes
        if selectedPeripheral == nil {      // Dont update while a peripheral has been selected
            WatchSessionManager.sharedInstance.updateApplicationContext(mode: .scan)
        }

        // Calculate num cells
        return peripheralList.filteredPeripherals(forceUpdate: false).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "PeripheralCell"
        let peripheralCell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! PeripheralTableViewCell

        // Note: not using willDisplayCell to avoid problems with self-sizing cells
        let peripheral = peripheralList.filteredPeripherals(forceUpdate: false)[indexPath.row]

        // Fill data
        let localizationManager = LocalizationManager.sharedInstance
        peripheralCell.titleLabel.text = peripheral.name ?? localizationManager.localizedString("peripherallist_unnamed")
        peripheralCell.rssiImageView.image = RssiUI.signalImage(for: peripheral.rssi)

        var subtitle: String? = nil
        if peripheral.advertisement.isConnectable == false {
            subtitle = localizationManager.localizedString("peripherallist_notconnectable")
        }
        else if peripheral.isUartAdvertised() {
            subtitle = localizationManager.localizedString("peripherallist_uartavailable")
        }
        peripheralCell.subtitleLabel.text = subtitle

        let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact

        let showConnect: Bool
        let showDisconnect: Bool
        if isMultiConnectEnabled {
            let connectedPeripherals = BleManager.sharedInstance.connectedPeripherals()
            showDisconnect = connectedPeripherals.contains(peripheral)
            showConnect = !showDisconnect
        } else {
            showConnect = isFullScreen || selectedPeripheral == nil
            showDisconnect = !isFullScreen && peripheral.identifier == selectedPeripheral?.identifier
        }

        peripheralCell.connectButton.isHidden = !showConnect
        peripheralCell.disconnectButton.isHidden = !showDisconnect

        peripheralCell.onConnect = { [unowned self] in
            self.connect(peripheral: peripheral)
        }
        peripheralCell.onDisconnect = { [unowned self] in
            tableView.deselectRow(at: indexPath, animated: true)
            self.disconnect(peripheral: peripheral)
        }

        // Detail Subview
        let isDetailViewOpen = isRowDetailOpenForPeripheral[peripheral.identifier] ?? false
        peripheralCell.baseStackView.arrangedSubviews[1].isHidden = !isDetailViewOpen
        if isDetailViewOpen {
            peripheralCell.setupPeripheralExtendedView(peripheral: peripheral)
        }

        return peripheralCell
    }
}

// MARK: UITableViewDelegate
extension ScannerViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let peripheral = peripheralList.filteredPeripherals(forceUpdate: false)[indexPath.row]
        let isDetailViewOpen = !(isRowDetailOpenForPeripheral[peripheral.identifier] ?? false)
        isRowDetailOpenForPeripheral[peripheral.identifier] = isDetailViewOpen

        isBaseTableAnimating = true
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            self?.isBaseTableAnimating = false
        }
        tableView.reloadRows(at: [indexPath], with: .fade)
        tableView.scrollToRow(at: indexPath, at: .none, animated: true)
        CATransaction.commit()
        tableView.deselectRow(at: indexPath, animated: false)

        // Animate changes
//        tableView.beginUpdates()
//        tableView.endUpdates()
    }
}

// MARK: UIScrollViewDelegate
extension ScannerViewController {

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isBaseTableScrolling = true
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        isBaseTableScrolling = false

        if isScannerTableWaitingForReload {
            reloadBaseTable()
        }
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension ScannerViewController: UIPopoverPresentationControllerDelegate {

    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        // This forces a popover to be displayed on the iPhone
        if traitCollection.verticalSizeClass != .compact {
            return .none
        } else {
            return .fullScreen
        }
    }

    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        DLog("selector dismissed")
    }
}

// MARK: - UITextFieldDelegate
extension ScannerViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - FirmwareUpdaterDelegate
extension ScannerViewController: FirmwareUpdaterDelegate {

    func onFirmwareUpdateAvailable(isUpdateAvailable: Bool, latestRelease: FirmwareInfo?, deviceInfo: DeviceInformationService?) {

        DLog("FirmwareUpdaterDelegate isUpdateAvailable: \(isUpdateAvailable)")

        DispatchQueue.main.async { [weak self] in
            self?.dismissInfoDialog {
                if isUpdateAvailable, let latestRelease = latestRelease {
                    self?.showUpdateAvailableForRelease(latestRelease)
                } else {
                    self?.showPeripheralDetails()
                }
            }
        }
    }
}
