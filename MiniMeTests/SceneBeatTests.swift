//
//  SceneBeatTests.swift
//  MiniMeTests
//

import Testing
@testable import MiniMe

struct SceneBeatTests {

    // MARK: - Wrapping

    @Test func elapsedTimeWrapsIntoTheUnitInterval() {
        let beat = SceneBeat(elapsed: 5, duration: 4)
        #expect(abs(beat.t - 0.25) < 0.0001)
    }

    @Test func elapsedTimeAtExactlyOneLoopIsBackAtTheStart() {
        let beat = SceneBeat(elapsed: 4, duration: 4)
        #expect(abs(beat.t) < 0.0001)
    }

    @Test func nonPositiveDurationDoesNotDivideByZero() {
        let beat = SceneBeat(elapsed: 3, duration: 0)
        #expect(beat.t == 0)
    }

    // MARK: - ramp

    @Test func rampIsZeroBeforeItsWindow() {
        #expect(SceneBeat(t: 0.1).ramp(0.4, 0.6) == 0)
    }

    @Test func rampIsOneAfterItsWindow() {
        #expect(SceneBeat(t: 0.9).ramp(0.4, 0.6) == 1)
    }

    @Test func rampIsAHalfAtTheMidpointOfItsWindow() {
        let value = SceneBeat(t: 0.5).ramp(0.4, 0.6)
        #expect(abs(value - 0.5) < 0.0001)
    }

    @Test func rampEasesRatherThanRunningLinear() {
        // Smoothstep at a quarter through the window is 0.15625, not 0.25.
        let value = SceneBeat(t: 0.45).ramp(0.4, 0.6)
        #expect(abs(value - 0.15625) < 0.0001)
    }

    @Test func rampRisesMonotonicallyAcrossItsWindow() {
        var previous = -1.0
        for step in 0...20 {
            let value = SceneBeat(t: Double(step) / 20).ramp(0.2, 0.8)
            #expect(value >= previous)
            previous = value
        }
    }

    @Test func rampWithAnEmptyWindowSnapsInsteadOfProducingNaN() {
        #expect(SceneBeat(t: 0.4).ramp(0.5, 0.5) == 0)
        #expect(SceneBeat(t: 0.6).ramp(0.5, 0.5) == 1)
    }

    // MARK: - pulse

    @Test func pulseIsZeroOutsideItsWindow() {
        #expect(SceneBeat(t: 0.05).pulse(0.2, 0.5, 0.8) == 0)
        #expect(SceneBeat(t: 0.95).pulse(0.2, 0.5, 0.8) == 0)
    }

    @Test func pulseReachesOneAtItsPeak() {
        #expect(SceneBeat(t: 0.5).pulse(0.2, 0.5, 0.8) == 1)
    }

    @Test func pulseRisesBeforeThePeakAndFallsAfterIt() {
        let rising = SceneBeat(t: 0.35).pulse(0.2, 0.5, 0.8)
        let falling = SceneBeat(t: 0.65).pulse(0.2, 0.5, 0.8)
        #expect(abs(rising - 0.5) < 0.0001)
        #expect(abs(falling - 0.5) < 0.0001)
    }
}
