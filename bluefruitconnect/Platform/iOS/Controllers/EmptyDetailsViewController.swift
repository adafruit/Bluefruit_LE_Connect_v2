//
//  EmptyDetailsViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class EmptyDetailsViewController: ModuleViewController {

    @IBOutlet weak var emptyLabel: UILabel!
    
    private var isConnnecting = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        setConnecting(isConnnecting)
    }
    
    func setConnecting(isConnecting : Bool) {
        self.isConnnecting = isConnecting
        
        let localizationManager = LocalizationManager.sharedInstance
        emptyLabel?.text = localizationManager.localizedString(isConnecting ? "peripheraldetails_connecting" : "peripheraldetails_select")
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
