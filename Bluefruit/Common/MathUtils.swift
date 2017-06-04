//
//  MathUtils.swift
//  Calibration
//
//  Created by Antonio García on 04/11/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

// Fast inverse square-root
// See: http://en.wikipedia.org/wiki/Fast_inverse_square_root
// 

func invSqrt(_ x: Float) -> Float {
    let halfx = 0.5 * x
    var i = x.bitPattern
    i = 0x5f3759df - (i >> 1)
    var y = Float(bitPattern: i)
    y = y * (1.5 - (halfx * y * y))
    return y
}

// Special version used on Mahony
func invSqrtMahony(_ x: Float) -> Float {
    let halfx = 0.5 * x
    var i = x.bitPattern
    i = 0x5f375a86 - (i >> 1)
    var y = Float(bitPattern: i)
    y = y * (1.5 - (halfx * y * y))
    y = y * (1.5 - (halfx * y * y))
    y = y * (1.5 - (halfx * y * y))
    return y
}

// function sets the matrix A to the identity matrix
func fmatrixAeqI(_ a: inout [[Scalar]], numRowsColumns rc: Int) {
    // rc = rows and columns in A

    for i in 0..<rc {
        for j in 0..<rc {
            a[i][j] = 0.0
        }
        a[i][i] = 1.0
    }
}

// function computes all eigenvalues and eigenvectors of a real symmetric matrix A[0..n-1][0..n-1]
// stored in the top left of a 10x10 array A[10][10]
// A[][] is changed on output.
// eigval[0..n-1] returns the eigenvalues of A[][].
// eigvec[0..n-1][0..n-1] returns the normalized eigenvectors of A[][]
// the eigenvectors are not sorted by value
func eigencompute(_ a: inout [[Scalar]], eigenValues eigval: inout [Scalar], eigenVectors eigvec: inout [[Scalar]], size n: Int) {
    // maximum number of iterations to achieve convergence: in practice 6 is typical
    let kNIterations = 15

    // initialize eigenvectors matrix and eigenvalues array
    for ir in 0..<n {
        // loop over all columns
        for ic in 0..<n {
            // set on diagonal and off-diagonal elements to zero
            eigvec[ir][ic] = 0.0
        }

        // correct the diagonal elements to 1.0
        eigvec[ir][ir] = 1.0

        // initialize the array of eigenvalues to the diagonal elements of m
        eigval[ir] = a[ir][ir]
    }

    // initialize the counter and loop until converged or NITERATIONS reached
    var ctr = 0                 // timeout ctr for number of passes of the algorithm
    var residue: Scalar = 0     // residue from remaining non-zero above diagonal terms
    repeat {
        // compute the absolute value of the above diagonal elements as exit criterion
        residue = 0.0
        // loop over rows excluding last row
        for ir in 0..<n-1 {
            // loop over above diagonal columns
            for ic in ir+1..<n {
                // accumulate the residual off diagonal terms which are being driven to zero
                residue += fabs(a[ir][ic])
            }
        }

        // check if we still have work to do
        if residue > 0.0 {
            // loop over all rows with the exception of the last row (since only rotating above diagonal elements)
            for ir in 0..<n-1 {
                // loop over columns ic (where ic is always greater than ir since above diagonal)
                for ic in ir+1..<n {
                    // only continue with this element if the element is non-zero
                    if fabs(a[ir][ic]) > 0.0 {
                        // calculate cot(2*phi) where phi is the Jacobi rotation angle
                        let cot2phi: Scalar = 0.5 * (eigval[ic] - eigval[ir]) / a[ir][ic]

                        // calculate tan(phi) correcting sign to ensure the smaller solution is used
                        var tanphi: Scalar = 1.0 / (fabs(cot2phi) + sqrtf(1.0 + cot2phi * cot2phi))
                        if cot2phi < 0.0 {
                            tanphi = -tanphi
                        }

                        // calculate the sine and cosine of the Jacobi rotation angle phi
                        let cosphi: Scalar = 1.0 / sqrtf(1.0 + tanphi * tanphi)
                        let sinphi: Scalar = tanphi * cosphi

                        // calculate tan(phi/2)
                        let tanhalfphi: Scalar = sinphi / (1.0 + cosphi)

                        // set tmp = tan(phi) times current matrix element used in update of leading diagonal elements
                        var ftmp = tanphi * a[ir][ic]

                        // apply the jacobi rotation to diagonal elements [ir][ir] and [ic][ic] stored in the eigenvalue array
                        // eigval[ir] = eigval[ir] - tan(phi) *  A[ir][ic]
                        eigval[ir] -= ftmp
                        // eigval[ic] = eigval[ic] + tan(phi) * A[ir][ic]
                        eigval[ic] += ftmp

                        // by definition, applying the jacobi rotation on element ir, ic results in 0.0
                        a[ir][ic] = 0.0

                        // apply the jacobi rotation to all elements of the eigenvector matrix
                        for j in 0..<n {
                            // store eigvec[j][ir]
                            ftmp = eigvec[j][ir]
                            // eigvec[j][ir] = eigvec[j][ir] - sin(phi) * (eigvec[j][ic] + tan(phi/2) * eigvec[j][ir])
                            eigvec[j][ir] = ftmp - sinphi * (eigvec[j][ic] + tanhalfphi * ftmp)
                            // eigvec[j][ic] = eigvec[j][ic] + sin(phi) * (eigvec[j][ir] - tan(phi/2) * eigvec[j][ic])
                            eigvec[j][ic] = eigvec[j][ic] + sinphi * (ftmp - tanhalfphi * eigvec[j][ic])
                        }

                        // apply the jacobi rotation only to those elements of matrix m that can change
                        if 0 <= ir-1 {          //  check bounds
                            for j in 0...ir-1 {
                                // store A[j][ir]
                                ftmp = a[j][ir]
                                // A[j][ir] = A[j][ir] - sin(phi) * (A[j][ic] + tan(phi/2) * A[j][ir])
                                a[j][ir] = ftmp - sinphi * (a[j][ic] + tanhalfphi * ftmp)
                                // A[j][ic] = A[j][ic] + sin(phi) * (A[j][ir] - tan(phi/2) * A[j][ic])
                                a[j][ic] = a[j][ic] + sinphi * (ftmp - tanhalfphi * a[j][ic])
                            }
                        }
                        if ir+1 <= ic-1 {      //  check bounds
                            for j in ir+1...ic-1 {
                                // store A[ir][j]
                                ftmp = a[ir][j]
                                // A[ir][j] = A[ir][j] - sin(phi) * (A[j][ic] + tan(phi/2) * A[ir][j])
                                a[ir][j] = ftmp - sinphi * (a[j][ic] + tanhalfphi * ftmp)
                                // A[j][ic] = A[j][ic] + sin(phi) * (A[ir][j] - tan(phi/2) * A[j][ic])
                                a[j][ic] = a[j][ic] + sinphi * (ftmp - tanhalfphi * a[j][ic])
                            }
                        }
                        for j in ic+1..<n {
                            // store A[ir][j]
                            ftmp = a[ir][j]
                            // A[ir][j] = A[ir][j] - sin(phi) * (A[ic][j] + tan(phi/2) * A[ir][j])
                            a[ir][j] = ftmp - sinphi * (a[ic][j] + tanhalfphi * ftmp)
                            // A[ic][j] = A[ic][j] + sin(phi) * (A[ir][j] - tan(phi/2) * A[ic][j])
                            a[ic][j] = a[ic][j] + sinphi * (ftmp - tanhalfphi * a[ic][j])

                        }
                    }   // end of test for matrix element already zero
                }   // end of loop over columns
            }   // end of loop over rows
        }  // end of test for non-zero residue
        ctr += 1
    } while residue > 0.0 && ctr <= kNIterations // end of main loop
}

// function uses Gauss-Jordan elimination to compute the inverse of matrix A in situ
// on exit, A is replaced with its inverse
func fmatrixAeqInvA(_ a: inout [[Scalar]], size: Int) {
    var iColInd = [Int](repeating: 0, count: size)
    var iRowInd = [Int](repeating: 0, count: size)
    var iPivot = [Int](repeating: 0, count: size)
    var iPivotRow = 0
    var largest: Scalar = 0     // largest element used for pivoting
    var iPivotCol = 0           // row and column of pivot element

    /*
    float scaling;					// scaling factor in pivoting
    float recippiv;					// reciprocal of pivot element
    float ftmp;						// temporary variable used in swaps
    int8_t i, j, k, l, m;			// index counters
    int8_t iPivotRow, iPivotCol;	// row and column of pivot element
    */

    // main loop i over the dimensions of the square matrix A
    for i in 0..<size {
        // zero the largest element found for pivoting
        largest = 0
        // loop over candidate rows j
        for j in 0..<size {
            // check if row j has been previously pivoted
            if iPivot[j] != 1 {
                // loop over candidate columns k
                for k in 0..<size {
                    // check if column k has previously been pivoted
                    if iPivot[k] == 0 {
                        // check if the pivot element is the largest found so far
                        if fabs(a[j][k]) >= largest {
                            // and store this location as the current best candidate for pivoting
                            iPivotRow = j
                            iPivotCol = k
                            largest = fabs(a[iPivotRow][iPivotCol])
                        }
                    } else if iPivot[k] > 1 {
                        // zero determinant situation: exit with identity matrix
                        fmatrixAeqI(&a, numRowsColumns: size)
                        return
                    }
                }
            }
        }
        // increment the entry in iPivot to denote it has been selected for pivoting
        iPivot[iPivotCol] = iPivot[iPivotCol] + 1

        // check the pivot rows iPivotRow and iPivotCol are not the same before swapping
        if iPivotRow != iPivotCol {
            // loop over columns l
            for l in 0..<size {
                // and swap all elements of rows iPivotRow and iPivotCol
                let ftmp = a[iPivotRow][l]
                a[iPivotRow][l] = a[iPivotCol][l]
                a[iPivotCol][l] = ftmp
            }
        }

        // record that on the i-th iteration rows iPivotRow and iPivotCol were swapped
        iRowInd[i] = iPivotRow
        iColInd[i] = iPivotCol

        // check for zero on-diagonal element (singular matrix) and return with identity matrix if detected
        if a[iPivotCol][iPivotCol] == 0.0 {
            // zero determinant situation: exit with identity matrix
            fmatrixAeqI(&a, numRowsColumns: size)
            return
        }

        // calculate the reciprocal of the pivot element knowing it's non-zero
        let recippiv: Scalar = 1.0 / a[iPivotCol][iPivotCol]
        // by definition, the diagonal element normalizes to 1
        a[iPivotCol][iPivotCol] = 1.0
        // multiply all of row iPivotCol by the reciprocal of the pivot element including the diagonal element
        // the diagonal element A[iPivotCol][iPivotCol] now has value equal to the reciprocal of its previous value
        for l in 0..<size {
            a[iPivotCol][l] *= recippiv
        }
        // loop over all rows m of A
        for m in 0..<size {
            if m != iPivotCol {
                // scaling factor for this row m is in column iPivotCol
                let scaling = a[m][iPivotCol]
                // zero this element
                a[m][iPivotCol] = 0
                // loop over all columns l of A and perform elimination
                for l in 0..<size {
                    a[m][l] -= a[iPivotCol][l] * scaling
                }
            }
        }
    } // end of loop i over the matrix dimensions

    // finally, loop in inverse order to apply the missing column swaps
    for l in stride(from: size-1, through: 0, by: -1) {
        // set i and j to the two columns to be swapped
        let i = iRowInd[l]
        let j = iColInd[l]

        // check that the two columns i and j to be swapped are not the same
        if i != j {
            // loop over all rows k to swap columns i and j of A
            for k in 0..<size {
                let ftmp = a[k][i]
                a[k][i] = a[k][j]
                a[k][j] = ftmp
            }
        }
    }
}

extension FloatingPoint {
    var degreesToRadians: Self { return self * .pi / 180 }
    var radiansToDegrees: Self { return self * 180 / .pi }
}
