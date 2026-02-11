//
//  Renderer.swift
//  Wander
//
//  Created by Mahdi BND on 2/11/26.
//

// Our platform independent renderer class

import Metal
import MetalKit
import QuartzCore
import simd

// Step 1 bootstrap: explicit spec targets and protocol-oriented engine boundaries.
struct EngineTargets {
    let targetFPS: Int
    let memoryBudgetMB: Int
    let minimumAppleSiliconGeneration: String
    let maxActiveChunks: Int
    let worldScaleMetersPerChunk: Float
    let vehicleIDs: [String]
    let biomeIDs: [String]

    static let zenDrivingM1 = EngineTargets(
        targetFPS: 60,
        memoryBudgetMB: 1536,
        minimumAppleSiliconGeneration: "M1",
        maxActiveChunks: 32,
        worldScaleMetersPerChunk: 128,
        vehicleIDs: ["glider", "trailblazer"],
        biomeIDs: ["mountain-mist", "desert-dusk"]
    )
}

final class EngineContext {
    let device: MTLDevice
    let targets: EngineTargets
    var drawableSize: CGSize

    init(device: MTLDevice, targets: EngineTargets, drawableSize: CGSize) {
        self.device = device
        self.targets = targets
        self.drawableSize = drawableSize
    }
}

protocol EngineSystem: AnyObject {
    var systemName: String { get }
    func start(context: EngineContext)
    func update(context: EngineContext, deltaTime: Float)
}

final class CameraSystemBootstrap: EngineSystem {
    let systemName = "CameraSystem"

    func start(context: EngineContext) {}
    func update(context: EngineContext, deltaTime: Float) {}
}

final class WorldStreamingBootstrap: EngineSystem {
    let systemName = "WorldGenerator"
    private var chunkBudget: Int = 0

    func start(context: EngineContext) {
        chunkBudget = context.targets.maxActiveChunks
    }

    func update(context: EngineContext, deltaTime: Float) {
        _ = chunkBudget
    }
}

final class FogAtmosphereBootstrap: EngineSystem {
    let systemName = "FogSystem"

    func start(context: EngineContext) {}
    func update(context: EngineContext, deltaTime: Float) {}
}

final class EngineCoordinator {
    private let systems: [EngineSystem]

    init(systems: [EngineSystem], context: EngineContext) {
        self.systems = systems
        systems.forEach { $0.start(context: context) }
    }

    func update(context: EngineContext, deltaTime: Float) {
        systems.forEach { $0.update(context: context, deltaTime: deltaTime) }
    }
}

struct FrameTick {
    let deltaTime: Float
    let smoothedFPS: Float
}

final class FrameClock {
    private var lastTimestamp: CFTimeInterval?
    private var smoothedDelta: Float
    private let maxDeltaSeconds: Float

    init(targetFPS: Int, maxDeltaSeconds: Float = 1.0 / 20.0) {
        let baselineDelta = 1.0 / Float(max(targetFPS, 1))
        self.smoothedDelta = baselineDelta
        self.maxDeltaSeconds = maxDeltaSeconds
    }

    func tick(now: CFTimeInterval = CACurrentMediaTime()) -> FrameTick {
        guard let lastTimestamp else {
            self.lastTimestamp = now
            return FrameTick(deltaTime: smoothedDelta, smoothedFPS: 1.0 / smoothedDelta)
        }

        let rawDelta = Float(now - lastTimestamp)
        self.lastTimestamp = now

        let clampedDelta = min(max(rawDelta, 0.0001), maxDeltaSeconds)
        smoothedDelta = (0.9 * smoothedDelta) + (0.1 * clampedDelta)

        return FrameTick(deltaTime: clampedDelta, smoothedFPS: 1.0 / smoothedDelta)
    }
}

struct SceneNodeID: Hashable, Sendable {
    let rawValue: UInt64
}

struct Transform: Sendable {
    var position: SIMD3<Float>
    var rotation: simd_quatf
    var scale: SIMD3<Float>

    static let identity = Transform(
        position: SIMD3<Float>(0, 0, 0),
        rotation: simd_quaternion(0, SIMD3<Float>(0, 1, 0)),
        scale: SIMD3<Float>(1, 1, 1)
    )

    func localMatrix() -> matrix_float4x4 {
        matrix4x4_translation(position.x, position.y, position.z) * matrix_float4x4(rotation) * matrix4x4_scale(scale.x, scale.y, scale.z)
    }
}

private struct SceneNodeRecord {
    let id: SceneNodeID
    var parent: SceneNodeID?
    var children: [SceneNodeID]
    var localTransform: Transform
    var worldMatrix: matrix_float4x4
    var isDirty: Bool
}

final class SceneGraph {
    private var nodes: [SceneNodeID: SceneNodeRecord] = [:]
    private var rootOrder: [SceneNodeID] = []
    private var nextRawID: UInt64 = 1
    private(set) var lastTraversalOrder: [SceneNodeID] = []

    @discardableResult
    func createNode(parent: SceneNodeID? = nil, localTransform: Transform = .identity) -> SceneNodeID {
        let id = SceneNodeID(rawValue: nextRawID)
        nextRawID += 1

        nodes[id] = SceneNodeRecord(
            id: id,
            parent: nil,
            children: [],
            localTransform: localTransform,
            worldMatrix: localTransform.localMatrix(),
            isDirty: true
        )

        if let parent {
            if !setParent(id, parent: parent) {
                rootOrder.append(id)
            }
        } else {
            rootOrder.append(id)
        }

        return id
    }

    func contains(_ id: SceneNodeID) -> Bool {
        nodes[id] != nil
    }

    func setLocalTransform(_ transform: Transform, for nodeID: SceneNodeID) {
        guard var node = nodes[nodeID] else { return }
        node.localTransform = transform
        nodes[nodeID] = node
        markSubtreeDirty(startingAt: nodeID)
    }

    func localTransform(for nodeID: SceneNodeID) -> Transform? {
        nodes[nodeID]?.localTransform
    }

    func worldMatrix(for nodeID: SceneNodeID) -> matrix_float4x4? {
        nodes[nodeID]?.worldMatrix
    }

    @discardableResult
    func setParent(_ childID: SceneNodeID, parent newParentID: SceneNodeID?) -> Bool {
        guard var child = nodes[childID] else { return false }

        if let newParentID {
            guard nodes[newParentID] != nil else { return false }
            if newParentID == childID { return false }
            if isDescendant(ancestor: childID, potentialDescendant: newParentID) { return false }
        }

        if let previousParentID = child.parent {
            guard var previousParent = nodes[previousParentID] else { return false }
            previousParent.children.removeAll { $0 == childID }
            nodes[previousParentID] = previousParent
        } else {
            rootOrder.removeAll { $0 == childID }
        }

        child.parent = newParentID
        nodes[childID] = child

        if let newParentID {
            guard var newParent = nodes[newParentID] else { return false }
            newParent.children.append(childID)
            nodes[newParentID] = newParent
        } else if !rootOrder.contains(childID) {
            rootOrder.append(childID)
        }

        markSubtreeDirty(startingAt: childID)
        return true
    }

    @discardableResult
    func removeNode(_ nodeID: SceneNodeID) -> Bool {
        guard let node = nodes[nodeID] else { return false }

        for childID in node.children {
            _ = removeNode(childID)
        }

        if let parentID = node.parent, var parent = nodes[parentID] {
            parent.children.removeAll { $0 == nodeID }
            nodes[parentID] = parent
        } else {
            rootOrder.removeAll { $0 == nodeID }
        }

        nodes.removeValue(forKey: nodeID)
        return true
    }

    func updateWorldTransforms() {
        var traversal: [SceneNodeID] = []
        for rootID in rootOrder where nodes[rootID] != nil {
            updateNodeWorld(
                nodeID: rootID,
                parentWorldMatrix: matrix_identity_float4x4,
                parentDirty: false,
                traversal: &traversal
            )
        }
        lastTraversalOrder = traversal
    }

    private func updateNodeWorld(nodeID: SceneNodeID,
                                 parentWorldMatrix: matrix_float4x4,
                                 parentDirty: Bool,
                                 traversal: inout [SceneNodeID]) {
        guard var node = nodes[nodeID] else { return }
        traversal.append(nodeID)

        let shouldRecompute = parentDirty || node.isDirty
        if shouldRecompute {
            node.worldMatrix = parentWorldMatrix * node.localTransform.localMatrix()
            node.isDirty = false
            nodes[nodeID] = node
        }

        for childID in node.children {
            updateNodeWorld(
                nodeID: childID,
                parentWorldMatrix: node.worldMatrix,
                parentDirty: shouldRecompute,
                traversal: &traversal
            )
        }
    }

    private func markSubtreeDirty(startingAt nodeID: SceneNodeID) {
        guard var node = nodes[nodeID] else { return }
        node.isDirty = true
        nodes[nodeID] = node
        for childID in node.children {
            markSubtreeDirty(startingAt: childID)
        }
    }

    private func isDescendant(ancestor: SceneNodeID, potentialDescendant: SceneNodeID) -> Bool {
        guard let node = nodes[ancestor] else { return false }
        if node.children.contains(potentialDescendant) { return true }
        return node.children.contains { isDescendant(ancestor: $0, potentialDescendant: potentialDescendant) }
    }
}

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

let maxBuffersInFlight = 3

nonisolated enum RendererError: Error {
    case badVertexDescriptor
}

class Renderer: NSObject, MTKViewDelegate {

    public let device: MTLDevice

    private let engineContext: EngineContext
    private let engineCoordinator: EngineCoordinator
    private let frameClock: FrameClock

    let commandQueue: MTL4CommandQueue
    let commandBuffer: MTL4CommandBuffer
    let commandAllocators: [MTL4CommandAllocator]
    let commandQueueResidencySet: MTLResidencySet
    let vertexArgumentTable: MTL4ArgumentTable
    let fragmentArgumentTable: MTL4ArgumentTable

    let endFrameEvent: MTLSharedEvent
    var frameIndex = 0

    var dynamicUniformBuffer: MTLBuffer
    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    var colorMap: MTLTexture

    var uniformBufferOffset = 0

    var uniformBufferIndex = 0

    var uniforms: UnsafeMutablePointer<Uniforms>

    var projectionMatrix: matrix_float4x4 = matrix_float4x4()

    var rotation: Float = 0

    var mesh: MTKMesh

    @MainActor
    init?(metalKitView: MTKView, targets: EngineTargets) {
        let device = metalKitView.device!
        self.device = device

        self.engineContext = EngineContext(device: device, targets: targets, drawableSize: metalKitView.drawableSize)
        self.engineCoordinator = EngineCoordinator(
            systems: [
                CameraSystemBootstrap(),
                WorldStreamingBootstrap(),
                FogAtmosphereBootstrap()
            ],
            context: engineContext
        )
        self.frameClock = FrameClock(targetFPS: targets.targetFPS)

        self.commandQueue = device.makeMTL4CommandQueue()!
        self.commandBuffer = device.makeCommandBuffer()!
        self.commandAllocators = (0..<maxBuffersInFlight).map { _ in device.makeCommandAllocator()! }

        let argTableDesc = MTL4ArgumentTableDescriptor()
        argTableDesc.maxBufferBindCount = 4
        self.vertexArgumentTable = try! device.makeArgumentTable(descriptor: argTableDesc)
        argTableDesc.maxTextureBindCount = 1
        self.fragmentArgumentTable = try! device.makeArgumentTable(descriptor: argTableDesc)

        self.endFrameEvent = device.makeSharedEvent()!
        frameIndex = maxBuffersInFlight
        self.endFrameEvent.signaledValue = UInt64(frameIndex - 1)

        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight

        guard let buffer = self.device.makeBuffer(length: uniformBufferSize, options: [MTLResourceOptions.storageModeShared]) else { return nil }
        dynamicUniformBuffer = buffer

        self.dynamicUniformBuffer.label = "UniformBuffer"

        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to: Uniforms.self, capacity: 1)

        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1

        let mtlVertexDescriptor = Renderer.buildMetalVertexDescriptor()

        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }

        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled = true
        guard let state = device.makeDepthStencilState(descriptor: depthStateDescriptor) else { return nil }
        depthState = state

        do {
            mesh = try Renderer.buildMesh(device: device, mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to build MetalKit Mesh. Error info: \(error)")
            return nil
        }

        do {
            colorMap = try Renderer.loadTexture(device: device, textureName: "ColorMap")
        } catch {
            print("Unable to load texture. Error info: \(error)")
            return nil
        }

        let residencySetDesc = MTLResidencySetDescriptor()
        residencySetDesc.initialCapacity = mesh.vertexBuffers.count + mesh.submeshes.count + 2 // color map + uniforms buffer
        let residencySet = try! self.device.makeResidencySet(descriptor: residencySetDesc)
        residencySet.addAllocations(mesh.vertexBuffers.map { $0.buffer })
        residencySet.addAllocations(mesh.submeshes.map { $0.indexBuffer.buffer })
        residencySet.addAllocations([colorMap, dynamicUniformBuffer])
        residencySet.commit()
        commandQueue.addResidencySet(residencySet)
        commandQueueResidencySet = residencySet

        super.init()
    }

    class func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        // Create a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices

        let mtlVertexDescriptor = MTLVertexDescriptor()

        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue

        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].format = MTLVertexFormat.float2
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue

        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = 12
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex

        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stride = 8
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex

        return mtlVertexDescriptor
    }

    @MainActor
    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object

        let library = device.makeDefaultLibrary()
        let compiler = try device.makeCompiler(descriptor: MTL4CompilerDescriptor())

        let vertexFunctionDescriptor = MTL4LibraryFunctionDescriptor()
        vertexFunctionDescriptor.library = library
        vertexFunctionDescriptor.name = "vertexShader"
        let fragmentFunctionDescriptor = MTL4LibraryFunctionDescriptor()
        fragmentFunctionDescriptor.library = library
        fragmentFunctionDescriptor.name = "fragmentShader"

        let pipelineDescriptor = MTL4RenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.rasterSampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunctionDescriptor = vertexFunctionDescriptor
        pipelineDescriptor.fragmentFunctionDescriptor = fragmentFunctionDescriptor
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor

        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat

        return try compiler.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    class func buildMesh(device: MTLDevice,
                         mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTKMesh {
        /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor

        let metalAllocator = MTKMeshBufferAllocator(device: device)

        let mdlMesh = MDLMesh.newBox(withDimensions: SIMD3<Float>(4, 4, 4),
                                     segments: SIMD3<UInt32>(2, 2, 2),
                                     geometryType: MDLGeometryType.triangles,
                                     inwardNormals: false,
                                     allocator: metalAllocator)

        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)

        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate

        mdlMesh.vertexDescriptor = mdlVertexDescriptor

        return try MTKMesh(mesh: mdlMesh, device: device)
    }

    class func loadTexture(device: MTLDevice,
                           textureName: String) throws -> MTLTexture {
        /// Load texture data with optimal parameters for sampling

        let textureLoader = MTKTextureLoader(device: device)

        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue)
        ]

        return try textureLoader.newTexture(name: textureName,
                                            scaleFactor: 1.0,
                                            bundle: nil,
                                            options: textureLoaderOptions)

    }

    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering

        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight

        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex

        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to: Uniforms.self, capacity: 1)
    }

    private func updateGameState(deltaTime: Float) {
        /// Update any game state before rendering

        uniforms[0].projectionMatrix = projectionMatrix

        let rotationAxis = SIMD3<Float>(1, 1, 0)
        let modelMatrix = matrix4x4_rotation(radians: rotation, axis: rotationAxis)
        let viewMatrix = matrix4x4_translation(0.0, 0.0, -8.0)
        uniforms[0].modelViewMatrix = simd_mul(viewMatrix, modelMatrix)

        // Tie animation speed to frame delta to keep behavior stable across frame pacing changes.
        rotation += 0.8 * deltaTime
    }

    func draw(in view: MTKView) {
        /// Per frame updates hare

        guard let drawable = view.currentDrawable else { return }

        /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
        ///   holding onto the drawable and blocking the display pipeline any longer than necessary
        guard let renderPassDescriptor = view.currentMTL4RenderPassDescriptor else { return }

        let tick = frameClock.tick()
        engineCoordinator.update(context: engineContext, deltaTime: tick.deltaTime)

        let previousValueToWaitFor = self.frameIndex - maxBuffersInFlight
        self.endFrameEvent.wait(untilSignaledValue: UInt64(previousValueToWaitFor), timeoutMS: 10)
        let commandAllocator = self.commandAllocators[uniformBufferIndex]
        commandAllocator.reset()
        commandBuffer.beginCommandBuffer(allocator: commandAllocator)

        self.updateDynamicBufferState()

        self.updateGameState(deltaTime: tick.deltaTime)

        guard let renderEncoder = self.commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            fatalError("Failed to create render command encoder")
        }

        /// Final pass rendering code here
        renderEncoder.label = "Primary Render Encoder"

        renderEncoder.pushDebugGroup("Draw Box")

        renderEncoder.setCullMode(.back)

        renderEncoder.setFrontFacing(.counterClockwise)

        renderEncoder.setRenderPipelineState(pipelineState)

        renderEncoder.setDepthStencilState(depthState)

        renderEncoder.setArgumentTable(self.vertexArgumentTable, stages: .vertex)
        renderEncoder.setArgumentTable(self.fragmentArgumentTable, stages: .fragment)

        self.vertexArgumentTable.setAddress(dynamicUniformBuffer.gpuAddress + UInt64(uniformBufferOffset), index: BufferIndex.uniforms.rawValue)
        self.fragmentArgumentTable.setAddress(dynamicUniformBuffer.gpuAddress + UInt64(uniformBufferOffset), index: BufferIndex.uniforms.rawValue)

        for (index, element) in mesh.vertexDescriptor.layouts.enumerated() {
            guard let layout = element as? MDLVertexBufferLayout else {
                return
            }

            if layout.stride != 0 {
                let buffer = mesh.vertexBuffers[index]
                self.vertexArgumentTable.setAddress(buffer.buffer.gpuAddress + UInt64(buffer.offset), index: index)
            }
        }

        self.fragmentArgumentTable.setTexture(colorMap.gpuResourceID, index: TextureIndex.color.rawValue)

        for submesh in mesh.submeshes {
            renderEncoder.drawIndexedPrimitives(primitiveType: submesh.primitiveType,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer.gpuAddress + UInt64(submesh.indexBuffer.offset),
                                                indexBufferLength: submesh.indexBuffer.buffer.length)
        }

        renderEncoder.popDebugGroup()

        renderEncoder.endEncoding()

        commandBuffer.useResidencySet((view.layer as! CAMetalLayer).residencySet)
        commandBuffer.endCommandBuffer()

        commandQueue.waitForDrawable(drawable)
        commandQueue.commit([commandBuffer])
        commandQueue.signalDrawable(drawable)
        commandQueue.signalEvent(self.endFrameEvent, value: UInt64(self.frameIndex))
        self.frameIndex += 1
        drawable.present()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here

        engineContext.drawableSize = size

        let aspect = Float(size.width) / Float(size.height)
        projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(65), aspectRatio: aspect, nearZ: 0.1, farZ: 100.0)
    }
}

// Generic matrix math utility functions
func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x
    let y = unitAxis.y
    let z = unitAxis.z
    return matrix_float4x4.init(columns: (vector_float4(ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                          vector_float4(x * y * ci - z * st, ct + y * y * ci, z * y * ci + x * st, 0),
                                          vector_float4(x * z * ci + y * st, y * z * ci - x * st, ct + z * z * ci, 0),
                                          vector_float4(0, 0, 0, 1)))
}

func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns: (vector_float4(1, 0, 0, 0),
                                          vector_float4(0, 1, 0, 0),
                                          vector_float4(0, 0, 1, 0),
                                          vector_float4(translationX, translationY, translationZ, 1)))
}

func matrix4x4_scale(_ scaleX: Float, _ scaleY: Float, _ scaleZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns: (vector_float4(scaleX, 0, 0, 0),
                                          vector_float4(0, scaleY, 0, 0),
                                          vector_float4(0, 0, scaleZ, 0),
                                          vector_float4(0, 0, 0, 1)))
}

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns: (vector_float4(xs, 0, 0, 0),
                                          vector_float4(0, ys, 0, 0),
                                          vector_float4(0, 0, zs, -1),
                                          vector_float4(0, 0, zs * nearZ, 0)))
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}
