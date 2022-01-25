//
//  UartSelectPeripheralViewController.swift
//  Bluefruit
//
//  Created by Antonio on 08/02/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

protocol UartSelectPeripheralViewControllerDelegate: AnyObject {
    func onUartSendToChanged(uuid: UUID?, name: String)
}

class UartSelectPeripheralViewController: UIViewController {

    weak var delegate: UartSelectPeripheralViewControllerDelegate?
    var colorForPeripheral: [UUID: Color]?

    private var connectedPeripherals = [BlePeripheral]()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

// MARK: - UITableViewDataSource
extension UartSelectPeripheralViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        connectedPeripherals = BleManager.shared.connectedPeripherals()
        return connectedPeripherals.count + 1   // +1 All
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let reuseIdentifier = "PeripheralCell"
        var cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
        }

        return cell!
    }
}

// MARK: - UITableViewDelegate
extension UartSelectPeripheralViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {

        if indexPath.row == 0 {
            cell.textLabel?.text = LocalizationManager.shared.localizedString("uart_send_toall_long")
            cell.textLabel?.textColor = UIColor.black
        } else {
            let peripheral = connectedPeripherals[indexPath.row-1]

            let localizationManager = LocalizationManager.shared
            cell.textLabel?.text = peripheral.name ?? localizationManager.localizedString("scanner_unnamed")
            cell.textLabel?.textColor = colorForPeripheral?[peripheral.identifier] ?? UIColor.black
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let localizationManager = LocalizationManager.shared
        if indexPath.row == 0 {
            delegate?.onUartSendToChanged(uuid: nil, name: localizationManager.localizedString("uart_send_toall_action"))
        } else {
            let peripheral = connectedPeripherals[indexPath.row-1]
            let name = peripheral.name ?? localizationManager.localizedString("scanner_unnamed")
            delegate?.onUartSendToChanged(uuid: peripheral.identifier, name: name)
        }
        tableView.deselectRow(at: indexPath, animated: true)
        dismiss(animated: true, completion: nil)
    }
}
