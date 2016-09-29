//
//  FilterTextSettingsViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 29/09/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class FilterTextSettingsViewController: UIViewController {

    @IBOutlet weak var baseTableView: UITableView!
    
    weak var peripheralList: PeripheralList!
    var onSettingsChanged: (()->())?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
extension FilterTextSettingsViewController: UITableViewDataSource {
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    /*
     func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var sectionTitleKey: String
        switch section {
        case 0:
            sectionTitleKey = "peripherallist_filter_name_matchsection"
        default:
            sectionTitleKey = "peripherallist_filter_name_casesection"
        }
        
        return LocalizationManager.sharedInstance.localizedString(sectionTitleKey)
     }*/
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let reuseIdentifier = "MatchCell"
        var cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .Default, reuseIdentifier: reuseIdentifier)
        }
        
        let row = indexPath.row
        var title: String
        var accesoryType: UITableViewCellAccessoryType
        
        switch indexPath.section {
        case 0:
            title = row == 0 ? "Name contains" : "Name equals"
            accesoryType = (row == 0 && !peripheralList.isFilterNameExact) || (row == 1 && peripheralList.isFilterNameExact) ? .Checkmark : .None
        default:
            title = row == 0 ? "Matching case" : "Ignoring case"
            accesoryType = (row == 0 && !peripheralList.isFilterNameCaseInsensitive) || (row == 1 && peripheralList.isFilterNameCaseInsensitive) ? .Checkmark : .None
        }
        
        cell!.textLabel?.text = title
        cell!.accessoryType = accesoryType
        
        return cell!
    }
}

// MARK: - UITableViewDelegate
extension FilterTextSettingsViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        let row = indexPath.row
        switch indexPath.section {
        case 0:
            peripheralList.isFilterNameExact = row == 1
        default:
            peripheralList.isFilterNameCaseInsensitive = row == 1
        }
        
        tableView.reloadData()
        onSettingsChanged?()
    }
}
