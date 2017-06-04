//
//  Calibration+Mahony.swift
//  Calibration
//
//  Created by Antonio García on 04/11/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//
//  Base code: https://github.com/PaulStoffregen/MotionCal

// Based on MahonyAHRS.c
//==============================================================================================
// MahonyAHRS.c
//==============================================================================================
//
// Madgwick's implementation of Mayhony's AHRS algorithm.
// See: http://www.x-io.co.uk/open-source-imu-and-ahrs-algorithms/
//
// From the x-io website "Open-source resources available on this website are
// provided under the GNU General Public Licence unless an alternative licence
// is provided in source."
//
// Date			Author			Notes
// 29/09/2011	SOH Madgwick    Initial release
// 02/10/2011	SOH Madgwick	Optimised for reduced CPU load
//
// Algorithm paper:
// http://ieeexplore.ieee.org/xpl/login.jsp?tp=&arnumber=4608934&url=http%3A%2F%2Fieeexplore.ieee.org%2Fstamp%2Fstamp.jsp%3Ftp%3D%26arnumber%3D4608934
//
//==============================================================================================

import Foundation

extension Calibration {
    func mahonyInit() {
        struct Holder {
            static var first = true
        }

        mahony.twoKp = MahonyData.kTwoKpDef     // 2 * proportional gain (Kp)
        mahony.twoKi = MahonyData.kTwoKiDef     // 2 * integral gain (Ki)

        if Holder.first {
            mahony.q = .identity
            Holder.first = false
        }

        mahony.resetNextUpdate = true
        mahony.integralFb = .zero
    }

    func mahonyUpdate(gyro: Vector3, accel: Vector3, mag: Vector3) {
        // Use IMU algorithm if magnetometer measurement invalid
        // (avoids NaN in magnetometer normalisation)

        var m = mag
        var a = accel
        var g = gyro
        guard m.x != 0.0 || m.y != 0.0 || m.z != 0.0 else {
            mahonyUpdateIMU(gyro: g, accel: a)
            return
        }

        var recipNorm: Scalar

        // Compute feedback only if accelerometer measurement valid
        // (avoids NaN in accelerometer normalisation)
        if !((a.x == 0.0) && (a.y == 0.0) && (a.z == 0.0)) {

            // Normalise accelerometer measurement
            recipNorm = invSqrtMahony(a.lengthSquared)
            a = a * recipNorm

            // Normalise magnetometer measurement
            recipNorm = invSqrtMahony(m.lengthSquared)
            m = m * recipNorm

            // Auxiliary variables to avoid repeated arithmetic
            let q0q0 = mahony.q.w * mahony.q.w
            let q0q1 = mahony.q.w * mahony.q.x
            let q0q2 = mahony.q.w * mahony.q.y
            let q0q3 = mahony.q.w * mahony.q.z
            let q1q1 = mahony.q.x * mahony.q.x
            let q1q2 = mahony.q.x * mahony.q.y
            let q1q3 = mahony.q.x * mahony.q.z
            let q2q2 = mahony.q.y * mahony.q.y
            let q2q3 = mahony.q.y * mahony.q.z
            let q3q3 = mahony.q.z * mahony.q.z

            // Reference direction of Earth's magnetic field
            let hx = 2.0 * (m.x * (0.5 - q2q2 - q3q3) + m.y * (q1q2 - q0q3) + m.z * (q1q3 + q0q2))
            let hy = 2.0 * (m.x * (q1q2 + q0q3) + m.y * (0.5 - q1q1 - q3q3) + m.z * (q2q3 - q0q1))
            let bx = sqrtf(hx * hx + hy * hy)
            let bz = 2.0 * (m.x * (q1q3 - q0q2) + m.y * (q2q3 + q0q1) + m.z * (0.5 - q1q1 - q2q2))

            // Estimated direction of gravity and magnetic field
            let halfvx = q1q3 - q0q2
            let halfvy = q0q1 + q2q3
            let halfvz = q0q0 - 0.5 + q3q3
            let halfwx = bx * (0.5 - q2q2 - q3q3) + bz * (q1q3 - q0q2)
            let halfwy = bx * (q1q2 - q0q3) + bz * (q0q1 + q2q3)
            let halfwz = bx * (q0q2 + q1q3) + bz * (0.5 - q1q1 - q2q2)

            // Error is sum of cross product between estimated direction
            // and measured direction of field vectors
            let halfex = (a.y * halfvz - a.z * halfvy) + (m.y * halfwz - m.z * halfwy)
            let halfey = (a.z * halfvx - a.x * halfvz) + (m.z * halfwx - m.x * halfwz)
            let halfez = (a.x * halfvy - a.y * halfvx) + (m.x * halfwy - m.y * halfwx)

            // Compute and apply integral feedback if enabled
            if mahony.twoKi > 0.0 {
                // integral error scaled by Ki
                mahony.integralFb.x += mahony.twoKi * halfex * MahonyData.kInvSampleRate
                mahony.integralFb.y += mahony.twoKi * halfey * MahonyData.kInvSampleRate
                mahony.integralFb.z += mahony.twoKi * halfez * MahonyData.kInvSampleRate

                g.x += mahony.integralFb.x      // apply integral feedback
                g.y += mahony.integralFb.y
                g.z += mahony.integralFb.z

            } else {
                mahony.integralFb = .zero       // prevent integral windup
            }

             //printf("err =  %.3f, %.3f, %.3f\n", halfex, halfey, halfez);

            // Apply proportional feedback
            if mahony.resetNextUpdate {
                g.x += 2.0 * halfex
                g.y += 2.0 * halfey
                g.z += 2.0 * halfez
                mahony.resetNextUpdate = false
            } else {
                g.x += mahony.twoKp * halfex
                g.y += mahony.twoKp * halfey
                g.z += mahony.twoKp * halfez
            }
        }

        // Integrate rate of change of quaternion
        g.x *= 0.5 * MahonyData.kInvSampleRate		// pre-multiply common factors
        g.y *= 0.5 * MahonyData.kInvSampleRate
        g.z *= 0.5 * MahonyData.kInvSampleRate

        let qa = mahony.q.w
        let qb = mahony.q.x
        let qc = mahony.q.y
        mahony.q.w += -qb * g.x - qc * g.y - mahony.q.z * g.z
        mahony.q.x += qa * g.x + qc * g.z - mahony.q.z * g.y
        mahony.q.y += qa * g.y - qb * g.z + mahony.q.z * g.x
        mahony.q.z += qa * g.z + qb * g.y - qc * g.x

        // Normalise quaternion
        recipNorm = invSqrtMahony(mahony.q.lengthSquared)
        mahony.q = mahony.q * recipNorm
    }

    func mahonyUpdateIMU(gyro: Vector3, accel: Vector3) {

        var a = accel
        var g = gyro

        var recipNorm: Scalar

        // Compute feedback only if accelerometer measurement valid
        // (avoids NaN in accelerometer normalisation)
        if !((a.x == 0.0) && (a.y == 0.0) && (a.z == 0.0)) {
            // Normalise accelerometer measurement
            recipNorm = invSqrtMahony(a.lengthSquared)
            a = a * recipNorm

            // Estimated direction of gravity and vector perpendicular to magnetic flux
            let halfvx = mahony.q.x * mahony.q.z - mahony.q.w * mahony.q.y
            let halfvy = mahony.q.w * mahony.q.x + mahony.q.y * mahony.q.z
            let halfvz = mahony.q.w * mahony.q.w - 0.5 + mahony.q.z * mahony.q.z

            // Error is sum of cross product between estimated and measured direction of gravity
            let halfex = a.y * halfvz - a.z * halfvy
            let halfey = a.z * halfvx - a.x * halfvz
            let halfez = a.x * halfvy - a.y * halfvx

            // Compute and apply integral feedback if enabled
            if mahony.twoKi > 0.0 {
                // integral error scaled by Ki
                mahony.integralFb.x += mahony.twoKi * halfex * MahonyData.kInvSampleRate
                mahony.integralFb.y += mahony.twoKi * halfey * MahonyData.kInvSampleRate
                mahony.integralFb.z += mahony.twoKi * halfez * MahonyData.kInvSampleRate

                g.x += mahony.integralFb.x      // apply integral feedback
                g.y += mahony.integralFb.y
                g.z += mahony.integralFb.z

            } else {
                mahony.integralFb = .zero       // prevent integral windup
            }

            // Apply proportional feedback
            g.x += mahony.twoKp * halfex
            g.y += mahony.twoKp * halfey
            g.z += mahony.twoKp * halfez
        }

        // Integrate rate of change of quaternion
        g.x *= 0.5 * MahonyData.kInvSampleRate		// pre-multiply common factors
        g.y *= 0.5 * MahonyData.kInvSampleRate
        g.z *= 0.5 * MahonyData.kInvSampleRate

        let qa = mahony.q.w
        let qb = mahony.q.x
        let qc = mahony.q.y
        mahony.q.w += -qb * g.x - qc * g.y - mahony.q.z * g.z
        mahony.q.x += qa * g.x + qc * g.z - mahony.q.z * g.y
        mahony.q.y += qa * g.y - qb * g.z + mahony.q.z * g.x
        mahony.q.z += qa * g.z + qb * g.y - qc * g.x

        // Normalise quaternion
        recipNorm = invSqrtMahony(mahony.q.lengthSquared)
        mahony.q = mahony.q * recipNorm
    }
}
