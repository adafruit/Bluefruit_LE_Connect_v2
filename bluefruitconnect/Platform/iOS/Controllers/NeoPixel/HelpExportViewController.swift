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
    var fileURL: NSURL?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    
    @IBAction func onCickExport(sender: AnyObject) {
        if let fileTitle = fileTitle, fileURL = fileURL {
            
            let activityViewController = UIActivityViewController(activityItems: [fileTitle, fileURL], applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = exportButton
            
            navigationController?.presentViewController(activityViewController, animated: true, completion: nil)
        }
        else {
            DLog("HelpExportViewController: wrong parameters")
        }
    }
    
}
