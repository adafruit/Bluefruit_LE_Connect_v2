//
//  MagnetometerParametersViewController.swift
//  Calibration
//
//  Created by Antonio on 14/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

protocol MagnetometerParametersViewControllerDelegate: class {
    func onParametersDone()
}

class MagnetometerParametersViewController: MagnetometerPageContentViewController {
    // Config
    private static let kSliderMaxDifferenceFromDefaultValue: Float = 0.1       // 1 = 100% difference

    // UI
    @IBOutlet weak var parametersStackView: UIStackView!

    // Data
    weak var parametersDelegate: MagnetometerParametersViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        for (i, view) in parametersStackView.arrangedSubviews.enumerated() {
            if let valueSlider = view.subviews[1] as? UISlider {

                var value: Float
                switch i {
                case 0: value = Calibration.kGapTarget
                case 1: value = Calibration.kWobbleTarget
                case 2: value = Calibration.kVarianceTarget
                default: value = Calibration.kFitErrorTarget
                }

                valueSlider.minimumValue = value - value*MagnetometerParametersViewController.kSliderMaxDifferenceFromDefaultValue
                valueSlider.maximumValue = value + value*MagnetometerParametersViewController.kSliderMaxDifferenceFromDefaultValue
                updateParametersUI()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func onClickDone(_ sender: Any) {
        parametersDelegate?.onParametersDone()
    }

    @IBAction func onClickSetDefaults(_ sender: Any) {
        Preferences.magnetometerGapTarget = Calibration.kGapTarget
        Preferences.magnetometerVarianceTarget = Calibration.kVarianceTarget
        Preferences.magnetometerWobbleTarget = Calibration.kWobbleTarget
        Preferences.magnetometerFitErrorTarget = Calibration.kFitErrorTarget
        updateParametersUI()
    }

    private func updateParametersUI(shouldUpdateSliders: Bool = true) {
        for (i, view) in parametersStackView.arrangedSubviews.enumerated() {
            if let valueSlider = view.subviews[1] as? UISlider, let valueLabel = view.subviews.last as? UILabel {

                var value: Float
                switch i {
                case 0: value = Preferences.magnetometerGapTarget
                case 1: value = Preferences.magnetometerWobbleTarget
                case 2: value = Preferences.magnetometerVarianceTarget
                default: value = Preferences.magnetometerFitErrorTarget
                }

                valueSlider.value = value
                valueLabel.text = String(format: " <%.1f%%", value)
            }
        }
    }

    @IBAction func onSliderChanged(_ sender: UISlider) {
        let tag = sender.tag
        let value = sender.value

        switch tag {
        case 0: Preferences.magnetometerGapTarget = value
        case 1: Preferences.magnetometerWobbleTarget = value
        case 2: Preferences.magnetometerVarianceTarget = value
        default: Preferences.magnetometerFitErrorTarget = value
        }

        updateParametersUI(shouldUpdateSliders: false)
        delegate?.onMagnetometerParametersChanged()
    }
}
