//
//  ScannerViewController.swift
//  NewtManager
//
//  Created by Antonio García on 13/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class ScannerViewController: UIViewController {
    // Config
    private static let kServicesToScan = [BlePeripheral.kUartServiceUUID]

    static let kFiltersPanelClosedHeight: CGFloat = 44
    static let kFiltersPanelOpenHeight: CGFloat = 226
    
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

    // Data
    private let refreshControl = UIRefreshControl()
    fileprivate var peripheralList: PeripheralList!

    fileprivate var selectedPeripheral: BlePeripheral?
    
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
        
        // Ble Notifications
        registerNotifications(enabled: true)
        
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
        
        DLog("Connecting...");
        let alertController = UIAlertController(title: nil, message: "Connecting...", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) -> Void in
            BleManager.sharedInstance.disconnect(from: peripheral)
        }))
        present(alertController, animated: true, completion:nil)
    }
    
    private func didConnectToPeripheral(notification: Notification) {
        guard let selectedPeripheral = selectedPeripheral, let identifier = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID, selectedPeripheral.identifier == identifier else {
            DLog("Connected to an unexpected peripheral")
            return
        }
        
        setupUart(peripheral: selectedPeripheral)
    }
    
    private func setupUart(peripheral: BlePeripheral) {
        // Setup Uart
        peripheral.uartInit(uartRxHandler: UartManager.sharedInstance.uartRxDataReceived) { [weak self] error in
            
            guard let context = self else {
                return
            }
            
            DispatchQueue.main.async { [unowned context] in
                guard error == nil else {
                    DLog("Error initializing uart")
                    context.dismiss(animated: true, completion: { [weak self] () -> Void in
                        if let context = self {
                            showErrorAlert(from: context, title: "Error", message: "Uart protocol can not be initialized")
                            
                            BleManager.sharedInstance.disconnect(from: peripheral)
                        }
                    })
                    return
                }
                
                // Show peripheral details
                if context.presentedViewController != nil {   // Dismiss current dialog if present
                    context.dismiss(animated: true, completion: { [weak self] () -> Void in
                        self?.showPeripheralDetails()
                    })
                }
                else {
                    context.showPeripheralDetails()
                }
            }
        }
    }

    private func didDisconnectFromPeripheral(notification: Notification) {

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
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return selectedPeripheral != nil
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        /*
        if let viewController = segue.destination as? UartViewController {
            viewController.blePeripheral = selectedPeripheral
        }
        else*/ if segue.identifier == "filterNameSettingsSegue", let controller = segue.destination.popoverPresentationController  {
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
        filtersRssiSlider.value = value != nil ? Float(-value!) : 100.0
        updateRssiValueLabel()
    }
    
    private func updateRssiValueLabel() {
        filterRssiValueLabel.text = "\(Int(-filtersRssiSlider.value)) dBM"
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
    
    
    // MARK: - UI
    private func updateScannedPeripherals() {
        
        // Reload table
        baseTableView.reloadData()
        
        // Select the previously selected row
        let peripherals = peripheralList.filteredPeripherals(forceUpdate: false)
        scanningWaitView.isHidden = peripherals.count > 0
        if let selectedPeripheral = selectedPeripheral, let selectedRow = peripherals.index(of: selectedPeripheral) {
            baseTableView.selectRow(at: IndexPath(row: selectedRow, section: 0), animated: false, scrollPosition: .none)
        }
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
        peripheralCell.titleLabel.text = peripheral.name ?? "<Unknown>"
        peripheralCell.rssiImageView.image = signalImage(for: peripheral.rssi)
        
        peripheralCell.subtitleLabel.isHidden = true
        
        peripheralCell.disconnectButton.isHidden = true
        peripheralCell.connectButton.isHidden = true
        peripheralCell.accessoryType = .disclosureIndicator
        
        /*
        peripheralCell.onConnect = { [unowned self] in
            self.showPeripheralDetails()
        }*/
        
        // Detail Subview
        let isDetailViewOpen = false //row == tableRowOpen
        peripheralCell.baseStackView.subviews[1].isHidden = !isDetailViewOpen
        if isDetailViewOpen {
            // setupPeripheralExtendedView(peripheralCell, advertisementData: blePeripheral.advertisementData)
        }
        
        return peripheralCell
    }
}

// MARK: UITableViewDelegate
extension ScannerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // Dismiss keyboard
        filtersNameTextField.resignFirstResponder()
        
        // Connect to selected peripheral
        let peripheral = peripheralList.filteredPeripherals(forceUpdate: false)[indexPath.row]
        selectedPeripheral = peripheral
        BleManager.sharedInstance.connect(to: peripheral)
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
