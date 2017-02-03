//
//  ScannerViewController.swift
//  NewtManager
//
//  Created by Antonio García on 13/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit
import CoreBluetooth

class ScannerViewController: UIViewController {
    // Config
    private static let kServicesToScan = [BlePeripheral.kUartServiceUUID]

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
        
        // MultiConnect
//        multiConnectSwitch.isOn = Preferences.
        
        // Ble Notifications
        registerNotifications(enabled: true)
        

        // If only connected to 1 peripheral and coming back to this
        let connectedPeripherals = BleManager.sharedInstance.connectedPeripherals()
        if connectedPeripherals.count == 1, let peripheral = connectedPeripherals.first {
            DLog("Disconnect form previously connected peripheral")
            // Disconnect from peripheral
            BleManager.sharedInstance.disconnect(from: peripheral)
        }
        
        // Start scannning
        BleManager.sharedInstance.startScan()
//        BleManager.sharedInstance.startScan(withServices: [ScannerViewController.kServicesToScan])
        
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
    private var didDiscoverPeripheralObserver: NSObjectProtocol?
    private var willConnectToPeripheralObserver: NSObjectProtocol?
    private var didConnectToPeripheralObserver: NSObjectProtocol?
    private var didDisconnectFromPeripheralObserver: NSObjectProtocol?
    
    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            didDiscoverPeripheralObserver = notificationCenter.addObserver(forName: .didDiscoverPeripheral, object: nil, queue: OperationQueue.main, using: didDiscoverPeripheral)
            willConnectToPeripheralObserver = notificationCenter.addObserver(forName: .willConnectToPeripheral, object: nil, queue: OperationQueue.main, using: willConnectToPeripheral)
            didConnectToPeripheralObserver = notificationCenter.addObserver(forName: .didConnectToPeripheral, object: nil, queue: OperationQueue.main, using: didConnectToPeripheral)
            didDisconnectFromPeripheralObserver = notificationCenter.addObserver(forName: .didDisconnectFromPeripheral, object: nil, queue: OperationQueue.main, using: didDisconnectFromPeripheral)
        }
        else {
            if let didDiscoverPeripheralObserver = didDiscoverPeripheralObserver {notificationCenter.removeObserver(didDiscoverPeripheralObserver)}
            if let willConnectToPeripheralObserver = willConnectToPeripheralObserver {notificationCenter.removeObserver(willConnectToPeripheralObserver)}
            if let didConnectToPeripheralObserver = didConnectToPeripheralObserver {notificationCenter.removeObserver(didConnectToPeripheralObserver)}
            if let didDisconnectFromPeripheralObserver = didDisconnectFromPeripheralObserver {notificationCenter.removeObserver(didDisconnectFromPeripheralObserver)}
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
        guard let peripheral = BleManager.sharedInstance.peripheral(from: notification) else {
            return
        }
        
        presentInfoDialog(title: "Connecting...", peripheral: peripheral)
    }
    
    fileprivate func presentInfoDialog(title: String, peripheral: BlePeripheral) {
        infoAlertController = UIAlertController(title: nil, message: title, preferredStyle: .alert)
        infoAlertController!.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) -> Void in
            BleManager.sharedInstance.disconnect(from: peripheral)
        }))
        present(infoAlertController!, animated: true, completion:nil)
    }
    
    fileprivate func dismissInfoDialog(completion: (() -> Void)? = nil) {
        infoAlertController?.dismiss(animated: true, completion: completion)
        infoAlertController = nil
    }
    
    private func didConnectToPeripheral(notification: Notification) {
        updateMultiConnectUI()

        guard let selectedPeripheral = selectedPeripheral, let identifier = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID, selectedPeripheral.identifier == identifier else {
            DLog("Connected to an unexpected peripheral")
            return
        }
        
        // Connection is managed here if the device is in compact mode
        let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
        if isFullScreen {
            DLog("list: connection on compact mode detected")
            
            // Deselect current row
            if let indexPathForSelectedRow = self.baseTableView.indexPathForSelectedRow {
                self.baseTableView.deselectRow(at: indexPathForSelectedRow, animated: true)
            }

            // Discover services
            infoAlertController?.message = "Discovering services..."
            discoverServices(peripheral: selectedPeripheral)
        }
    }

    private func didDisconnectFromPeripheral(notification: Notification) {
        updateMultiConnectUI()

        guard let peripheral = BleManager.sharedInstance.peripheral(from: notification) else {
            return
        }
        
        guard let selectedPeripheral = selectedPeripheral, peripheral.identifier == selectedPeripheral.identifier else {
            return
        }
        
        // Clear selected peripheral
        self.selectedPeripheral = nil
        
        DispatchQueue.main.async { [unowned self] in
            // Reload table
            self.baseTableView.reloadData()
        }
    }
    
    // MARK: - Navigation
    fileprivate func showPeripheralDetails() {
        // Segue
        performSegue(withIdentifier: "showDetailSegue", sender: self)
    }
    
    fileprivate func showPeripheralUpdate() {
        // Segue
        performSegue(withIdentifier: "showUpdateSegue", sender: self)
    }

    fileprivate func showMultiUartMode() {
        // Segue
        performSegue(withIdentifier: "showMultiUartSegue", sender: self)
    }

    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return selectedPeripheral != nil
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showDetailSegue", let peripheralDetailsViewController = (segue.destination as? UINavigationController)?.topViewController as? PeripheralDetailsViewController {
            peripheralDetailsViewController.blePeripheral = selectedPeripheral
        }
        else if segue.identifier == "showUpdateSegue", let peripheralDetailsViewController = (segue.destination as? UINavigationController)?.topViewController as? PeripheralDetailsViewController {
            peripheralDetailsViewController.blePeripheral = selectedPeripheral
            peripheralDetailsViewController.startingController = .update
        }
        else if segue.identifier == "showMultiUartSegue", let peripheralDetailsViewController = (segue.destination as? UINavigationController)?.topViewController as? PeripheralDetailsViewController {
            peripheralDetailsViewController.blePeripheral = nil
            peripheralDetailsViewController.startingController = .multiUart
        }
        else if segue.identifier == "filterNameSettingsSegue", let controller = segue.destination.popoverPresentationController  {
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
            guard let context = self else {
                return
            }
        
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
                    context.dismissInfoDialog() {
                        
                    }
                }
                else {
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
            self.showPeripheralDetails()
        }))
        alert.addAction(UIAlertAction(title: localizationManager.localizedString("autoupdate_later"), style: UIAlertActionStyle.default, handler: { [unowned self] _ in
            self.showPeripheralUpdate()
            
        }))
        alert.addAction(UIAlertAction(title: localizationManager.localizedString("autoupdate_ignore"), style: UIAlertActionStyle.cancel, handler: {  _ in
            Preferences.softwareUpdateIgnoredVersion = latestRelease.version
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
        baseTableView.reloadData()
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
        BleManager.sharedInstance.refreshPeripherals()
        refreshControl.endRefreshing()
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
        }
        else {
            let connectedPeripherals = BleManager.sharedInstance.connectedPeripherals()
            if !connectedPeripherals.isEmpty {
                for connectedPeripheral in connectedPeripherals {
                    BleManager.sharedInstance.disconnect(from: connectedPeripheral)
                }
                BleManager.sharedInstance.refreshPeripherals()      // Force refresh because they wont reappear. Check why is this happening
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
        baseTableView.reloadData()
    }
    
    fileprivate func disconnect(peripheral: BlePeripheral) {
        selectedPeripheral = nil
        BleManager.sharedInstance.disconnect(from: peripheral)
        baseTableView.reloadData()
    }
    
    // MARK: - UI
    private func updateScannedPeripherals() {
        
        // Reload table
        baseTableView.reloadData()
        
        // Select the previously selected row
        let peripherals = peripheralList.filteredPeripherals(forceUpdate: false)
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
}

// MARK: - UITableViewDataSource
extension ScannerViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripheralList.filteredPeripherals(forceUpdate: true).count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "PeripheralCell"
        let peripheralCell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! PeripheralTableViewCell
        
        let peripheral = peripheralList.filteredPeripherals(forceUpdate: false)[indexPath.row]
        
        // Fill data
        let localizationManager = LocalizationManager.sharedInstance
        peripheralCell.titleLabel.text = peripheral.name ?? localizationManager.localizedString("peripherallist_unnamed")
        peripheralCell.rssiImageView.image = signalImage(for: peripheral.rssi)

        let isUartCapable = peripheral.isUartAdvertised()
        peripheralCell.subtitleLabel.text = isUartCapable ? localizationManager.localizedString("peripherallist_uartavailable") : nil
        
        // Show either a disconnect button or a disclosure indicator depending on the UISplitViewController displayMode
        //peripheralCell.accessoryType = .disclosureIndicator
        let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact

        
        let showConnect: Bool
        let showDisconnect: Bool
        if isMultiConnectEnabled {
            let connectedPeripherals = BleManager.sharedInstance.connectedPeripherals()
            showDisconnect = connectedPeripherals.contains(peripheral)
            showConnect = !showDisconnect
        }
        else {
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
        peripheralCell.baseStackView.subviews[1].isHidden = !isDetailViewOpen
        if isDetailViewOpen {
            setupPeripheralExtendedView(peripheralCell: peripheralCell, peripheral: peripheral)
        }
        
        return peripheralCell
    }
    
    private func setupPeripheralExtendedView(peripheralCell: PeripheralTableViewCell, peripheral: BlePeripheral) {
        guard let detailBaseStackView = peripheralCell.detailBaseStackView else { return }
        
        var currentIndex = 0
        
        // Local Name
        var isLocalNameAvailable = false
        if let localName = peripheral.advertisement.localName {
            peripheralCell.localNameValueLabel.text = localName
            isLocalNameAvailable = true
        }
        detailBaseStackView.subviews[currentIndex].isHidden = !isLocalNameAvailable
        currentIndex = currentIndex+1
        
        // Manufacturer Name
        var isManufacturerAvailable = false
        if let manufacturerString = peripheral.advertisement.manufacturerString {
            peripheralCell.manufacturerValueLabel.text = manufacturerString
            isManufacturerAvailable = true
        }
        else {
            peripheralCell.manufacturerValueLabel.text = nil
        }
        detailBaseStackView.subviews[currentIndex].isHidden = !isManufacturerAvailable
        currentIndex = currentIndex+1
        
        // Services
        var areServicesAvailable = false
        if let services = peripheral.advertisement.services, let stackView = peripheralCell.servicesStackView {
            //DLog("services: \(services.count)")
            addServiceNames(stackView: stackView, services: services)
            areServicesAvailable = services.count > 0
        }
        detailBaseStackView.subviews[currentIndex].isHidden = !areServicesAvailable
        currentIndex = currentIndex+1
        
        // Services Overflow
        var areServicesOverflowAvailable = false
        if let servicesOverflow =  peripheral.advertisement.servicesOverflow, let stackView = peripheralCell.servicesOverflowStackView {
            addServiceNames(stackView: stackView, services: servicesOverflow)
            areServicesOverflowAvailable = servicesOverflow.count > 0
        }
        detailBaseStackView.subviews[currentIndex].isHidden = !areServicesOverflowAvailable
        currentIndex = currentIndex+1
        
        // Solicited Services
        var areSolicitedServicesAvailable = false
        if let servicesSolicited = peripheral.advertisement.servicesSolicited, let stackView = peripheralCell.servicesOverflowStackView {
            addServiceNames(stackView: stackView, services: servicesSolicited)
            areSolicitedServicesAvailable = servicesSolicited.count > 0
        }
        detailBaseStackView.subviews[currentIndex].isHidden = !areSolicitedServicesAvailable
        currentIndex = currentIndex+1
        
        
        // Tx Power
        var isTxPowerAvailable: Bool
        if let txpower = peripheral.advertisement.txPower {
            peripheralCell.txPowerLevelValueLabel.text = String(txpower)
            isTxPowerAvailable = true
        }
        else {
            isTxPowerAvailable = false
        }
        detailBaseStackView.subviews[currentIndex].isHidden = !isTxPowerAvailable
        currentIndex = currentIndex+1
        
        // Connectable
        let isConnectable = peripheral.advertisement.isConnectable
        peripheralCell.connectableValueLabel.text = isConnectable != nil ? "\(isConnectable! ? "true":"false")":"unknown"
        currentIndex = currentIndex+1
        
    }
    
    private func addServiceNames(stackView: UIStackView, services: [CBUUID]) {
        let styledLabel = stackView.arrangedSubviews.first! as! UILabel
        styledLabel.isHidden = true     // The first view is only to define style in InterfaceBuilder. Hide it
        
        // Clear current subviews
        for arrangedSubview in stackView.arrangedSubviews {
            if arrangedSubview != stackView.arrangedSubviews.first {
                arrangedSubview.removeFromSuperview()
                stackView.removeArrangedSubview(arrangedSubview)
            }
        }
        
        // Add services as subviews
        for serviceCBUUID in services {
            let label = UILabel()
            var identifier = serviceCBUUID.uuidString
            if let name = BleUUIDNames.sharedInstance.nameForUUID(identifier) {
                identifier = name
            }
            label.text = identifier
            label.font = styledLabel.font
            label.minimumScaleFactor = styledLabel.minimumScaleFactor
            label.adjustsFontSizeToFitWidth = styledLabel.adjustsFontSizeToFitWidth
            stackView.addArrangedSubview(label)
        }
    }
}

// MARK: UITableViewDelegate
extension ScannerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let peripheral = peripheralList.filteredPeripherals(forceUpdate: false)[indexPath.row]
        let isDetailViewOpen = !(isRowDetailOpenForPeripheral[peripheral.identifier] ?? false)
        isRowDetailOpenForPeripheral[peripheral.identifier] = isDetailViewOpen

        tableView.reloadRows(at: [indexPath], with: .fade)
        tableView.deselectRow(at: indexPath, animated: false)

        // Animate changes
//        tableView.beginUpdates()
//        tableView.endUpdates()
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension ScannerViewController: UIPopoverPresentationControllerDelegate {
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        // This forces a popover to be displayed on the iPhone
        if traitCollection.verticalSizeClass != .compact {
            return .none
        }
        else {
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
            self?.dismissInfoDialog() {
                if isUpdateAvailable, let latestRelease = latestRelease {
                    self?.showUpdateAvailableForRelease(latestRelease)
                }
                else {
                    self?.showPeripheralDetails()
                }
            }
        }
    }
}

