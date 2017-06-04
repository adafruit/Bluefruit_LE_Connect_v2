//
//  GyroscopeParametersViewController.swift
//  Calibration
//
//  Created by Antonio on 18/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

protocol GyroscopeParametersViewControllerDelegate: class {
    func onParametersDone()
}

class GyroscopeParametersViewController: GyroscopePageContentViewController {

    @IBOutlet weak var parametersStackView: UIStackView!
    weak var parametersDelegate: GyroscopeParametersViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        updateParametersUI()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func onClickDone(_ sender: Any) {
        parametersDelegate?.onParametersDone()
    }

    @IBAction func onClickSetDefaults(_ sender: Any) {
        Preferences.gyroReadingsCount = GyroscopeViewController.kNumReadingsToCheckForStable
        Preferences.gyroNoiseLevel = GyroscopeViewController.kReadingsMaxDifferenceToBeStable
        updateParametersUI()
    }

    private func updateParametersUI(shouldUpdateSliders: Bool = true) {
        for (i, view) in parametersStackView.arrangedSubviews.enumerated() {
            if let valueSlider = view.subviews[1] as? UISlider, let valueLabel = view.subviews.last as? UILabel {

                var value: Float
                switch i {
                case 0: value = Float(Preferences.gyroReadingsCount)
                default: value = Preferences.gyroNoiseLevel
                }

                valueSlider.value = Float(value)
                valueLabel.text = String(format: "%.0f", value)
            }
        }
    }

    @IBAction func onGyroReadingsCountChanged(_ sender: UISlider) {
        let value = Int(sender.value)

        Preferences.gyroReadingsCount = value
        updateParametersUI(shouldUpdateSliders: false)
        delegate?.onGyroscopeParametersChanged()
    }

    @IBAction func onNoiseLevelChanged(_ sender: UISlider) {
        let value = Int(sender.value)

        Preferences.gyroNoiseLevel = Float(value)
        updateParametersUI(shouldUpdateSliders: false)
        delegate?.onGyroscopeParametersChanged()
    }
}
