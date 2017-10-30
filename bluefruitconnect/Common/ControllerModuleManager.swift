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
    
  var isSensorEnabled = [Bool](repeating: false, count: ControllerModuleManager.numSensors)
  
    let coreMotionManager = CMMotionManager()

    private let locationManager = CLLocationManager()
    private var lastKnownLocation :CLLocation?
    
    private var pollTimer : DispatchSourceTimer?
//    private var pollTimer: Timer?
    private var timerHandler : (()->())?
    
    private let uartManager = UartManager.sharedInstance
    
    private var pollInterval: TimeInterval = 1        // in seconds
    
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
          setSensorEnabled(enabled: false, index: i)
        }
    }
    
    func start(pollInterval: TimeInterval, handler:(()->())?) {
        self.pollInterval = pollInterval
        self.timerHandler = handler
        
        // Start Uart Manager
        UartManager.sharedInstance.blePeripheral = BleManager.sharedInstance.blePeripheralConnected       // Note: this will start the service discovery
        
        // Notifications
      let notificationCenter =  NotificationCenter.default
        if !uartManager.isReady() {
            notificationCenter.addObserver(self, selector: #selector(uartIsReady), name: .uartDidBecomeReady, object: nil)
        }
        else {
            delegate?.onControllerUartIsReady()
            startUpdatingData()
        }
        
    }
    
    func stop() {
        let notificationCenter =  NotificationCenter.default
        notificationCenter.removeObserver(self, name: .uartDidBecomeReady, object: nil)
        
        stopUpdatingData()
    }
    
    // MARK: Notifications
  @objc func uartIsReady(notification: NSNotification) {
    DLog(message: "Uart is ready")
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: .uartDidBecomeReady, object: nil)
        
        delegate?.onControllerUartIsReady()
        startUpdatingData()
    }
    

    // MARK: -
    private func startUpdatingData() {
//        pollTimer = MSWeakTimer.scheduledTimer(pollInterval, target: self, selector: #selector(updateSensors), userInfo: nil, repeats: true, dispatchQueue: dispatch_get_main_queue())
        
        let queue = DispatchQueue.main
        pollTimer = DispatchSource.makeTimerSource(queue: queue)
        pollTimer?.schedule(deadline: .now(), repeating: pollInterval, leeway: .nanoseconds(0))
        pollTimer?.setEventHandler(handler: { [weak self] in
            self?.updateSensors()
        })
        pollTimer?.resume()
    }
    
    private func stopUpdatingData() {
        timerHandler = nil
//        pollTimer?.invalidate()
        pollTimer?.cancel()
        pollTimer = nil
    }
    
  @objc func updateSensors() {
        timerHandler?()
        
        for i in 0..<ControllerModuleManager.numSensors {
            if isSensorEnabled(index: i) {
              if let sensorData = getSensorData(index: i) {
                    
                    let data = NSMutableData()
                let prefixData = ControllerModuleManager.prefixes[i].data(using: String.Encoding.utf8)!
                data.append(prefixData)
                    
                    for value in sensorData {
                        var floatValue = Float(value)
                      data.append(&floatValue, length: MemoryLayout<Float>.size)
                    }
                    
                uartManager.sendDataWithCrc(data: data)
                }
            }
        }
    }
    
    func isSensorEnabled(index: Int) -> Bool {
        return isSensorEnabled[index]
    }
    
    func getSensorData(index: Int) -> [Double]? {
        guard isSensorEnabled(index: index) else {
            return nil
        }
        
        switch ControllerType(rawValue: index)! {
        case .Attitude:
            if let attitude = coreMotionManager.deviceMotion?.attitude {
                return [attitude.quaternion.x, attitude.quaternion.y, attitude.quaternion.z, attitude.quaternion.w]
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
                    case .notDetermined:
                        locationManager.requestWhenInUseAuthorization()
                    case .denied:
                      errorString = LocalizationManager.sharedInstance.localizedString(key: "controller_sensor_location_denied")
                    case .restricted:
                      errorString = LocalizationManager.sharedInstance.localizedString(key: "controller_sensor_location_restricted")
                    default:
                        locationManager.startUpdatingLocation()
                    }
                }
                else {      // Location services disabled
                  DLog(message: "Location services disabled")
                  errorString = LocalizationManager.sharedInstance.localizedString(key: "controller_sensor_location_disabled")
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
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
      if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastKnownLocation = locations.last
    }
}















