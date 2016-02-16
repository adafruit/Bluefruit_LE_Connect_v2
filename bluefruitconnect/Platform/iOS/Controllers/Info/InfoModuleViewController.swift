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
    var onServicesDiscovered : (() -> ())?
    
    // Data
    private var blePeripheral : BlePeripheral?
    private var services : [CBService]?
    private var characteristicDisplayMode = [String : DisplayMode]()
    
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
        baseTableView.estimatedRowHeight = 60
        baseTableView.rowHeight = UITableViewAutomaticDimension
        /*
        enclosingView.layer.borderWidth = 1
        enclosingView.layer.borderColor = UIColor.lightGrayColor().CGColor
        enclosingView.layer.masksToBounds = true
        */
        // Discover services
        shouldDiscoverCharacteristics = Preferences.infoIsRefreshOnLoadEnabled
        services = nil
        discoverServices()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let title = String(format: localizationManager.localizedString("info_navigation_title_format"), arguments: [blePeripheral!.name])
        tabBarController?.navigationItem.title = title
        
        // Refresh data
        baseTableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func discoverServices() {
        isDiscoveringServices = true
        elementsToDiscover = 0
        elementsDiscovered = 0
        valuesToRead = 0
        valuesRead = 0
        
        services = nil
        showWait(true)
//        self.baseTableView.reloadData()
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
        let numCharacteristics = service.characteristics == nil ? 0 : service.characteristics!.count
        return numCharacteristics
    }
    /*
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let service = services![section]
        var identifier = service.UUID.UUIDString
        if let name = BleUUIDNames.sharedInstance.nameForUUID(identifier) {
            identifier = name
        }
        
        let reuseIdentifier = "ServiceCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath: NSIndexPath(forRow: -1, inSection: section)) as! InfoCharacteristicTableViewCell
        cell.titleLabel.text = identifier
        cell.subtitleLabel.text = LocalizationManager.sharedInstance.localizedString("info_type_service")
        return cell.contentView
    }
*/
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let service = services![section]
        var identifier = service.UUID.UUIDString
        if let name = BleUUIDNames.sharedInstance.nameForUUID(identifier) {
            identifier = name
        }

        return identifier
    }
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let reuseIdentifier = "CharacteristicCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath:indexPath)
        /*
        return cell
    }
    
    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
*/
        let service = services![indexPath.section]
        
        var identifier = ""
        var value = " "
        var hasValue = false
        if let characteristic = service.characteristics?[indexPath.row] {
            
            identifier = characteristic.UUID.UUIDString
            
            var currentDisplayMode = DisplayMode.Auto
            if let displayMode = characteristicDisplayMode[identifier] {
                currentDisplayMode = displayMode
            }
            else {
                characteristicDisplayMode[identifier] = .Auto
            }
            
            if let name = BleUUIDNames.sharedInstance.nameForUUID(identifier) {
                identifier = name
            }
            
            if let characteristicValue = characteristic.value {
                hasValue = true
                
                switch currentDisplayMode {
                case .Auto:
                    if let characteristicString = NSString(data:characteristicValue, encoding: NSUTF8StringEncoding) as String? {
                        if isStringPrintable(characteristicString) {
                            value = characteristicString
                        }
                        else {      // print as hex
                            value = hexString(characteristicValue)
                        }
                    }
                case .Text:
                    if let text = NSString(data:characteristicValue, encoding: NSUTF8StringEncoding) as? String {
                        value = text
                    }
                case .Hex:
                    value = hexString(characteristicValue)
                }
            }
            
        }
        let characteristicCell = cell as! InfoCharacteristicTableViewCell
        characteristicCell.titleLabel.text = identifier
        characteristicCell.subtitleLabel.text = hasValue ? value : LocalizationManager.sharedInstance.localizedString("info_type_characteristic")
        characteristicCell.subtitleLabel.textColor = hasValue ? UIColor.blackColor() : UIColor.lightGrayColor()
        
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

        let service = services![indexPath.section]
        if let characteristic = service.characteristics?[indexPath.row] {
            
            let identifier = characteristic.UUID.UUIDString
            if let displayMode =  characteristicDisplayMode[identifier] {
                switch displayMode {
                case .Text:
                    characteristicDisplayMode[identifier] = .Hex
                case .Hex:
                    characteristicDisplayMode[identifier] = .Text
                default:
                    
                    // Check if is printable
                    var isPrintable = false
                    if let characteristic = service.characteristics?[indexPath.row] {
                        if let characteristicValue = characteristic.value {
                            if let characteristicString = NSString(data:characteristicValue, encoding: NSUTF8StringEncoding) as String? {
                                isPrintable = isStringPrintable(characteristicString)
                            }
                        }
                    }
                    characteristicDisplayMode[identifier] = isPrintable ? .Hex: .Text
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
        discoverServices()
    }
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        DLog("centralManager didModifyServices: \(peripheral.name != nil ? peripheral.name! : "")")
        discoverServices()
    }

    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        isDiscoveringServices = false

        if services == nil {
            //DLog("centralManager didDiscoverServices: \(peripheral.name != nil ? peripheral.name! : "")")
            
            services = blePeripheral?.peripheral.services
            elementsToDiscover = 0
            elementsDiscovered = 0
            
            // Discover characteristics
            if shouldDiscoverCharacteristics {
                if let services = services {
                    for service in services {
                        elementsToDiscover++
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
        
        elementsDiscovered++
        
//        var discoveringDescriptors = false
        if let characteristics = service.characteristics {
            if (characteristics.count > 0)  {
               // discoveringDescriptors = true
            }
            for characteristic in characteristics {
                if (characteristic.properties.rawValue & CBCharacteristicProperties.Read.rawValue != 0) {
                    valuesToRead++
                    peripheral.readValueForCharacteristic(characteristic)
                }
                
                elementsToDiscover++
                blePeripheral?.peripheral.discoverDescriptorsForCharacteristic(characteristic)
            }
        }
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            //self.updateDiscoveringStatusLabel()
            //if (self.elementsDiscovered == self.elementsToDiscover) {
                self.baseTableView.reloadData()
            //}
            })
    }

    func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        //DLog("centralManager didDiscoverDescriptorsForCharacteristic: \(characteristic.UUID.UUIDString)")
        elementsDiscovered++
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            //self.updateDiscoveringStatusLabel()
            if (self.elementsDiscovered == self.elementsToDiscover) {
                self.baseTableView.reloadData()
            }
            })
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        //DLog("centralManager didUpdateValueForCharacteristic: \(characteristic.UUID.UUIDString)")
        
        valuesRead++
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            //self.updateDiscoveringStatusLabel()
            if (self.elementsDiscovered == self.elementsToDiscover) {
                self.baseTableView.reloadData()
            }
            })
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        //DLog("centralManager didUpdateValueForDescriptor: \(descriptor.UUID.UUIDString)")
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            //self.updateDiscoveringStatusLabel()
            if (self.elementsDiscovered == self.elementsToDiscover) {
                self.baseTableView.reloadData()
            }
            })
    }
}
