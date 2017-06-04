//
//  ScanningInterfaceController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 01/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import WatchKit
import Foundation

class ScanningInterfaceController: WKInterfaceController {

    @IBOutlet var foundPeripheralsLabel: WKInterfaceLabel!

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        // Configure interface objects here.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()

        // Update values
        if let appContext = WatchSessionManager.sharedInstance.session?.receivedApplicationContext {
            didReceiveApplicationContext(appContext)
        }
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    // MARK: - Session
    func didReceiveApplicationContext(_ applicationContext: [String : Any]) {
        DLog("ScanningInterfaceController didReceiveApplicationContext: \(applicationContext)")

        var peripheralsCount = 0
        if let peripheralsFound = (applicationContext["bleFoundPeripherals"] as AnyObject).integerValue {
            peripheralsCount = peripheralsFound
        }

        foundPeripheralsLabel.setText( String(peripheralsCount) )
    }
}
