//
//  ControllerModuleViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class ControllerModuleViewController: ModuleViewController {

    // Constants
    static private let kPollInterval = 0.5
    
    static private let kSensorTitleKeys : [String] = ["controller_sensor_quaternion", "controller_sensor_accelerometer", "controller_sensor_gyro", "controller_sensor_magnetometer", "controller_sensor_location"]
    static private let kModuleTitleKeys : [String] = ["controller_module_pad", "controller_module_colorpicker"]
    
    // UI
    @IBOutlet weak var baseTableView: UITableView!

    // Data
    private let controllerData = ControllerModuleManager()
    private var contentItems = [Int]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup table
        baseTableView.contentInset = UIEdgeInsetsMake(44, 0, 0, 0)      // extend below navigation inset fix
  
        //
        updateContentItemsFromSensorsEnabled()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        controllerData.startUpdatingData(ControllerModuleViewController.kPollInterval) { [unowned self] in
            self.baseTableView.reloadData()
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        controllerData.stopUpdatingData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private let kDetailItemOffset = 100
    private func updateContentItemsFromSensorsEnabled() {
        var items = [Int]()
        var i = 0
        for j in 0..<ControllerModuleManager.numSensors {
            let isSensorEnabled = controllerData.isSensorEnabled(j)
            items.append(i)
            if isSensorEnabled {
                items.append(i+kDetailItemOffset)
            }
            i += 1
        }
        
        contentItems = items
    }

    // MARK: - Actions
    @IBAction func onClickHelp(sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
        let helpViewController = storyboard!.instantiateViewControllerWithIdentifier("HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("controller_help_text"), title: localizationManager.localizedString("controller_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .Popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender
        
        presentViewController(helpNavigationController, animated: true, completion: nil)
    }
}

// MARK: - UITableViewDataSource
extension ControllerModuleViewController : UITableViewDataSource {
    
    enum ControllerSection : Int  {
        case SensorData = 0
        case Module = 1
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch ControllerSection(rawValue: section)! {
        case .SensorData:
            //let enabledCount = sensorsEnabled.filter{ $0 }.count
            //return ControllerModuleViewController.kSensorTitleKeys.count + enabledCount
            return contentItems.count
        case .Module:
            return ControllerModuleViewController.kModuleTitleKeys.count
        }
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        var localizationKey: String!
        
        switch ControllerSection(rawValue: section)! {
        case .SensorData:
            localizationKey = "controller_sensor_title"
        case .Module:
            localizationKey = "controller_module_title"
        }
        
        return LocalizationManager.sharedInstance.localizedString(localizationKey)
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let localizationManager = LocalizationManager.sharedInstance
        var cell: UITableViewCell!
        switch ControllerSection(rawValue: indexPath.section)! {
            
        case .SensorData:
            let item = contentItems[indexPath.row]
            let isDetailCell = item>=kDetailItemOffset
            
            if isDetailCell {
                let sensorIndex = item - kDetailItemOffset
                let reuseIdentifier = "ComponentsCell"
                let componentsCell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath: indexPath) as! ControllerComponentsTableViewCell
             
                let componentNameKeys : [String]
                if sensorIndex == ControllerModuleManager.ControllerType.Location.rawValue {
                    componentNameKeys = ["lat", "long", "alt"]
                }
                else {
                    componentNameKeys = ["x", "y", "z", "w"]
                }
                if let sensorData = controllerData.getSensorData(sensorIndex) {
                    var i=0
                    for subview in componentsCell.componentsStackView.subviews {
                        let hasComponent = i<sensorData.count
                        subview.hidden = !hasComponent
                        if let label = subview as? UILabel where hasComponent {
                            let attributedText = NSMutableAttributedString(string: "\(componentNameKeys[i]): \(sensorData[i])")
                            let titleLength = componentNameKeys[i].lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
                            attributedText.addAttribute(NSFontAttributeName, value: UIFont.systemFontOfSize(12, weight: UIFontWeightMedium), range: NSMakeRange(0, titleLength))
                            label.attributedText = attributedText
                        }
                   
                        i += 1
                    }
                }
                else {
                    for subview in componentsCell.componentsStackView.subviews {
                        subview.hidden = true
                    }
                }
                
                cell = componentsCell
            }
            else {
                let reuseIdentifier = "SensorCell"
                let sensorCell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath: indexPath) as! ControllerSensorTableViewCell
                sensorCell.titleLabel!.text = localizationManager.localizedString( ControllerModuleViewController.kSensorTitleKeys[item])
                
                sensorCell.enableSwitch.on = controllerData.isSensorEnabled(item)
                sensorCell.onSensorEnabled = { [unowned self] (enabled) in
                    
                    self.controllerData.setSensorEnabled(enabled, index:item)
                    self.updateContentItemsFromSensorsEnabled()
                    
                    if let currentRow = self.contentItems.indexOf(item) {
                        let detailIndexPath = NSIndexPath(forRow: currentRow+1, inSection: indexPath.section)
                        if enabled {
                            tableView.insertRowsAtIndexPaths([detailIndexPath], withRowAnimation: .Top)
                        }
                        else {
                            tableView.deleteRowsAtIndexPaths([detailIndexPath], withRowAnimation: .Top)
                        }
                    }
                    
                    // self.baseTableView.reloadData()
                }
                cell = sensorCell
            }
            
        case .Module:
            let reuseIdentifier = "ModuleCell"
            cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .Default, reuseIdentifier: reuseIdentifier)
            }
            cell.accessoryType = .DisclosureIndicator
            cell.textLabel!.text = localizationManager.localizedString(ControllerModuleViewController.kModuleTitleKeys[indexPath.row])
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        switch ControllerSection(rawValue: indexPath.section)! {
        case .SensorData:
            let item = contentItems[indexPath.row]
            let isDetailCell = item>=kDetailItemOffset
            return isDetailCell ? 120: 44
        default:
            return 44
        }
    }
}

// MARK:  UITableViewDelegate
extension ControllerModuleViewController : UITableViewDelegate {
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        switch ControllerSection(rawValue: indexPath.section)! {
        case .Module:
            let controllerIdentifiers = ["ControllerPadViewController", "ControllerColorWheelViewController"]
            
            let viewController = storyboard!.instantiateViewControllerWithIdentifier(controllerIdentifiers[indexPath.row])
            //tabBarController!.navigationController!.showViewController(viewController, sender: self)
            navigationController?.showViewController(viewController, sender: self)
            
        default:
            break
        }
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}
