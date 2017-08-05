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
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripheralServices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "ServiceCell"
        let serviceCell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! ServiceTableViewCell
        
        

        return serviceCell
    }
}

// MARK: - UITableViewDelegate
extension GattServerViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
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
