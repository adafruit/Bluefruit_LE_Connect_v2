//
//  InfoViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 05/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit
import CoreBluetooth

class InfoModeViewController: PeripheralModeViewController {
    // Config
    private static let kReadForbiddenCCCD = false     // Added to avoid generating a didModifyServices callback when reading Uart/DFU CCCD (bug??)

    // Constants
    static let kDeviceInformationService = "180A"
    static let kForbiddenCCCD = "2902"
    static let kDfuControlPointCharacteristicUUIDString = "00001531-1212-EFDE-1523-785FEABCD123"

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    @IBOutlet weak var waitView: UIActivityIndicatorView!

    // Data
    private static let kDisServiceUUID = CBUUID(string: InfoModeViewController.kDeviceInformationService)
    private static let kForbiddenDescriptorUUID = CBUUID(string: InfoModeViewController.kForbiddenCCCD)
    private static let kDfuControlPointCharacteristicUUID = CBUUID(string: InfoModeViewController.kDfuControlPointCharacteristicUUIDString)

    enum DisplayMode: Int {
        case auto = 0
        case text = 1
        case hex = 2
    }
    private let refreshControl = UIRefreshControl()
    fileprivate var services: [CBService]?
    fileprivate var itemDisplayMode = [String: DisplayMode]()

    private var shouldDiscoverCharacteristics = Preferences.infoIsRefreshOnLoadEnabled

    private var isDiscoveringServices = false
    fileprivate var elementsToDiscover = 0
    fileprivate var elementsDiscovered = 0
    fileprivate var valuesToRead = 0
    fileprivate var valuesRead = 0

    fileprivate var isFirstRun = true

    override func viewDidLoad() {
        super.viewDidLoad()

        assert(blePeripheral != nil)

        // Init
        shouldDiscoverCharacteristics = Preferences.infoIsRefreshOnLoadEnabled

        // Setup table
        baseTableView.estimatedRowHeight = 60
        baseTableView.rowHeight = UITableViewAutomaticDimension

        // Setup table refresh
        refreshControl.addTarget(self, action: #selector(onTableRefresh(_:)), for: .valueChanged)
        baseTableView.addSubview(refreshControl)
        baseTableView.sendSubview(toBack: refreshControl)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Discover services
        if isFirstRun {
            isFirstRun = false
            services = blePeripheral?.peripheral.services
            didDiscoverServices()       // Services were discovered previously
        }

        // Notifications
        registerNotifications(enabled: true)

        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral?.name ?? LocalizationManager.sharedInstance.localizedString("scanner_unnamed")

        self.title = traitCollection.horizontalSizeClass == .regular ? String(format: localizationManager.localizedString("info_navigation_title_format"), arguments: [name]) : localizationManager.localizedString("info_tab_title")

        // Refresh data
        baseTableView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Notifications
        registerNotifications(enabled: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - BLE Notifications
    private weak var peripheralDidUpdateNameObserver: NSObjectProtocol?
    private weak var peripheralDidModifyServicesObserver: NSObjectProtocol?

    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            peripheralDidUpdateNameObserver = notificationCenter.addObserver(forName: .peripheralDidUpdateName, object: nil, queue: .main, using: peripheralDidUpdateName)
            peripheralDidModifyServicesObserver = notificationCenter.addObserver(forName: .peripheralDidModifyServices, object: nil, queue: .main, using: peripheralDidModifyServices)
        } else {
            if let peripheralDidUpdateNameObserver = peripheralDidUpdateNameObserver {notificationCenter.removeObserver(peripheralDidUpdateNameObserver)}
            if let peripheralDidModifyServicesObserver = peripheralDidModifyServicesObserver {notificationCenter.removeObserver(peripheralDidModifyServicesObserver)}
        }
    }

    private func peripheralDidUpdateName(notification: Notification) {
        guard let selectedPeripheral = blePeripheral, let identifier = notification.userInfo?[BlePeripheral.NotificationUserInfoKey.uuid.rawValue] as? UUID, selectedPeripheral.identifier == identifier else {
            return
        }

        let name = notification.userInfo?[BlePeripheral.NotificationUserInfoKey.name.rawValue] as? String
        DLog("centralManager peripheralDidUpdateName: \(name ?? "<unknown>")")
    }

    private func peripheralDidModifyServices(notification: Notification) {
        guard let selectedPeripheral = blePeripheral, let identifier = notification.userInfo?[BlePeripheral.NotificationUserInfoKey.uuid.rawValue] as? UUID, selectedPeripheral.identifier == identifier else {
            return
        }
        // let invalidatedServices =  notification.userInfo?[BlePeripheral.NotificationUserInfoKey.invalidatedServices.rawValue] as? [CBService]
        DLog("info didModifyServices: \(selectedPeripheral.name ?? "<unknown>")")

        DispatchQueue.main.async { [weak self] in
            self?.blePeripheral?.reset()
            self?.discoverServices()
        }
    }

    // MARK: - Services
    private func discoverServices() {
        guard isDiscoveringServices == false else {
            DLog("warning: call to discoverServices while services discovery in process")
            return
        }

        isDiscoveringServices = true
        elementsToDiscover = 0
        elementsDiscovered = 0
        valuesToRead = 0
        valuesRead = 0

        services = nil
        showWait(true)
        blePeripheral?.discover(serviceUuids: nil) { [weak self] error in
            self?.didDiscoverServices()
        }
    }

    private func didDiscoverServices() {
        isDiscoveringServices = false

        services = blePeripheral?.peripheral.services

        guard let discoveredServices = services, !discoveredServices.isEmpty else {
            DLog("Warning: no services discovered")
            return
        }

        elementsToDiscover = 0
        elementsDiscovered = 0

        // Order services so "DIS" is at the top (if present)
        let kDisServiceUUID = "180A"    // DIS service UUID
        if let unorderedServices = services {
            services = unorderedServices.sorted(by: { (serviceA, serviceB) -> Bool in
                let isServiceBDis = serviceB.uuid.isEqual(CBUUID(string: kDisServiceUUID))
                return !isServiceBDis
            })
        }

        // Discover characteristics
        if shouldDiscoverCharacteristics {
            if let services = services {
                for service in services {
                    elementsToDiscover += 1
                    blePeripheral?.discover(characteristicUuids: nil, service: service) { error in
                        self.didDiscoverCharacteristics(for: service)
                    }
                }
            }
        }

        // Update UI
        DispatchQueue.main.async { [unowned self] in
            self.baseTableView?.reloadData()
            self.showWait(false)
        }
    }

    // MARK: - Characteristics
    private func didDiscoverCharacteristics(for service: CBService) {
        elementsDiscovered += 1

        if let characteristics = service.characteristics {

            for characteristic in characteristics {
                if characteristic.properties.rawValue & CBCharacteristicProperties.read.rawValue != 0 {
                    valuesToRead += 1
                    blePeripheral?.readCharacteristic(characteristic) { [weak self] (value, error) in
                        guard error == nil else {
                            DLog("Warning: Error reading characteristic: \(characteristic.uuid.uuidString). Error: \(error.debugDescription)")
                            return
                        }
                        self?.didReadCharacteristic()
                    }
                }

                //elementsToDiscover += 1       // Dont add descriptors to elementsToDiscover because the number of descriptors found is unknown
                blePeripheral?.discoverDescriptors(characteristic: characteristic) { [weak self] error in
                    guard error == nil else {
                        DLog("Warning: Error discovering descriptors for characteristic: \(characteristic.uuid.uuidString). Error: \(error.debugDescription)")
                        return
                    }

                    self?.didDicoverDescriptors(for: characteristic)
                }
            }
        }

        DispatchQueue.main.async { [unowned self] in
            self.baseTableView?.reloadData()
        }
    }

    private func didReadCharacteristic() {
        if elementsDiscovered >= elementsToDiscover {
            DispatchQueue.main.async { [weak self] in
                self?.baseTableView?.reloadData()
            }
        }
    }

    // MARK: - Descriptors
    private func didDicoverDescriptors(for characteristic: CBCharacteristic) {

        if let descriptors = characteristic.descriptors {
            for descriptor in descriptors {

                let isAForbiddenCCCD = descriptor.uuid == InfoModeViewController.kForbiddenDescriptorUUID && (characteristic.uuid == BlePeripheral.kUartRxCharacteristicUUID || characteristic.uuid == InfoModeViewController.kDfuControlPointCharacteristicUUID)
                if InfoModeViewController.kReadForbiddenCCCD || !isAForbiddenCCCD {
                    valuesToRead += 1
                    blePeripheral?.readDescriptor(descriptor) { [weak self] (data, error) in
                        self?.didReadDescriptor()
                    }
                }
            }
        }

        if self.elementsDiscovered == self.elementsToDiscover {
            DispatchQueue.main.async { [unowned self] in
                self.baseTableView?.reloadData()
            }
        }
    }

    private func didReadDescriptor() {
        if elementsDiscovered >= elementsToDiscover {
            DispatchQueue.main.async { [weak self] in
                self?.baseTableView?.reloadData()
            }
        }
    }

    private func showWait(_ show: Bool) {
        baseTableView.isHidden = show
        waitView.isHidden = !show
    }

    // MARK: - Actions
    @IBAction func onClickHelp(_ sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("info_help_text"), title: localizationManager.localizedString("info_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender

        present(helpNavigationController, animated: true, completion: nil)
    }

    // MARK - Actions
    @objc func onTableRefresh(_ sender: AnyObject) {
        refreshControl.endRefreshing()
        discoverServices()
    }
}

// MARK: - UITableViewDataSource
extension InfoModeViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return services?.count ?? 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let service = services?[section] else {
            DLog("warning: numberOfRowsInSection service is nil")
            return 0
        }

        guard let characteristics = service.characteristics else {
            return 0
        }

        let numCharacteristics = characteristics.count

        var numDescriptors = 0
        for characteristic in characteristics {
            numDescriptors += characteristic.descriptors?.count ?? 0
        }

        //DLog("section:\(section) - numCharacteristics: \(numCharacteristics), numDescriptors:\(numDescriptors), service: \(service.UUID.UUIDString)")
        return numCharacteristics + numDescriptors
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let service = services?[section] else {
            DLog("warning: titleForHeaderInSection service is nil")
            return nil
        }

        var identifier = service.uuid.uuidString
        if let name = BleUUIDNames.sharedInstance.nameForUUID(identifier) {
            identifier = name
        }

        return identifier
    }

    fileprivate func itemForIndexPath(_ indexPath: IndexPath) -> (Int, CBAttribute?, Bool) {
        let service = services![indexPath.section]

        // The same table view section is used for characteristics and descriptors. So first calculate if the current indexPath.row is for a characteristic or descriptor
        var currentItem: CBAttribute?
        var currentCharacteristicIndex = 0
        var currentRow = 0
        var isDescriptor = false

//        DLog("section:\(indexPath.section) - service: \(service.UUID.UUIDString)")
        while currentRow <= indexPath.row && currentCharacteristicIndex < service.characteristics!.count && service.characteristics != nil {
            let characteristic = service.characteristics![currentCharacteristicIndex]

            if currentRow == indexPath.row {
                currentItem = characteristic
                currentRow += 1     // same as break
            } else {
                currentRow += 1     // + 1 characteristic

                let numDescriptors = characteristic.descriptors?.count ?? 0
                if numDescriptors > 0 {
                    let remaining = indexPath.row-currentRow
                    if remaining < numDescriptors {
                        currentItem = characteristic.descriptors![remaining]
                        isDescriptor = true
                    }
                    currentRow += numDescriptors
                }
            }

            if currentItem == nil {
                currentCharacteristicIndex += 1
            }
        }

        if currentItem == nil {
            DLog("Error populating tableview")
        }

        return (currentCharacteristicIndex, currentItem, isDescriptor)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let service = services?[indexPath.section], service.characteristics != nil else {
            DLog("warning: cellForRowAtIndexPath characteristics is nil")
            return tableView.dequeueReusableCell(withIdentifier: "CharacteristicCell", for:indexPath)
        }

        let (currentCharacteristicIndex, currentItemOptional, isDescriptor) = itemForIndexPath(indexPath)

        guard let currentItem = currentItemOptional else {
            DLog("warning: current item is nil")
            return tableView.dequeueReusableCell(withIdentifier: "CharacteristicCell", for:indexPath)
        }

        //DLog("secrow: \(indexPath.section)/\(indexPath.row): ci: \(currentCharacteristicIndex) isD: \(isDescriptor))")

        // Intanciate cell
        let reuseIdentifier = isDescriptor ? "DescriptorCell":"CharacteristicCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for:indexPath)

        var identifier = ""
        var value = " "
        var valueData: Data?
        if let characteristic = service.characteristics?[currentCharacteristicIndex] {

            identifier = currentItem.uuid.uuidString

            let displayModeIdentifier = "\(service.uuid.uuidString)\(currentCharacteristicIndex)_\(identifier)"       // Descriptors in different characteristics or different services could have the same CBUUID
            var currentDisplayMode = DisplayMode.auto
            if let displayMode = itemDisplayMode[displayModeIdentifier] {
                currentDisplayMode = displayMode
            } else {
                itemDisplayMode[displayModeIdentifier] = .auto
            }

            if let name = BleUUIDNames.sharedInstance.nameForUUID(identifier) {
                identifier = name
            }

            if isDescriptor {
                let descriptor = currentItem as! CBDescriptor
                valueData = InfoModuleManager.parseDescriptorValue(descriptor)
            } else {
                valueData = characteristic.value
            }

            if valueData != nil {
                switch currentDisplayMode {
                case .auto:
                    if let characteristicString = String(data: valueData!, encoding: .utf8) {
                        if isStringPrintable(characteristicString) {
                            value = characteristicString
                        } else {      // print as hex
                            value = hexDescription(data: valueData!)
                        }
                    }
                case .text:
                    if let text = String(data:valueData!, encoding: .utf8) {
                        value = text
                    }
                case .hex:
                    value = hexDescription(data: valueData!)
                }
            }
        }

        let characteristicCell = cell as! InfoCharacteristicTableViewCell
        characteristicCell.titleLabel.text = identifier
        characteristicCell.subtitleLabel.text = valueData != nil ? value : LocalizationManager.sharedInstance.localizedString(isDescriptor ? "info_type_descriptor":"info_type_characteristic")
        characteristicCell.subtitleLabel.textColor = valueData != nil ? UIColor.black : UIColor.lightGray

        return cell
    }

    fileprivate func isStringPrintable(_ text: String) -> Bool {
        let printableCharacterSet = NSCharacterSet.alphanumerics
        let isPrintable  = text.rangeOfCharacter(from: printableCharacterSet) != nil
        return isPrintable
    }
}

// MARK: - UITableViewDelegate

extension InfoModeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        guard let service = services?[indexPath.section], service.characteristics != nil else {
            DLog("warning: didSelectRowAtIndexPath characteristics is nil")
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }

        let (currentCharacteristicIndex, currentItemOptional, isDescriptor) = itemForIndexPath(indexPath)

        guard let currentItem = currentItemOptional else {
            DLog("warning: current item is nil")
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }

        if let characteristic = service.characteristics?[currentCharacteristicIndex] {

            let identifier = currentItem.uuid.uuidString
            let displayModeIdentifier = "\(service.uuid.uuidString)\(currentCharacteristicIndex)_\(identifier)"       // Descriptors in different characteristics or different services could have the same CBUUID
            if let displayMode =  itemDisplayMode[displayModeIdentifier] {
                switch displayMode {
                case .text:
                    itemDisplayMode[displayModeIdentifier] = .hex
                case .hex:
                    itemDisplayMode[displayModeIdentifier] = .text
                default:
                    // Check if is printable
                    var isPrintable = false
                    var valueData: Data?
                    if isDescriptor {
                        let descriptor = currentItem as! CBDescriptor
                        valueData = InfoModuleManager.parseDescriptorValue(descriptor)
                    } else {
                        valueData = characteristic.value
                    }

                    if let value = valueData {
                        if let characteristicString = String(data:value, encoding: .utf8) {
                            isPrintable = isStringPrintable(characteristicString)
                        }
                    }
                    itemDisplayMode[displayModeIdentifier] = isPrintable ? .hex: .text
                }
            }

            tableView.reloadData()
            //tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}
