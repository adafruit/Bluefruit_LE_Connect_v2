//
//  GyroscopeProgressViewController.swift
//  Calibration
//
//  Created by Antonio on 12/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class GyroscopeProgressViewController: GyroscopePageContentViewController {
    // UI
    @IBOutlet weak var calibrationProgressView: UIProgressView!
 //   @IBOutlet weak var calibrationProgressLabel: UILabel!
    @IBOutlet weak var calibrationTitleLabel: UILabel!
    @IBOutlet weak var calibrationDescriptionLabel: UILabel!

    @IBOutlet weak var dataView: UIView!
    @IBOutlet weak var parametersView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initial visibility
        dataView.isHidden = false
        parametersView.isHidden = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let gyroscopeParametersViewController = segue.destination as? GyroscopeParametersViewController {
            gyroscopeParametersViewController.parametersDelegate = self
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

        calibrationProgressView.progress = progress
//        calibrationProgressLabel.text = String(format: "%.0f%%", progress*100)

        calibrationTitleLabel.text = isCalibrating ? "Calibrating...":"Calibration completed"
        calibrationProgressView.isHidden = !isCalibrating
  //      calibrationProgressLabel.isHidden = !isCalibrating
        calibrationDescriptionLabel.text = isCalibrating ? "Pose the board on a surface and wait until the resting orientation is detected" : "Gyroscope calibration completed sucessfully."
    }

    @IBAction func onClickRestart(_ sender: Any) {
        delegate?.onGyroscopeRestart()
    }

    @IBAction func onClickSettings(_ sender: Any) {
          flipViews()
    }
}

extension GyroscopeProgressViewController: GyroscopeParametersViewControllerDelegate {
    func onParametersDone() {
        flipViews()
    }
}
