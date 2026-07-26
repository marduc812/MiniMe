//
//  ActiveScreenResolverTests.swift
//  MiniMeTests
//

import Testing
import Foundation
@testable import MiniMe

struct ActiveScreenResolverTests {

    // Built-in display at the origin, external display to its right and
    // vertically offset — the classic laptop-plus-monitor arrangement that
    // leaves dead coordinate space above the smaller screen.
    private let builtIn = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let external = CGRect(x: 1440, y: -300, width: 2560, height: 1440)

    private var frames: [CGRect] { [builtIn, external] }

    @Test func mouseInsideFirstScreenResolvesToIt() {
        let index = ActiveScreenResolver.screenIndex(
            mouseLocation: CGPoint(x: 700, y: 400),
            frames: frames
        )
        #expect(index == 0)
    }

    @Test func mouseInsideSecondScreenResolvesToIt() {
        let index = ActiveScreenResolver.screenIndex(
            mouseLocation: CGPoint(x: 2000, y: 500),
            frames: frames
        )
        #expect(index == 1)
    }

    @Test func mouseOnMaxEdgeStillResolvesToThatScreen() {
        // CGRect.contains excludes maxX/maxY, so a cursor pinned to the top-right
        // corner matches no frame. Nearest-by-distance must still pick screen 0.
        let index = ActiveScreenResolver.screenIndex(
            mouseLocation: CGPoint(x: builtIn.maxX - 1, y: builtIn.maxY),
            frames: frames
        )
        #expect(index == 0)
    }

    @Test func mouseInDeadSpaceResolvesToNearestScreen() {
        // Above the built-in display, left of the external one: inside neither.
        let index = ActiveScreenResolver.screenIndex(
            mouseLocation: CGPoint(x: 200, y: 1000),
            frames: frames
        )
        #expect(index == 0)
    }

    @Test func deadSpaceNearerTheExternalScreenResolvesToIt() {
        let index = ActiveScreenResolver.screenIndex(
            mouseLocation: CGPoint(x: 1430, y: 1200),
            frames: frames
        )
        #expect(index == 1)
    }

    @Test func singleScreenAlwaysResolvesToIndexZero() {
        let index = ActiveScreenResolver.screenIndex(
            mouseLocation: CGPoint(x: -5000, y: 9999),
            frames: [builtIn]
        )
        #expect(index == 0)
    }

    @Test func emptyScreenListReturnsNil() {
        let index = ActiveScreenResolver.screenIndex(
            mouseLocation: .zero,
            frames: []
        )
        #expect(index == nil)
    }

    // MARK: - Rect placement

    @Test func rectIsCenteredInVisibleFrame() {
        let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let rect = ActiveScreenResolver.centeredRect(
            size: CGSize(width: 460, height: 520),
            in: visible
        )
        #expect(rect.midX == visible.midX)
        #expect(rect.midY == visible.midY)
        #expect(rect.width == 460)
        #expect(rect.height == 520)
    }

    @Test func rectIsCenteredOnAnOffsetScreen() {
        let visible = CGRect(x: 1440, y: -300, width: 2560, height: 1400)
        let rect = ActiveScreenResolver.centeredRect(
            size: CGSize(width: 460, height: 520),
            in: visible
        )
        #expect(rect.midX == visible.midX)
        #expect(rect.midY == visible.midY)
    }

    @Test func oversizedRectIsClampedToTheScreen() {
        let visible = CGRect(x: 0, y: 0, width: 400, height: 300)
        let rect = ActiveScreenResolver.centeredRect(
            size: CGSize(width: 460, height: 520),
            in: visible
        )
        #expect(rect.width == 400)
        #expect(rect.height == 300)
        #expect(visible.contains(rect))
    }

    @Test func rectNeverExtendsBeyondVisibleFrame() {
        let visible = CGRect(x: 100, y: 50, width: 500, height: 540)
        let rect = ActiveScreenResolver.centeredRect(
            size: CGSize(width: 460, height: 520),
            in: visible
        )
        #expect(rect.minX >= visible.minX)
        #expect(rect.minY >= visible.minY)
        #expect(rect.maxX <= visible.maxX)
        #expect(rect.maxY <= visible.maxY)
    }
}
