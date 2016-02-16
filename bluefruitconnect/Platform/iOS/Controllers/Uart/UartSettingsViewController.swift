//
//  UartSettingsViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 07/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class UartSettingsViewController: UIViewController {

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    
    // Data
    var onClickClear : (()->())?
    var onClickExport : (()->())?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //view.backgroundColor = StyleConfig.backgroundColor
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
extension UartSettingsViewController : UITableViewDataSource {
    
    private enum SettingsSection : Int {
        case DisplayMode = 0
        case DataMode = 1
        case Echo = 2
        case Eol = 3
    }
    
    private enum ActionsSetion : Int {
        case Clear = 0
        case Export = 1
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var title: String?
        switch section {
        case 0:
            title = "Display settings"
        case 1:
            title = "Actions"
        default:
            break
        }
        return title
    }
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 4
        }
        else {
            return 2
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let row = indexPath.row
        var reuseIdentifier : String!
        
        if indexPath.section == 0 {
            switch SettingsSection(rawValue: row)! {
            case .DisplayMode:
                reuseIdentifier = "UartSettingSegmentedCell"
            case .DataMode:
                reuseIdentifier = "UartSettingSegmentedCell"
            case .Echo:
                reuseIdentifier = "UartSettingSwitchCell"
            case .Eol:
                reuseIdentifier = "UartSettingSwitchCell"
            }
        }
        else {
            switch ActionsSetion(rawValue: row)! {
            case .Clear:
                reuseIdentifier = "UartTextCell"
            case .Export:
                reuseIdentifier = "UartTextCell"
            }
        }
        
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath:indexPath)

        cell.backgroundColor = UIColor(hex: 0xe2e1e0)
        return cell
    }
    
    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        
        let localizationManager = LocalizationManager.sharedInstance
        let uartCell = cell as! UartSettingTableViewCell
        var titleKey: String?
        
        let row = indexPath.row
        
        if indexPath.section == 0 {
            switch SettingsSection(rawValue: row)! {
            case .DisplayMode:
                titleKey = "uart_settings_displayMode_title"
                uartCell.segmentedControl.setTitle(localizationManager.localizedString("uart_settings_displayMode_timestamp"), forSegmentAtIndex: 0)
                uartCell.segmentedControl.setTitle(localizationManager.localizedString("uart_settings_displayMode_text"), forSegmentAtIndex: 1)
                uartCell.segmentedControl.selectedSegmentIndex = Preferences.uartIsDisplayModeTimestamp ? 0:1
                uartCell.onSegmentedControlIndexChanged = { selectedIndex in
                    Preferences.uartIsDisplayModeTimestamp = selectedIndex == 0
                }
            case .DataMode:
                titleKey = "uart_settings_dataMode_title"
                uartCell.segmentedControl.setTitle(localizationManager.localizedString("uart_settings_dataMode_ascii"), forSegmentAtIndex: 0)
                uartCell.segmentedControl.setTitle(localizationManager.localizedString("uart_settings_dataMode_hex"), forSegmentAtIndex: 1)
                uartCell.segmentedControl.selectedSegmentIndex = Preferences.uartIsInHexMode ? 1:0
                uartCell.onSegmentedControlIndexChanged = { selectedIndex in
                    Preferences.uartIsInHexMode = selectedIndex == 1
                }
            case .Echo:
                titleKey = "uart_settings_echo_title"
                uartCell.switchControl.on = Preferences.uartIsEchoEnabled
                uartCell.onSwitchEnabled = { enabled in
                    Preferences.uartIsEchoEnabled = enabled
                }
            case .Eol:
                titleKey = "uart_settings_eol_title"
                uartCell.switchControl.on = Preferences.uartIsAutomaticEolEnabled
                uartCell.onSwitchEnabled = { enabled in
                    Preferences.uartIsAutomaticEolEnabled = enabled
                }
            }

            uartCell.titleLabel.text = titleKey == nil ? nil : localizationManager.localizedString(titleKey!)+":"
        }
        else {
            var iconIdentifier : String?
            switch ActionsSetion(rawValue: row)! {
            case .Clear:
                titleKey = "uart_settings_clear_title"
                iconIdentifier = "clear_icon"
                
            case .Export:
                titleKey = "uart_settings_export_title"
                iconIdentifier = "action_icon"
            }
            
            uartCell.textLabel?.text = titleKey == nil ? nil : localizationManager.localizedString(titleKey!)
            uartCell.imageView?.image = iconIdentifier == nil ? nil : UIImage(named: iconIdentifier!)
        }
    }
}

// MARK: - UITableViewDelegate
extension UartSettingsViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        if indexPath.section == 1 {
            switch ActionsSetion(rawValue: indexPath.row)! {
            case .Clear:
                presentingViewController?.dismissViewControllerAnimated(true, completion: { [unowned self] () -> Void in
                    self.onClickClear?()
                })
            case .Export:
                presentingViewController?.dismissViewControllerAnimated(true, completion: { [unowned self] () -> Void in
                    self.onClickExport?()
                })
            }
        }
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}
