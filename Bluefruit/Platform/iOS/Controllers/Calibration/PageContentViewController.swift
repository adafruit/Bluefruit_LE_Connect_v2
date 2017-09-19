//
//  PageContentViewController.swift
//  Calibration
//
//  Created by Antonio on 12/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class PageContentViewController: UIViewController {

    @IBOutlet weak var contentView: UIView?
    var isCalibrating = false {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.updateUI()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        contentView?.layer.cornerRadius = 8
        contentView?.layer.masksToBounds = true
        contentView?.layer.borderColor = UIColor(red: 8/255, green: 155/255, blue: 40/255, alpha: 1).cgColor
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func updateUI() {
        contentView?.layer.borderWidth = isCalibrating ? 0:4

        // Override if needed on subclasses
    }
}
