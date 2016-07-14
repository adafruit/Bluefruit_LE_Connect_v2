//
//  ControllerModuleManager.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import CoreLocation
import MSWeakTimer

// TODO: add support for OSX
#if os(OSX)
#else
    import CoreMotion
#endif

protocol ControllerModuleManagerDelegate: class {
    func onControllerUartIsReady()
}

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
    weak var delegate: ControllerModuleManagerDelegate?
    
    var isSensorEnabled = [Bool](count:ControllerModuleManager.numSensors, repeatedValue: false)

    #if os(OSX)
    #else
    private let coreMotionManager = CMMotionManager()
    #endif
    private let locationManager = CLLocationManager()
    private var lastKnownLocation :CLLocation?
    
    private var pollTimer : MSWeakTimer?
    private var timerHandler : (()->())?
    
    private let uartManager = UartManager.sharedInstance
    
    private var pollInterval: NSTimeInterval = 1        // in seconds
    
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
    
    func start(pollInterval: NSTimeInterval, handler:(()->())?) {
        self.pollInterval = pollInterval
        self.timerHandler = handler
        
        // Start Uart Manager
        UartManager.sharedInstance.blePeripheral = BleManager.sharedInstance.blePeripheralConnected       // Note: this will start the service discovery
        
        // Notifications
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        if !uartManager.isReady() {
            notificationCenter.addObserver(self, selector: #selector(uartIsReady(_:)), name: UartManager.UartNotifications.DidBecomeReady.rawValue, object: nil)
        }
        else {
            delegate?.onControllerUartIsReady()
            startUpdatingData()
        }
        
    }
    
    func stop() {
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: UartManager.UartNotifications.DidBecomeReady.rawValue, object: nil)
        
        stopUpdatingData()
    }
    
    // MARK: Notifications
    func uartIsReady(notification: NSNotification) {
        DLog("Uart is ready")
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: UartManager.UartNotifications.DidBecomeReady.rawValue, object: nil)
        
        delegate?.onControllerUartIsReady()
        startUpdatingData()
    }
    

    // MARK: -
    private func startUpdatingData() {
        pollTimer = MSWeakTimer.scheduledTimerWithTimeInterval(pollInterval, target: self, selector: #selector(updateSensors), userInfo: nil, repeats: true, dispatchQueue: dispatch_get_main_queue())
    }
    
    private func stopUpdatingData() {
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
                    let authorizationStatus = CLLocationManager.authorizationStatus()
                    switch authorizationStatus {
                    case .NotDetermined:
                        locationManager.requestWhenInUseAuthorization()
                    case .Denied:
                        errorString = LocalizationManager.sharedInstance.localizedString("controller_sensor_location_denied")
                    case .Restricted:
                        errorString = LocalizationManager.sharedInstance.localizedString("controller_sensor_location_restricted")
                    default:
                        locationManager.startUpdatingLocation()
                    }
                }
                else {      // Location services disabled
                    DLog("Location services disabled")
                    errorString = LocalizationManager.sharedInstance.localizedString("controller_sensor_location_disabled")
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