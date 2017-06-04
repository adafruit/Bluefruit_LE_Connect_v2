//
//  VisualizationProgressViewController.swift
//  Calibration
//
//  Created by Antonio on 24/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

protocol VisualizationProgressViewControllerDelegate: class {
    func onVisualizationParametersChanged()
    func onVisualizationOriginReset()
    func onVisualizationOriginSet()
}

class VisualizationProgressViewController: PageContentViewController {

    // UI
    @IBOutlet weak var dataView: UIView!
    @IBOutlet weak var parametersView: UIView!
    @IBOutlet weak var quaternionValuesStackView: UIStackView!
    @IBOutlet weak var eulerValuesStackView: UIStackView!
    @IBOutlet weak var eulerOffsetStackView: UIStackView!

    // Data
    weak var delegate: VisualizationProgressViewControllerDelegate?
    var originOffset = Quaternion.identity
    var orientation = Quaternion.identity

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
        if let visualizationParametersViewController = segue.destination as? VisualizationParametersViewController {
            visualizationParametersViewController.parametersDelegate = self
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

        // Update quaternion values
        for (i, subview) in quaternionValuesStackView.arrangedSubviews.enumerated() {
            if let label = subview as? UILabel {
                var value: Float
                switch i {
                case 0: value = orientation.w
                case 1: value = orientation.x
                case 2: value = orientation.y
                default: value = orientation.z
                }
                label.text = String(format: "%0.4f", value)
            }
        }

        // Update Euler values
        for (i, subview) in eulerValuesStackView.arrangedSubviews.enumerated() {
            if let label = subview as? UILabel {
                var value: Float
                switch i {
                case 0: value = orientation.pitch.radiansToDegrees
                case 1: value = orientation.yaw.radiansToDegrees
                default: value = orientation.roll.radiansToDegrees
                }
                label.text = String(format: "%0.2f", value)
            }
        }

        // Update origin offset values
        for (i, subview) in eulerOffsetStackView.arrangedSubviews.enumerated() {
            if let label = subview as? UILabel {
                var value: Float
                switch i {
                case 0: value = originOffset.pitch.radiansToDegrees
                case 1: value = originOffset.yaw.radiansToDegrees
                default: value = originOffset.roll.radiansToDegrees
                }

                if value == -0 {        // Avoid showing -0. Show 0 instead
                    value = 0
                }
                label.text = String(format: "%0.2f", value)
            }
        }

    }

    @IBAction func onClickSettings(_ sender: Any) {
        flipViews()
    }

    @IBAction func onClickSetOrigin(_ sender: Any) {
        delegate?.onVisualizationOriginSet()
    }

    @IBAction func onClickResetOrigin(_ sender: Any) {
        delegate?.onVisualizationOriginReset()
    }
}

extension VisualizationProgressViewController: VisualizationParametersViewControllerDelegate {
    func onVisualizationParametersChanged() {
        delegate?.onVisualizationParametersChanged()
    }

    func onParametersDone() {
        flipViews()
    }
}
