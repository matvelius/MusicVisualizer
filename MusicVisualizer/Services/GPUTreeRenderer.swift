//
//  GPUTreeRenderer.swift
//  MusicVisualizer
//
//  Created by Claude Code on 8/25/25.
//

import Foundation
import Metal
import MetalKit
import SwiftUI
import simd

// MARK: - GPU Tree Structures

struct GPUTreeNode {
    var position: SIMD2<Float>
    var parentIndex: Int32 // -1 if no parent
    var thickness: Float
    var length: Float
    var angle: Float
    var age: Float
    var isVisible: Int32 // 0 or 1
    var isRoot: Int32 // 0 or 1
    var growthProgress: Float
    var color: SIMD4<Float>
    
    static let size = MemoryLayout<GPUTreeNode>.stride
}

struct GPUTreeParams {
    var nodeCount: UInt32
    var leafCount: UInt32
    var currentTime: Float
    var stageProgress: Float
    var currentStage: UInt32
    var audioLow: Float
    var audioMid: Float
    var audioHigh: Float
    var audioOverall: Float
    var seedPosition: SIMD2<Float>
    var branchingAngle: Float
    var baseGrowthRate: Float
    var maxNodes: UInt32
    var maxLeaves: UInt32
    
    static let size = MemoryLayout<GPUTreeParams>.stride
}

struct GPUTreeLeaf {
    var position: SIMD2<Float>
    var parentNode: Int32
    var age: Float
    var maxAge: Float
    var size: Float
    var angle: Float
    var color: SIMD4<Float>
    var isAlive: Int32
    var isFalling: Int32
    var fallVelocity: SIMD2<Float>
    
    static let size = MemoryLayout<GPUTreeLeaf>.stride
}

// MARK: - GPU Tree Renderer

class GPUTreeRenderer: ObservableObject {
    // Metal objects
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var library: MTLLibrary
    
    // Compute pipeline states
    private var treeGrowthComputeState: MTLComputePipelineState!
    private var leafUpdateComputeState: MTLComputePipelineState!
    
    // Render pipeline state
    private var renderPipelineState: MTLRenderPipelineState!
    
    // Buffers - Triple buffered for optimal performance
    private var nodeBuffers: [MTLBuffer] = []
    private var leafBuffers: [MTLBuffer] = []
    private var paramsBuffers: [MTLBuffer] = []
    private var quadVertexBuffer: MTLBuffer!
    private var currentBufferIndex: Int = 0
    private let maxBuffersInFlight: Int = 3
    
    // Synchronization
    private var inflightSemaphore: DispatchSemaphore
    
    // Tree parameters
    private var treeParams = GPUTreeParams(
        nodeCount: 1, // Start with seed
        leafCount: 0,
        currentTime: 0.0,
        stageProgress: 0.0,
        currentStage: 0, // .seed
        audioLow: 0.0,
        audioMid: 0.0,
        audioHigh: 0.0,
        audioOverall: 0.0,
        seedPosition: SIMD2<Float>(0.0, -0.8),
        branchingAngle: Float.pi / 6,
        baseGrowthRate: 0.3,
        maxNodes: 1000,
        maxLeaves: 500
    )
    
    // Settings and state
    var isAnimating: Bool = true
    private var lastTime: CFTimeInterval = CACurrentMediaTime()
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw GPUTreeError.metalNotSupported
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw GPUTreeError.failedToCreateCommandQueue
        }
        
        guard let library = device.makeDefaultLibrary() else {
            throw GPUTreeError.failedToLoadShaders
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.library = library
        self.inflightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
        
        try setupComputePipelines()
        try setupRenderPipeline()
        try setupBuffers()
        
        initializeTreeData()
    }
    
    private func setupComputePipelines() throws {
        guard let treeGrowthFunction = library.makeFunction(name: "treeGrowthCompute"),
              let leafUpdateFunction = library.makeFunction(name: "leafUpdateCompute") else {
            throw GPUTreeError.failedToLoadShaders
        }
        
        do {
            treeGrowthComputeState = try device.makeComputePipelineState(function: treeGrowthFunction)
            leafUpdateComputeState = try device.makeComputePipelineState(function: leafUpdateFunction)
        } catch {
            print("Failed to create compute pipeline states: \(error)")
            throw GPUTreeError.failedToCreatePipelineState
        }
    }
    
    private func setupRenderPipeline() throws {
        guard let vertexFunction = library.makeFunction(name: "treeVertexShader"),
              let fragmentFunction = library.makeFunction(name: "treeFragmentShader") else {
            throw GPUTreeError.failedToLoadShaders
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        // Vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 2
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        // Render target setup
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
            throw GPUTreeError.failedToCreatePipelineState
        }
    }
    
    private func setupBuffers() throws {
        let maxNodes = Int(treeParams.maxNodes)
        let maxLeaves = Int(treeParams.maxLeaves)
        
        // Create triple-buffered resources
        for _ in 0..<maxBuffersInFlight {
            guard let nodeBuffer = device.makeBuffer(length: GPUTreeNode.size * maxNodes, options: .storageModeShared),
                  let leafBuffer = device.makeBuffer(length: GPUTreeLeaf.size * maxLeaves, options: .storageModeShared),
                  let paramsBuffer = device.makeBuffer(length: GPUTreeParams.size, options: .storageModeShared) else {
                throw GPUTreeError.failedToCreateBuffer
            }
            
            nodeBuffers.append(nodeBuffer)
            leafBuffers.append(leafBuffer)
            paramsBuffers.append(paramsBuffer)
        }
        
        // Create quad vertices for instanced rendering
        let quadVertices: [Float] = [
            -1.0, -1.0,  // Bottom left
             1.0, -1.0,  // Bottom right
            -1.0,  1.0,  // Top left
             1.0, -1.0,  // Bottom right
             1.0,  1.0,  // Top right
            -1.0,  1.0   // Top left
        ]
        
        guard let vertexBuffer = device.makeBuffer(bytes: quadVertices, 
                                                   length: quadVertices.count * MemoryLayout<Float>.size, 
                                                   options: []) else {
            throw GPUTreeError.failedToCreateBuffer
        }
        
        quadVertexBuffer = vertexBuffer
    }
    
    private func initializeTreeData() {
        // Initialize seed node
        let seedNode = GPUTreeNode(
            position: treeParams.seedPosition,
            parentIndex: -1,
            thickness: 0.02,
            length: 0.0,
            angle: 0.0,
            age: 0.0,
            isVisible: 0, // Start invisible
            isRoot: 0,
            growthProgress: 0.0,
            color: SIMD4<Float>(0.6, 0.4, 0.2, 1.0)
        )
        
        // Write initial seed node to all buffers
        for buffer in nodeBuffers {
            let nodePointer = buffer.contents().bindMemory(to: GPUTreeNode.self, capacity: Int(treeParams.maxNodes))
            nodePointer.pointee = seedNode
        }
    }
    
    func updateAudioData(low: Float, mid: Float, high: Float, overall: Float) {
        treeParams.audioLow = low
        treeParams.audioMid = mid
        treeParams.audioHigh = high
        treeParams.audioOverall = overall
    }
    
    func render(to drawable: CAMetalDrawable, in view: MTKView) {
        guard isAnimating else { return }
        
        // Wait for available buffer
        _ = inflightSemaphore.wait(timeout: .distantFuture)
        
        let currentTime = CACurrentMediaTime()
        let deltaTime = Float(currentTime - lastTime)
        lastTime = currentTime
        
        // Update tree parameters
        treeParams.currentTime += deltaTime
        
        // Get current buffer index
        let bufferIndex = currentBufferIndex
        currentBufferIndex = (currentBufferIndex + 1) % maxBuffersInFlight
        
        let nodeBuffer = nodeBuffers[bufferIndex]
        let leafBuffer = leafBuffers[bufferIndex]
        let paramsBuffer = paramsBuffers[bufferIndex]
        
        // Update parameters buffer
        let paramsPointer = paramsBuffer.contents().bindMemory(to: GPUTreeParams.self, capacity: 1)
        paramsPointer.pointee = treeParams
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // GPU tree growth compute
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.setComputePipelineState(treeGrowthComputeState)
            computeEncoder.setBuffer(nodeBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 1)
            
            let threadsPerThreadgroup = MTLSize(width: 32, height: 1, depth: 1)
            let threadgroups = MTLSize(
                width: (Int(treeParams.maxNodes) + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
                height: 1,
                depth: 1
            )
            
            computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
            computeEncoder.endEncoding()
        }
        
        // GPU leaf update compute
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.setComputePipelineState(leafUpdateComputeState)
            computeEncoder.setBuffer(leafBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(nodeBuffer, offset: 0, index: 1)
            computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 2)
            
            let threadsPerThreadgroup = MTLSize(width: 32, height: 1, depth: 1)
            let threadgroups = MTLSize(
                width: (Int(treeParams.maxLeaves) + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
                height: 1,
                depth: 1
            )
            
            computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
            computeEncoder.endEncoding()
        }
        
        // Render the tree
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            inflightSemaphore.signal()
            return
        }
        
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            inflightSemaphore.signal()
            return
        }
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(nodeBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(leafBuffer, offset: 0, index: 2)
        renderEncoder.setVertexBuffer(paramsBuffer, offset: 0, index: 3)
        
        // Draw tree nodes
        renderEncoder.drawPrimitives(type: .triangle, 
                                     vertexStart: 0, 
                                     vertexCount: 6, 
                                     instanceCount: Int(treeParams.nodeCount))
        
        // Draw leaves
        renderEncoder.drawPrimitives(type: .triangle, 
                                     vertexStart: 0, 
                                     vertexCount: 6, 
                                     instanceCount: Int(treeParams.leafCount))
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        
        // Signal semaphore when GPU work is done
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.inflightSemaphore.signal()
        }
        
        commandBuffer.commit()
    }
    
    func reset() {
        treeParams.nodeCount = 1
        treeParams.leafCount = 0
        treeParams.currentTime = 0.0
        treeParams.stageProgress = 0.0
        treeParams.currentStage = 0
        initializeTreeData()
    }
}

// MARK: - Error Types

enum GPUTreeError: Error, LocalizedError {
    case metalNotSupported
    case failedToCreateCommandQueue
    case failedToLoadShaders
    case failedToCreatePipelineState
    case failedToCreateBuffer
    
    var errorDescription: String? {
        switch self {
        case .metalNotSupported:
            return "Metal is not supported on this device"
        case .failedToCreateCommandQueue:
            return "Failed to create Metal command queue"
        case .failedToLoadShaders:
            return "Failed to load GPU tree shaders"
        case .failedToCreatePipelineState:
            return "Failed to create pipeline state"
        case .failedToCreateBuffer:
            return "Failed to create Metal buffer"
        }
    }
}