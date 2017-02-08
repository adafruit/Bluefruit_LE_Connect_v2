//
//  UartSelectPeripheralViewController.swift
//  Bluefruit
//
//  Created by Antonio on 08/02/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

protocol UartSelectPeripheralViewControllerDelegate: class {
    func onUartSendToChanged(uuid: UUID?, name: String)
}

class UartSelectPeripheralViewController: UIViewController {

    weak var delegate: UartSelectPeripheralViewControllerDelegate?
    var colorForPeripheral: [UUID: Color]?
    
    fileprivate var connectedPeripherals = [BlePeripheral]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */


}

// MARK: - UITableViewDataSource
extension UartSelectPeripheralViewController: UITableViewDataSource {
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        connectedPeripherals = BleManager.sharedInstance.connectedPeripherals()
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
    
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if indexPath.row == 0 {
            cell.textLabel?.text = "All Connected Peripherals"
            cell.textLabel?.textColor = UIColor.black
        }
        else {
            let peripheral = connectedPeripherals[indexPath.row-1]
            
            let localizationManager = LocalizationManager.sharedInstance
            cell.textLabel?.text = peripheral.name ?? localizationManager.localizedString("peripherallist_unnamed")
            cell.textLabel?.textColor = colorForPeripheral?[peripheral.identifier] ?? UIColor.black
        }
    }
}

// MARK: - UITableViewDelegate
extension UartSelectPeripheralViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.row == 0 {
            delegate?.onUartSendToChanged(uuid: nil, name: "To All")
        }
        else {
            let localizationManager = LocalizationManager.sharedInstance
            let peripheral = connectedPeripherals[indexPath.row-1]
            let name = peripheral.name ?? localizationManager.localizedString("peripherallist_unnamed")
            delegate?.onUartSendToChanged(uuid: peripheral.identifier, name: name)
        }
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)
        dismiss(animated: true, completion: nil)
    }
}
