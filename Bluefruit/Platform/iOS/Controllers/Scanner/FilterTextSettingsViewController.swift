//
//  FilterTextSettingsViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 29/09/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class FilterTextSettingsViewController: UIViewController {

    // UI
    @IBOutlet weak var baseTableView: UITableView!

    // Params
    weak var peripheralList: PeripheralList?
    var onSettingsChanged: (() -> Void)?

    // MARK: - View Lifecyclwe
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
extension FilterTextSettingsViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "MatchCell"
        var cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
        }

        let row = indexPath.row
        var title: String
        var accesoryType: UITableViewCellAccessoryType

        let localizationManager = LocalizationManager.sharedInstance
        if let peripheralList = peripheralList {
            switch indexPath.section {
            case 0:
                title = localizationManager.localizedString(row == 0 ? "scanner_filter_name_settings_contains" : "scanner_filter_name_settings_exact")
                accesoryType = (row == 0 && !peripheralList.isFilterNameExact) || (row == 1 && peripheralList.isFilterNameExact) ? .checkmark : .none
            default:
                title = localizationManager.localizedString(row == 0 ? "scanner_filter_name_settings_sensitive" : "scanner_filter_name_settings_insensitive")
                accesoryType = (row == 0 && !peripheralList.isFilterNameCaseInsensitive) || (row == 1 && peripheralList.isFilterNameCaseInsensitive) ? .checkmark : .none
            }

            cell!.textLabel?.text = title
            cell!.accessoryType = accesoryType
        }

        return cell!
    }
}

// MARK: UITableViewDelegate
extension FilterTextSettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let peripheralList = peripheralList else { return }

        let row = indexPath.row
        switch indexPath.section {
        case 0:
            peripheralList.isFilterNameExact = row == 1
        default:
            peripheralList.isFilterNameCaseInsensitive = row == 1
        }

        tableView.reloadData()
        onSettingsChanged?()
    }
}
