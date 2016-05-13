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
    
    weak var delegate : DfuDialogViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Fade-in background
        backgroundView.alpha = 0
        UIView.animateWithDuration(0.5, animations: { [unowned self] () -> Void in
            self.backgroundView.alpha = 1
            })
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func setProgressText(text : String) {
        progressLabel.text = text
    }
    
    func setProgress(value : Double) {
        progressIndicator.progress = Float(value/100.0)
        progressPercentageLabel.text = String(format: "%1.0f%%", value);
    }
    
    @IBAction func onClickCancel(sender: AnyObject) {
        delegate?.onUpdateDialogCancel()
    }

}
