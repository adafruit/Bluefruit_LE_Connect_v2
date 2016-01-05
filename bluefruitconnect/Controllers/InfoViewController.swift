//
//  InfoViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 25/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa
import CoreBluetooth


class InfoViewController: NSViewController, CBPeripheralDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private static let kExpandAllNodes  = true
    
    @IBOutlet weak var baseTableView: NSOutlineView!
    
    var onServicesDiscovered : (() -> ())?
    
    private var blePeripheral : BlePeripheral?
    private var services : [CBService]?
    private var gattUUIds : [String : String]?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Read known UUIDs
        let path = NSBundle.mainBundle().pathForResource("GattUUIDs", ofType: "plist")!
        gattUUIds = NSDictionary(contentsOfFile: path) as? [String : String]
    
        // Peripheral should be connected
        blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        
        // Discover services
        discoverServices()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
    }
    
    func discoverServices() {
        BleManager.sharedInstance.discover(blePeripheral!, serviceUUIDs: nil)
    }
  
    // MARK: - NSOutlineViewDataSource
    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if (item == nil) {
            // Services
            if let services = services {
                return services.count
            }
            else {
                return 0
            }
        }
        else if let service = item as? CBService {
            return service.characteristics == nil ?0:service.characteristics!.count
        }
        else if let characteristic = item as? CBCharacteristic {
            return characteristic.descriptors == nil ?0:characteristic.descriptors!.count
        }
        else {
            return 0
        }
        
    }
    
    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        if let service = item as? CBService {
            return service.characteristics?.count > 0
        }
        else if let characteristic = item as? CBCharacteristic {
            return characteristic.descriptors?.count > 0
        }
        else {
            return false
        }
    }
    
    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if (item == nil) {
            return services![index]
        }
        else if let service = item as? CBService {
            return service.characteristics![index]
        }
        else if let characteristic = item as? CBCharacteristic {
            return characteristic.descriptors![index]
        }
        else {
            return "<Unknown>"
        }
    }
    
    
    // MARK: NSOutlineViewDelegate
    
    func outlineView(outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
        
        var cell = NSTableCellView()
        
        if let columnIdentifier = tableColumn?.identifier {
            switch(columnIdentifier) {
            case "UUIDColumn":
                cell = outlineView.makeViewWithIdentifier("InfoNameCell", owner: self) as! NSTableCellView
                
                var identifier = ""
                if let service = item as? CBService {
                    identifier = service.UUID.UUIDString
                }
                else if let characteristic = item as? CBCharacteristic {
                    identifier = characteristic.UUID.UUIDString
                }
                else if let descriptor = item as? CBDescriptor {
                    identifier = descriptor.UUID.UUIDString
                }
                
                if let name = gattUUIds?[identifier] {
                    identifier = name
                }
                cell.textField?.stringValue = identifier
            
            case "ValueStringColumn":
                cell = outlineView.makeViewWithIdentifier("InfoValueStringCell", owner: self) as! NSTableCellView
                var value : String = ""
                if let characteristic = item as? CBCharacteristic {
                    if let characteristicValue = characteristic.value {
                        if let characteristicString = NSString(data:characteristicValue, encoding: NSUTF8StringEncoding) as String? {
                            value = characteristicString
                        }
                    }
                }
                else if let descriptor = item as? CBDescriptor {
                    if let descriptorValue = descriptor.value as? NSData{
                        if let descriptorString = NSString(data:descriptorValue, encoding: NSUTF8StringEncoding) as String? {
                            value = descriptorString
                        }
                    }
                }
                
                cell.textField?.stringValue = value
                
            case "ValueHexColumn":
                cell = outlineView.makeViewWithIdentifier("InfoValueHexCell", owner: self) as! NSTableCellView
                var value : String = ""
                if let characteristic = item as? CBCharacteristic {
                    if let characteristicValue = characteristic.value {
                        value = hexString(characteristicValue)
                    }
                }
                else if let descriptor = item as? CBDescriptor {
                    if let descriptorValue = descriptor.value as? NSData{
                        value = hexString(descriptorValue)
                    }
                }
                
                cell.textField?.stringValue = value
                
            case "TypeColumn":
                cell = outlineView.makeViewWithIdentifier("InfoTypeCell", owner: self) as! NSTableCellView
                
                var type = "<Unknown Type>"
                if let _ = item as? CBService {
                    type = "Service"
                }
                else if let _ = item as? CBCharacteristic {
                    type = "Characteristic"
                }
                else if let _ = item as? CBDescriptor {
                    type = "Descriptor"
                }
                cell.textField?.stringValue = type
                
            default:
                cell.textField?.stringValue = ""
            }
        }
        
        
        return cell
    }
    
    
    // MARK: - CBPeripheralDelegate
    
    func peripheralDidUpdateName(peripheral: CBPeripheral) {
        DLog("centralManager peripheralDidUpdateName: \(peripheral.name != nil ? peripheral.name! : "")")
        discoverServices()
    }
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        DLog("centralManager didModifyServices: \(peripheral.name != nil ? peripheral.name! : "")")
        discoverServices()
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        DLog("centralManager didDiscoverServices: \(peripheral.name != nil ? peripheral.name! : "")")
        
        services = blePeripheral?.peripheral.services
        
        // Discover characteristics
        if let services = services {
            for service in services {
                blePeripheral?.peripheral.discoverCharacteristics(nil, forService: service)
            }
        }
        
        // Update UI
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            
            self.baseTableView.reloadData()
            self.onServicesDiscovered?()
            })
    }

    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        DLog("centralManager didDiscoverCharacteristicsForService: \(service.UUID.UUIDString)")
        
        var discoveringDescriptors = false
        if let characteristics = service.characteristics {
            if (characteristics.count > 0)  {
                discoveringDescriptors = true
            }
            for characteristic in characteristics {
                if (characteristic.properties.rawValue & CBCharacteristicProperties.Read.rawValue != 0) {
                    peripheral.readValueForCharacteristic(characteristic)
                }
                
                blePeripheral?.peripheral.discoverDescriptorsForCharacteristic(characteristic)
            }
        }
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.baseTableView.reloadData()
            if (!discoveringDescriptors && InfoViewController.kExpandAllNodes) {
                // Expand all nodes if not waiting for descriptors
                self.baseTableView.expandItem(nil, expandChildren: true)
            }
            })
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        DLog("centralManager didDiscoverDescriptorsForCharacteristic: \(characteristic.UUID.UUIDString)")

        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            
            self.baseTableView.reloadData()
            
            if (InfoViewController.kExpandAllNodes) {
                // Expand all nodes
                self.baseTableView.expandItem(nil, expandChildren: true)
            }
            })
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        DLog("centralManager didUpdateValueForCharacteristic: \(characteristic.UUID.UUIDString)")

        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            
            self.baseTableView.reloadData()
            })
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        DLog("centralManager didUpdateValueForDescriptor: \(descriptor.UUID.UUIDString)")

        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.baseTableView.reloadData()
            })
    }
    
    
}
