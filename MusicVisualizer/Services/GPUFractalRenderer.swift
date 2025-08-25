//
//  GPUFractalRenderer.swift
//  MusicVisualizer
//
//  Created by Claude Code on 8/24/25.
//

import Foundation
import Metal
import MetalKit
import SwiftUI
import simd

// MARK: - GPU Fractal Uniforms

struct GPUFractalParams {
    var resolution: SIMD2<UInt32>
    var zoom: Float
    var center: SIMD2<Float>
    var maxIterations: UInt32
    var fractalType: UInt32
    var juliaConstant: SIMD2<Float>
    var colorPhase: Float
    var morphFactor: Float
    
    init() {
        resolution = SIMD2<UInt32>(1024, 1024)
        zoom = 2.0
        center = SIMD2<Float>(0.0, 0.0)
        maxIterations = 80
        fractalType = 0
        juliaConstant = SIMD2<Float>(-0.7, 0.27015)
        colorPhase = 0.0
        morphFactor = 0.0
    }
}

struct GPUAudioData {
    var low: Float
    var mid: Float
    var high: Float
    var overall: Float
    var time: Float
    
    init() {
        low = 0.0
        mid = 0.0
        high = 0.0
        overall = 0.0
        time = 0.0
    }
}

// MARK: - GPU Fractal Renderer

class GPUFractalRenderer: ObservableObject {
    // Metal objects
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var computePipelineState: MTLComputePipelineState!
    private var layeredComputePipelineState: MTLComputePipelineState!
    
    // Buffers
    private var paramsBuffer: MTLBuffer
    private var audioBuffer: MTLBuffer
    
    // Render targets
    private var fractalTexture: MTLTexture?
    private var renderPipelineState: MTLRenderPipelineState!
    private var quadVertexBuffer: MTLBuffer
    
    // Parameters
    private var fractalParams: GPUFractalParams
    private var audioData: GPUAudioData
    private var settingsManager = SettingsManager.shared
    
    // Performance tracking
    private var startTime: CFTimeInterval
    private var lastUpdateTime: CFTimeInterval = 0
    var isAnimating: Bool = true
    
    // Configuration
    var useLayeredRendering: Bool = true
    var adaptiveQuality: Bool = true
    
    init() throws {
        // Initialize Metal
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw GPUFractalError.metalNotSupported
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw GPUFractalError.failedToCreateCommandQueue
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.startTime = CACurrentMediaTime()
        
        // Initialize parameters
        self.fractalParams = GPUFractalParams()
        self.audioData = GPUAudioData()
        
        // Create buffers
        guard let paramsBuffer = device.makeBuffer(
            length: MemoryLayout<GPUFractalParams>.stride,
            options: .storageModeShared
        ),
        let audioBuffer = device.makeBuffer(
            length: MemoryLayout<GPUAudioData>.stride,
            options: .storageModeShared
        ) else {
            throw GPUFractalError.failedToCreateBuffer
        }
        
        self.paramsBuffer = paramsBuffer
        self.audioBuffer = audioBuffer
        
        // Create quad vertices for full-screen rendering
        let quadVertices: [Float] = [
            -1.0, -1.0, 0.0, 0.0, // Bottom left
             1.0, -1.0, 1.0, 0.0, // Bottom right
            -1.0,  1.0, 0.0, 1.0, // Top left
             1.0,  1.0, 1.0, 1.0  // Top right
        ]
        
        guard let vertexBuffer = device.makeBuffer(
            bytes: quadVertices,
            length: quadVertices.count * MemoryLayout<Float>.stride,
            options: []
        ) else {
            throw GPUFractalError.failedToCreateBuffer
        }
        
        self.quadVertexBuffer = vertexBuffer
        
        // Setup Metal pipelines
        try setupComputePipeline()
        try setupRenderPipeline()
        
        // Apply initial settings
        updateFractalType()
    }
    
    private func setupComputePipeline() throws {
        guard let library = device.makeDefaultLibrary() else {
            throw GPUFractalError.failedToLoadShader
        }
        
        // Main compute pipeline
        guard let computeFunction = library.makeFunction(name: "fractalComputeShader") else {
            throw GPUFractalError.failedToLoadShader
        }
        
        do {
            computePipelineState = try device.makeComputePipelineState(function: computeFunction)
        } catch {
            print("Failed to create compute pipeline state: \(error)")
            throw GPUFractalError.failedToCreatePipelineState
        }
        
        // Layered compute pipeline
        guard let layeredFunction = library.makeFunction(name: "layeredFractalComputeShader") else {
            print("Warning: Layered fractal shader not found, using basic shader")
            layeredComputePipelineState = computePipelineState
            return
        }
        
        do {
            layeredComputePipelineState = try device.makeComputePipelineState(function: layeredFunction)
        } catch {
            print("Warning: Failed to create layered compute pipeline, using basic: \(error)")
            layeredComputePipelineState = computePipelineState
        }
    }
    
    private func setupRenderPipeline() throws {
        guard let library = device.makeDefaultLibrary() else {
            throw GPUFractalError.failedToLoadShader
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        
        // Vertex shader for full-screen quad
        guard let vertexFunction = library.makeFunction(name: "fullscreenVertexShader") else {
            throw GPUFractalError.failedToLoadShader
        }
        
        // Fragment shader for texture display
        guard let fragmentFunction = library.makeFunction(name: "textureFragmentShader") else {
            throw GPUFractalError.failedToLoadShader
        }
        
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Set up vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 2
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 4
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
            throw GPUFractalError.failedToCreatePipelineState
        }
    }
    
    func updateAudioData(low: Float, mid: Float, high: Float, overall: Float) {
        audioData.low = low
        audioData.mid = mid
        audioData.high = high
        audioData.overall = overall
        audioData.time = Float(CACurrentMediaTime() - startTime)
        
        // Update fractal parameters based on audio
        updateFractalParameters()
    }
    
    private func updateFractalParameters() {
        // Audio-reactive zoom
        let baseZoom: Float = 2.0
        let zoomVariation = sin(audioData.time * 0.5) * 0.3 + audioData.overall * 0.5
        fractalParams.zoom = baseZoom + zoomVariation
        
        // Audio-reactive center movement
        let centerSpeed: Float = 0.1
        fractalParams.center.x += cos(audioData.time * centerSpeed) * audioData.low * 0.02
        fractalParams.center.y += sin(audioData.time * centerSpeed * 1.3) * audioData.mid * 0.02
        
        // Audio-reactive iterations for detail
        let baseIterations: UInt32 = 60
        let audioBoost = UInt32(audioData.high * 40 + audioData.overall * 20)
        fractalParams.maxIterations = min(150, baseIterations + audioBoost)
        
        // Color phase rotation
        fractalParams.colorPhase += 0.01 + audioData.overall * 0.02
        if fractalParams.colorPhase > 1.0 {
            fractalParams.colorPhase -= 1.0
        }
        
        // Julia constant animation
        if fractalParams.fractalType == 1 { // Julia set
            fractalParams.juliaConstant.x = -0.7 + cos(audioData.time * 0.5) * 0.3 * audioData.overall
            fractalParams.juliaConstant.y = 0.27015 + sin(audioData.time * 0.7) * 0.2 * audioData.mid
        }
        
        // Morph factor for smooth transitions
        fractalParams.morphFactor = sin(audioData.time * 0.2) * 0.5 + 0.5
    }
    
    func updateFractalType() {
        fractalParams.fractalType = UInt32(settingsManager.fractalType)
        
        // Adjust parameters per fractal type
        switch settingsManager.fractalType {
        case 0: // Mandelbrot
            fractalParams.center = SIMD2<Float>(-0.5, 0.0)
            fractalParams.zoom = 2.0
        case 1: // Julia
            fractalParams.center = SIMD2<Float>(0.0, 0.0)
            fractalParams.zoom = 2.5
            fractalParams.juliaConstant = SIMD2<Float>(-0.7, 0.27015)
        case 2: // Burning Ship
            fractalParams.center = SIMD2<Float>(-1.8, -0.08)
            fractalParams.zoom = 1.5
        default: // Spiral
            fractalParams.center = SIMD2<Float>(0.0, 0.0)
            fractalParams.zoom = 3.0
        }
    }
    
    private func createFractalTexture(size: CGSize) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.pixelFormat = .rgba8Unorm
        descriptor.width = Int(size.width)
        descriptor.height = Int(size.height)
        descriptor.usage = [.shaderWrite, .shaderRead]
        
        return device.makeTexture(descriptor: descriptor)
    }
    
    func render(to drawable: CAMetalDrawable, in view: MTKView) {
        guard isAnimating else { return }
        
        // Update timing
        let currentTime = CACurrentMediaTime()
        let deltaTime = Float(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime
        
        // Update resolution
        let drawableSize = drawable.layer.drawableSize
        fractalParams.resolution = SIMD2<UInt32>(UInt32(drawableSize.width), UInt32(drawableSize.height))
        
        // Create or recreate texture if needed
        if fractalTexture?.width != Int(drawableSize.width) || fractalTexture?.height != Int(drawableSize.height) {
            fractalTexture = createFractalTexture(size: drawableSize)
        }
        
        guard let fractalTexture = fractalTexture else { return }
        
        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // Update buffers
        updateBuffers()
        
        // Compute pass - Generate fractal on GPU
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            let pipelineState = useLayeredRendering ? layeredComputePipelineState : computePipelineState
            computeEncoder.setComputePipelineState(pipelineState!)
            
            computeEncoder.setTexture(fractalTexture, index: 0)
            computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(audioBuffer, offset: 0, index: 1)
            
            // Calculate optimal thread group size
            let threadgroupSize = MTLSize(
                width: min(16, fractalTexture.width),
                height: min(16, fractalTexture.height),
                depth: 1
            )
            
            let threadgroupCount = MTLSize(
                width: (fractalTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
                height: (fractalTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
                depth: 1
            )
            
            computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
            computeEncoder.endEncoding()
        }
        
        // Render pass - Display fractal texture
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            renderEncoder.setRenderPipelineState(renderPipelineState)
            renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
            renderEncoder.setFragmentTexture(fractalTexture, index: 0)
            
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()
        }
        
        // Present immediately for minimum latency
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func updateBuffers() {
        // Update parameters buffer
        let paramsPointer = paramsBuffer.contents().bindMemory(to: GPUFractalParams.self, capacity: 1)
        paramsPointer.pointee = fractalParams
        
        // Update audio buffer
        let audioPointer = audioBuffer.contents().bindMemory(to: GPUAudioData.self, capacity: 1)
        audioPointer.pointee = audioData
    }
    
    func reset() {
        fractalParams = GPUFractalParams()
        audioData = GPUAudioData()
        startTime = CACurrentMediaTime()
        updateFractalType()
    }
}

// MARK: - Error Types

enum GPUFractalError: Error, LocalizedError {
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
            return "Failed to load GPU fractal shader"
        case .failedToCreatePipelineState:
            return "Failed to create compute pipeline state"
        case .failedToCreateBuffer:
            return "Failed to create Metal buffer"
        }
    }
}