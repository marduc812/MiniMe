//
//  AboutIconEyeGeometryTests.swift
//  MiniMeTests
//

import Testing
import CoreGraphics
@testable import MiniMe

struct AboutIconEyeGeometryTests {

    private let center = CGPoint(x: 100, y: 100)
    private let maxShift: CGFloat = 3

    @Test func noPointerLeavesPupilsCentered() {
        let offset = AboutIconEyeGeometry.pupilOffset(
            pointer: nil,
            iconCenter: center,
            maxShift: maxShift
        )
        #expect(offset == .zero)
    }

    @Test func pointerFarToTheRightPushesPupilsFullyRight() {
        let offset = AboutIconEyeGeometry.pupilOffset(
            pointer: CGPoint(x: 900, y: 100),
            iconCenter: center,
            maxShift: maxShift
        )
        #expect(abs(offset.width - maxShift) < 0.0001)
        #expect(abs(offset.height) < 0.0001)
    }

    @Test func pointerFarAboveIsNotInverted() {
        // A negative height means "up" in SwiftUI's coordinate space, matching a
        // pointer whose y sits above the icon.
        let offset = AboutIconEyeGeometry.pupilOffset(
            pointer: CGPoint(x: 100, y: -400),
            iconCenter: center,
            maxShift: maxShift
        )
        #expect(abs(offset.height + maxShift) < 0.0001)
        #expect(abs(offset.width) < 0.0001)
    }

    @Test func diagonalPointerIsNormalisedRatherThanOvershooting() {
        // Naive per-axis clamping would put both components at maxShift, giving a
        // magnitude of maxShift * sqrt(2) and letting the pupils escape the eye.
        let offset = AboutIconEyeGeometry.pupilOffset(
            pointer: CGPoint(x: 900, y: 900),
            iconCenter: center,
            maxShift: maxShift
        )
        let magnitude = (offset.width * offset.width + offset.height * offset.height).squareRoot()
        #expect(abs(magnitude - maxShift) < 0.0001)
        #expect(abs(offset.width - offset.height) < 0.0001)
    }

    @Test func nearbyPointerMovesPupilsProportionally() {
        // Within the falloff radius the pupils should lag behind the pointer so
        // small cursor moves read as a glance, not a snap to the edge.
        let offset = AboutIconEyeGeometry.pupilOffset(
            pointer: CGPoint(x: 130, y: 100),
            iconCenter: center,
            maxShift: maxShift
        )
        #expect(offset.width > 0)
        #expect(offset.width < maxShift)
    }

    @Test func pointerAtTheIconCentreLeavesPupilsCentered() {
        let offset = AboutIconEyeGeometry.pupilOffset(
            pointer: center,
            iconCenter: center,
            maxShift: maxShift
        )
        #expect(offset == .zero)
    }

    @Test func offsetNeverExceedsMaxShift() {
        let probes = [
            CGPoint(x: -50, y: 40),
            CGPoint(x: 260, y: -180),
            CGPoint(x: 101, y: 99),
            CGPoint(x: 5000, y: -5000)
        ]
        for probe in probes {
            let offset = AboutIconEyeGeometry.pupilOffset(
                pointer: probe,
                iconCenter: center,
                maxShift: maxShift
            )
            let magnitude = (offset.width * offset.width + offset.height * offset.height).squareRoot()
            #expect(magnitude <= maxShift + 0.0001)
        }
    }
}
