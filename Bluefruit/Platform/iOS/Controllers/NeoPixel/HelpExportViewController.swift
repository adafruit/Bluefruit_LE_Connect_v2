//
//  HelpExportViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 24/03/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class HelpExportViewController: HelpViewController {

    // UI
    @IBOutlet weak var exportButton: UIButton!

    // Data
    var fileTitle: String?
    var fileURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func onCickExport(_ sender: AnyObject) {
        if let fileTitle = fileTitle, let fileURL = fileURL {

            let activityViewController = UIActivityViewController(activityItems: [fileTitle, fileURL], applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = exportButton

            navigationController?.present(activityViewController, animated: true, completion: nil)
        } else {
            DLog("HelpExportViewController: wrong parameters")
        }
    }

}
