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
    
    // Shape variety properties
    var shapeType: Int // 0=circle, 1=triangle, 2=square, 3=hexagon, 4=star
    var morphProgress: Float // Progress through shape transformation
    var nextShapeType: Int // Target shape for morphing
    var morphSpeed: Float // Speed of shape transformation
    var scaleX: Float // Non-uniform scaling for shape variety
    var scaleY: Float
    var opacity: Float // Individual opacity for blending
    
    init(position: SIMD2<Float>, size: Float, generation: Int = 0, fractalType: Int = 0) {
        self.position = position
        self.size = size
        self.rotation = 0.0
        self.color = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
        self.age = 0.0
        self.maxAge = 12.0 + Float.random(in: -4.0...8.0) // 8-20 seconds lifespan
        self.generation = generation
        self.fractalType = fractalType
        self.complexity = 1.0
        self.isAlive = true
        self.lastSpawnTime = 0.0
        self.spawnCooldown = 0.2 + Float.random(in: 0.0...0.3) // Shorter spawn delay for more activity
        self.velocityX = Float.random(in: -0.01...0.01)
        self.velocityY = Float.random(in: -0.01...0.01)
        
        // Initialize shape variety properties
        self.shapeType = Int.random(in: 0...4) // Random initial shape
        self.morphProgress = 0.0
        self.nextShapeType = Int.random(in: 0...4) // Random morph target
        self.morphSpeed = 0.3 + Float.random(in: 0.0...0.7) // Varying morph speeds
        self.scaleX = 0.8 + Float.random(in: 0.0...0.4) // Slight scale variation
        self.scaleY = 0.8 + Float.random(in: 0.0...0.4)
        self.opacity = 0.4 + Float.random(in: 0.0...0.4) // Semi-transparent for blending
    }
    
    mutating func update(deltaTime: Float, audioLow: Float, audioMid: Float, audioHigh: Float, audioOverall: Float) {
        age += deltaTime
        
        // Update position with slight drift and boundary constraints
        let driftSpeed: Float = 0.3 // Reduced drift speed
        let audioMultiplier = 1.0 + audioOverall * 0.5
        let velocityMultiplier = deltaTime * driftSpeed * audioMultiplier
        let newX = position.x + velocityX * velocityMultiplier
        let newY = position.y + velocityY * velocityMultiplier
        
        // Keep particles within screen bounds (normalized coordinates -1 to 1)
        let boundary: Float = 0.9 // Leave small margin
        position.x = max(-boundary, min(boundary, newX))
        position.y = max(-boundary, min(boundary, newY))
        
        // If particle hits boundary, reverse velocity and apply gentle pull toward center
        if abs(position.x) >= boundary || abs(position.y) >= boundary {
            if abs(position.x) >= boundary {
                velocityX *= -0.8 // Reverse and dampen
            }
            if abs(position.y) >= boundary {
                velocityY *= -0.8 // Reverse and dampen
            }
            
            // Add gentle pull toward center
            let centerPull: Float = 0.02
            let distanceFromCenter = sqrt(position.x * position.x + position.y * position.y)
            if distanceFromCenter > 0 {
                velocityX -= (position.x / distanceFromCenter) * centerPull
                velocityY -= (position.y / distanceFromCenter) * centerPull
            }
        }
        
        // Update rotation with audio-reactive speed
        rotation += deltaTime * 0.2 * (1.0 + audioMid * 2.0)
        
        // Update shape morphing based on audio
        morphProgress += deltaTime * morphSpeed * (0.5 + audioHigh * 1.5)
        if morphProgress >= 1.0 {
            // Complete morph - switch to next shape
            shapeType = nextShapeType
            nextShapeType = Int.random(in: 0...4)
            morphProgress = 0.0
            morphSpeed = 0.3 + Float.random(in: 0.0...0.7) // Randomize next morph speed
        }
        
        // Update non-uniform scaling based on audio frequencies
        let scaleVariation = sin(age * 2.0 + Float(generation)) * 0.2 * audioOverall
        scaleX = max(0.5, min(1.5, 1.0 + scaleVariation + audioLow * 0.3))
        scaleY = max(0.5, min(1.5, 1.0 - scaleVariation * 0.7 + audioHigh * 0.3))
        
        // Update color based on selected theme and audio
        color = getThemeBasedColor(audioLow: audioLow, audioMid: audioMid, audioHigh: audioHigh, audioOverall: audioOverall)
        
        // Update size with breathing effect (ensure minimum visible size)
        let breathingFactor = 1.0 + sin(age * 3.0 + Float(generation)) * 0.1 * audioOverall
        let newSize = size * breathingFactor
        size = max(newSize, 0.05) // Ensure particles don't become invisible
        
        // Update opacity for smooth blending effects
        let baseOpacity = 0.3 + audioOverall * 0.4 // More transparent for better blending
        opacity = baseOpacity * getAlpha() // Combine with lifecycle alpha
        
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
    
    func getThemeBasedColor(audioLow: Float, audioMid: Float, audioHigh: Float, audioOverall: Float) -> SIMD4<Float> {
        let settingsManager = SettingsManager.shared
        let theme = settingsManager.colorTheme
        
        // Create a position based on generation, age, and audio for color variety
        let basePosition = (Float(generation) * 0.15 + age * 0.03 + audioMid * 0.5).truncatingRemainder(dividingBy: 1.0)
        let position = Double(max(0, min(1, basePosition)))
        
        // Get the theme color
        let themeColor = theme.color(for: Int(position * 100), totalBands: 100)
        let uiColor = UIColor(themeColor)
        
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Apply audio-reactive intensity modulation
        let intensity = CGFloat(0.7 + audioOverall * 0.3)
        let saturationBoost = CGFloat(1.0 + audioHigh * 0.5)
        
        // Convert to HSV for better intensity control
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Enhance saturation and brightness based on audio
        let enhancedSaturation = min(1.0, saturation * saturationBoost)
        let enhancedBrightness = min(1.0, brightness * intensity)
        
        let finalColor = UIColor(hue: hue, saturation: enhancedSaturation, brightness: enhancedBrightness, alpha: alpha)
        finalColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return SIMD4<Float>(Float(red), Float(green), Float(blue), getAlpha())
    }
    
    func shouldSpawn(currentTime: Float, audioVolume: Float) -> Bool {
        let timeSinceLastSpawn = currentTime - lastSpawnTime
        let volumeSpeedMultiplier = 0.5 + audioVolume * 1.5 // More responsive to volume
        let adjustedCooldown = spawnCooldown / volumeSpeedMultiplier
        
        // More lenient generation limits with guaranteed spawning for early generations
        let maxGeneration = 8 // Simplified max generation
        
        // Guarantee spawning for early generations, reduce probability for later ones
        let generationProbability: Float
        if generation < 3 {
            generationProbability = 1.0 // Always spawn for generations 0-2
        } else if generation < 6 {
            generationProbability = 0.8 // High probability for generations 3-5
        } else {
            generationProbability = 0.4 // Lower but still decent probability for generations 6-7
        }
        
        return timeSinceLastSpawn > adjustedCooldown && 
               generation < maxGeneration && 
               Float.random(in: 0...1) < generationProbability
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
    var shapeType: Int32
    var nextShapeType: Int32
    var morphProgress: Float
    var scaleX: Float
    var scaleY: Float
    var opacity: Float
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
    private let settingsManager = SettingsManager.shared
    
    // Performance tracking
    private var lastUpdateTime: CFTimeInterval = CACurrentMediaTime()
    private var lastRegenerationTime: Float = 0.0
    
    // Public access to particle count for debugging
    var particleCount: Int {
        return particles.count
    }
    
    // Debug information
    var debugInfo: String {
        let generationCounts = Dictionary(grouping: particles, by: { $0.generation })
            .mapValues { $0.count }
            .sorted { $0.key < $1.key }
        
        let generationSummary = generationCounts.map { "G\($0.key): \($0.value)" }.joined(separator: ", ")
        return "Total: \(particles.count) [\(generationSummary)]"
    }
    
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
        
        // Enhanced blending for better transparency and shape overlap
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        
        // Use additive blending for RGB to create glow/blend effects
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one // Additive for glowing blend
        
        // Standard alpha blending for transparency
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
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
            fractalType: settingsManager.fractalType
        )
        particles.append(seedParticle)
    }
    
    private func createSeedParticle() {
        let seedParticle = FractalParticle(
            position: SIMD2<Float>(0.0, 0.0),
            size: 0.3 + Float.random(in: -0.1...0.1),
            generation: 0,
            fractalType: settingsManager.fractalType
        )
        particles.append(seedParticle)
    }
    
    private func createRandomSeedParticle() {
        // Create seed particles in a smaller central area to prevent immediate drift
        let randomPosition = SIMD2<Float>(
            Float.random(in: -0.2...0.2),
            Float.random(in: -0.2...0.2)
        )
        var seedParticle = FractalParticle(
            position: randomPosition,
            size: 0.2 + Float.random(in: 0.0...0.2),
            generation: 0,
            fractalType: settingsManager.fractalType
        )
        // Reduce initial velocity for seed particles
        seedParticle.velocityX *= 0.5
        seedParticle.velocityY *= 0.5
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
            
            // Remove dead particles or particles that somehow got too far off-screen
            if !particles[i].isAlive {
                particles.remove(at: i)
                continue
            }
            
            // Safety check: remove particles that are way off screen (shouldn't happen with new constraints)
            let position = particles[i].position
            if abs(position.x) > 2.0 || abs(position.y) > 2.0 {
                particles.remove(at: i)
                continue
            }
            
            // Spawn children if conditions are met
            if particles[i].shouldSpawn(currentTime: currentTime, audioVolume: audioOverall) {
                spawnChildren(from: i)
                particles[i].lastSpawnTime = currentTime
            }
        }
        
        // Much more aggressive particle regeneration
        let minParticleCount = Int(5 + audioOverall * 10) // 5-15 minimum particles based on audio
        let currentCount = particles.count
        
        // Always ensure minimum population regardless of audio level
        if currentCount == 0 {
            // Emergency regeneration - create multiple seed particles immediately
            for _ in 0..<3 {
                createSeedParticle()
            }
        } else if currentCount < minParticleCount {
            // Add particles aggressively when below threshold
            let particlesToAdd = min(minParticleCount - currentCount, 5) // Add up to 5 per frame
            for _ in 0..<particlesToAdd {
                if audioOverall > 0.05 {
                    createRandomSeedParticle()
                } else {
                    // Even during low audio, maintain some activity
                    createSeedParticle()
                }
            }
        }
        
        // Additional insurance: if we have very few low-generation particles, create more seeds
        let lowGenerationCount = particles.filter { $0.generation < 2 }.count
        if lowGenerationCount < 2 && audioOverall > 0.02 {
            for _ in 0..<(3 - lowGenerationCount) {
                createRandomSeedParticle()
            }
        }
        
        // Time-based safety regeneration: ensure we create new particles at least every 3 seconds
        if currentTime - lastRegenerationTime > 3.0 {
            if particles.count < 8 { // Always maintain at least 8 particles
                for _ in 0..<max(1, 8 - particles.count) {
                    createRandomSeedParticle()
                }
            }
            lastRegenerationTime = currentTime
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
            let baseDistance = parent.size * 1.5 * (0.8 + audioMid * 0.4) // Reduced distance
            
            var childPosition = SIMD2<Float>(
                parent.position.x + cos(angle) * baseDistance,
                parent.position.y + sin(angle) * baseDistance
            )
            
            // Constrain child position to stay within bounds
            let boundary: Float = 0.85
            childPosition.x = max(-boundary, min(boundary, childPosition.x))
            childPosition.y = max(-boundary, min(boundary, childPosition.y))
            
            // If child would spawn out of bounds, pull it back toward parent
            if abs(childPosition.x) >= boundary || abs(childPosition.y) >= boundary {
                let pullFactor: Float = 0.7
                childPosition.x = parent.position.x + (childPosition.x - parent.position.x) * pullFactor
                childPosition.y = parent.position.y + (childPosition.y - parent.position.y) * pullFactor
            }
            
            // Size decreases with generation
            let sizeFactor = pow(0.75, Float(parent.generation + 1)) // Slightly less aggressive size reduction
            let childSize = parent.size * sizeFactor * (0.8 + audioHigh * 0.4)
            
            var child = FractalParticle(
                position: childPosition,
                size: childSize,
                generation: parent.generation + 1,
                fractalType: settingsManager.fractalType
            )
            
            // Set smaller initial velocity to reduce drift
            let velocityScale: Float = 0.008 // Reduced from 0.02
            child.velocityX = cos(angle) * velocityScale
            child.velocityY = sin(angle) * velocityScale
            
            particles.append(child)
            
            // Stop if we hit max particles
            if particles.count >= maxParticles {
                break
            }
        }
    }
    
    func render(to drawable: CAMetalDrawable, in view: MTKView) {
        // Ultra-low latency: no frame throttling, immediate rendering
        let currentSystemTime = CACurrentMediaTime()
        let deltaTime = Float(currentSystemTime - lastUpdateTime)
        lastUpdateTime = currentSystemTime
        
        // Update with actual delta time for smooth animation
        update(deltaTime: min(deltaTime, 0.033)) // Cap at ~30fps delta for stability
        
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
            
            // Create model matrix with non-uniform scaling
            let translation = matrix4x4_translation(particle.position.x, particle.position.y, 0)
            let rotation = matrix4x4_rotation(radians: particle.rotation, axis: SIMD3<Float>(0, 0, 1))
            let scale = matrix4x4_scale(particle.size * particle.scaleX, particle.size * particle.scaleY, 1)
            let modelMatrix = translation * rotation * scale
            
            // Set up uniforms with shape morphing data
            var uniforms = ParticleUniforms(
                modelMatrix: modelMatrix,
                color: SIMD4<Float>(particle.color.x, particle.color.y, particle.color.z, particle.opacity),
                size: particle.size,
                complexity: particle.complexity,
                fractalType: Int32(particle.fractalType),
                generation: Int32(particle.generation),
                shapeType: Int32(particle.shapeType),
                nextShapeType: Int32(particle.nextShapeType),
                morphProgress: particle.morphProgress,
                scaleX: particle.scaleX,
                scaleY: particle.scaleY,
                opacity: particle.opacity
            )
            
            let alignedOffset = alignedUniformSize * index
            let uniformPointer = uniformsBuffer.contents().advanced(by: alignedOffset)
            uniformPointer.copyMemory(from: &uniforms, byteCount: MemoryLayout<ParticleUniforms>.size)
            
            encoder.setVertexBuffer(uniformsBuffer, offset: alignedOffset, index: 1)
            encoder.setFragmentBuffer(uniformsBuffer, offset: alignedOffset, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }
        
        encoder.endEncoding()
        
        // Present immediately for minimum latency
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        // Don't wait for completion - let GPU work asynchronously
    }
    
    func reset() {
        particles.removeAll()
        initializeSeedParticle()
        currentTime = 0.0
    }
    
    func updateFractalType() {
        // Update all existing particles to use the new fractal type
        for i in particles.indices {
            particles[i].fractalType = settingsManager.fractalType
        }
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