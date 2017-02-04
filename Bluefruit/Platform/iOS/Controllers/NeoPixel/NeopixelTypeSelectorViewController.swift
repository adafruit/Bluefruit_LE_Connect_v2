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

    fileprivate var types: [[String: AnyObject]]?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Read types from resources
        let path = Bundle.main.path(forResource: "NeopixelTypes", ofType: "plist")!
        types = NSArray(contentsOfFile: path) as? [Dictionary]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        preferredContentSize = CGSize(width: preferredContentSize.width, height: baseTableView.contentSize.height)
    }
}


// MARK: - UITableViewDataSource
extension NeopixelTypeSelectorViewController : UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return types != nil ? types!.count: 0
        }
        else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var reuseIdentifier: String
        if indexPath.section == 0 {
            reuseIdentifier = "TextCell"
        }
        else {
            reuseIdentifier = "TypeValueCell"
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for:indexPath as IndexPath)
        return cell
    }
    

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let row = indexPath.row
        
        if indexPath.section == 0 {
            let uartCell = cell as! UartSettingTableViewCell
            let type = types![row]
            uartCell.textLabel?.text = type["name"] as? String
            
            let isCurrentType = currentType == UInt16((type["value"] as! NSNumber).intValue)
            uartCell.accessoryType = isCurrentType ? .checkmark:.none
        }
        else {
            let typeValueCell = cell as! NeopixelTypeValueTableViewCell
            if let currentType = currentType {
                typeValueCell.valueTextField.text = String(currentType)
            }
            typeValueCell.delegate = self
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
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
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 0 {
            tableView.deselectRow(at: indexPath as IndexPath, animated: indexPath.section == 0)
            
            let type = types![indexPath.row]
            currentType =  UInt16((type["value"] as! NSNumber).intValue)
            baseTableView.reloadData()
        }
       
    }
}

// MARK: - NeopixelTypeValueTableViewCellDelegate
extension NeopixelTypeSelectorViewController: NeopixelTypeValueTableViewCellDelegate {
    func onSetValue(_ value: UInt16) {
         dismiss(animated: true) {[unowned self] () -> Void in
            self.onClickSetType?(value)
         }
    }
}
