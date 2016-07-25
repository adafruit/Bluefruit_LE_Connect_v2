//
//  InfoViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 05/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class InfoModuleViewController: ModuleViewController {

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    @IBOutlet weak var waitView: UIActivityIndicatorView!
 //   @IBOutlet weak var enclosingView: UIView!
    
    // Delegates
    var onServicesDiscovered: (() -> ())?
    
    // Data
    private var blePeripheral: BlePeripheral?
    private var services: [CBService]?
    private var itemDisplayMode = [String : DisplayMode]()
    
    private var shouldDiscoverCharacteristics = Preferences.infoIsRefreshOnLoadEnabled
    
    private var isDiscoveringServices = false
    private var elementsToDiscover = 0
    private var elementsDiscovered = 0
    private var valuesToRead = 0
    private var valuesRead = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Peripheral should be connected
        blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        guard blePeripheral != nil else {
            DLog("Error: Info: blePeripheral is nil")
            return
        }

        // Setup table
        baseTableView.contentInset = UIEdgeInsetsMake(44, 0, 0, 0)      // extend below navigation inset fix
        baseTableView.estimatedRowHeight = 60
        baseTableView.rowHeight = UITableViewAutomaticDimension

        // Discover services
        shouldDiscoverCharacteristics = Preferences.infoIsRefreshOnLoadEnabled
        services = nil
        discoverServices()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral!.name != nil ? blePeripheral!.name! : LocalizationManager.sharedInstance.localizedString("peripherallist_unnamed")
        
        let title = String(format: localizationManager.localizedString("info_navigation_title_format"), arguments: [name])
        //tabBarController?.navigationItem.title = title
        navigationController?.navigationItem.title = title
        
        // Refresh data
        baseTableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func discoverServices() {
        guard isDiscoveringServices == false else {
            DLog("warning: call to discoverServices while services discovery in process")
            return;
        }
        
        isDiscoveringServices = true
        elementsToDiscover = 0
        elementsDiscovered = 0
        valuesToRead = 0
        valuesRead = 0
        
        services = nil
        showWait(true)
        BleManager.sharedInstance.discover(blePeripheral!, serviceUUIDs: nil)
    }
    
    func showWait(show: Bool) {
        baseTableView.hidden = show
        waitView.hidden = !show
    }
    
    // MARK: - Actions
    @IBAction func onClickHelp(sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
        let helpViewController = storyboard!.instantiateViewControllerWithIdentifier("HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("info_help_text"), title: localizationManager.localizedString("info_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .Popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender
        
        presentViewController(helpNavigationController, animated: true, completion: nil)
    }
}

extension InfoModuleViewController : UITableViewDataSource {
    enum DisplayMode : Int {
        case Auto = 0
        case Text = 1
        case Hex = 2
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Services
        if let services = services {
            return services.count
        }
        else {
            return 0
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let service = services![section]
        
        if let characteristics = service.characteristics {
            let numCharacteristics = characteristics.count

            var numDescriptors = 0
            for characteristic in characteristics {
                numDescriptors += characteristic.descriptors?.count ?? 0
            }
            
            return numCharacteristics + numDescriptors
        }
        else {
            return 0
        }
    }

    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let service = services?[section] else {
            DLog("warning: titleForHeaderInSection service is nil")
            return nil
        }
        
        var identifier = service.UUID.UUIDString
        if let name = BleUUIDNames.sharedInstance.nameForUUID(identifier) {
            identifier = name
        }

        return identifier
    }
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }
    
    private func itemForIndexPath(indexPath: NSIndexPath) -> (Int, CBAttribute, Bool) {
        let service = services![indexPath.section]
        
        // The same table view section is used for characteristics and descriptors. So first calculate if the current indexPath.row is for a characteristic or descriptor
        var currentItem: CBAttribute?
        var currentCharacteristicIndex = 0
        var currentRow = 0
        var isDescriptor = false
        while currentRow <= indexPath.row {
            let characteristic = service.characteristics![currentCharacteristicIndex]
            
            if currentRow == indexPath.row {
                currentItem = characteristic
                currentRow += 1     // same as break
            }
            else {
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
        
        return (currentCharacteristicIndex, currentItem!, isDescriptor)
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

        guard let service = services?[indexPath.section] where service.characteristics != nil else {
            DLog("warning: cellForRowAtIndexPath characteristics is nil")
            return tableView.dequeueReusableCellWithIdentifier("CharacteristicCell", forIndexPath:indexPath)
        }
        
        let (currentCharacteristicIndex, currentItem, isDescriptor) = itemForIndexPath(indexPath)
        
        //DLog("secrow: \(indexPath.section)/\(indexPath.row): ci: \(currentCharacteristicIndex) isD: \(isDescriptor))")
        
        // Intanciate cell
        let reuseIdentifier = isDescriptor ? "DescriptorCell":"CharacteristicCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath:indexPath)

        
        var identifier = ""
        var value = " "
        var valueData: NSData?
        if let characteristic = service.characteristics?[currentCharacteristicIndex] {
            
            identifier = currentItem.UUID.UUIDString
            
            let displayModeIdentifier = "\(currentCharacteristicIndex)_\(identifier)"       // Descriptors in different characteristics could have the same CBUUID
            var currentDisplayMode = DisplayMode.Auto
            if let displayMode = itemDisplayMode[displayModeIdentifier] {
                currentDisplayMode = displayMode
            }
            else {
                itemDisplayMode[displayModeIdentifier] = .Auto
            }
            
            if let name = BleUUIDNames.sharedInstance.nameForUUID(identifier) {
                identifier = name
            }
            
            if isDescriptor {
                let descriptor = currentItem as! CBDescriptor
                valueData = InfoModuleManager.parseDescriptorValue(descriptor)
            }
            else {
                valueData = characteristic.value
            }
            
            if valueData != nil {
                switch currentDisplayMode {
                case .Auto:
                    if let characteristicString = NSString(data: valueData!, encoding: NSUTF8StringEncoding) as String? {
                        if isStringPrintable(characteristicString) {
                            value = characteristicString
                        }
                        else {      // print as hex
                            value = hexString(valueData!)
                        }
                    }
                case .Text:
                    if let text = NSString(data:valueData!, encoding: NSUTF8StringEncoding) as? String {
                        value = text
                    }
                case .Hex:
                    value = hexString(valueData!)
                }
            }
        }
        
        let characteristicCell = cell as! InfoCharacteristicTableViewCell
        characteristicCell.titleLabel.text = identifier
        characteristicCell.subtitleLabel.text = valueData != nil ? value : LocalizationManager.sharedInstance.localizedString(isDescriptor ? "info_type_descriptor":"info_type_characteristic")
        characteristicCell.subtitleLabel.textColor = valueData != nil ? UIColor.blackColor() : UIColor.lightGrayColor()
        
        return cell
    }
    
    private func isStringPrintable(text: String) -> Bool {
        //NSCharacterSet
        //let printableCharacterSet:NSCharacterSet = NSCharacterSet(charactersInString: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLKMNOPQRSTUVWXYZ0123456789")
        
        let printableCharacterSet = NSCharacterSet.alphanumericCharacterSet()
        let isPrintable  = text.rangeOfCharacterFromSet(printableCharacterSet) != nil
        return isPrintable
    }
}

extension InfoModuleViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        guard let service = services?[indexPath.section] where service.characteristics != nil else {
            DLog("warning: didSelectRowAtIndexPath characteristics is nil")
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
            return
        }
        
        let (currentCharacteristicIndex, currentItem, isDescriptor) = itemForIndexPath(indexPath)
        
        if let characteristic = service.characteristics?[currentCharacteristicIndex] {
            
            let identifier = currentItem.UUID.UUIDString
            let displayModeIdentifier = "\(currentCharacteristicIndex)_\(identifier)"       // Descriptors in different characteristics could have the same CBUUID
            if let displayMode =  itemDisplayMode[displayModeIdentifier] {
                switch displayMode {
                case .Text:
                    itemDisplayMode[displayModeIdentifier] = .Hex
                case .Hex:
                    itemDisplayMode[displayModeIdentifier] = .Text
                default:
                    
                    // Check if is printable
                    var isPrintable = false
                    var valueData: NSData?
                    if isDescriptor {
                        let descriptor = currentItem as! CBDescriptor
                        valueData = InfoModuleManager.parseDescriptorValue(descriptor)
                    }
                    else {
                        valueData = characteristic.value
                    }
                    
                    if let value = valueData {
                        if let characteristicString = NSString(data:value, encoding: NSUTF8StringEncoding) as String? {
                            isPrintable = isStringPrintable(characteristicString)
                        }
                    }
                    itemDisplayMode[displayModeIdentifier] = isPrintable ? .Hex: .Text
                }
            }
            
            tableView.reloadData()
            //tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
        }
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}

// MARK: - CBPeripheralDelegate
extension InfoModuleViewController : CBPeripheralDelegate {
    
    func peripheralDidUpdateName(peripheral: CBPeripheral) {
        DLog("centralManager peripheralDidUpdateName: \(peripheral.name != nil ? peripheral.name! : "")")
        /*
        dispatch_async(dispatch_get_main_queue(),{ [weak self] in
            self?.discoverServices()
            })
 */
    }
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        DLog("centralManager didModifyServices: \(peripheral.name != nil ? peripheral.name! : "")")
        
        dispatch_async(dispatch_get_main_queue(),{ [weak self] in
            self?.discoverServices()
        })
    }

    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        isDiscoveringServices = false

        if services == nil {
            //DLog("centralManager didDiscoverServices: \(peripheral.name != nil ? peripheral.name! : "")")
            
            services = blePeripheral?.peripheral.services
            elementsToDiscover = 0
            elementsDiscovered = 0
            
            // Order services so "DIS" is at the top (if present)
            let kDisServiceUUID = "180A"    // DIS service UUID
            if let unorderedServices = services {
                services = unorderedServices.sort({ (serviceA, serviceB) -> Bool in
                    let isServiceBDis = serviceB.UUID.isEqual(CBUUID(string: kDisServiceUUID))
                    return !isServiceBDis
                })
            }
            
            // Discover characteristics
            if shouldDiscoverCharacteristics {
                if let services = services {
                    for service in services {
                        elementsToDiscover += 1
                        blePeripheral?.peripheral.discoverCharacteristics(nil, forService: service)
                    }
                }
            }
            
            // Update UI
            dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
 
                //self.updateDiscoveringStatusLabel()
                self.baseTableView.reloadData()
                self.showWait(false)
                self.onServicesDiscovered?()
                })
        }
    }

    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        //DLog("centralManager didDiscoverCharacteristicsForService: \(service.UUID.UUIDString)")
        
        elementsDiscovered += 1
        
 //       var discoveringDescriptors = false
        if let characteristics = service.characteristics {
            if (characteristics.count > 0)  {
//                discoveringDescriptors = true
            }
            for characteristic in characteristics {
                if (characteristic.properties.rawValue & CBCharacteristicProperties.Read.rawValue != 0) {
                    valuesToRead += 1
                    peripheral.readValueForCharacteristic(characteristic)
                }
                
                //elementsToDiscover += 1       // Dont add descriptors to elementsToDiscover because the number of descriptors found is unknown
                blePeripheral?.peripheral.discoverDescriptorsForCharacteristic(characteristic)
            }
        }
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            //self.updateDiscoveringStatusLabel()
            //if (!discoveringDescriptors && && self.elementsDiscovered == self.elementsToDiscover) {
                self.baseTableView.reloadData()
            //}
            })
    }

    func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        //DLog("centralManager didDiscoverDescriptorsForCharacteristic: \(characteristic.UUID.UUIDString)")
        //elementsDiscovered += 1
        
        if let descriptors = characteristic.descriptors {
            for descriptor in descriptors {
                valuesToRead += 1
                peripheral.readValueForDescriptor(descriptor)
            }
        }
        
        if (self.elementsDiscovered == self.elementsToDiscover) {
            dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
                //self.updateDiscoveringStatusLabel()
                self.baseTableView.reloadData()
                })
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        //DLog("centralManager didUpdateValueForCharacteristic: \(characteristic.UUID.UUIDString)")
        
        valuesRead += 1
        
        if (self.elementsDiscovered >= self.elementsToDiscover) {
            dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
                //self.updateDiscoveringStatusLabel()
                self.baseTableView.reloadData()
                })
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        //DLog("centralManager didUpdateValueForDescriptor: \(descriptor.UUID.UUIDString)")
        valuesRead += 1
        
        DLog("didUpdateValueForDescriptor: \(descriptor.UUID.UUIDString) characteristic: \(descriptor.characteristic.UUID.UUIDString)")
        
//        DLog("disco \(self.elementsDiscovered)/\(self.elementsToDiscover)")
        if (self.elementsDiscovered >= self.elementsToDiscover) {
            dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
                //self.updateDiscoveringStatusLabel()
                self.baseTableView.reloadData()
                })
        }
    }
}
