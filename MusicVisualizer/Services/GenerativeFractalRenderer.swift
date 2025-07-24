//
//  GenerativeFractalRenderer.swift
//  MusicVisualizer
//
//  Created by Claude Code on 7/24/25.
//

import Foundation
import Metal
import MetalKit
import SwiftUI
import simd

// MARK: - Fractal Particle System

struct FractalParticle {
    var position: SIMD2<Float>
    var size: Float
    var rotation: Float
    var color: SIMD4<Float>
    var age: Float
    var maxAge: Float
    var generation: Int
    var fractalType: Int
    var complexity: Float
    var isAlive: Bool
    var lastSpawnTime: Float
    var spawnCooldown: Float
    var velocityX: Float
    var velocityY: Float
    
    init(position: SIMD2<Float>, size: Float, generation: Int = 0, fractalType: Int = 0) {
        self.position = position
        self.size = size
        self.rotation = 0.0
        self.color = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
        self.age = 0.0
        self.maxAge = 8.0 + Float.random(in: -2.0...4.0) // 6-12 seconds lifespan
        self.generation = generation
        self.fractalType = fractalType
        self.complexity = 1.0
        self.isAlive = true
        self.lastSpawnTime = 0.0
        self.spawnCooldown = 0.5 + Float.random(in: 0.0...1.0) // Random spawn delay
        self.velocityX = Float.random(in: -0.01...0.01)
        self.velocityY = Float.random(in: -0.01...0.01)
    }
    
    mutating func update(deltaTime: Float, audioLow: Float, audioMid: Float, audioHigh: Float, audioOverall: Float) {
        age += deltaTime
        
        // Update position with slight drift
        position.x += velocityX * deltaTime * (1.0 + audioOverall * 0.5)
        position.y += velocityY * deltaTime * (1.0 + audioOverall * 0.5)
        
        // Update rotation
        rotation += deltaTime * 0.2 * (1.0 + audioMid * 2.0)
        
        // Update color based on audio
        let hue = (audioMid + Float(generation) * 0.1).truncatingRemainder(dividingBy: 1.0)
        color = hsvToRgb(h: hue, s: 0.8 + audioHigh * 0.2, v: 0.8 + audioOverall * 0.2, a: getAlpha())
        
        // Update size with breathing effect
        let breathingFactor = 1.0 + sin(age * 3.0 + Float(generation)) * 0.1 * audioOverall
        size *= breathingFactor
        
        // Update complexity
        complexity = 0.5 + audioHigh * 1.5
        
        // Check if particle should die
        if age > maxAge {
            isAlive = false
        }
    }
    
    func getAlpha() -> Float {
        let lifeRatio = age / maxAge
        if lifeRatio < 0.1 {
            // Fade in
            return lifeRatio * 10.0
        } else if lifeRatio > 0.8 {
            // Fade out
            return (1.0 - lifeRatio) * 5.0
        } else {
            // Full opacity
            return 1.0
        }
    }
    
    func shouldSpawn(currentTime: Float, audioVolume: Float) -> Bool {
        let timeSinceLastSpawn = currentTime - lastSpawnTime
        let volumeSpeedMultiplier = 0.3 + audioVolume * 2.0 // Higher volume = faster spawning
        let adjustedCooldown = spawnCooldown / volumeSpeedMultiplier
        
        return timeSinceLastSpawn > adjustedCooldown && generation < 6 // Max 6 generations
    }
}

// MARK: - Particle Uniforms for Metal

struct ParticleUniforms {
    var modelMatrix: simd_float4x4
    var color: SIMD4<Float>
    var size: Float
    var complexity: Float
    var fractalType: Int32
    var generation: Int32
}

// MARK: - Generative Fractal Renderer

class GenerativeFractalRenderer: ObservableObject {
    // Metal objects
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var renderPipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer
    private var uniformsBuffer: MTLBuffer
    
    // Buffer alignment
    private let uniformBufferAlignment: Int = 256 // Metal requires 256-byte alignment
    private let alignedUniformSize: Int
    
    // Particle system
    private var particles: [FractalParticle] = []
    private let maxParticles = 200
    private var currentTime: Float = 0.0
    private let particlePool: [FractalParticle]
    
    // Audio data
    private var audioLow: Float = 0.0
    private var audioMid: Float = 0.0
    private var audioHigh: Float = 0.0
    private var audioOverall: Float = 0.0
    
    // Settings
    var isAnimating: Bool = true
    var generationRate: Float = 1.0
    var maxGenerations: Int = 6
    var particleLifetime: Float = 8.0
    
    // Performance tracking
    private var lastUpdateTime: CFTimeInterval = 0
    private let targetFrameRate: Double = 60.0
    
    init() throws {
        // Calculate aligned uniform buffer size
        let uniformSize = MemoryLayout<ParticleUniforms>.size
        self.alignedUniformSize = (uniformSize + uniformBufferAlignment - 1) & ~(uniformBufferAlignment - 1)
        
        // Initialize Metal
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw GenerativeFractalError.metalNotSupported
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw GenerativeFractalError.failedToCreateCommandQueue
        }
        
        self.device = device
        self.commandQueue = commandQueue
        
        // Create particle pool for performance
        self.particlePool = (0..<maxParticles).map { _ in
            FractalParticle(position: SIMD2<Float>(0, 0), size: 0.1)
        }
        
        // Create buffers with proper alignment
        guard let vertexBuffer = device.makeBuffer(length: MemoryLayout<Float>.size * 6 * 2, options: []),
              let uniformsBuffer = device.makeBuffer(length: alignedUniformSize * maxParticles, options: []) else {
            throw GenerativeFractalError.failedToCreateBuffer
        }
        
        self.vertexBuffer = vertexBuffer
        self.uniformsBuffer = uniformsBuffer
        
        // Set up Metal pipeline
        self.renderPipelineState = try self.setupMetalPipeline()
        
        // Set up quad vertices
        setupQuadVertices()
        
        // Initialize with single seed particle
        initializeSeedParticle()
    }
    
    private func setupMetalPipeline() throws -> MTLRenderPipelineState {
        guard let library = device.makeDefaultLibrary() else {
            throw GenerativeFractalError.failedToLoadShader
        }
        
        // Create render pipeline for instanced particle rendering
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        
        guard let vertexFunction = library.makeFunction(name: "particleVertexShader") else {
            print("Failed to find particleVertexShader function")
            throw GenerativeFractalError.failedToLoadShader
        }
        
        guard let fragmentFunction = library.makeFunction(name: "particleFragmentShader") else {
            print("Failed to find particleFragmentShader function")
            throw GenerativeFractalError.failedToLoadShader
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
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
            if let error = error as? MTLLibraryError {
                print("MTLLibraryError: \(error)")
            }
            throw GenerativeFractalError.failedToCreatePipelineState
        }
    }
    
    private func setupQuadVertices() {
        // Simple quad vertices for particle rendering
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
    
    private func initializeSeedParticle() {
        particles.removeAll()
        let seedParticle = FractalParticle(
            position: SIMD2<Float>(0.0, 0.0),
            size: 0.3,
            generation: 0,
            fractalType: 0
        )
        particles.append(seedParticle)
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
        
        // Update existing particles
        for i in particles.indices.reversed() {
            particles[i].update(deltaTime: deltaTime, audioLow: audioLow, audioMid: audioMid, audioHigh: audioHigh, audioOverall: audioOverall)
            
            // Remove dead particles
            if !particles[i].isAlive {
                particles.remove(at: i)
                continue
            }
            
            // Spawn children if conditions are met
            if particles[i].shouldSpawn(currentTime: currentTime, audioVolume: audioOverall) {
                spawnChildren(from: i)
                particles[i].lastSpawnTime = currentTime
            }
        }
    }
    
    private func spawnChildren(from parentIndex: Int) {
        let parent = particles[parentIndex]
        
        // Don't spawn if we're at max capacity
        guard particles.count < maxParticles else { return }
        
        // Number of children based on audio intensity and generation
        let baseChildren = max(1, Int(audioLow * 4))
        let childCount = max(1, min(4, baseChildren - parent.generation))
        
        let goldenAngle = Float.pi * (3.0 - sqrt(5.0)) // Golden ratio angle
        
        for i in 0..<childCount {
            // Calculate spawn position using golden ratio spiral
            let angle = goldenAngle * Float(i) + parent.rotation
            let distance = parent.size * 2.0 * (1.0 + audioMid * 0.5)
            
            let childPosition = SIMD2<Float>(
                parent.position.x + cos(angle) * distance,
                parent.position.y + sin(angle) * distance
            )
            
            // Size decreases with generation
            let sizeFactor = pow(0.7, Float(parent.generation + 1))
            let childSize = parent.size * sizeFactor * (0.8 + audioHigh * 0.4)
            
            var child = FractalParticle(
                position: childPosition,
                size: childSize,
                generation: parent.generation + 1,
                fractalType: parent.fractalType
            )
            
            // Set initial velocity away from parent
            child.velocityX = cos(angle) * 0.02
            child.velocityY = sin(angle) * 0.02
            
            particles.append(child)
            
            // Stop if we hit max particles
            if particles.count >= maxParticles {
                break
            }
        }
    }
    
    func render(to drawable: CAMetalDrawable, in view: MTKView) {
        // Throttle updates for performance
        let currentSystemTime = CACurrentMediaTime()
        guard currentSystemTime - lastUpdateTime >= 1.0 / targetFrameRate else { return }
        lastUpdateTime = currentSystemTime
        
        let deltaTime = Float(1.0 / targetFrameRate)
        update(deltaTime: deltaTime)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // Render each particle
        for (index, particle) in particles.enumerated() {
            guard index < maxParticles else { break }
            
            // Create model matrix
            let translation = matrix4x4_translation(particle.position.x, particle.position.y, 0)
            let rotation = matrix4x4_rotation(radians: particle.rotation, axis: SIMD3<Float>(0, 0, 1))
            let scale = matrix4x4_scale(particle.size, particle.size, 1)
            let modelMatrix = translation * rotation * scale
            
            // Set up uniforms
            var uniforms = ParticleUniforms(
                modelMatrix: modelMatrix,
                color: particle.color,
                size: particle.size,
                complexity: particle.complexity,
                fractalType: Int32(particle.fractalType),
                generation: Int32(particle.generation)
            )
            
            let alignedOffset = alignedUniformSize * index
            let uniformPointer = uniformsBuffer.contents().advanced(by: alignedOffset)
            uniformPointer.copyMemory(from: &uniforms, byteCount: MemoryLayout<ParticleUniforms>.size)
            
            encoder.setVertexBuffer(uniformsBuffer, offset: alignedOffset, index: 1)
            encoder.setFragmentBuffer(uniformsBuffer, offset: alignedOffset, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func reset() {
        particles.removeAll()
        initializeSeedParticle()
        currentTime = 0.0
    }
}

// MARK: - Utility Functions

func hsvToRgb(h: Float, s: Float, v: Float, a: Float) -> SIMD4<Float> {
    let c = v * s
    let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
    let m = v - c
    
    var rgb: SIMD3<Float>
    
    if h < 1.0 / 6.0 {
        rgb = SIMD3<Float>(c, x, 0)
    } else if h < 2.0 / 6.0 {
        rgb = SIMD3<Float>(x, c, 0)
    } else if h < 3.0 / 6.0 {
        rgb = SIMD3<Float>(0, c, x)
    } else if h < 4.0 / 6.0 {
        rgb = SIMD3<Float>(0, x, c)
    } else if h < 5.0 / 6.0 {
        rgb = SIMD3<Float>(x, 0, c)
    } else {
        rgb = SIMD3<Float>(c, 0, x)
    }
    
    return SIMD4<Float>(rgb.x + m, rgb.y + m, rgb.z + m, a)
}

func matrix4x4_translation(_ x: Float, _ y: Float, _ z: Float) -> simd_float4x4 {
    return simd_float4x4(
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(0, 0, 1, 0),
        SIMD4<Float>(x, y, z, 1)
    )
}

func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> simd_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    
    return simd_float4x4(
        SIMD4<Float>(ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
        SIMD4<Float>(x * y * ci - z * st, ct + y * y * ci, z * y * ci + x * st, 0),
        SIMD4<Float>(x * z * ci + y * st, y * z * ci - x * st, ct + z * z * ci, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
}

func matrix4x4_scale(_ x: Float, _ y: Float, _ z: Float) -> simd_float4x4 {
    return simd_float4x4(
        SIMD4<Float>(x, 0, 0, 0),
        SIMD4<Float>(0, y, 0, 0),
        SIMD4<Float>(0, 0, z, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
}

// MARK: - Error Types

enum GenerativeFractalError: Error, LocalizedError {
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
            return "Failed to load particle shader"
        case .failedToCreatePipelineState:
            return "Failed to create render pipeline state"
        case .failedToCreateBuffer:
            return "Failed to create Metal buffer"
        }
    }
}