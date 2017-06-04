//
//  VectorMath+Adafruit.swift
//  Calibration
//
//  Created by Antonio García on 04/11/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

extension Vector3 {
    subscript(index: Int) -> Scalar {
        get {
            switch index {
            case 0: return x
            case 1: return y
            case 2: return z
            default: assert(false, "Index out of range")
            }

            return Scalar.nan
        }
        set {
            switch index {
            case 0: x = newValue
            case 1: y = newValue
            case 2: z = newValue
            default: assert(false, "Index out of range")
            }
        }
    }
}

extension Matrix3 {
    init(value v: Scalar) {
        self.init(
            v, v, v,
            v, v, v,
            v, v, v
        )
    }

    subscript(_ row: Int, _ column: Int) -> Scalar {
        get {
            switch row {
            case 0:
                switch column {
                case 0: return m11
                case 1: return m12
                case 2: return m13
                default: assert(false, "Column out of range")
                }
            case 1:
                switch column {
                case 0: return m21
                case 1: return m22
                case 2: return m23
                default: assert(false, "Column out of range")
                }
            case 2:
                switch column {
                case 0: return m31
                case 1: return m32
                case 2: return m33
                default: assert(false, "Column out of range")
                }
            default: assert(false, "Row out of range")
            }

            return Scalar.nan
        }
        set {
            switch row {
            case 0:
                switch column {
                case 0: m11 = newValue
                case 1: m12 = newValue
                case 2: m13 = newValue
                default: assert(false, "Column out of range")
                }
            case 1:
                switch column {
                case 0: m21 = newValue
                case 1: m22 = newValue
                case 2: m23 = newValue
                default: assert(false, "Column out of range")
                }
            case 2:
                switch column {
                case 0: m31 = newValue
                case 1: m32 = newValue
                case 2: m33 = newValue
                default: assert(false, "Column out of range")
                }
            default: assert(false, "Row out of range")
            }

        }
    }

    public static prefix func -(m: Matrix3) -> Matrix3 {
        return Matrix3(
            -m.m11, -m.m12, -m.m13,
            -m.m21, -m.m22, -m.m23,
            -m.m31, -m.m32, -m.m33
        )
    }

    public var symmetricInverse: Matrix3 {
        // calculate useful products
        let fB11B22mB12B12 = m22 * m33 - m23 * m23
        let fB12B02mB01B22 = m23 * m13 - m12 * m33
        let fB01B12mB11B02 = m12 * m23 - m22 * m13

        // set ftmp to the determinant of the input matrix
        var ftmp = m11 * fB11B22mB12B12 + m12 * fB12B02mB01B22 + m13 * fB01B12mB11B02

        // set A to the inverse of B for any determinant except zero
        if ftmp != 0.0 {
            ftmp = 1.0 / ftmp

            let am11 = fB11B22mB12B12 * ftmp
            let am12 = fB12B02mB01B22 * ftmp
            let am21 = am12
            let am13 = fB01B12mB11B02 * ftmp
            let am31 = am13
            let am22 = (m11 * m33 - m13 * m13) * ftmp
            let am23 = (m13 * m12 - m11 * m23) * ftmp
            let am32 = am23
            let am33 = (m11 * m22 - m12 * m12) * ftmp

            return Matrix3(am11, am12, am13, am21, am22, am23, am31, am32, am33)

        } else {
            // provide the identity matrix if the determinant is zero
            return Matrix3.identity
        }

    }
}
