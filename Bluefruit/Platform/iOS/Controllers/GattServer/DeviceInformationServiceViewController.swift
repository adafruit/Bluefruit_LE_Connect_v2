//
//  DeviceInformationServiceViewController.swift
//  Bluefruit
//
//  Created by Antonio García on 05/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class DeviceInformationServiceViewController: UIViewController {

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    
    // Parameters
    var disPeripheralService: DeviceInformationPeripheralService?
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

// MARK: UITableViewDataSource
extension DeviceInformationServiceViewController: UITableViewDataSource {
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        
        let editValueCell = tableView.dequeueReusableCell(withIdentifier: "ValueCell", for: indexPath) as! MqttSettingsValueAndSelector
        editValueCell.reset()
        
        let labels = ["Manufacturer:", "Password:"]
        editValueCell.nameLabel.text = labels[row]
        
        let valueTextField = editValueCell.valueTextField!
        if row == 0 {
            valueTextField.text = disPeripheralService?.manufacturer
        } else if row == 1 {
            valueTextField.text = nil
        }
        
        if let valueTextField = editValueCell.valueTextField {
            valueTextField.returnKeyType = UIReturnKeyType.next
            valueTextField.delegate = self
            valueTextField.tag = row
        }
        
        editValueCell.backgroundColor = UIColor(hex: 0xe2e1e0)
        return editValueCell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Characteristics"
    }
    
}

// MARK: UITableViewDelegate
extension DeviceInformationServiceViewController: UITableViewDelegate {
    
    
    
}

// MARK: - UITextFieldDelegate
extension DeviceInformationServiceViewController: UITextFieldDelegate {
    
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        // Go to next textField
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
        
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let indexPath = IndexPath(row: textField.tag, section: 0)
        let row = indexPath.row
        
        if row == 0 {
            disPeripheralService?.manufacturer = textField.text
        }
        
    }
}
