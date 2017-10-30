//
//  SensorsData.swift
//  Calibration
//
//  Created by Antonio García on 29/06/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import CoreMotion


class SensorsData {
    private let coreMotionManager = CMMotionManager()    
   
    func startUpdatingData() {
        // Start received data updates
        coreMotionManager.startAccelerometerUpdates()
        coreMotionManager.startGyroUpdates()
        coreMotionManager.startMagnetometerUpdates()
    }
    
    func stopUpdatingData() {
        // Stop updating data
        coreMotionManager.stopAccelerometerUpdates()
        coreMotionManager.stopGyroUpdates()
        coreMotionManager.stopMagnetometerUpdates()
    }

  
    func magnetometerData() -> CMMagnetometerData? {
        return coreMotionManager.magnetometerData
    }
    
    func gyroData() -> CMGyroData? {
        return coreMotionManager.gyroData
    }
    
    func accelerometerData() -> CMAccelerometerData? {
        return coreMotionManager.accelerometerData
    }
    
}