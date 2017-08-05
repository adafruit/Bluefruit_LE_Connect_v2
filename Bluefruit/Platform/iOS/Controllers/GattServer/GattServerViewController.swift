//
//  GattServerViewController.swift
//  Bluefruit
//
//  Created by Antonio García on 03/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class GattServerViewController: ModeTabViewController {

    // Data
    fileprivate let gattServer = GattServer()
    fileprivate var peripheralServices = [PeripheralService]()

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Define services
        let deviceInformationPeripheralService = DeviceInformationPeripheralService()
        peripheralServices = [deviceInformationPeripheralService]
        
        // Add services
        for peripheralService in peripheralServices {
            if peripheralService.isEnabled {
                gattServer.addService(peripheralService)
            }
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        gattServer.startAdvertising()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        gattServer.stopAdvertising()
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // MARK: - Navigation
    override func loadDetailRootController() {
        detailRootController = self.storyboard?.instantiateViewController(withIdentifier: "PeripheralServiceViewController")
    }
    
    // MARK: - Detail View Controllers
    fileprivate func showDisDetail(with peripheralService: DeviceInformationPeripheralService) {
        detailRootController = self.storyboard?.instantiateViewController(withIdentifier: "DeviceInformationServiceNavigationController")
        if let detailRootController = detailRootController as? UINavigationController, let deviceInfomationServiceViewController = detailRootController.topViewController as? DeviceInformationServiceViewController {
            deviceInfomationServiceViewController.disPeripheralService = peripheralService
            showDetailViewController(detailRootController, sender: self)
        }
    }

}

// MARK: - UITableViewDataSource
extension GattServerViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : peripheralServices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let section = indexPath.section
        
        var reuseIdentifier: String
        if section == 0 {
            reuseIdentifier = "AdvertisingInfoCell"
        }
        else {
            reuseIdentifier = "ServiceCell"
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Advertising Info" : "Services"
    }
}

// MARK: - UITableViewDelegate
extension GattServerViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if indexPath.section == 0 {
            guard let editValueCell = cell as? MqttSettingsValueAndSelector else { return }
            editValueCell.reset()
            let valueTextField = editValueCell.valueTextField!
            valueTextField.text = gattServer.advertisementLocalName
            
            if let valueTextField = editValueCell.valueTextField {
                valueTextField.delegate = self
                valueTextField.tag = indexPath.row
            }
            
        }
        else {
            guard let serviceCell = cell as? ServiceTableViewCell, indexPath.row < peripheralServices.count else { return }
            let peripheralService = peripheralServices[indexPath.row]
            
            serviceCell.titleLabel.text = peripheralService.name
            // serviceCell.subtitleLabel.text = subtitle
            serviceCell.enabledSwitch.isOn = peripheralService.isEnabled
            serviceCell.isEnabledChanged = { [weak self] isEnabled in
                guard let context = self else { return }
                
                peripheralService.isEnabled = isEnabled
                
                // Update advertising
                context.gattServer.stopAdvertising()
                if (isEnabled) {
                    context.gattServer.addService(peripheralService)
                }
                else {
                    context.gattServer.removeService(peripheralService)
                }
                
                context.gattServer.startAdvertising()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row >= 0 && indexPath.row < peripheralServices.count {
            let peripheralService = peripheralServices[indexPath.row]
            
            if let deviceInformationPeripheralService = peripheralService as? DeviceInformationPeripheralService {
                showDisDetail(with: deviceInformationPeripheralService)
            }
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension GattServerViewController: UITextFieldDelegate {
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        // Go to next textField
        /*
        if textField.returnKeyType == UIReturnKeyType.next {
            let tag = textField.tag
            let nextPathForTag = IndexPath(row: tag+1, section: 0)
            let nextView = baseTableView.cellForRow(at: nextPathForTag)?.viewWithTag(tag+1)
            
            if let next = nextView as? UITextField {
                next.becomeFirstResponder()
                
                // Scroll to show it
                baseTableView.scrollToRow(at: nextPathForTag, at: .middle, animated: true)
                
            } else {
                textField.resignFirstResponder()
            }
        }
        else {*/
            textField.resignFirstResponder()
        //}
        
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let indexPath = IndexPath(row: textField.tag, section: 0)
        let row = indexPath.row
        
        let text = textField.text
        if row == 0 {
            gattServer.advertisementLocalName = text
        }
        
    }
}
