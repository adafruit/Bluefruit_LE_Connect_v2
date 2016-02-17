//
//  ControllerModuleManager.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import CoreLocation

// TODO: add support for OSX
#if os(OSX)
#else
    import CoreMotion
#endif

class ControllerModuleManager : NSObject {
    
    enum ControllerType : Int {
        case Attitude = 0
        case Accelerometer
        case Gyroscope
        case Magnetometer
        case Location
    }
    static let numSensors = 5
    
    static private let prefixes = ["!Q", "!A", "!G", "!M", "!L"];     // same order that ControllerType
    
    // Data
    private var isSensorEnabled = [Bool](count:ControllerModuleManager.numSensors, repeatedValue: false)

    #if os(OSX)
    #else
    private let coreMotionManager = CMMotionManager()
    #endif
    private let locationManager = CLLocationManager()
    private var lastKnownLocation :CLLocation?
    
    private var pollTimer : NSTimer?
    private var timerHandler : (()->())?
    
    private let uartManager = UartManager.sharedInstance
    
    override init() {
        super.init()
        
        // Setup Location Manager
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.delegate = self
    }
    
    deinit {
        locationManager.delegate = nil
        // Disable everthing
        for i in 0..<ControllerModuleManager.numSensors {
            setSensorEnabled(false, index: i)
        }
    }
    
    func startUpdatingData(pollInterval: NSTimeInterval, handler:(()->())?) {
        timerHandler = handler
        pollTimer = NSTimer.scheduledTimerWithTimeInterval(pollInterval, target: self, selector: "updateSensors", userInfo: nil, repeats: true)
    }
    
    func stopUpdatingData() {
        timerHandler = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    func updateSensors() {
        timerHandler?()
        
        for i in 0..<ControllerModuleManager.numSensors {
            if isSensorEnabled(i) {
                if let sensorData = getSensorData(i) {
                    
                    let data = NSMutableData()
                    let prefixData = ControllerModuleManager.prefixes[i].dataUsingEncoding(NSUTF8StringEncoding)!
                    data.appendData(prefixData)
                    
                    for value in sensorData {
                        var floatValue = Float(value)
                        data.appendBytes(&floatValue, length: sizeof(Float))
                    }
                    
                    uartManager.sendDataWithCrc(data)
                }
            }
        }
    }
    
    func isSensorEnabled(index: Int) -> Bool {
        return isSensorEnabled[index]
    }
    
    func getSensorData(index: Int) -> [Double]? {
        guard isSensorEnabled(index) else {
            return nil
        }
        
        switch ControllerType(rawValue: index)! {
        case .Attitude:
            if let attitude = coreMotionManager.deviceMotion?.attitude {
                return [attitude.quaternion.x, attitude.quaternion.y, attitude.quaternion.z, attitude.quaternion.z]
            }
        case .Accelerometer:
            if let acceleration = coreMotionManager.accelerometerData?.acceleration {
                return [acceleration.x, acceleration.y, acceleration.z]
            }
        case .Gyroscope:
            if let rotation = coreMotionManager.gyroData?.rotationRate {
                return [rotation.x, rotation.y, rotation.z]
            }
        case .Magnetometer:
            if let magneticField = coreMotionManager.magnetometerData?.magneticField {
                return [magneticField.x, magneticField.y, magneticField.z]
            }
        case .Location:
            if let location = lastKnownLocation {
                return [location.coordinate.latitude, location.coordinate.longitude, location.altitude]
            }
        }
        
        return nil
    }
    
    func setSensorEnabled(enabled: Bool, index: Int) -> String? {
        isSensorEnabled[index] = enabled
        
        var errorString : String?
        switch ControllerType(rawValue: index)! {
        case .Attitude:
            if enabled {
                coreMotionManager.startDeviceMotionUpdates()
            }
            else {
                coreMotionManager.stopDeviceMotionUpdates()
            }

        case .Accelerometer:
            if enabled {
                coreMotionManager.startAccelerometerUpdates()
            }
            else {
                coreMotionManager.stopAccelerometerUpdates()
            }
        case .Gyroscope:
            if enabled {
                coreMotionManager.startGyroUpdates()
            }
            else {
                coreMotionManager.stopGyroUpdates()
            }
            
        case .Magnetometer:
            if enabled {
                coreMotionManager.startMagnetometerUpdates()
            }
            else {
                coreMotionManager.stopMagnetometerUpdates()
            }
            
        case .Location:
            if enabled {
                if CLLocationManager.locationServicesEnabled() {
                    if CLLocationManager.authorizationStatus() == .NotDetermined {
                        locationManager.requestWhenInUseAuthorization()
                    }
                    else {
                        locationManager.startUpdatingLocation()
                    }
                }
                else {      // Location services disabled
                    errorString = "Location Services Disabled"
                    DLog("Location services disabled")
                    
                }
            }
            else {
                locationManager.stopUpdatingLocation()
            }

        }
        
        return errorString
    }
}

extension ControllerModuleManager: CLLocationManagerDelegate {
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .AuthorizedAlways || status == .AuthorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastKnownLocation = locations.last
    }
}