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

    // Params
    var onClickClear: (() -> Void)?
    var onClickExport: (() -> Void)?

    // Data
    private var openCellIndexPath: IndexPath?
    private var titlesIdForDisplayMode: [String] {
        return ["uart_settings_displayMode_timestamp", "uart_settings_displayMode_text", "uart_settings_displayMode_terminal"]
    }
    private var titlesForEolCharacters: [String] {
        return ["\\n", "\\r", "\\n\\r", "\\r\\n"]
    }

    // MARK: - View Lifecycle
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

        preferredContentSize = CGSize(width: preferredContentSize.width, height: baseTableView.contentSize.height)
    }
    
    // MARK: - Cell Utils
    private func tagFromIndexPath(_ indexPath: IndexPath, scale: Int) -> Int {
        // To help identify each textfield a tag is added with this format: ab (a is the section, b is the row)
        return indexPath.section * scale + indexPath.row
    }
    
    private func indexPathFromTag(_ tag: Int, scale: Int) -> IndexPath {
        // To help identify each textfield a tag is added with this format: 12 (1 is the section, 2 is the row)
        return IndexPath(row: tag % scale, section: tag / scale)
    }

}

// MARK: - UITableViewDataSource
extension UartSettingsViewController: UITableViewDataSource {

    private enum SettingsSection: Int {
        case displayMode = 0
        case dataMode = 1
        case echo = 2
        case eol = 3
        case eolCharacters = 4
    }

    private enum ActionsSetion: Int {
        case clear = 0
        case export = 1
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numberOfRows: Int
        if section == 0 {
            numberOfRows = 5
        } else {
            numberOfRows = 2
        }
        
        if let openCellIndexPath = openCellIndexPath {
            if openCellIndexPath.section == section {
                numberOfRows += 1
            }
        }
        return numberOfRows
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let row = indexPath.row
        var reuseIdentifier: String!
        
        guard indexPath != openCellIndexPath else {
            let pickerCell = tableView.dequeueReusableCell(withIdentifier: "PickerCell", for: indexPath) as! UartSettingPickerCell
            pickerCell.pickerView.tag = indexPath.section * 100 + indexPath.row-1
            pickerCell.pickerView.dataSource = self
            pickerCell.pickerView.delegate = self
            
            let pickerSelectedRow: Int
            switch SettingsSection(rawValue: row-1)! {
            case .displayMode: pickerSelectedRow = Preferences.uartDisplayMode.rawValue
            case .eolCharacters: pickerSelectedRow = Preferences.uartEolCharactersId
            default: pickerSelectedRow = 0
            }
            
            pickerCell.pickerView.selectRow(pickerSelectedRow, inComponent: 0, animated: false)
            pickerCell.backgroundColor = .systemGroupedBackground //UIColor(hex: 0xe2e1e0)
            
            return pickerCell
        }
        
        if indexPath.section == 0 {
            switch SettingsSection(rawValue: row)! {
            case .displayMode:
                reuseIdentifier = "SelectorCell" //"UartSettingSegmentedCell"
            case .dataMode:
                reuseIdentifier = "UartSettingSegmentedCell"
            case .echo:
                reuseIdentifier = "UartSettingSwitchCell"
            case .eol:
                reuseIdentifier = "UartSettingSwitchCell"
            case .eolCharacters:
                reuseIdentifier = "SelectorCell"
            }
        } else {
            switch ActionsSetion(rawValue: row)! {
            case .clear:
                reuseIdentifier = "UartTextCell"
            case .export:
                reuseIdentifier = "UartTextCell"
            }
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for:indexPath)

        cell.backgroundColor = .systemGroupedBackground // UIColor(hex: 0xe2e1e0)
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {

        guard let uartCell = cell as? UartSettingTableViewCell else { return }

        let localizationManager = LocalizationManager.shared
        var titleKey: String?
        let row = indexPath.row

        if indexPath.section == 0 {
            switch SettingsSection(rawValue: row)! {
            case .displayMode:
                titleKey = "uart_settings_displayMode_title"
                /*
                uartCell.segmentedControl.removeAllSegments()
                uartCell.segmentedControl.insertSegment(withTitle: localizationManager.localizedString("uart_settings_displayMode_timestamp"), at: 0, animated: false)
                uartCell.segmentedControl.insertSegment(withTitle: localizationManager.localizedString("uart_settings_displayMode_text"), at: 1, animated: false)
                uartCell.segmentedControl.insertSegment(withTitle: localizationManager.localizedString("uart_settings_displayMode_terminal"), at: 2, animated: false)
                uartCell.segmentedControl.selectedSegmentIndex = Preferences.uartDisplayMode.rawValue
                uartCell.onSegmentedControlIndexChanged = { selectedIndex in
                    Preferences.uartDisplayMode = Preferences.UartDisplayMode(rawValue: selectedIndex) ?? .timeStamp
                }*/
                let typeButton = uartCell.typeButton!
                typeButton.tag = tagFromIndexPath(indexPath, scale:100)
                if Preferences.uartDisplayMode.rawValue < 0 || Preferences.uartDisplayMode.rawValue >= titlesIdForDisplayMode.count {
                    Preferences.uartDisplayMode = .timeStamp     // Reset to default
                    DLog("Warning: wrong uartDisplayMode found in Preferences")
                }
                typeButton.setTitle(localizationManager.localizedString(titlesIdForDisplayMode[Preferences.uartDisplayMode.rawValue]), for: .normal)
                typeButton.addTarget(self, action: #selector(onClickTypeButton(_:)), for: .touchUpInside)
                
            case .dataMode:
                titleKey = "uart_settings_dataMode_title"
                uartCell.segmentedControl.removeAllSegments()
                uartCell.segmentedControl.insertSegment(withTitle: localizationManager.localizedString("uart_settings_dataMode_ascii"), at: 0, animated: false)
                uartCell.segmentedControl.insertSegment(withTitle: localizationManager.localizedString("uart_settings_dataMode_hex"), at: 1, animated: false)
                uartCell.segmentedControl.selectedSegmentIndex = Preferences.uartIsInHexMode ? 1:0
                uartCell.onSegmentedControlIndexChanged = { selectedIndex in
                    Preferences.uartIsInHexMode = selectedIndex == 1
                }
            case .echo:
                titleKey = "uart_settings_echo_title"
                uartCell.switchControl.isOn = Preferences.uartIsEchoEnabled
                uartCell.onSwitchEnabled = { enabled in
                    Preferences.uartIsEchoEnabled = enabled
                }
            case .eol:
                titleKey = "uart_settings_eol_title"
                uartCell.switchControl.isOn = Preferences.uartIsAutomaticEolEnabled
                uartCell.onSwitchEnabled = { enabled in
                    Preferences.uartIsAutomaticEolEnabled = enabled
                }
            case .eolCharacters:
                titleKey = "uart_settings_eolCharacters_title"
                let typeButton = uartCell.typeButton!
                typeButton.tag = tagFromIndexPath(indexPath, scale:100)
                if Preferences.uartEolCharactersId < 0 || Preferences.uartEolCharactersId >= titlesForEolCharacters.count {
                    Preferences.uartEolCharactersId = 0     // Reset to default
                    DLog("Warning: wrong uartEolCharactersId found in Preferences")
                }
                typeButton.setTitle(titlesForEolCharacters[Preferences.uartEolCharactersId], for: .normal)
                typeButton.addTarget(self, action: #selector(onClickTypeButton(_:)), for: .touchUpInside)
            }
            
            uartCell.titleLabel.text = titleKey == nil ? nil : localizationManager.localizedString(titleKey!)+":"
        } else {
            var iconIdentifier: String?
            switch ActionsSetion(rawValue: row)! {
            case .clear:
                titleKey = "uart_settings_clear_title"
                iconIdentifier = "clear_icon"

            case .export:
                titleKey = "uart_settings_export_title"
                iconIdentifier = "action_icon"
            }

            uartCell.textLabel?.text = titleKey == nil ? nil : localizationManager.localizedString(titleKey!)
            uartCell.imageView?.image = iconIdentifier == nil ? nil : UIImage(named: iconIdentifier!)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath == openCellIndexPath ? 100 : 44
    }
    
    @objc func onClickTypeButton(_ sender: UIButton) {
        let selectedIndexPath = indexPathFromTag(sender.tag, scale:100)
        displayInlineDatePickerForRowAtIndexPath(selectedIndexPath)
    }
    
    private func displayInlineDatePickerForRowAtIndexPath(_ indexPath: IndexPath) {
        // display the date picker inline with the table content
        baseTableView.beginUpdates()
        
        var isReplacingOpenedPicker = false
        var isBefore = false   // indicates if the date picker is below "indexPath", help us determine which row to reveal
        var isSameCellClicked = false
        if let openCellIndexPath = openCellIndexPath {
            isBefore = openCellIndexPath.section <= indexPath.section || openCellIndexPath.row < indexPath.row
            
            isSameCellClicked = openCellIndexPath.section == indexPath.section && openCellIndexPath.row - 1 == indexPath.row
            
            isReplacingOpenedPicker = !isSameCellClicked
            
            // remove any date picker cell if it exists
            baseTableView.deleteRows(at: [openCellIndexPath], with: .fade)
            self.openCellIndexPath = nil
        }
        
        if !isSameCellClicked {
            // hide the old date picker and display the new one
            var rowToReveal = isBefore ? indexPath.row - 1 : indexPath.row
            if isReplacingOpenedPicker {
                rowToReveal = rowToReveal + 1
            }
            let indexPathToReveal = IndexPath(row: rowToReveal, section: indexPath.section)
            
            toggleDatePickerForSelectedIndexPath(indexPathToReveal)
            self.openCellIndexPath = IndexPath(row: indexPathToReveal.row + 1, section: indexPathToReveal.section)
        }
        
        // always deselect the row containing the start or end date
        baseTableView.deselectRow(at: indexPath, animated:true)
        
        baseTableView.endUpdates()
        
        // inform our date picker of the current date to match the current cell
        //updateOpenCell()
    }
    
    private func toggleDatePickerForSelectedIndexPath(_ indexPath: IndexPath) {
        
        baseTableView.beginUpdates()
        let indexPaths = [IndexPath(row: indexPath.row + 1, section: indexPath.section)]
        
        // check if 'indexPath' has an attached date picker below it
        if hasPickerForIndexPath(indexPath) {
            // found a picker below it, so remove it
            baseTableView.deleteRows(at: indexPaths, with: .fade)
        } else {
            // didn't find a picker below it, so we should insert it
            baseTableView.insertRows(at: indexPaths, with: .fade)
        }
        
        baseTableView.endUpdates()
    }
    
    private func hasPickerForIndexPath(_ indexPath: IndexPath) -> Bool {
        var hasPicker = false
        
        if baseTableView.cellForRow(at: IndexPath(row: indexPath.row+1, section: indexPath.section)) is UartSettingPickerCell {
            hasPicker = true
        }
        
        return hasPicker
    }
}

// MARK: - UITableViewDelegate
extension UartSettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if indexPath.section == 1 {
            switch ActionsSetion(rawValue: indexPath.row)! {
            case .clear:
                presentingViewController?.dismiss(animated: true, completion: { [unowned self] in
                    self.onClickClear?()
                })
            case .export:
                presentingViewController?.dismiss(animated: true, completion: { [unowned self] in
                    self.onClickExport?()
                })
            }
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: UIPickerViewDataSource
extension UartSettingsViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        
        let result: Int
        switch SettingsSection(rawValue: openCellIndexPath!.row-1)! {
        case .displayMode: result = titlesIdForDisplayMode.count
        case .eolCharacters: result = titlesForEolCharacters.count
        default: result = 0
        }
        
        return result
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let result: String?
        switch SettingsSection(rawValue: openCellIndexPath!.row-1)! {
        case .displayMode: result = LocalizationManager.shared.localizedString(titlesIdForDisplayMode[row])
        case .eolCharacters: result = titlesForEolCharacters[row]
        default: result = nil
        }
        
        return result
    }
}


// MARK: UIPickerViewDelegate
extension UartSettingsViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedIndexPath = indexPathFromTag(pickerView.tag, scale:100)
        
        
        switch SettingsSection(rawValue: openCellIndexPath!.row-1)! {
        case .displayMode:
            if row >= 0 && row < titlesIdForDisplayMode.count {
                Preferences.uartDisplayMode = Preferences.UartDisplayMode(rawValue: row) ?? .timeStamp
            }
        case .eolCharacters:
            if row >= 0 && row < titlesForEolCharacters.count {
                Preferences.uartEolCharactersId = row
            }
        default: break
        }
        
               
        // Refresh cell
        baseTableView.reloadRows(at: [selectedIndexPath], with: .none)
    }
}
