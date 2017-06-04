//
//  VisualizationParametersViewController.swift
//  Calibration
//
//  Created by Antonio on 18/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

protocol VisualizationParametersViewControllerDelegate: class {
    func onVisualizationParametersChanged()
    func onParametersDone()
}

class VisualizationParametersViewController: PageContentViewController {

    @IBOutlet weak var parametersStackView: UIStackView!

    weak var parametersDelegate: VisualizationParametersViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        for (i, view) in parametersStackView.arrangedSubviews.enumerated() {
            if let valueSwitch = view.subviews.last as? UISwitch {
                var isOn: Bool
                switch i {
                case 0: isOn = Preferences.visualizationXAxisInverted
                case 1: isOn = Preferences.visualizationYAxisInverted
                case 2: isOn = Preferences.visualizationZAxisInverted
                default: isOn = Preferences.visualizationSwitchYZ
                }

                valueSwitch.isOn = isOn
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func onInvertAxisChanged(_ sender: UISwitch) {

        switch sender.tag {
        case 0: Preferences.visualizationXAxisInverted = sender.isOn
        case 1: Preferences.visualizationYAxisInverted = sender.isOn
        case 2: Preferences.visualizationZAxisInverted = sender.isOn
        default: Preferences.visualizationSwitchYZ = sender.isOn
        }

        parametersDelegate?.onVisualizationParametersChanged()
    }

    @IBAction func onFlipAxisChanged(_ sender: UISwitch) {
        switch sender.tag {
        case 0: Preferences.visualizationXAxisFlipped = sender.isOn
        case 1: Preferences.visualizationYAxisFlipped = sender.isOn
        default: Preferences.visualizationZAxisFlipped = sender.isOn
        }

        parametersDelegate?.onVisualizationParametersChanged()
    }

    @IBAction func onClickDone(_ sender: Any) {
        parametersDelegate?.onParametersDone()
    }
}
