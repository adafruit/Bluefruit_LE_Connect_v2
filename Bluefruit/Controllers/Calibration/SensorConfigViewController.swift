//
//  SensorConfigViewController.swift
//  Calibration
//
//  Created by Antonio on 18/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class SensorConfigViewController: UIViewController {

    @IBOutlet weak var baseTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Remove extra separators
        baseTableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 0))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        preferredContentSize = baseTableView.contentSize
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func onClickDone(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - UITableViewDataSource

extension SensorConfigViewController: UITableViewDataSource {
    enum TableSections: Int {
        case magnetometer = 0
        case accelerometer = 1
        case gyroscope = 2

        var name: String {
            switch self {
            case .magnetometer: return "Magnetometer"
            case .accelerometer: return "Accelerometer"
            case .gyroscope: return "Gyroscope"
            }
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return TableSections.gyroscope.rawValue+1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {

        guard let tableSection = TableSections(rawValue: section) else {return nil}

        return tableSection.name
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        guard let tableSection = TableSections(rawValue: section) else {return 0}

        var count: Int
        switch tableSection {
        case .magnetometer:
            count = SensorParameters.sharedInstance.magnetometerSensors.count
        case .accelerometer:
            count = SensorParameters.sharedInstance.accelerometerSensors.count
        case .gyroscope:
            count = SensorParameters.sharedInstance.gyroscopeSensors.count
        }
        return count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        /*
        let tableSection = TableSections(rawValue: indexPath.section) ?? .gyroscope
        
        var cell: UITableViewCell?
        switch tableSection {
            
            
        case .imageSlots:
            let reuseIdentifier = "MagnetometerCell"
            cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
            }
            
        default:
            let reuseIdentifier = "GyroscopeCell"
            cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
            }
        }
 */

        let reuseIdentifier = "Cell"
        var cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
        }

        return cell!
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {

        guard let tableSection = TableSections(rawValue: indexPath.section) else {return}

        let row = indexPath.row
        switch tableSection {

        case .magnetometer:
            cell.textLabel?.text = SensorParameters.sharedInstance.magnetometerSensors[row].name
            cell.accessoryType =  Preferences.magnetometerType == row ? .checkmark:.none

        case .accelerometer:
            cell.textLabel?.text = SensorParameters.sharedInstance.accelerometerSensors[row].name
            cell.accessoryType =  Preferences.accelerometerType == row ? .checkmark:.none

        case .gyroscope:
            cell.textLabel?.text = SensorParameters.sharedInstance.gyroscopeSensors[row].name
            cell.accessoryType =  Preferences.gyroscopeType == row ? .checkmark:.none
        }
    }
}

// MARK: - UITableViewDelegate
extension SensorConfigViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }

        let row = indexPath.row
        guard let tableSection = TableSections(rawValue: indexPath.section) else {return}

        switch tableSection {
        case .magnetometer:
            Preferences.magnetometerType = row
        case .accelerometer:
            Preferences.accelerometerType = row
        case .gyroscope:
            Preferences.gyroscopeType = row
        }

        tableView.reloadData()
    }
}
