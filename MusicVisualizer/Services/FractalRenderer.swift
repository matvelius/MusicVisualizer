//
//  FractalRenderer.swift
//  MusicVisualizer
//
//  Created by Claude Code on 7/24/25.
//

import Foundation
import Metal
import MetalKit
import SwiftUI

// MARK: - Fractal Types

enum FractalType: Int, CaseIterable, Identifiable {
    case mandelbrot = 0
    case julia = 1
    case burningShip = 2
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .mandelbrot:
            return "Mandelbrot"
        case .julia:
            return "Julia"
        case .burningShip:
            return "Burning Ship"
        }
    }
}

// MARK: - Fractal Uniforms Structure

struct FractalUniforms {
    var center: SIMD2<Float>
    var zoom: Float
    var maxIterations: UInt32
    var resolution: SIMD2<Float>
    var time: Float
    var colorPalette: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)
    var fractalType: UInt32
    var juliaConstant: SIMD2<Float>
    var audioLow: Float
    var audioMid: Float
    var audioHigh: Float
    var audioOverall: Float
    
    init() {
        center = SIMD2<Float>(0.0, 0.0)
        zoom = 1.0
        maxIterations = 100
        resolution = SIMD2<Float>(1.0, 1.0)
        time = 0.0
        colorPalette = (
            SIMD4<Float>(0.0, 0.0, 0.5, 1.0),  // Dark blue
            SIMD4<Float>(0.0, 0.5, 1.0, 1.0),  // Blue
            SIMD4<Float>(0.5, 1.0, 1.0, 1.0),  // Cyan
            SIMD4<Float>(1.0, 1.0, 0.5, 1.0),  // Yellow
            SIMD4<Float>(1.0, 0.5, 0.0, 1.0),  // Orange
            SIMD4<Float>(1.0, 0.0, 0.5, 1.0),  // Pink
            SIMD4<Float>(0.5, 0.0, 1.0, 1.0),  // Purple
            SIMD4<Float>(0.0, 0.0, 0.0, 1.0)   // Black
        )
        fractalType = 0
        juliaConstant = SIMD2<Float>(-0.7, 0.27015)
        audioLow = 0.0
        audioMid = 0.0
        audioHigh = 0.0
        audioOverall = 0.0
    }
}

// MARK: - Fractal Renderer

@Observable
class FractalRenderer {
    // Metal objects
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var computePipelineState: MTLComputePipelineState
    private var uniformsBuffer: MTLBuffer
    
    // Fractal parameters
    var uniforms: FractalUniforms
    var fractalType: FractalType = .mandelbrot
    var isAnimating: Bool = true
    
    // Performance tracking
    private var startTime: CFTimeInterval
    private let targetFrameRate: Double = 60.0
    private var lastUpdateTime: CFTimeInterval = 0
    
    init() throws {
        // Initialize Metal
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw FractalRendererError.metalNotSupported
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw FractalRendererError.failedToCreateCommandQueue
        }
        
        self.device = device
        self.commandQueue = commandQueue
        
        // Load and compile shader
        guard let library = device.makeDefaultLibrary(),
              let fractalFunction = library.makeFunction(name: "fractalComputeShader") else {
            throw FractalRendererError.failedToLoadShader
        }
        
        do {
            self.computePipelineState = try device.makeComputePipelineState(function: fractalFunction)
        } catch {
            throw FractalRendererError.failedToCreatePipelineState
        }
        
        // Create uniforms buffer
        guard let uniformsBuffer = device.makeBuffer(length: MemoryLayout<FractalUniforms>.size,
                                                   options: .storageModeShared) else {
            throw FractalRendererError.failedToCreateBuffer
        }
        
        self.uniformsBuffer = uniformsBuffer
        self.uniforms = FractalUniforms()
        self.startTime = CACurrentMediaTime()
        
        // Set initial fractal parameters
        setupInitialParameters()
    }
    
    private func setupInitialParameters() {
        uniforms.center = SIMD2<Float>(-0.5, 0.0)  // Classic Mandelbrot view
        uniforms.zoom = 0.8
        uniforms.maxIterations = 100
        uniforms.fractalType = UInt32(fractalType.rawValue)
        
        // Set up default color palette (spectrum-like colors)
        uniforms.colorPalette = (
            SIMD4<Float>(0.1, 0.1, 0.5, 1.0),  // Deep blue
            SIMD4<Float>(0.2, 0.3, 0.8, 1.0),  // Blue
            SIMD4<Float>(0.1, 0.8, 0.9, 1.0),  // Cyan
            SIMD4<Float>(0.3, 0.9, 0.3, 1.0),  // Green
            SIMD4<Float>(0.9, 0.9, 0.1, 1.0),  // Yellow
            SIMD4<Float>(0.9, 0.5, 0.1, 1.0),  // Orange
            SIMD4<Float>(0.9, 0.1, 0.1, 1.0),  // Red
            SIMD4<Float>(0.5, 0.1, 0.5, 1.0)   // Purple
        )
    }
    
    func updateAudioData(low: Float, mid: Float, high: Float, overall: Float) {
        uniforms.audioLow = low
        uniforms.audioMid = mid
        uniforms.audioHigh = high
        uniforms.audioOverall = overall
        
        // Update zoom based on audio intensity
        let baseZoom: Float = 0.8
        let zoomVariation = overall * 0.5
        uniforms.zoom = baseZoom + zoomVariation
        
        // Update iteration count based on high frequencies for detail
        let baseIterations: UInt32 = 80
        let iterationBoost = UInt32(high * 40)
        uniforms.maxIterations = baseIterations + iterationBoost
        
        // Animate Julia constant based on audio
        if fractalType == .julia {
            uniforms.juliaConstant.x = -0.7 + cos(Float(CACurrentMediaTime() - startTime)) * 0.3 * overall
            uniforms.juliaConstant.y = 0.27015 + sin(Float(CACurrentMediaTime() - startTime) * 1.3) * 0.2 * mid
        }
    }
    
    func setFractalType(_ type: FractalType) {
        fractalType = type
        uniforms.fractalType = UInt32(type.rawValue)
        
        // Adjust initial parameters for different fractal types
        switch type {
        case .mandelbrot:
            uniforms.center = SIMD2<Float>(-0.5, 0.0)
            uniforms.zoom = 0.8
        case .julia:
            uniforms.center = SIMD2<Float>(0.0, 0.0)
            uniforms.zoom = 1.2
            uniforms.juliaConstant = SIMD2<Float>(-0.7, 0.27015)
        case .burningShip:
            uniforms.center = SIMD2<Float>(-1.8, -0.08)
            uniforms.zoom = 0.6
        }
    }
    
    func render(to texture: MTLTexture) {
        // Throttle updates to maintain performance
        let currentTime = CACurrentMediaTime()
        let frameInterval = 1.0 / targetFrameRate
        guard currentTime - lastUpdateTime >= frameInterval else { return }
        lastUpdateTime = currentTime
        
        // Update time for animation
        uniforms.time = Float(currentTime - startTime)
        uniforms.resolution = SIMD2<Float>(Float(texture.width), Float(texture.height))
        
        // Update uniforms buffer
        let uniformsPointer = uniformsBuffer.contents().bindMemory(to: FractalUniforms.self, capacity: 1)
        uniformsPointer.pointee = uniforms
        
        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        // Set up compute encoder
        encoder.setComputePipelineState(computePipelineState)
        encoder.setTexture(texture, index: 0)
        encoder.setBuffer(uniformsBuffer, offset: 0, index: 0)
        
        // Calculate thread groups
        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupsPerGrid = MTLSize(
            width: (texture.width + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
            height: (texture.height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}

// MARK: - Error Types

enum FractalRendererError: Error, LocalizedError {
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
            return "Failed to load fractal shader"
        case .failedToCreatePipelineState:
            return "Failed to create compute pipeline state"
        case .failedToCreateBuffer:
            return "Failed to create Metal buffer"
        }
    }
}