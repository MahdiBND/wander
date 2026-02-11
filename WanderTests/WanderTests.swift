//
//  WanderTests.swift
//  WanderTests
//
//  Created by Mahdi BND on 2/11/26.
//

import Testing
@testable import Wander
import simd

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

    @Test func sceneGraphBuildsWorldMatricesDepthFirst() {
        let sceneGraph = SceneGraph()

        let root = sceneGraph.createNode(
            localTransform: Transform(
                position: SIMD3<Float>(1, 0, 0),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
                scale: SIMD3<Float>(1, 1, 1)
            )
        )

        let child = sceneGraph.createNode(
            parent: root,
            localTransform: Transform(
                position: SIMD3<Float>(0, 2, 0),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
                scale: SIMD3<Float>(2, 2, 2)
            )
        )

        _ = sceneGraph.createNode(
            parent: child,
            localTransform: Transform(
                position: SIMD3<Float>(0, 0, 3),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
                scale: SIMD3<Float>(1, 1, 1)
            )
        )

        sceneGraph.updateWorldTransforms()

        let childWorld = sceneGraph.worldMatrix(for: child)!
        let worldPosition = SIMD3<Float>(childWorld.columns.3.x, childWorld.columns.3.y, childWorld.columns.3.z)
        #expect(approxEqual(worldPosition, SIMD3<Float>(1, 2, 0)))
    }

    @Test func sceneGraphReparentUpdatesWorldSpace() {
        let sceneGraph = SceneGraph()

        let leftRoot = sceneGraph.createNode(
            localTransform: Transform(
                position: SIMD3<Float>(10, 0, 0),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
                scale: SIMD3<Float>(1, 1, 1)
            )
        )
        let rightRoot = sceneGraph.createNode(
            localTransform: Transform(
                position: SIMD3<Float>(-4, 0, 0),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
                scale: SIMD3<Float>(1, 1, 1)
            )
        )
        let child = sceneGraph.createNode(
            parent: leftRoot,
            localTransform: Transform(
                position: SIMD3<Float>(0, 1, 0),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
                scale: SIMD3<Float>(1, 1, 1)
            )
        )

        sceneGraph.updateWorldTransforms()

        _ = sceneGraph.setParent(child, parent: rightRoot)
        sceneGraph.updateWorldTransforms()

        let childWorld = sceneGraph.worldMatrix(for: child)!
        let worldPosition = SIMD3<Float>(childWorld.columns.3.x, childWorld.columns.3.y, childWorld.columns.3.z)
        #expect(approxEqual(worldPosition, SIMD3<Float>(-4, 1, 0)))
    }

    @Test func sceneGraphTraversalOrderIsStableDepthFirst() {
        let sceneGraph = SceneGraph()

        let rootA = sceneGraph.createNode()
        let a1 = sceneGraph.createNode(parent: rootA)
        let a2 = sceneGraph.createNode(parent: rootA)
        let rootB = sceneGraph.createNode()
        let b1 = sceneGraph.createNode(parent: rootB)

        sceneGraph.updateWorldTransforms()

        #expect(sceneGraph.lastTraversalOrder == [rootA, a1, a2, rootB, b1])
    }

}

private func approxEqual(_ lhs: SIMD3<Float>, _ rhs: SIMD3<Float>, epsilon: Float = 0.0001) -> Bool {
    simd_length(lhs - rhs) <= epsilon
}
