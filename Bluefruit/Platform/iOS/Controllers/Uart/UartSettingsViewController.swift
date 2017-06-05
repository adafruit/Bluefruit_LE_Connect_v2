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
    var onClickClear: (() -> Void)?
    var onClickExport: (() -> Void)?

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
}

// MARK: - UITableViewDataSource
extension UartSettingsViewController: UITableViewDataSource {

    fileprivate enum SettingsSection: Int {
        case displayMode = 0
        case dataMode = 1
        case echo = 2
        case eol = 3
    }

    fileprivate enum ActionsSetion: Int {
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
        if section == 0 {
            return 4
        } else {
            return 2
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let row = indexPath.row
        var reuseIdentifier: String!

        if indexPath.section == 0 {
            switch SettingsSection(rawValue: row)! {
            case .displayMode:
                reuseIdentifier = "UartSettingSegmentedCell"
            case .dataMode:
                reuseIdentifier = "UartSettingSegmentedCell"
            case .echo:
                reuseIdentifier = "UartSettingSwitchCell"
            case .eol:
                reuseIdentifier = "UartSettingSwitchCell"
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

        cell.backgroundColor = UIColor(hex: 0xe2e1e0)
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {

        guard let uartCell = cell as? UartSettingTableViewCell else { return }

        let localizationManager = LocalizationManager.sharedInstance
        var titleKey: String?
        let row = indexPath.row

        if indexPath.section == 0 {
            switch SettingsSection(rawValue: row)! {
            case .displayMode:
                titleKey = "uart_settings_displayMode_title"
                uartCell.segmentedControl.setTitle(localizationManager.localizedString("uart_settings_displayMode_timestamp"), forSegmentAt: 0)
                uartCell.segmentedControl.setTitle(localizationManager.localizedString("uart_settings_displayMode_text"), forSegmentAt: 1)
                uartCell.segmentedControl.selectedSegmentIndex = Preferences.uartIsDisplayModeTimestamp ? 0:1
                uartCell.onSegmentedControlIndexChanged = { selectedIndex in
                    Preferences.uartIsDisplayModeTimestamp = selectedIndex == 0
                }
            case .dataMode:
                titleKey = "uart_settings_dataMode_title"
                uartCell.segmentedControl.setTitle(localizationManager.localizedString("uart_settings_dataMode_ascii"), forSegmentAt: 0)
                uartCell.segmentedControl.setTitle(localizationManager.localizedString("uart_settings_dataMode_hex"), forSegmentAt: 1)
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
