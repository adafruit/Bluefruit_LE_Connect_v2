//
//  NeopixelBoardSelectorViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 26/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class NeopixelBoardSelectorViewController: UIViewController {

    // Data
    fileprivate var boards: [[String: AnyObject]]?

    var onClickStandardBoard: ((Int) -> Void)?
    var onClickCustomLineStrip : (() -> Void)?

    // UI
    @IBOutlet weak var baseTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Read boards from resources
        let path = Bundle.main.path(forResource: "NeopixelBoards", ofType: "plist")!
        boards = NSArray(contentsOfFile: path) as? [Dictionary]
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
extension NeopixelBoardSelectorViewController: UITableViewDataSource {
    /*
    private enum SettingsSection : Int {
        case StandardBoards = 0
        case CustomBoards = 1
    }
    */

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var title: String?
        switch section {
        case 0:
            title = "STANDARD BOARD SIZES"
        case 1:
            title = "CUSTOM BOARD SIZE"
        default:
            break
        }
        return title
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return boards != nil ? boards!.count: 0
        } else {
            return 1
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "TextCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)

        cell.backgroundColor = UIColor(hex: 0xe2e1e0)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension NeopixelBoardSelectorViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let uartCell = cell as? UartSettingTableViewCell else { return }

        let row = indexPath.row

        if indexPath.section == 0 {
            let board = boards![row]
            uartCell.titleLabel?.text = board["name"] as? String
        } else {
            uartCell.titleLabel?.text = "Line Strip"
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: indexPath.section == 0)

        dismiss(animated: true) {[unowned self] in
            if indexPath.section == 0 {
                self.onClickStandardBoard?(indexPath.row)
            } else {
                self.onClickCustomLineStrip?()
            }
        }
    }
}
