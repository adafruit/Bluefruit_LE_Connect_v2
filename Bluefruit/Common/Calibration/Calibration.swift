//
//  Calibrator.swift
//  Calibration
//
//  Created by Antonio García on 03/11/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//
//  Base code: https://github.com/PaulStoffregen/MotionCal
//  This version is a direct port of that code. TODO:  organize it better. There are still dependencies between logic and visual elements

import Foundation
import QuartzCore

class Calibration {
    // Config
    static let kGapTarget: Scalar = 15
    static let kVarianceTarget: Scalar = 4.5
    static let kWobbleTarget: Scalar = 4
    static let kFitErrorTarget: Scalar = 5

    fileprivate static let kOversampleRatio = 4
    fileprivate static let kSensorFs = 100

    // Data
    struct AccelSensor {
//      static var kGPerCount: Scalar = 0.0001220703125  // = 1/8192        g/lsb                       // FXOS8700
//      static var kGPerCount: Scalar = 0.244/1000  g/lsb                                               // LSM303DLHC
        static var gPerCount: Scalar = SensorParameters.sharedInstance.selectedAccelerometerParameters.gPerCount

        var gp = Vector3.zero         // slow (typically 25Hz) averaged readings (g)
        var gpFast = Vector3.zero     // fast (typically 200Hz) readings (g)
    }

    struct MagSensor {
//      static var kUtPerCount: Scalar = 0.1                                                            // FXOS8700
//      static var kUtPerCount: Vector3 = Vector3(1.0/11, 1.0/11, 1/9.8)            // uT/lsb           // LSM303DLHC
//      static var kUtPerCount: Scalar = 0.14                                                            // FXOS8700
        static var utPerCount: Vector3 = SensorParameters.sharedInstance.selectedMagnetometerParameters.utPerCount

        var bc = Vector3.zero         // slow (typically 25Hz) averaged calibrated readings (uT)
        var bcFast = Vector3.zero     // fast (typically 200Hz) calibrated readings (uT)
    }

    struct GyroSensor {
//      static var kDegPerSecPerCount: Scalar = 0.0625  // = 1/16                                       // FXAS21002
//      static var kDegPerSecPerCount: Scalar = 0.00875                                                 // L3GD20
        static var degPerSecPerCount =  SensorParameters.sharedInstance.selectedGyroscopeParameters.degPerSecPerCount

        var yp = Vector3.zero         // raw gyro sensor output (deg/s)
        var ypFast = [Vector3](repeating:Vector3.zero, count: Calibration.kOversampleRatio)   // fast (typically 200Hz) readings
    }

    struct MahonyData {
        static let kTwoKpDef: Scalar = 2.0 * 0.02       // 2 * proportional gain
        static let kTwoKiDef: Scalar = 2.0 * 0.0        // 2 * integral gain
        static let kInvSampleRate: Scalar =  1.0 / Scalar(kSensorFs)

        var twoKp = MahonyData.kTwoKpDef                // 2 * proportional gain (Kp)
        var twoKi = MahonyData.kTwoKiDef                // 2 * integral gain (Ki)
        var q = Quaternion.identity                     // quaternion of sensor frame relative to auxiliary frame
        var integralFb = Vector3.zero                   // integral error terms scaled by Kis

        var resetNextUpdate = false
    }

    private var accel = AccelSensor()
    private var mag = MagSensor()
    private var gyro = GyroSensor()

    private var magCal = MagCalibration()
    var currentOrientation = Quaternion.identity
    private var rawCount = Calibration.kOversampleRatio

    var mahony = MahonyData()
    private var dataLock = NSLock()

    func reset() {
        dataLock.lock(); defer {dataLock.unlock()}

        rawCount = Calibration.kOversampleRatio
        fusionInit()
        magCal = MagCalibration()
    }

    private var forceOrientationCounter = 0
    func addData(accelX: Int16, accelY: Int16, accelZ: Int16, gyroX: Int16, gyroY: Int16, gyroZ: Int16, magX: Int16, magY: Int16, magZ: Int16) {
        dataLock.lock(); defer {dataLock.unlock()}

        magCal.addMagCalData(accelX: accelX, accelY: accelY, accelZ: accelZ, gyroX: gyroX, gyroY: gyroY, gyroZ: gyroZ, magX: magX, magY: magY, magZ: magZ)
        if magCal.run() {
            var v = magCal.v
            v = v - magCal.v
            let magDiff = v.length
            DLog(String(format: "magdiff = %.2f\n", magDiff))
            if magDiff > 0.8 {
                fusionInit()
                rawCount = Calibration.kOversampleRatio
                forceOrientationCounter = 240
            }
        }

        if forceOrientationCounter > 0 {
            forceOrientationCounter -= 1
            if forceOrientationCounter == 0 {
                fusionInit()
                rawCount = Calibration.kOversampleRatio
            }
        }

        if rawCount >= Calibration.kOversampleRatio {
            accel = AccelSensor()
            mag = MagSensor()
            gyro = GyroSensor()
            rawCount = 0
        }

        let x = Scalar(accelX) * AccelSensor.gPerCount
        let y = Scalar(accelY) * AccelSensor.gPerCount
        let z = Scalar(accelZ) * AccelSensor.gPerCount
        let v = Vector3(x, y, z)
        accel.gpFast = v
        accel.gp = accel.gp + v

        let point = magCal.applyCalibration(Vector3(Scalar(magX), Scalar(magY), Scalar(magZ)))
        mag.bcFast = point
        mag.bc = mag.bc + point

        rawCount += 1

        if rawCount >= Calibration.kOversampleRatio {
            let ratio = 1.0 / Scalar(Calibration.kOversampleRatio)
            accel.gp = accel.gp * ratio
            gyro.yp = gyro.yp * ratio
            mag.bc = mag.bc * ratio

            fusionUpdate(accel: accel, mag: mag, gyro: gyro, magCal: magCal)
            currentOrientation = fusionRead()
        }
    }

    func applyCalibration(index i: Int) -> Vector3? {
        //      dataLock.lock(); defer {dataLock.unlock()}

        return magCal.applyCalibration(bpFastIndex: i)
    }

    func sphericalFitError() -> Scalar {
        dataLock.lock(); defer {dataLock.unlock()}
        return magCal.fitError
    }

    func magneticOffset() -> Vector3 {
        dataLock.lock(); defer {dataLock.unlock()}
        return magCal.v
    }

    func magneticMapping() -> Matrix3 {
        dataLock.lock(); defer {dataLock.unlock()}
        return magCal.invW
    }

    func hardIron() -> Vector3 {
        dataLock.lock(); defer {dataLock.unlock()}
        return magCal.v
    }

    func magneticField() -> Scalar {
        dataLock.lock(); defer {dataLock.unlock()}
        return magCal.b
    }

    func surfaceGapError() -> Scalar {
        dataLock.lock(); defer {dataLock.unlock()}
        return magCal.quality.surfaceGapError()
    }

    func magnitudeVarianceError() -> Scalar {
        dataLock.lock(); defer {dataLock.unlock()}
        return magCal.quality.magnitudeVarianceError()
    }

    func wobbleError() -> Scalar {
        dataLock.lock(); defer {dataLock.unlock()}
        return magCal.quality.wobbleError()
    }

    func qualityReset() {
        dataLock.lock(); defer {dataLock.unlock()}
        return magCal.quality.reset()
    }

    func qualityUpdate(point: Vector3) {
        dataLock.lock(); defer {dataLock.unlock()}
        return magCal.quality.update(point: point)
    }

    func lastUsedIndex() -> Int? {
        return magCal.lastUsedIndex
    }

    // MARK: - MagCalibration
    struct MagCalibration {
        static let kMagBufferSize = 650
        private static let kMinMeasurements4Cal = 40            // minimum number of measurements for 4 element calibration
        private static let kMinMeasurements7Cal = 100           // minimum number of measurements for 7 element calibration
        private static let kMinMeasurements10Cal = 150          // minimum number of measurements for 10 element calibration

        private static let kFxos8700UtPerCount: Scalar = 0.1
        private static let kDefaultB: Scalar =  50              // default geomagnetic field (uT)

        private static let kMinFitUt: Scalar = 22               // minimum geomagnetic field B (uT) for valid calibration
        private static let kMaxFitUt: Scalar = 67               // maximum geomagnetic field B (uT) for valid calibration

        private static let  kOneThird: Scalar = 0.33333333        // one third
        private static let  kOneSixth: Scalar = 0.166666667       // one sixth

        private let X = 0           // Index helper
        private let Y = 1           // Index helper
        private let Z = 2           // Index helper

        var v: Vector3              // current hard iron offset x, y, z, (uT)
        var invW: Matrix3           // current inverse soft iron matrix
        var b: Scalar               // current geomagnetic field magnitude (uT)
        var fourBsq: Scalar         // current 4*B*B (uT^2)
        var fitError: Scalar        // current fit error %
        var fitErrorAge: Scalar     // current fit error % (grows automatically with age)
        var trV: Vector3            // trial value of hard iron offset z, y, z (uT)
        var trinvW: Matrix3         // trial inverse soft iron matrix size
        var trB: Scalar             // trial value of geomagnetic field magnitude in uT
        var trFitErrorpc: Scalar    // trial value of fit error %
        var a: Matrix3              // ellipsoid matrix A
        var invA: Matrix3           // inverse of ellipsoid matrix A

        var matA: [[Scalar]]        // scratch 10x10 matrix used by calibration algorithms
        var matB: [[Scalar]]        // scratch 10x10 matrix used by calibration algorithms
        var vecA: [Scalar]          // scratch 10x1 vector used by calibration algorithms
        var vecB: [Scalar]          // scratch 4x1 vector used by calibration algorithms
        var validMagCal: Int8       // integer value 0, 4, 7, 10 denoting both valid calibration and solver used
        var bpFast: [[Int16]]       // uncalibrated magnetometer readings
        var valid: [Bool]           // 1=has data, 0=empty slot

        var magBufferCount: Int     // number of magnetometer readings

        var quality = Quality()

        var cachedSquaredDistanceBetweenReadings: [[Int64]]
        var lastUsedIndex: Int?

        init() {
            // Initial values
            v = Vector3(x: 0, y: 0, z: 80)      // initial guess
            invW = .identity
            b = MagCalibration.kDefaultB
            fourBsq = 0
            fitError = 100
            fitErrorAge = 100
            trV = .zero
            trinvW = .identity
            trB = 0
            trFitErrorpc = 0
            a = .identity
            invA = .identity
            matA = [[Scalar]](repeating: [Scalar](repeating:0, count: 10), count: 10)
            matB = [[Scalar]](repeating: [Scalar](repeating:0, count: 10), count: 10)
            vecA = [Scalar](repeating:0, count: 10)
            vecB = [Scalar](repeating:0, count: 4)
            validMagCal = 0
            bpFast = [[Int16]](repeating: [Int16](repeating:0, count: MagCalibration.kMagBufferSize), count: 3)
            valid = [Bool](repeating:false, count: MagCalibration.kMagBufferSize)
            magBufferCount = 0

            cachedSquaredDistanceBetweenReadings = [[Int64]](repeating: [Int64](repeating:0, count: MagCalibration.kMagBufferSize), count: MagCalibration.kMagBufferSize)
        }

        func applyCalibration(bpFastIndex i: Int) -> Vector3? {
            guard valid[i] else { return nil }

            let raw = Vector3(Scalar(bpFast[X][i]), Scalar(bpFast[Y][i]), Scalar(bpFast[Z][i]))
            let result = applyCalibration(raw)
            return result
        }

        func applyCalibration(_ raw: Vector3) -> Vector3 {
            //let value = raw * MagSensor.kUtPerCount - v
            let value = Vector3(raw.x * MagSensor.utPerCount.x, raw.y * MagSensor.utPerCount.y, raw.z * MagSensor.utPerCount.z ) - v
            let result = value * invW
            return result
        }

        mutating func addMagCalData(accelX: Int16, accelY: Int16, accelZ: Int16, gyroX: Int16, gyroY: Int16, gyroZ: Int16, magX: Int16, magY: Int16, magZ: Int16) {
            // first look for an unused caldata slot

            var unusedIndex = valid.index(where: {!$0})

            if unusedIndex == nil {
                // If the buffer is full, we must choose which old data to discard.
                // We must choose wisely!  Throwing away the wrong data could prevent
                // collecting enough data distributed across the entire 3D angular
                // range, preventing a decent cal from ever happening at all.  Making
                // any assumption about good vs bad data is particularly risky,
                // because being wrong could cause an unstable feedback loop where
                // bad data leads to wrong decisions which leads to even worse data.
                // But if done well, purging bad data has massive potential to
                // improve results.  The trick is telling the good from the bad while
                // still in the process of learning what's good...

                unusedIndex = chooseDiscardMagCal()
                if unusedIndex == nil {
                    unusedIndex = Int(arc4random_uniform(UInt32(MagCalibration.kMagBufferSize)))
                }
                //DLog("discard: \(unusedIndex!)")
            }

            if let unusedIndex = unusedIndex {

                // add it to the cal buffer
                bpFast[0][unusedIndex] = magX
                bpFast[1][unusedIndex] = magY
                bpFast[2][unusedIndex] = magZ
                valid[unusedIndex] = true

                // precalculate distance between this point all previous ones
                let j = unusedIndex
                for i in 0..<MagCalibration.kMagBufferSize {
                    if valid[i] && i != j {
                        let dx = Int64(bpFast[0][i] - magX)
                        let dy = Int64(bpFast[1][i] - magY)
                        let dz = Int64(bpFast[2][i] - magZ)
                        let distSquared = dx * dx + dy * dy + dz * dz

                        cachedSquaredDistanceBetweenReadings[i <= j ? i:j][i > j ? i:j] = distSquared       // only fill the top right area of the matrix (distance between i and j is the same that between j and i)
                    }
                }

                // save last point added
                lastUsedIndex = unusedIndex
            } else {
                DLog("Error finding unusedIndex to add reading")
            }
        }

        var chooseDiscardMagCalRunCount = 0
        private mutating func chooseDiscardMagCal() -> Int? {

            // When enough data is collected (gaps error is low), assume we
            // have a pretty good coverage and the field stregth is known.
            var gaps = quality.surfaceGapError()
            if gaps < 25 {
                // occasionally look for points farthest from average field strength
                // always rate limit assumption-based data purging, but allow the
                // rate to increase as the angular coverage improves.

                if gaps < 1 {
                    gaps = 1
                }
                chooseDiscardMagCalRunCount = chooseDiscardMagCalRunCount + 1
                if chooseDiscardMagCalRunCount > Int(gaps * 10) {
                    var j = MagCalibration.kMagBufferSize
                    var errorMax: Scalar = 0
                    for i in 0..<MagCalibration.kMagBufferSize {
                        let rawX = bpFast[0][i]
                        let rawY = bpFast[1][i]
                        let rawZ = bpFast[2][i]
                        let point = applyCalibration(Vector3(Scalar(rawX), Scalar(rawY), Scalar(rawZ)))
                        let field = point.length
                        // if magcal.B is bad, things could go horribly wrong
                        let error = fabsf(field - b)
                        if error > errorMax {
                            errorMax = error
                            j = i
                        }
                    }
                    chooseDiscardMagCalRunCount = 0
                    if j < MagCalibration.kMagBufferSize {
                        return j
                    }
                }
            } else {
                chooseDiscardMagCalRunCount = 0
            }

            // When solid info isn't availabe, find 2 points closest to each other,
            // and randomly discard one.  When we don't have good coverage, this
            // approach tends to add points into previously unmeasured areas while
            // discarding info from areas with highly redundant info.

            var minSum = Int64.max
            var minIndex = 0

            //            let profileStartTime: CFTimeInterval = CACurrentMediaTime()

            for i in 0..<MagCalibration.kMagBufferSize {
                for j in i+1..<MagCalibration.kMagBufferSize {

                    /*
                     let dx = Int64(bpFast[0][i] - bpFast[0][j])
                     let dy = Int64(bpFast[1][i] - bpFast[1][j])
                     let dz = Int64(bpFast[2][i] - bpFast[2][j])
                     let distSquared = dx * dx + dy * dy + dz * dz
                     */
                    //                    DLog("dst[\(i <= j ? i:j)][\(i > j ? i:j)]")
                    let distSquared = cachedSquaredDistanceBetweenReadings[i][j]
                    /*
                    if distSquared == 0 {
                        DLog("Warning: distSquared is 0!! ")
                    }*/
                    if distSquared < minSum {
                        minSum = distSquared
                        minIndex = arc4random_uniform(2) > 0 ? i:j
                        //minIndex = i    // Debug: make it deterministic
                    }
                }
            }

            //            let currentTime = CACurrentMediaTime()
            //            let elapsedTime = currentTime - profileStartTime
            //            DLog("elapsed: \(String(format: "%.1f", elapsedTime * 1000))")

            //DLog("chooseDiscardMagCal: \(minIndex)")
            return minIndex
        }

        mutating func run() -> Bool {
            struct Holder {
                static var waitCount = 0
            }

            // only do the calibration occasionally
            Holder.waitCount += 1

            guard Holder.waitCount >= 20 else { return false }
            Holder.waitCount = 0

            // count number of data points
            let count = valid.reduce(0, {$0 + ($1 ? 1:0) })
            guard count >= MagCalibration.kMinMeasurements4Cal else { return false }

            if validMagCal != 0 {
                // age the existing fit error to avoid one good calibration locking out future updates
                fitErrorAge *= 1.02
            }

            // is enough data collected
            var iSolver: Int8
            if count < MagCalibration.kMinMeasurements7Cal {
                iSolver = 4
                updateCalibration4INV(); // 4 element matrix inversion calibration
                if trFitErrorpc < 12 {
                    trFitErrorpc = 12
                }
            } else if count < MagCalibration.kMinMeasurements10Cal {
                iSolver = 7
                updateCalibration7EIG(); // 7 element eigenpair calibration
                if trFitErrorpc < 7.5 {
                    trFitErrorpc = 7.5
                }
            } else {
                iSolver = 10
                updateCalibration10EIG(); // 10 element eigenpair calibration
            }

            // the trial geomagnetic field must be in range (earth is 22uT to 67uT)

            if trB >= MagCalibration.kMinFitUt && trB <= MagCalibration.kMaxFitUt {
                // always accept the calibration if
                //  1: no previous calibration exists
                //  2: the calibration fit is reduced or+
                //  3: an improved solver was used giving a good trial calibration (4% or under)
                if validMagCal == 0 || trFitErrorpc <= fitErrorAge || (iSolver > validMagCal && trFitErrorpc <= 4.0) {
                    // accept the new calibration solution
                    //printf("new magnetic cal, B=%.2f uT\n", magcal.trB);
                    validMagCal = iSolver
                    fitError = trFitErrorpc
                    DLog("fit error: \(fitError)")
                    if trFitErrorpc > 2.0 {
                        fitErrorAge = trFitErrorpc
                    } else {
                        fitErrorAge = 2.0
                    }
                    b = trB
                    fourBsq = 4.0 * trB * trB
                    for i in X...Z {
                        v[i] = trV[i]
                    }
                    invW = trinvW
                    return true // indicates new calibration applied
                }
            }

            return false
        }

        private mutating func updateCalibration4INV() {
            DLog("updateCalibration4INV")

            // compute fscaling to reduce multiplications later
            let fScaling = MagCalibration.kFxos8700UtPerCount / MagCalibration.kDefaultB

            // the trial inverse soft iron matrix invW always equals
            // the identity matrix for 4 element calibration
            trinvW = .identity

            // zero fSumBp4=Y^T.Y, vecB=X^T.Y (4x1) and on and above
            // diagonal elements of matA=X^T*X (4x4)
            var fSumBp4: Scalar = 0
            for i in 0..<4 {
                vecB[i] = 0
                for j in 0..<4 {
                    matA[i][j] = 0
                }
            }

            var iOffset = [Int16](repeating: 0, count: 3)

            // use from MINEQUATIONS up to MAXEQUATIONS entries from magnetic buffer to compute matrices
            var iCount = 0          // number of measurements counted
            for j in 0..<MagCalibration.kMagBufferSize {
                if valid[j] {
                    // use first valid magnetic buffer entry as estimate (in counts) for offset
                    if iCount == 0 {
                        for k in X...Z {
                            iOffset[k] = bpFast[k][j]
                        }
                    }

                    // store scaled and offset fBp[XYZ] in vecA[0-2] and fBp[XYZ]^2 in vecA[3-5]
                    for k in X...Z {
                        vecA[k] = Scalar(Int32(bpFast[k][j]) - Int32(iOffset[k])) * fScaling
                        vecA[k + 3] = vecA[k] * vecA[k]
                    }

                    // calculate fBp2 = Bp[X]^2 + Bp[Y]^2 + Bp[Z]^2 (scaled uT^2)
                    let fBp2 = vecA[3] + vecA[4] + vecA[5]

                    // accumulate fBp^4 over all measurements into fSumBp4=Y^T.Y
                    fSumBp4 += fBp2 * fBp2

                    // now we have fBp2, accumulate vecB[0-2] = X^T.Y =sum(Bp2.Bp[XYZ])
                    for k in X...Z {
                        vecB[k] += vecA[k] * fBp2
                    }

                    //accumulate vecB[3] = X^T.Y =sum(fBp2)
                    vecB[3] += fBp2

                    // accumulate on and above-diagonal terms of matA = X^T.X ignoring matA[3][3]
                    matA[0][0] += vecA[X + 3]
                    matA[0][1] += vecA[X] * vecA[Y]
                    matA[0][2] += vecA[X] * vecA[Z]
                    matA[0][3] += vecA[X]
                    matA[1][1] += vecA[Y + 3]
                    matA[1][2] += vecA[Y] * vecA[Z]
                    matA[1][3] += vecA[Y]
                    matA[2][2] += vecA[Z + 3]
                    matA[2][3] += vecA[Z]

                    // increment the counter for next iteration
                    iCount += 1

                }
            }

            // set the last element of the measurement matrix to the number of buffer elements used
            matA[3][3] = Scalar(iCount)

            // store the number of measurements accumulated
            magBufferCount = iCount

            // use above diagonal elements of symmetric matA to set both matB and matA to X^T.X
            for i in 0..<4 {
                for j in i..<4 {
                    matB[i][j] = matA[i][j]
                    matB[j][i] = matA[i][j]
                    matA[j][i] = matA[i][j]
                }
            }

            // calculate in situ inverse of matB = inv(X^T.X) (4x4) while matA still holds X^T.X
            fmatrixAeqInvA(&matB, size: 4)

            // calculate vecA = solution beta (4x1) = inv(X^T.X).X^T.Y = matB * vecB
            for i in 0..<4 {
                vecA[i] = 0
                for k in 0..<4 {
                    vecA[i] += matB[i][k] * vecB[k]
                }
            }

            // calculate P = r^T.r = Y^T.Y - 2 * beta^T.(X^T.Y) + beta^T.(X^T.X).beta
            // = fSumBp4 - 2 * vecA^T.vecB + vecA^T.matA.vecA
            // first set P = Y^T.Y - 2 * beta^T.(X^T.Y) = SumBp4 - 2 * vecA^T.vecB
            var fE: Scalar = 0
            for i in 0..<4 {
                fE += vecA[i] * vecB[i]
            }
            fE = fSumBp4 - 2.0 * fE

            // set vecB = (X^T.X).beta = matA.vecA
            for i in 0..<4 {
                vecB[i] = 0
                for k in 0..<4 {
                    vecB[i] += matA[i][k] * vecA[k]
                }
            }

            // complete calculation of P by adding beta^T.(X^T.X).beta = vecA^T * vecB
            for i in 0..<4 {
                fE += vecB[i] * vecA[i]
            }

            // compute the hard iron vector (in uT but offset and scaled by FMATRIXSCALING)
            for k in X...Z {
                trV[k] = 0.5 * vecA[k]
            }

            // compute the scaled geomagnetic field strength B (in uT but scaled by FMATRIXSCALING)
            trB = sqrtf(vecA[3] + trV[X] * trV[X] + trV[Y] * trV[Y] + trV[Z] * trV[Z])

            // calculate the trial fit error (percent) normalized to number of measurements
            // and scaled geomagnetic field strength
            trFitErrorpc = sqrtf(fE / Scalar(magBufferCount)) * 100.0 / (2.0 * trB * trB)

            // correct the hard iron estimate for FMATRIXSCALING and the offsets applied (result in uT)
            for k in X...Z {
                trV[k] = trV[k] * MagCalibration.kDefaultB + Scalar(iOffset[k]) * MagCalibration.kFxos8700UtPerCount
            }

            // correct the geomagnetic field strength B to correct scaling (result in uT)
            trB *= MagCalibration.kDefaultB
        }

        private mutating func updateCalibration7EIG() {
            DLog("updateCalibration7EIG")

            // compute fscaling to reduce multiplications later
            let fScaling = MagCalibration.kFxos8700UtPerCount / MagCalibration.kDefaultB

            var iOffset = [Int16](repeating: 0, count: 3)

            // zero the on and above diagonal elements of the 7x7 symmetric measurement matrix matA
            for m in 0..<7 {
                for n in m..<7 {
                    matA[m][n] = 0.0
                }
            }

            // place from MINEQUATIONS to MAXEQUATIONS entries into product matrix matA
            var iCount = 0
            for j in 0..<MagCalibration.kMagBufferSize {
                if valid[j] {
                    // use first valid magnetic buffer entry as offset estimate (bit counts)
                    if iCount == 0 {
                        for k in X...Z {
                            iOffset[k] = bpFast[k][j]
                        }
                    }

                    // apply the offset and scaling and store in vecA
                    for k in X...Z {
                        vecA[k + 3] = Scalar(Int32(bpFast[k][j]) - Int32(iOffset[k])) * fScaling
                        vecA[k] = vecA[k + 3] * vecA[k + 3]
                    }

                    // accumulate the on-and above-diagonal terms of
                    // matA=Sigma{vecA^T * vecA}
                    // with the exception of matA[6][6] which will sum to the number
                    // of measurements and remembering that vecA[6] equals 1.0F
                    // update the right hand column [6] of matA except for matA[6][6]
                    for m in 0..<6 {
                        matA[m][6] += vecA[m]
                    }
                    // update the on and above diagonal terms except for right hand column 6
                    for m in 0..<6 {
                        for n in m..<6 {
                            matA[m][n] += vecA[m] * vecA[n]
                        }
                    }

                    // increment the measurement counter for the next iteration
                    iCount += 1
                }
            }

            // finally set the last element matA[6][6] to the number of measurements
            matA[6][6] = Scalar(iCount)

            // store the number of measurements accumulated
            magBufferCount = iCount

            // copy the above diagonal elements of matA to below the diagonal
            for m in 1..<7 {
                for n in 0..<m {
                    matA[m][n] = matA[n][m]
                }
            }

            // set tmpA7x1 to the unsorted eigenvalues and matB to the unsorted eigenvectors of matA
            eigencompute(&matA, eigenValues: &vecA, eigenVectors: &matB, size: 7)

            // find the smallest eigenvalue
            var j = 0
            for i in 1..<7 {
                if vecA[i] < vecA[j] {
                    j = i
                }
            }

            // set ellipsoid matrix A to the solution vector with smallest eigenvalue,
            // compute its determinant and the hard iron offset (scaled and offset)
            a = Matrix3(value: 0)

            var det: Scalar = 1.0
            for k in X...Z {
                a[k, k] = matB[k][j]
                det *= a[k, k]
                trV[k] = -0.5 * matB[k + 3][j] / a[k, k]
            }

            // negate A if it has negative determinant
            if det < 0.0 {
                a = -a
                matB[6][j] = -matB[6][j]
                det = -det
            }

            // set ftmp to the square of the trial geomagnetic field strength B
            // (counts times FMATRIXSCALING)
            var ftmp = -matB[6][j]
            for k in X...Z {
                ftmp += a[k, k] * trV[k] * trV[k]
            }

            // calculate the trial normalized fit error as a percentage
            trFitErrorpc = 50.0 * sqrtf(fabs(vecA[j]) / Scalar(magBufferCount)) / fabs(ftmp)

            // normalize the ellipsoid matrix A to unit determinant
            a = a * powf(det, -MagCalibration.kOneThird)

            // convert the geomagnetic field strength B into uT for normalized
            // soft iron matrix A and normalize
            trB = sqrtf(fabs(ftmp)) * MagCalibration.kDefaultB * powf(det, -MagCalibration.kOneSixth)

            // compute trial invW from the square root of A also with normalized
            // determinant and hard iron offset in uT
            trinvW = .identity
            for k in X...Z {
                trinvW[k, k] = sqrtf(fabs(a[k, k]))
                trV[k] = trV[k] * MagCalibration.kDefaultB + Scalar(iOffset[k]) * MagCalibration.kFxos8700UtPerCount
            }
        }

        private mutating func updateCalibration10EIG() {
            DLog("updateCalibration10EIG")

            // compute fscaling to reduce multiplications later
            let fScaling = MagCalibration.kFxos8700UtPerCount / MagCalibration.kDefaultB

            var iOffset = [Int16](repeating: 0, count: 3)

            // zero the on and above diagonal elements of the 10x10 symmetric measurement matrix matA
            for m in 0..<10 {
                for n in 0..<10 {
                    matA[m][n] = 0
                }
            }

            // sum between MINEQUATIONS to MAXEQUATIONS entries into the 10x10 product matrix matA
            var iCount = 0
            for j in 0..<MagCalibration.kMagBufferSize {
                if true /*valid[j]*/ {
                    // use first valid magnetic buffer entry as offset estimate (bit counts)
                    if iCount == 0 {
                        for k in X...Z {
                            iOffset[k] = bpFast[k][j]
                        }
                    }

                    // apply the fixed offset and scaling and enter into vecA[6-8]
                    for k in X...Z {
                        vecA[k + 6] = Scalar(Int32(bpFast[k][j]) - Int32(iOffset[k])) * fScaling
                    }

                    // compute measurement vector elements vecA[0-5] from vecA[6-8]
                    vecA[0] = vecA[6] * vecA[6]
                    vecA[1] = 2.0 * vecA[6] * vecA[7]
                    vecA[2] = 2.0 * vecA[6] * vecA[8]
                    vecA[3] = vecA[7] * vecA[7]
                    vecA[4] = 2.0 * vecA[7] * vecA[8]
                    vecA[5] = vecA[8] * vecA[8]

                    /*
                     DLog("icount: \(iCount)")
                     for zz in 0...5 {
                     DLog("vec\(zz): \(vecA[zz])")
                     }*/

                    // accumulate the on-and above-diagonal terms of matA=Sigma{vecA^T * vecA}
                    // with the exception of matA[9][9] which equals the number of measurements
                    // update the right hand column [9] of matA[0-8][9] ignoring matA[9][9]
                    for m in 0..<9 {
                        matA[m][9] += vecA[m]
                    }
                    // update the on and above diagonal terms of matA ignoring right hand column 9
                    for m in 0..<9 {
                        for n in m..<9 {
                            matA[m][n] += vecA[m] * vecA[n]
                        }
                    }

                    // increment the measurement counter for the next iteration
                    iCount += 1
                }
            }

            // set the last element matA[9][9] to the number of measurements
            matA[9][9] = Scalar(iCount)

            // store the number of measurements accumulated
            magBufferCount = iCount

            // copy the above diagonal elements of symmetric product matrix matA to below the diagonal
            for m in 1..<10 {
                for n in 0..<m {
                    matA[m][n] = matA[n][m]
                }
            }

            // set vecA to the unsorted eigenvalues and matB to the unsorted
            // normalized eigenvectors of matA
            eigencompute(&matA, eigenValues: &vecA, eigenVectors: &matB, size: 10)

            // set ellipsoid matrix A from elements of the solution vector column j with
            // smallest eigenvalue
            var j = 0
            for i in 1..<10 {
                if vecA[i] < vecA[j] {
                    j = i
                }
            }
            a[0, 0] = matB[0][j]
            a[0, 1] = matB[1][j]
            a[1, 0] = matB[1][j]
            a[0, 2] = matB[2][j]
            a[2, 0] = matB[2][j]
            a[1, 1] = matB[3][j]
            a[1, 2] = matB[4][j]
            a[2, 1] = matB[4][j]
            a[2, 2] = matB[5][j]

            // negate entire solution if A has negative determinant
            var det = a.determinant
            if det < 0.0 {
                a = -a
                matB[6][j] = -matB[6][j]
                matB[7][j] = -matB[7][j]
                matB[8][j] = -matB[8][j]
                matB[9][j] = -matB[9][j]
                det = -det
            }

            // compute the inverse of the ellipsoid matrix
            invA = a.symmetricInverse

            // compute the trial hard iron vector in offset bit counts times FMATRIXSCALING
            for k in X...Z {
                trV[k] = 0.0
                for m in X...Z {
                    trV[k] += invA[k, m] * matB[m + 6][j]
                }
                trV[k] *= -0.5
            }

            // compute the trial geomagnetic field strength B in bit counts times FMATRIXSCALING
            let component00 = a[0, 0] * trV[X] * trV[X]
            let component01 = a[0, 1] * trV[X] * trV[Y]
            let component02 = a[0, 2] * trV[X] * trV[Z]
            let component11 = a[1, 1] * trV[Y] * trV[Y]
            let component12 = a[1, 2] * trV[Y] * trV[Z]
            let component22 = a[2, 2] * trV[Z] * trV[Z]

            trB = sqrtf(fabs(component00 +
                2.0 * component01 +
                2.0 * component02 +
                component11 +
                2.0 * component12 +
                component22
                - matB[9][j]))

            // calculate the trial normalized fit error as a percentage
            trFitErrorpc = 50.0 * sqrtf( fabs(vecA[j]) / Scalar(magBufferCount) ) /  (trB * trB)

            // correct for the measurement matrix offset and scaling and
            // get the computed hard iron offset in uT
            for k in X...Z {
                trV[k] = trV[k] * MagCalibration.kDefaultB + Scalar(iOffset[k]) * MagCalibration.kFxos8700UtPerCount
            }

            // convert the trial geomagnetic field strength B into uT for
            // un-normalized soft iron matrix A
            trB *= MagCalibration.kDefaultB

            // normalize the ellipsoid matrix A to unit determinant and
            // correct B by root of this multiplicative factor
            a = a * powf(det, -MagCalibration.kOneThird)
            trB *= powf(det, -MagCalibration.kOneSixth)

            // compute trial invW from the square root of fA (both with normalized determinant)
            // set vecA to the unsorted eigenvalues and matB to the unsorted eigenvectors of matA
            // where matA holds the 3x3 matrix fA in its top left elements
            for i in 0..<3 {
                for j in 0..<3 {
                    matA[i][j] = a[i, j]
                }
            }

            eigencompute(&matA, eigenValues: &vecA, eigenVectors: &matB, size: 3)

            // set MagCal->matB to be eigenvectors . diag(sqrt(sqrt(eigenvalues))) =
            //   matB . diag(sqrt(sqrt(vecA))
            for j in 0..<3 {        // loop over columns j
                let ftmp: Scalar = sqrtf(sqrtf(fabs(vecA[j])))
                for i in 0..<3 { // loop over rows i
                    matB[i][j] *= ftmp
                }
            }

            // set trinvW to eigenvectors * diag(sqrt(eigenvalues)) * eigenvectors^T =
            //   matB * matB^T = sqrt(fA) (guaranteed symmetric)
            // loop over rows
            for i in 0..<3 {
                // loop over on and above diagonal columns
                for j in i..<3 {
                    trinvW[i, j] = 0.0
                    // accumulate the matrix product
                    for k in 0..<3 {
                        trinvW[i, j] += matB[i][k] * matB[j][k]
                    }
                    // copy to below diagonal element
                    trinvW[j, i] = trinvW[i, j]
                }
            }
        }
    }

    // MARK: - Quality
    struct Quality {
        private static let kNumElements = 100

        var count = 0
        var sphereDist: [Int]
        var sphereData: [Vector3]
        var sphereIdeal: [Vector3]

        private var gapsBuffer: Scalar?
        private var varianceBuffer: Scalar?
        private var wobbleBuffer: Scalar?

        var magnitude: [Scalar]

        init() {
            sphereDist = [Int](repeating: 0, count: Quality.kNumElements)
            sphereData = [Vector3](repeating: Vector3.zero, count: Quality.kNumElements)

            // SphereIdeal
            sphereIdeal = [Vector3]()
            sphereIdeal.append(Vector3.zero)
            for i in 1...15 {
                let longitude: Float = (Float(i-1) + 0.5) * (Float.pi * 2.0 / 15.0)
                let x = cosf(longitude) * cosf(1.05911) * -1
                let y = sinf(longitude) * cosf(1.05911) * -1
                let z = sinf(1.05911)
                sphereIdeal.append(Vector3(x, y, z))
            }
            for i in 16...49 {
                let longitude: Float = (Float(i-16) + 0.5) * (Float.pi * 2.0 / 34.0)
                let x = cosf(longitude) * cosf(0.37388) * -1
                let y = sinf(longitude) * cosf(0.37388) * -1
                let z = sinf(0.37388)
                sphereIdeal.append(Vector3(x, y, z))
            }
            for i in 50...83 {
                let longitude: Float = (Float(i-50) + 0.5) * (Float.pi * 2.0 / 34.0)
                let x = cosf(longitude) * cosf(0.37388) * -1
                let y = sinf(longitude) * cosf(0.37388) * -1
                let z = sinf(-0.37388)
                sphereIdeal.append(Vector3(x, y, z))
            }
            for i in 84...98 {
                let longitude: Float = (Float(i-1) + 0.5) * (Float.pi * 2.0 / 15.0)
                let x = cosf(longitude) * cosf(1.05911) * -1
                let y = sinf(longitude) * cosf(1.05911) * -1
                let z = sinf(-1.05911)
                sphereIdeal.append(Vector3(x, y, z))
            }
            sphereIdeal.append(-Vector3.z)

            //
            magnitude = [Scalar](repeating: 0, count: Calibration.MagCalibration.kMagBufferSize)
        }

        mutating func reset() {
            count = 0
            sphereDist = [Int](repeating: 0, count: Quality.kNumElements)
            sphereData = [Vector3](repeating: Vector3.zero, count: Quality.kNumElements)

            gapsBuffer = nil
            varianceBuffer = nil
            wobbleBuffer = nil
        }

        // How many surface gaps
        mutating func surfaceGapError() -> Scalar {
            // Check if cached
            guard gapsBuffer == nil else {
                return gapsBuffer!
            }

            // Compute
            var error: Scalar = 0

            for i in 0..<100 {
                let num = sphereDist[i]
                if num == 0 {
                    error += 1.0
                } else if num == 1 {
                    error += 0.2
                } else if num == 2 {
                    error += 0.01
                }
            }

            gapsBuffer = error
            return gapsBuffer!
        }

        mutating func magnitudeVarianceError() -> Scalar {
            // Check if cached
            guard varianceBuffer == nil else {
                return varianceBuffer!
            }

            // Compute
            let sum = magnitude.reduce(0, {$0 + $1})
            let mean: Scalar = sum / Scalar(count)
            var variance: Scalar = 0
            for i in 0..<count {
                let diff = magnitude[i] - mean
                variance = diff * diff
            }
            variance = variance / Scalar(count)

            varianceBuffer = sqrt(variance) / mean * 100.0
            return varianceBuffer!
        }

        mutating func wobbleError() -> Scalar {
            // Check if cached
            guard wobbleBuffer == nil else {
                return wobbleBuffer!
            }

            // Compute
            let sum = magnitude.reduce(0, {$0 + $1})
            let radius = sum / Scalar(count)

            var n = 0
            var offset = Vector3.zero
            for (i, dist) in sphereDist.enumerated() {
                if dist > 0 {
                    let data = sphereData[i] / Scalar(dist)
                    let ideal = sphereIdeal[i] * Scalar(radius)
                    offset = offset + (data - ideal)
                    n += 1
                }
            }

            guard n > 0 else { return 100 }

            offset = offset / Scalar(n)

            wobbleBuffer = offset.length / radius * 100
            return wobbleBuffer!
        }

        mutating func update(point: Vector3) {
            magnitude[count] = point.length
            let region = sphereRegion(point: point)
            sphereDist[region] = sphereDist[region] + 1
            sphereData[region] = sphereData[region] + point
            count = count + 1

            gapsBuffer = nil
            varianceBuffer = nil
            wobbleBuffer = nil
        }

        private func sphereRegion(point: Vector3) -> Int {
            let longitude = atan2f(point.y, point.x) + Float.pi
            let latitude = Float.halfPi - atan2f(sqrtf(point.x * point.x + point.y * point.y), point.z)

            // https://etna.mcs.kent.edu/vol.25.2006/pp309-327.dir/pp309-327.html
            var region: Int
            if latitude > 1.37046 {
                region = 0
            } else if latitude < -1.37046 {
                region = 99
            } else if latitude > 0.74776 || latitude < -0.74776 {
                region = Int(floorf(longitude * (15.0 / Float.twoPi)))
                region = max(0, min(region, 14))
                if latitude > 0 {
                    region += 1
                } else {
                    region += 84
                }
            } else {
                region = Int(floorf(longitude * (34.0 / Float.twoPi)))
                region = max(0, min(region, 33))
                if latitude >= 0 {
                    region += 16
                } else {
                    region += 50
                }

            }

            return region
        }
    }
}

// MARK: - Fusion
extension Calibration {
    func fusionInit() {
        mahonyInit()
    }

    func fusionUpdate(accel: AccelSensor, mag: MagSensor, gyro: GyroSensor, magCal: MagCalibration) {
        let factor = Float.pi / 180

        for i in 0..<Calibration.kOversampleRatio {
            let g = gyro.ypFast[i] * factor
            mahonyUpdate(gyro: g, accel: accel.gp, mag: mag.bc)
        }
    }

    func fusionRead() -> Quaternion {
        return mahony.q
    }
}
