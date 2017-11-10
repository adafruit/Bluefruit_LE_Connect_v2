//
//  MainMenuViewController.swift
//  Calibration
//
//  Created by Antonio on 11/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class CalibrationMenuViewController: PeripheralModeViewController {

    @IBOutlet weak var menuStackView: UIStackView!
    @IBOutlet weak var magnetometerButton: StyledLinkedButton!
    @IBOutlet weak var gyroscopeButton: StyledLinkedButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral?.name ?? LocalizationManager.sharedInstance.localizedString("scanner_unnamed")
        self.title = traitCollection.horizontalSizeClass == .regular ? String(format: localizationManager.localizedString("calibration_navigation_title_format"), arguments: [name]) : localizationManager.localizedString("calibration_tab_title")
        
        // UI
        for view in menuStackView.arrangedSubviews {
            view.layer.cornerRadius = 8
            view.layer.masksToBounds = true
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? CalibrationUartViewController {
            viewController.blePeripheral = blePeripheral
        }
    }

}
