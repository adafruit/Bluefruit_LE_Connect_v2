//
//  MagnetometerProgressViewController.swift
//  Calibration
//
//  Created by Antonio on 09/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class MagnetometerProgressViewController: MagnetometerPageContentViewController {

    // UI
    @IBOutlet weak var calibrationProgressView: UIProgressView!
    @IBOutlet weak var calibrationProgressLabel: UILabel!
    @IBOutlet weak var calibrationTitleLabel: UILabel!
    @IBOutlet weak var calibrationDescriptionLabel: UILabel!
    @IBOutlet weak var valuesStackView: UIStackView!

    @IBOutlet weak var dataView: UIView!
    @IBOutlet weak var parametersView: UIView!

    private var isShowingHelp = true

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initial visibility
        calibrationDescriptionLabel.alpha = 1
        valuesStackView.alpha = 0

        dataView.isHidden = false
        parametersView.isHidden = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let magnetometerParametersViewController = segue.destination as? MagnetometerParametersViewController {
            magnetometerParametersViewController.parametersDelegate = self
        }
    }

    fileprivate func flipViews() {
        let isFrontVisible = !dataView.isHidden

        if let frontView = isFrontVisible ? dataView : parametersView, let backView = isFrontVisible ? parametersView : dataView {

            UIView.transition(from: frontView, to: backView, duration: 0.8, options: [.transitionFlipFromRight, .showHideTransitionViews]) { (isFinished) in
            }
        }
    }

    override func updateUI() {
        super.updateUI()

        guard let calibration = calibration else {
            return
        }

        let kGapFactor: Float = 1
        let kVarianceFactor: Float = 0.05
        let kWobbleFactor: Float = 0.05
        let kFitFactor: Float = 0.2

        let gapError = calibration.surfaceGapError()
        let gapProgress = min(100-Calibration.kGapTarget, 100-gapError)
        let varianceError = calibration.magnitudeVarianceError()
        let varianceProgress = min(100-Calibration.kVarianceTarget, 100-varianceError)
        let wobbleError = calibration.wobbleError()
        let wobbleProgress = min(100-Calibration.kWobbleTarget, 100-wobbleError)
        let fitError = calibration.sphericalFitError()
        let fitProgress = min(100-Calibration.kFitErrorTarget, 100-fitError)

        let progressTotal = kGapFactor*(100-Calibration.kGapTarget) + kVarianceFactor*(100-Calibration.kVarianceTarget) + kWobbleFactor*(100-Calibration.kWobbleTarget) + kFitFactor*(100-Calibration.kFitErrorTarget)

        let progress = (kGapFactor*gapProgress + kVarianceFactor*varianceProgress + kWobbleFactor*wobbleProgress + kFitFactor*fitProgress) / progressTotal        // between 0 and 1

        calibrationProgressView.progress = progress * 0.95      // visually show the max as 95% to avoid the user thinking that is finished when is not
        //calibrationProgressLabel.text = String(format: "%.1f%%", progress*100)

        calibrationTitleLabel.text = isCalibrating ? "Calibrating...":"Calibration completed"
        calibrationProgressView.isHidden = !isCalibrating
        //calibrationProgressLabel.isHidden = !isCalibrating

        let showHelp = progress < 0.10 || progress >= 1

        if showHelp != isShowingHelp {
            UIView.animate(withDuration: 0.3) { [unowned self] in
                self.calibrationDescriptionLabel.alpha = showHelp ? 1:0
                self.valuesStackView.alpha = showHelp ? 0:1
            }
            isShowingHelp = showHelp
        }

        if showHelp {
            calibrationDescriptionLabel.text = isCalibrating ? "Rotate the board along the 3 axis until enough samples are collected for the Magnetometer calibration" : "Magnetometer calibration completed sucessfully."
        } else {
            for (i, subview) in valuesStackView.arrangedSubviews.enumerated() {
                if let valueLabel = subview.viewWithTag(10) as? UILabel, let targetLabel = subview.viewWithTag(11) as? UILabel {
                    var text: String?
                    var targetValue: Scalar = 0
                    switch i {
                    case 0:
                        let value = calibration.surfaceGapError()
                        text = String.init(format: "%.1f%%", value)
                        targetValue = Preferences.magnetometerGapTarget
                    case 1:
                        let value = calibration.wobbleError()
                        text = String.init(format: "%.1f%%", value)
                        targetValue = Preferences.magnetometerWobbleTarget
                    case 2:
                        let value = calibration.magnitudeVarianceError()
                        text = String.init(format: "%.1f%%", value)
                        targetValue = Preferences.magnetometerVarianceTarget
                    case 3:
                        let value = calibration.sphericalFitError()
                        text = String.init(format: "%.1f%%", value)
                        targetValue = Preferences.magnetometerFitErrorTarget
                    default:
                        title = nil
                        text = nil
                    }

                    valueLabel.text = text
                    targetLabel.text = String(format: "(target < %.1f)", targetValue)
                }
            }
        }
    }

    @IBAction func onClickRestart(_ sender: Any) {
        delegate?.onMagnetometerRestart()
    }

    @IBAction func onClickSettings(_ sender: Any) {
        flipViews()
    }

}

extension MagnetometerProgressViewController: MagnetometerParametersViewControllerDelegate {
    func onParametersDone() {
        flipViews()
    }
}
