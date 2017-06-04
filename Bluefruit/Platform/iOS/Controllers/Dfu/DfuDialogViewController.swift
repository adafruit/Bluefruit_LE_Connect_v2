//
//  DfuDialogViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 09/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

protocol DfuDialogViewControllerDelegate: class {
    func onUpdateDialogCancel()
}

class DfuDialogViewController: UIViewController {

    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progressIndicator: UIProgressView!
    @IBOutlet weak var progressPercentageLabel: UILabel!
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var cancelButton: UIButton!

    weak var delegate: DfuDialogViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        cancelButton.isHidden = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Fade-in background
        backgroundView.alpha = 0
        UIView.animate(withDuration: 0.5, animations: { [unowned self] () -> Void in
            self.backgroundView.alpha = 1
            })

        // Disable sleep mode while the DFU Dialog progress is shown
        UIApplication.shared.isIdleTimerDisabled = true
        DLog("Disable sleep mode")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Enable sleep again mode when the DFU Dialog progress dissapears
        UIApplication.shared.isIdleTimerDisabled = false
        DLog("Restore sleep mode")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func setProgressText(_ text: String) {
        progressLabel.text = text
    }

    func setProgress(_ value: Double) {
        cancelButton.isHidden = value <= 0
        progressIndicator.progress = Float(value/100.0)
        progressPercentageLabel.text = String(format: "%1.0f%%", value)
    }

    @IBAction func onClickCancel(_ sender: AnyObject) {
        delegate?.onUpdateDialogCancel()
    }

}
