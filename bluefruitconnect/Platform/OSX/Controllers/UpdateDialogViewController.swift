//
//  UpdateDialogViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 26/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

protocol UpdateDialogControllerDelegate: class {
    func onUpdateDialogCancel()
}

class UpdateDialogViewController: NSViewController {

    @IBOutlet private weak var progressLabel: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var progressPercentageLabel: NSTextField!
    
    weak var delegate : UpdateDialogControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Setup StatusManager
        StatusManager.sharedInstance.updateDialogViewController = self
    }
    
    func setProgressText(text : String) {
        progressLabel.stringValue = text
    }
    
    func setProgress(value : Double) {
        progressIndicator.indeterminate = false
        progressIndicator.doubleValue = value
        progressPercentageLabel.stringValue = String(format: "%1.0f%%", value);
    }
    
    @IBAction func onClickCancel(sender: AnyObject) {
        delegate?.onUpdateDialogCancel()
    }
}