//
//  TreeVisualizationRenderer.swift
//  MusicVisualizer
//
//  Created by Claude Code on 7/29/25.
//

import Foundation
import Metal
import MetalKit
import SwiftUI
import simd

// MARK: - Tree Growth Stages

enum TreeGrowthStage: Int, CaseIterable {
    case seed = 0
    case roots = 1 
    case trunk = 2
    case branches = 3
    case leaves = 4
    case mature = 5
    
    var displayName: String {
        switch self {
        case .seed: return "Seed"
        case .roots: return "Roots"
        case .trunk: return "Trunk"
        case .branches: return "Branches"
        case .leaves: return "Leaves"
        case .mature: return "Mature"
        }
    }
}

// MARK: - Tree Components

struct TreeNode {
    var position: SIMD2<Float>
    var parent: Int? // Index of parent node
    var children: [Int] // Indices of child nodes
    var age: Float
    var thickness: Float
    var length: Float
    var angle: Float // Angle from parent
    var isRoot: Bool
    var isVisible: Bool
    var growthProgress: Float // 0.0 to 1.0
    var color: SIMD4<Float>
    
    init(position: SIMD2<Float>, parent: Int? = nil, thickness: Float = 0.1, angle: Float = 0.0, isRoot: Bool = false) {
        self.position = position
        self.parent = parent
        self.children = []
        self.age = 0.0
        self.thickness = thickness
        self.length = 0.0
        self.angle = angle
        self.isRoot = isRoot
        self.isVisible = false
        self.growthProgress = 0.0
        self.color = SIMD4<Float>(0.6, 0.4, 0.2, 1.0) // Brown color
    }
}

struct TreeLeaf {
    var position: SIMD2<Float>
    var parentNode: Int
    var age: Float
    var maxAge: Float
    var size: Float
    var angle: Float
    var color: SIMD4<Float>
    var isAlive: Bool
    var isFalling: Bool
    var fallVelocity: SIMD2<Float>
    
    init(position: SIMD2<Float>, parentNode: Int) {
        self.position = position
        self.parentNode = parentNode
        self.age = 0.0
        self.maxAge = 30.0 + Float.random(in: -10.0...20.0) // 20-50 seconds
        self.size = 0.02 + Float.random(in: 0.0...0.03)
        self.angle = Float.random(in: 0...2 * Float.pi)
        self.color = SIMD4<Float>(0.2, 0.8, 0.3, 1.0) // Green color
        self.isAlive = true
        self.isFalling = false
        self.fallVelocity = SIMD2<Float>(0, 0)
    }
}

// MARK: - Tree Visualization Renderer

class TreeVisualizationRenderer: ObservableObject {
    // Metal objects
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var renderPipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer
    private var uniformsBuffer: MTLBuffer
    
    // Buffer alignment
    private let uniformBufferAlignment: Int = 256 // Metal requires 256-byte alignment
    private let alignedUniformSize: Int
    
    // Tree system
    private var nodes: [TreeNode] = []
    private var leaves: [TreeLeaf] = []
    private let maxNodes = 1000
    private let maxLeaves = 500
    private var currentTime: Float = 0.0
    private var seedPosition: SIMD2<Float> = SIMD2<Float>(0.0, -0.8)
    
    // Tree growth parameters
    private var currentStage: TreeGrowthStage = .seed
    private var stageProgress: Float = 0.0
    private var baseGrowthRate: Float = 0.3
    private var branchingAngle: Float = Float.pi / 6 // 30 degrees
    
    // Audio data
    private var audioLow: Float = 0.0
    private var audioMid: Float = 0.0
    private var audioHigh: Float = 0.0
    private var audioOverall: Float = 0.0
    
    // Settings
    var isAnimating: Bool = true
    private let settingsManager = SettingsManager.shared
    
    // Growth timing
    private let stageDurations: [TreeGrowthStage: Float] = [
        .seed: 2.0,      // 2 seconds
        .roots: 8.0,     // 8 seconds
        .trunk: 12.0,    // 12 seconds
        .branches: 20.0, // 20 seconds
        .leaves: 15.0,   // 15 seconds
        .mature: Float.infinity // Ongoing
    ]
    
    init() throws {
        // Calculate aligned uniform buffer size
        let uniformSize = MemoryLayout<ParticleUniforms>.size
        self.alignedUniformSize = (uniformSize + uniformBufferAlignment - 1) & ~(uniformBufferAlignment - 1)
        
        // Initialize Metal
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TreeVisualizationError.metalNotSupported
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw TreeVisualizationError.failedToCreateCommandQueue
        }
        
        self.device = device
        self.commandQueue = commandQueue
        
        // Create buffers with proper alignment
        guard let vertexBuffer = device.makeBuffer(length: MemoryLayout<Float>.size * 6 * 2, options: []),
              let uniformsBuffer = device.makeBuffer(length: alignedUniformSize * (maxNodes + maxLeaves), options: []) else {
            throw TreeVisualizationError.failedToCreateBuffer
        }
        
        self.vertexBuffer = vertexBuffer
        self.uniformsBuffer = uniformsBuffer
        
        // Set up Metal pipeline
        self.renderPipelineState = try self.setupMetalPipeline()
        
        // Set up quad vertices for rendering
        setupQuadVertices()
        
        // Initialize with seed
        initializeSeed()
    }
    
    private func setupMetalPipeline() throws -> MTLRenderPipelineState {
        guard let library = device.makeDefaultLibrary() else {
            throw TreeVisualizationError.failedToLoadShader
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        
        // Use existing particle shaders as they are compatible
        guard let vertexFunction = library.makeFunction(name: "particleVertexShader") else {
            throw TreeVisualizationError.failedToLoadShader
        }
        
        guard let fragmentFunction = library.makeFunction(name: "particleFragmentShader") else {
            throw TreeVisualizationError.failedToLoadShader
        }
        
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        // Set up vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 2
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        
        // Use alpha blending for smooth outlines
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create tree render pipeline state: \(error)")
            throw TreeVisualizationError.failedToCreatePipelineState
        }
    }
    
    private func setupQuadVertices() {
        let vertices: [Float] = [
            -1.0, -1.0,  // Bottom left
             1.0, -1.0,  // Bottom right
            -1.0,  1.0,  // Top left
             1.0, -1.0,  // Bottom right
             1.0,  1.0,  // Top right  
            -1.0,  1.0   // Top left
        ]
        
        let vertexPointer = vertexBuffer.contents().bindMemory(to: Float.self, capacity: vertices.count)
        vertexPointer.update(from: vertices, count: vertices.count)
    }
    
    private func initializeSeed() {
        nodes.removeAll()
        leaves.removeAll()
        currentStage = .seed
        stageProgress = 0.0
        currentTime = 0.0
        
        // Create initial seed node (invisible)
        var seedNode = TreeNode(position: seedPosition, thickness: 0.0)
        seedNode.isVisible = false
        nodes.append(seedNode)
    }
    
    func updateAudioData(low: Float, mid: Float, high: Float, overall: Float) {
        audioLow = low
        audioMid = mid
        audioHigh = high
        audioOverall = overall
    }
    
    func update(deltaTime: Float) {
        guard isAnimating else { return }
        
        currentTime += deltaTime
        
        // Calculate growth speed based on audio
        let audioGrowthMultiplier = 1.0 + audioOverall * 2.0 // Speed up with volume
        let effectiveDeltaTime = deltaTime * audioGrowthMultiplier
        
        // Update stage progress
        if let stageDuration = stageDurations[currentStage], stageDuration != Float.infinity {
            stageProgress += effectiveDeltaTime / stageDuration
            
            // Advance to next stage if current stage is complete
            if stageProgress >= 1.0 {
                advanceToNextStage()
            }
        }
        
        // Update tree based on current stage
        updateTreeGrowth(deltaTime: effectiveDeltaTime)
        
        // Update leaves
        updateLeaves(deltaTime: deltaTime)
        
        // Update colors based on audio frequency
        updateColors()
    }
    
    private func advanceToNextStage() {
        let allStages = TreeGrowthStage.allCases
        if let currentIndex = allStages.firstIndex(of: currentStage),
           currentIndex + 1 < allStages.count {
            currentStage = allStages[currentIndex + 1]
            stageProgress = 0.0
            print("Tree advanced to stage: \(currentStage.displayName)")
        }
    }
    
    private func updateTreeGrowth(deltaTime: Float) {
        switch currentStage {
        case .seed:
            updateSeedStage()
        case .roots:
            updateRootsStage(deltaTime: deltaTime)
        case .trunk:
            updateTrunkStage(deltaTime: deltaTime)
        case .branches:
            updateBranchesStage(deltaTime: deltaTime)
        case .leaves:
            updateLeavesStage(deltaTime: deltaTime)
        case .mature:
            updateMatureStage(deltaTime: deltaTime)
        }
        
        // Update node ages
        for i in nodes.indices {
            nodes[i].age += deltaTime
        }
    }
    
    private func updateSeedStage() {
        // Make seed visible as it germinates
        if !nodes.isEmpty {
            nodes[0].isVisible = true
            nodes[0].thickness = stageProgress * 0.02
        }
    }
    
    private func updateRootsStage(deltaTime: Float) {
        let rootCount = Int(stageProgress * 5) + 1 // Up to 6 roots
        
        // Grow roots downward and outward
        for rootIndex in 1..<rootCount {
            if rootIndex >= nodes.count {
                let rootAngle = Float.pi + Float(rootIndex - 1) * (Float.pi / 3) - Float.pi / 2
                let rootLength = 0.3 * stageProgress
                let rootPos = SIMD2<Float>(
                    seedPosition.x + sin(rootAngle) * rootLength,
                    seedPosition.y - cos(rootAngle) * rootLength * 0.5 // Roots go down
                )
                
                var rootNode = TreeNode(
                    position: rootPos,
                    parent: 0,
                    thickness: 0.015 * (1.0 - Float(rootIndex) * 0.1),
                    angle: rootAngle,
                    isRoot: true
                )
                rootNode.isVisible = true
                rootNode.color = SIMD4<Float>(0.4, 0.2, 0.1, 1.0) // Darker brown for roots
                nodes.append(rootNode)
                nodes[0].children.append(rootIndex)
            }
        }
    }
    
    private func updateTrunkStage(deltaTime: Float) {
        // Grow main trunk upward
        let trunkHeight = stageProgress * 0.6 // Trunk grows to 60% of screen
        let trunkPosition = SIMD2<Float>(seedPosition.x, seedPosition.y + trunkHeight)
        
        // Find or create trunk node
        let trunkIndex = nodes.firstIndex { !$0.isRoot && $0.parent == 0 } ?? nodes.count
        
        if trunkIndex == nodes.count {
            var trunkNode = TreeNode(
                position: trunkPosition,
                parent: 0,
                thickness: 0.04,
                angle: 0.0 // Straight up
            )
            trunkNode.isVisible = true
            nodes.append(trunkNode)
            nodes[0].children.append(trunkIndex)
        } else {
            // Update existing trunk
            nodes[trunkIndex].position = trunkPosition
            nodes[trunkIndex].growthProgress = stageProgress
        }
    }
    
    private func updateBranchesStage(deltaTime: Float) {
        let branchLevels = Int(stageProgress * 4) + 1 // Up to 5 levels of branches
        let trunkIndex = nodes.firstIndex { !$0.isRoot && $0.parent == 0 } ?? 0
        
        if trunkIndex < nodes.count {
            growBranches(from: trunkIndex, level: 0, maxLevel: branchLevels, baseLength: 0.2)
        }
    }
    
    private func growBranches(from parentIndex: Int, level: Int, maxLevel: Int, baseLength: Float) {
        guard level < maxLevel && nodes.count < maxNodes else { return }
        
        let parent = nodes[parentIndex]
        let branchCount = max(1, 3 - level) // Fewer branches at higher levels
        
        for i in 0..<branchCount {
            let branchAngle = parent.angle + (Float(i) - 1.0) * branchingAngle * (1.0 + audioMid * 0.5)
            let branchLength = baseLength * pow(0.7, Float(level)) * (0.8 + audioHigh * 0.4)
            let branchThickness = parent.thickness * 0.6
            
            let branchPosition = SIMD2<Float>(
                parent.position.x + cos(branchAngle - Float.pi/2) * branchLength,
                parent.position.y + sin(branchAngle - Float.pi/2) * branchLength
            )
            
            // Check if this branch already exists
            let existingBranch = parent.children.first { childIndex in
                childIndex < nodes.count && 
                abs(nodes[childIndex].angle - branchAngle) < 0.1
            }
            
            if existingBranch == nil && nodes.count < maxNodes {
                var branchNode = TreeNode(
                    position: branchPosition,
                    parent: parentIndex,
                    thickness: branchThickness,
                    angle: branchAngle
                )
                branchNode.isVisible = true
                branchNode.growthProgress = stageProgress
                
                let branchIndex = nodes.count
                nodes.append(branchNode)
                nodes[parentIndex].children.append(branchIndex)
                
                // Recursively grow sub-branches
                if level < maxLevel - 1 {
                    growBranches(from: branchIndex, level: level + 1, maxLevel: maxLevel, baseLength: baseLength)
                }
            }
        }
    }
    
    private func updateLeavesStage(deltaTime: Float) {
        // Add leaves to branch tips
        let leafGrowthRate = Int(stageProgress * 50) + 10 // Target leaf count
        
        if leaves.count < leafGrowthRate && leaves.count < maxLeaves {
            // Find branch tips (nodes with no children)
            let branchTips = nodes.indices.filter { index in
                !nodes[index].isRoot && nodes[index].children.isEmpty && nodes[index].parent != nil
            }
            
            if !branchTips.isEmpty {
                let randomTip = branchTips.randomElement()!
                let tipNode = nodes[randomTip]
                
                // Create leaf near the branch tip
                let leafOffset = SIMD2<Float>(
                    Float.random(in: -0.03...0.03),
                    Float.random(in: -0.03...0.03)
                )
                
                let leaf = TreeLeaf(
                    position: tipNode.position + leafOffset,
                    parentNode: randomTip
                )
                leaves.append(leaf)
            }
        }
    }
    
    private func updateMatureStage(deltaTime: Float) {
        // Continue growing leaves and manage leaf lifecycle
        if leaves.count < maxLeaves / 2 {
            updateLeavesStage(deltaTime: deltaTime)
        }
        
        // Seasonal leaf changes based on audio
        let seasonalFactor = sin(currentTime * 0.1) * 0.5 + 0.5 // Slow seasonal cycle
        let shouldDropLeaves = seasonalFactor < 0.3 || audioOverall > 0.8 // Drop in "autumn" or with intense music
        
        if shouldDropLeaves {
            dropLeaves()
        }
    }
    
    private func updateLeaves(deltaTime: Float) {
        for i in leaves.indices.reversed() {
            leaves[i].age += deltaTime
            
            // Check if leaf should start falling
            if !leaves[i].isFalling && (leaves[i].age > leaves[i].maxAge || audioOverall > 0.9) {
                leaves[i].isFalling = true
                leaves[i].fallVelocity = SIMD2<Float>(
                    Float.random(in: -0.02...0.02),
                    -0.05 - Float.random(in: 0.0...0.03)
                )
            }
            
            // Update falling leaves
            if leaves[i].isFalling {
                leaves[i].position += leaves[i].fallVelocity * deltaTime
                leaves[i].fallVelocity.y -= 0.02 * deltaTime // Gravity
                
                // Add wind effect based on audio
                leaves[i].fallVelocity.x += sin(currentTime * 2.0 + leaves[i].age) * 0.01 * audioMid
                
                // Remove leaves that have fallen off screen
                if leaves[i].position.y < -1.2 {
                    leaves.remove(at: i)
                }
            }
        }
    }
    
    private func dropLeaves() {
        for i in leaves.indices {
            if !leaves[i].isFalling && Float.random(in: 0...1) < 0.02 { // 2% chance per frame
                leaves[i].isFalling = true
                leaves[i].fallVelocity = SIMD2<Float>(
                    Float.random(in: -0.03...0.03),
                    -0.02 - Float.random(in: 0.0...0.05)
                )
            }
        }
    }
    
    private func updateColors() {
        let settingsManager = SettingsManager.shared
        let theme = settingsManager.colorTheme
        
        // Update node colors based on frequency spectrum
        for i in nodes.indices {
            let node = nodes[i]
            if node.isRoot {
                // Roots - brown with slight variation
                let intensity = 0.3 + audioLow * 0.2
                nodes[i].color = SIMD4<Float>(0.4 * intensity, 0.2 * intensity, 0.1 * intensity, 1.0)
            } else {
                // Trunk and branches - brown to green gradient based on audio
                let baseColor = SIMD4<Float>(0.6, 0.4, 0.2, 1.0) // Brown
                let audioColor = getThemeColor(theme: theme, audioMid: audioMid, audioHigh: audioHigh)
                let mixFactor = audioOverall * 0.3
                nodes[i].color = simd_mix(baseColor, audioColor, SIMD4<Float>(mixFactor, mixFactor, mixFactor, 0))
            }
        }
        
        // Update leaf colors
        for i in leaves.indices {
            let leaf = leaves[i]
            if leaf.isFalling {
                // Falling leaves - warmer colors
                let fallProgress = min(1.0, leaf.age / leaf.maxAge)
                let greenColor = SIMD4<Float>(0.2, 0.8, 0.3, 1.0)
                let autumnColor = SIMD4<Float>(0.8, 0.6, 0.2, 1.0)
                leaves[i].color = simd_mix(greenColor, autumnColor, SIMD4<Float>(fallProgress, fallProgress, fallProgress, 0))
            } else {
                // Living leaves - green with audio reactivity
                let baseGreen = SIMD4<Float>(0.2, 0.8, 0.3, 1.0)
                let audioColor = getThemeColor(theme: theme, audioMid: audioMid, audioHigh: audioHigh)
                let mixFactor = audioHigh * 0.4
                leaves[i].color = simd_mix(baseGreen, audioColor, SIMD4<Float>(mixFactor, mixFactor, mixFactor, 0))
            }
        }
    }
    
    private func getThemeColor(theme: ColorTheme, audioMid: Float, audioHigh: Float) -> SIMD4<Float> {
        let position = Double(audioMid * 0.5 + audioHigh * 0.5)
        let themeColor = theme.color(for: Int(position * 100), totalBands: 100)
        let uiColor = UIColor(themeColor)
        
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
    }
    
    func render(to drawable: CAMetalDrawable, in view: MTKView) {
        let effectiveDeltaTime = Float(1.0 / 60.0)
        update(deltaTime: effectiveDeltaTime)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        var renderIndex = 0
        
        // Render tree nodes
        for node in nodes where node.isVisible && renderIndex < maxNodes {
            let scale = matrix4x4_scale(node.thickness * 20, node.thickness * 20, 1)
            let translation = matrix4x4_translation(node.position.x, node.position.y, 0)
            let modelMatrix = translation * scale
            
            var uniforms = ParticleUniforms(
                modelMatrix: modelMatrix,
                color: node.color,
                size: node.thickness,
                complexity: 0.5,
                fractalType: Int32(3), // Use spiral type for tree branches
                generation: Int32(node.isRoot ? 0 : 1),
                shapeType: Int32(node.isRoot ? 2 : 1), // Square for roots, triangle for branches
                nextShapeType: Int32(node.isRoot ? 2 : 1),
                morphProgress: 0.0,
                scaleX: 1.0,
                scaleY: node.isRoot ? 0.5 : 2.0, // Make roots wider, branches taller
                opacity: node.color.w
            )
            
            let alignedOffset = alignedUniformSize * renderIndex
            let uniformPointer = uniformsBuffer.contents().advanced(by: alignedOffset)
            uniformPointer.copyMemory(from: &uniforms, byteCount: MemoryLayout<ParticleUniforms>.size)
            
            encoder.setVertexBuffer(uniformsBuffer, offset: alignedOffset, index: 1)
            encoder.setFragmentBuffer(uniformsBuffer, offset: alignedOffset, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            
            renderIndex += 1
        }
        
        // Render leaves
        for leaf in leaves where renderIndex < maxNodes + maxLeaves {
            let scale = matrix4x4_scale(leaf.size * 30, leaf.size * 30, 1)
            let rotation = matrix4x4_rotation(radians: leaf.angle, axis: SIMD3<Float>(0, 0, 1))
            let translation = matrix4x4_translation(leaf.position.x, leaf.position.y, 0)
            let modelMatrix = translation * rotation * scale
            
            var uniforms = ParticleUniforms(
                modelMatrix: modelMatrix,
                color: leaf.color,
                size: leaf.size,
                complexity: 0.3,
                fractalType: Int32(1), // Use Julia type for organic leaf patterns
                generation: Int32(2),
                shapeType: Int32(0), // Circle for leaves
                nextShapeType: Int32(0),
                morphProgress: 0.0,
                scaleX: 1.0,
                scaleY: 1.0,
                opacity: leaf.color.w
            )
            
            let alignedOffset = alignedUniformSize * renderIndex
            let uniformPointer = uniformsBuffer.contents().advanced(by: alignedOffset)
            uniformPointer.copyMemory(from: &uniforms, byteCount: MemoryLayout<ParticleUniforms>.size)
            
            encoder.setVertexBuffer(uniformsBuffer, offset: alignedOffset, index: 1)
            encoder.setFragmentBuffer(uniformsBuffer, offset: alignedOffset, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            
            renderIndex += 1
        }
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func reset() {
        initializeSeed()
    }
    
    // Debug information
    var debugInfo: String {
        return "Stage: \(currentStage.displayName) (\(Int(stageProgress * 100))%) | Nodes: \(nodes.count) | Leaves: \(leaves.count)"
    }
}

// MARK: - Metal Uniforms
// Using existing ParticleUniforms from GenerativeFractalRenderer for compatibility

// MARK: - Error Types

enum TreeVisualizationError: Error, LocalizedError {
    case metalNotSupported
    case failedToCreateCommandQueue
    case failedToLoadShader
    case failedToCreatePipelineState
    case failedToCreateBuffer
    
    var errorDescription: String? {
        switch self {
        case .metalNotSupported:
            return "Metal is not supported on this device"
        case .failedToCreateCommandQueue:
            return "Failed to create Metal command queue"
        case .failedToLoadShader:
            return "Failed to load tree shader"
        case .failedToCreatePipelineState:
            return "Failed to create render pipeline state"
        case .failedToCreateBuffer:
            return "Failed to create Metal buffer"
        }
    }
}