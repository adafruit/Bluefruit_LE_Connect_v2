//
//  NeopixelTypeSelectorViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 19/04/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class NeopixelTypeSelectorViewController: UIViewController {

    // UI
    @IBOutlet weak var baseTableView: UITableView!

    // Data
    var onClickSetType:((UInt16)->())?
    var currentType: UInt16?

    private var types: [[String: AnyObject]]?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Read types from resources
        let path = NSBundle.mainBundle().pathForResource("NeopixelTypes", ofType: "plist")!
        types = NSArray(contentsOfFile: path) as? [Dictionary]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        preferredContentSize = CGSizeMake(preferredContentSize.width, baseTableView.contentSize.height)
    }
}


// MARK: - UITableViewDataSource
extension NeopixelTypeSelectorViewController : UITableViewDataSource {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var title: String?
        switch section {
        case 0:
            title = "PREDEFINED PIXEL TYPES"
        case 1:
            title = "PIXEL CONFIG REGISTER"
        default:
            break
        }
        return title
    }
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return types != nil ? types!.count: 0
        }
        else {
            return 1
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        var reuseIdentifier: String
        if indexPath.section == 0 {
            reuseIdentifier = "TextCell"
        }
        else {
            reuseIdentifier = "TypeValueCell"
        }
        
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath:indexPath)
        return cell
    }
    
    
    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        
        
        let row = indexPath.row
        
        if indexPath.section == 0 {
            let uartCell = cell as! UartSettingTableViewCell
            let type = types![row]
            uartCell.textLabel?.text = type["name"] as? String
            
            let isCurrentType = currentType == UInt16((type["value"] as! NSNumber).integerValue)
            uartCell.accessoryType = isCurrentType ? .Checkmark:.None
        }
        else {
            let typeValueCell = cell as! NeopixelTypeValueTableViewCell
            if let currentType = currentType {
                typeValueCell.valueTextField.text = String(currentType)
            }
            typeValueCell.delegate = self
                        
//            uartCell.textLabel?.text = "Line Strip"
        }
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 44
        }
        else {
            return 88
        }
    }
}

// MARK: - UITableViewDelegate
extension NeopixelTypeSelectorViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        if indexPath.section == 0 {
            tableView.deselectRowAtIndexPath(indexPath, animated: indexPath.section == 0)
            
            let type = types![indexPath.row]
            currentType =  UInt16((type["value"] as! NSNumber).integerValue)
            baseTableView.reloadData()
        }
       
    }
}

// MARK: - NeopixelTypeValueTableViewCellDelegate
extension NeopixelTypeSelectorViewController: NeopixelTypeValueTableViewCellDelegate {
    func onSetValue(value: UInt16) {
         dismissViewControllerAnimated(true) {[unowned self] () -> Void in
            self.onClickSetType?(value)
         }
        
    }
}