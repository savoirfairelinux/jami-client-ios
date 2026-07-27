/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import XCTest
import AVFoundation
import UIKit
@testable import Ring

final class CameraOrientationResolutionTests: XCTestCase {

    private func input(_ device: UIDeviceOrientation,
                       _ interface: UIInterfaceOrientation) -> DeviceOrientationInput {
        return DeviceOrientationInput(device: device, interface: interface)
    }

    func testValidDeviceOrientationWins() {
        XCTAssertEqual(AVCaptureVideoOrientation.resolve(input(.portrait, .landscapeLeft)),
                       .portrait)
        XCTAssertEqual(AVCaptureVideoOrientation.resolve(input(.landscapeLeft, .portrait)),
                       .landscapeLeft)
        XCTAssertEqual(AVCaptureVideoOrientation.resolve(input(.landscapeRight, .portrait)),
                       .landscapeRight)
        XCTAssertEqual(AVCaptureVideoOrientation.resolve(input(.portraitUpsideDown, .portrait)),
                       .portraitUpsideDown)
    }

    func testFlatDeviceFallsBackToInterface() {
        XCTAssertEqual(AVCaptureVideoOrientation.resolve(input(.faceUp, .portrait)), .portrait)
        XCTAssertEqual(AVCaptureVideoOrientation.resolve(input(.faceDown, .portrait)), .portrait)
        XCTAssertEqual(AVCaptureVideoOrientation.resolve(input(.unknown, .portraitUpsideDown)),
                       .portraitUpsideDown)
    }

    func testInterfaceFallbackInvertsLandscape() {
        XCTAssertEqual(AVCaptureVideoOrientation.resolve(input(.faceUp, .landscapeLeft)),
                       .landscapeRight)
        XCTAssertEqual(AVCaptureVideoOrientation.resolve(input(.faceUp, .landscapeRight)),
                       .landscapeLeft)
    }

    func testNoUsableOrientationKeepsLastStableState() {
        XCTAssertNil(AVCaptureVideoOrientation.resolve(input(.faceUp, .unknown)))
        XCTAssertNil(AVCaptureVideoOrientation.resolve(input(.unknown, .unknown)))
    }
}

final class CameraOrientationStateTests: XCTestCase {

    private struct LinearTransform {
        let componentA: CGFloat
        let componentB: CGFloat
        let componentC: CGFloat
        let componentD: CGFloat
    }

    private struct Expectation {
        let orientation: AVCaptureVideoOrientation
        let cameraPosition: AVCaptureDevice.Position
        let transform: LinearTransform
        let imageOrientation: UIImage.Orientation
        let outgoingAngle: Int
    }

    private static let table: [Expectation] = [
        Expectation(orientation: .portrait, cameraPosition: .front,
                    transform: LinearTransform(componentA: 0, componentB: 1,
                                               componentC: 1, componentD: 0),
                    imageOrientation: .leftMirrored,
                    outgoingAngle: 270),
        Expectation(orientation: .portrait, cameraPosition: .back,
                    transform: LinearTransform(componentA: 0, componentB: -1,
                                               componentC: 1, componentD: 0),
                    imageOrientation: .left,
                    outgoingAngle: 90),
        Expectation(orientation: .portraitUpsideDown, cameraPosition: .front,
                    transform: LinearTransform(componentA: 0, componentB: -1,
                                               componentC: -1, componentD: 0),
                    imageOrientation: .rightMirrored,
                    outgoingAngle: 90),
        Expectation(orientation: .portraitUpsideDown, cameraPosition: .back,
                    transform: LinearTransform(componentA: 0, componentB: 1,
                                               componentC: -1, componentD: 0),
                    imageOrientation: .right,
                    outgoingAngle: 270),
        Expectation(orientation: .landscapeRight, cameraPosition: .front,
                    transform: LinearTransform(componentA: -1, componentB: 0,
                                               componentC: 0, componentD: 1),
                    imageOrientation: .upMirrored,
                    outgoingAngle: 0),
        Expectation(orientation: .landscapeRight, cameraPosition: .back,
                    transform: LinearTransform(componentA: 1, componentB: 0,
                                               componentC: 0, componentD: 1),
                    imageOrientation: .up,
                    outgoingAngle: 0),
        Expectation(orientation: .landscapeLeft, cameraPosition: .front,
                    transform: LinearTransform(componentA: 1, componentB: 0,
                                               componentC: 0, componentD: -1),
                    imageOrientation: .downMirrored,
                    outgoingAngle: 180),
        Expectation(orientation: .landscapeLeft, cameraPosition: .back,
                    transform: LinearTransform(componentA: -1, componentB: 0,
                                               componentC: 0, componentD: -1),
                    imageOrientation: .down,
                    outgoingAngle: 180)
    ]

    func testEveryOrientationAndCameraProducesItsExactState() {
        for expected in Self.table {
            let state = CameraOrientationState.make(orientation: expected.orientation,
                                                    cameraPosition: expected.cameraPosition)
            let label = "\(expected.orientation.rawValue) \(expected.cameraPosition.rawValue)"

            assertTransform(state.layerTransform, equals: expected.transform, label: label)
            XCTAssertEqual(state.imageOrientation, expected.imageOrientation, label)
            XCTAssertEqual(state.outgoingAngle, expected.outgoingAngle, label)
            XCTAssertEqual(state.orientation, expected.orientation, label)
            XCTAssertEqual(state.cameraPosition, expected.cameraPosition, label)
        }
    }

    private func assertTransform(_ transform: CGAffineTransform,
                                 equals expected: LinearTransform,
                                 label: String,
                                 file: StaticString = #file, line: UInt = #line) {
        let tolerance: CGFloat = 0.0001
        XCTAssertEqual(transform.a, expected.componentA, accuracy: tolerance, "a — " + label,
                       file: file, line: line)
        XCTAssertEqual(transform.b, expected.componentB, accuracy: tolerance, "b — " + label,
                       file: file, line: line)
        XCTAssertEqual(transform.c, expected.componentC, accuracy: tolerance, "c — " + label,
                       file: file, line: line)
        XCTAssertEqual(transform.d, expected.componentD, accuracy: tolerance, "d — " + label,
                       file: file, line: line)
        XCTAssertEqual(transform.tx, 0, accuracy: tolerance, "tx — " + label,
                       file: file, line: line)
        XCTAssertEqual(transform.ty, 0, accuracy: tolerance, "ty — " + label,
                       file: file, line: line)
    }
}
