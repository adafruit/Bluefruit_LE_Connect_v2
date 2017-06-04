//
//  SensorParameters.swift
//  Calibration
//
//  Created by Antonio on 18/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class SensorParameters {

    // Singleton
    static let sharedInstance = SensorParameters()

    struct MagnetometerParameters {
        var name: String
        var utPerCount: Vector3
    }

    struct AccelometerParameters {
        var name: String
        var gPerCount: Float
    }

    struct GyroscopeParameters {
        var name: String
        var degPerSecPerCount: Float
    }

    var magnetometerSensors = [MagnetometerParameters]()
    var accelerometerSensors = [AccelometerParameters]()
    var gyroscopeSensors = [GyroscopeParameters]()

    var selectedMagnetometerParameters: MagnetometerParameters {
        return magnetometerSensors[Preferences.magnetometerType]
    }

    var selectedAccelerometerParameters: AccelometerParameters {
        return accelerometerSensors[Preferences.accelerometerType]
    }

    var selectedGyroscopeParameters: GyroscopeParameters {
        return gyroscopeSensors[Preferences.gyroscopeType]
    }

    init() {
        if let path = Bundle.main.path(forResource: "MagnetometerParameters", ofType: "plist") {
            if let sensors = NSArray(contentsOfFile: path) as? [Dictionary<String, Any>] {

                for sensorParameters in sensors {
                    let sensorName = sensorParameters["name"] as? String
                    let x = sensorParameters["UtPerCountX"] as? Float
                    let y = sensorParameters["UtPerCountY"] as? Float
                    let z = sensorParameters["UtPerCountZ"] as? Float

                    if let sensorName = sensorName, let x = x, let y = y, let z = z {
                        let parameters = MagnetometerParameters(name: sensorName, utPerCount: Vector3(x, y, z))
                        magnetometerSensors.append(parameters)
                    }

                }
            }
        }

        if let path = Bundle.main.path(forResource: "AccelerometerParameters", ofType: "plist") {
            if let sensors = NSArray(contentsOfFile: path) as? [Dictionary<String, Any>] {

                for sensorParameters in sensors {
                    let sensorName = sensorParameters["name"] as? String
                    if let sensorName = sensorName, let value = sensorParameters["GPerCount"] as? Float {
                        let parameters = AccelometerParameters(name: sensorName, gPerCount: value)
                        accelerometerSensors.append(parameters)
                    }
                }
            }
        }

        if let path = Bundle.main.path(forResource: "GyroscopeParameters", ofType: "plist") {
            if let sensors = NSArray(contentsOfFile: path) as? [Dictionary<String, Any>] {

                for sensorParameters in sensors {
                    let sensorName = sensorParameters["name"] as? String
                    if let sensorName = sensorName, let value = sensorParameters["DegPerSecPerCount"] as? Float {
                        let parameters = GyroscopeParameters(name: sensorName, degPerSecPerCount: value)
                        gyroscopeSensors.append(parameters)

                    }

                }
            }
        }

    }

}
