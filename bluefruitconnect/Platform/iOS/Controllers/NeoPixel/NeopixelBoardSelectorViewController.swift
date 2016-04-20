//
//  NeopixelBoardSelectorViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 26/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class NeopixelBoardSelectorViewController: UIViewController {

    // Data
    private var boards: [[String: AnyObject]]?
    
    var onClickStandardBoard:((Int)->())?
    var onClickCustomLineStrip : (()->())?
    
    // UI
    @IBOutlet weak var baseTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Read boards from resources
        let path = NSBundle.mainBundle().pathForResource("NeopixelBoards", ofType: "plist")!
        boards = NSArray(contentsOfFile: path) as? [Dictionary]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        preferredContentSize = CGSizeMake(preferredContentSize.width, baseTableView.contentSize.height)
    }
}

// MARK: - UITableViewDataSource
extension NeopixelBoardSelectorViewController : UITableViewDataSource {
    /*
    private enum SettingsSection : Int {
        case StandardBoards = 0
        case CustomBoards = 1
    }
    */
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var title: String?
        switch section {
        case 0:
            title = "STARDARD BOARD SIZES"
        case 1:
            title = "CUSTOM BOARD SIZE"
        default:
            break
        }
        return title
    }
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return boards != nil ? boards!.count: 0
        }
        else {
            return 1
        }
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let reuseIdentifier = "TextCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath:indexPath)
        
        cell.backgroundColor = UIColor(hex: 0xe2e1e0)
        return cell
    }
    
    
    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        
        let uartCell = cell as! UartSettingTableViewCell
        
        let row = indexPath.row

        if indexPath.section == 0 {
            let board = boards![row]
            uartCell.textLabel?.text = board["name"] as? String
        }
        else {
            uartCell.textLabel?.text = "Line Strip"
        }
    }
}

// MARK: - UITableViewDelegate
extension NeopixelBoardSelectorViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
      
        tableView.deselectRowAtIndexPath(indexPath, animated: indexPath.section == 0)
        
        dismissViewControllerAnimated(true) {[unowned self] () -> Void in
            if indexPath.section == 0 {
                self.onClickStandardBoard?(indexPath.row)
            }
            else {
                self.onClickCustomLineStrip?()
            }
        }
    }
}
