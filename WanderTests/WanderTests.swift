//
//  WanderTests.swift
//  WanderTests
//
//  Created by Mahdi BND on 2/11/26.
//

import Testing
@testable import Wander

struct WanderTests {

    @Test func engineTargetsMeetM1SpecBaseline() {
        let targets = EngineTargets.zenDrivingM1

        #expect(targets.targetFPS == 60)
        #expect(targets.minimumAppleSiliconGeneration == "M1")
        #expect(targets.vehicleIDs.count == 2)
        #expect(targets.biomeIDs.count == 2)
        #expect(targets.maxActiveChunks > 0)
    }

    @Test func frameClockClampsLargeDelta() {
        let clock = FrameClock(targetFPS: 60, maxDeltaSeconds: 0.05)

        _ = clock.tick(now: 10.0)
        let tick = clock.tick(now: 11.0)

        #expect(tick.deltaTime == 0.05)
        #expect(tick.smoothedFPS > 0)
    }

}
