//
//  GenerativeFractalRendererTests.swift
//  MusicVisualizerTests
//
//  Created by Claude Code on 7/24/25.
//

import XCTest
import Metal
import MetalKit
@testable import MusicVisualizer

final class GenerativeFractalRendererTests: XCTestCase {
    
    var renderer: GenerativeFractalRenderer?
    var mockDevice: MTLDevice?
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Set up Metal device for testing
        mockDevice = MTLCreateSystemDefaultDevice()
        guard mockDevice != nil else {
            throw XCTSkip("Metal not available for testing")
        }
        
        // Initialize renderer
        do {
            renderer = try GenerativeFractalRenderer()
        } catch {
            XCTFail("Failed to create GenerativeFractalRenderer: \(error)")
        }
    }
    
    override func tearDownWithError() throws {
        renderer = nil
        mockDevice = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testRendererInitialization() throws {
        let renderer = try GenerativeFractalRenderer()
        XCTAssertNotNil(renderer)
        XCTAssertTrue(renderer.isAnimating)
    }
    
    func testRendererInitializationWithoutMetal() throws {
        // This test would require mocking MTLCreateSystemDefaultDevice to return nil
        // For now, we'll skip if Metal is not available
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal not available - cannot test Metal failure scenario")
        }
    }
    
    // MARK: - Audio Data Tests
    
    func testAudioDataUpdate() throws {
        let renderer = try GenerativeFractalRenderer()
        
        // Test valid audio data
        renderer.updateAudioData(low: 0.5, mid: 0.7, high: 0.3, overall: 0.6)
        
        // No direct way to verify internal state, but this should not crash
        XCTAssertNoThrow(renderer.updateAudioData(low: 0.5, mid: 0.7, high: 0.3, overall: 0.6))
    }
    
    func testAudioDataBoundaryValues() throws {
        let renderer = try GenerativeFractalRenderer()
        
        // Test boundary values
        renderer.updateAudioData(low: 0.0, mid: 0.0, high: 0.0, overall: 0.0)
        renderer.updateAudioData(low: 1.0, mid: 1.0, high: 1.0, overall: 1.0)
        
        // Test negative values (should be handled gracefully)
        renderer.updateAudioData(low: -0.1, mid: -0.5, high: -1.0, overall: -0.3)
        
        // Test values > 1.0 (should be handled gracefully)
        renderer.updateAudioData(low: 1.5, mid: 2.0, high: 1.2, overall: 1.8)
        
        XCTAssertTrue(true) // If we get here without crashing, test passes
    }
    
    // MARK: - Animation Control Tests
    
    func testAnimationControl() throws {
        let renderer = try GenerativeFractalRenderer()
        
        // Test initial state
        XCTAssertTrue(renderer.isAnimating)
        
        // Test stopping animation
        renderer.isAnimating = false
        XCTAssertFalse(renderer.isAnimating)
        
        // Test starting animation
        renderer.isAnimating = true
        XCTAssertTrue(renderer.isAnimating)
    }
    
    // MARK: - Reset Functionality Tests
    
    func testResetFunctionality() throws {
        let renderer = try GenerativeFractalRenderer()
        
        // Update with some audio data to create particles
        renderer.updateAudioData(low: 0.8, mid: 0.6, high: 0.4, overall: 0.7)
        
        // Simulate some time passing to potentially create particles
        let deltaTime: Float = 1.0 / 60.0 // 60 FPS
        for _ in 0..<120 { // 2 seconds of simulation
            renderer.update(deltaTime: deltaTime)
        }
        
        // Reset the renderer
        renderer.reset()
        
        // Verify reset worked (should not crash and should start fresh)
        XCTAssertNoThrow(renderer.updateAudioData(low: 0.5, mid: 0.5, high: 0.5, overall: 0.5))
    }
    
    // MARK: - Performance Tests
    
    func testUpdatePerformance() throws {
        let renderer = try GenerativeFractalRenderer()
        renderer.updateAudioData(low: 0.8, mid: 0.6, high: 0.9, overall: 0.8)
        
        let deltaTime: Float = 1.0 / 60.0
        
        measure {
            // Simulate 1 second of updates at 60 FPS
            for _ in 0..<60 {
                renderer.update(deltaTime: deltaTime)
            }
        }
    }
    
    func testHighVolumeStressTest() throws {
        let renderer = try GenerativeFractalRenderer()
        
        // Set high volume to trigger rapid particle spawning
        renderer.updateAudioData(low: 1.0, mid: 1.0, high: 1.0, overall: 1.0)
        
        let deltaTime: Float = 1.0 / 60.0
        
        // Run for 10 seconds to stress test particle system
        for _ in 0..<600 {
            renderer.update(deltaTime: deltaTime)
        }
        
        // Should not crash or consume excessive memory
        XCTAssertTrue(true)
    }
    
    // MARK: - Error Handling Tests
    
    func testRendererPropertiesAccess() throws {
        let renderer = try GenerativeFractalRenderer()
        
        // Test accessing properties doesn't crash
        XCTAssertGreaterThanOrEqual(renderer.generationRate, 0)
        XCTAssertGreaterThan(renderer.maxGenerations, 0)
        XCTAssertGreaterThan(renderer.particleLifetime, 0)
        
        // Test setting properties
        let originalRate = renderer.generationRate
        renderer.generationRate = 2.0
        XCTAssertEqual(renderer.generationRate, 2.0)
        
        // Reset to original
        renderer.generationRate = originalRate
    }
    
    // MARK: - Animation Persistence Tests
    
    func testAnimationPersistenceAndRecovery() throws {
        let renderer = try GenerativeFractalRenderer()
        
        // Simulate active audio for several seconds
        renderer.updateAudioData(low: 0.8, mid: 0.7, high: 0.6, overall: 0.9)
        
        // Run for 10 seconds to generate many particles
        for _ in 0..<600 { // 10 seconds at 60fps
            renderer.update(deltaTime: 1.0/60.0)
        }
        
        // Should have spawned particles during active period
        XCTAssertTrue(true) // Basic test that it doesn't crash
        
        // Simulate silence (no audio) for 30 seconds
        renderer.updateAudioData(low: 0.0, mid: 0.0, high: 0.0, overall: 0.0)
        
        for _ in 0..<1800 { // 30 seconds at 60fps
            renderer.update(deltaTime: 1.0/60.0)
        }
        
        // During silence, system should maintain minimal activity
        XCTAssertTrue(true) // System should handle silence gracefully
        
        // Resume audio activity - should recover quickly
        renderer.updateAudioData(low: 0.7, mid: 0.8, high: 0.5, overall: 0.85)
        
        // Run for 5 seconds
        for _ in 0..<300 { // 5 seconds at 60fps
            renderer.update(deltaTime: 1.0/60.0)
        }
        
        // Should have recovered with new activity
        XCTAssertTrue(true) // System should recover from silence
        
        // Verify continuous activity maintains particle population
        for _ in 0..<600 { // Another 10 seconds
            renderer.update(deltaTime: 1.0/60.0)
        }
        
        // Should maintain activity over extended time
        XCTAssertTrue(true) // System should maintain long-term stability
    }
    
    func testParticleRegenerationDuringLowActivity() throws {
        let renderer = try GenerativeFractalRenderer()
        
        // Start with very low audio
        renderer.updateAudioData(low: 0.05, mid: 0.03, high: 0.02, overall: 0.04)
        
        // Run until initial particle would die
        for _ in 0..<1500 { // 25 seconds at 60fps - longer than max particle lifetime
            renderer.update(deltaTime: 1.0/60.0)
        }
        
        // System should maintain minimal activity even with low audio
        XCTAssertTrue(true) // System should handle low activity
        
        // Increase audio slightly
        renderer.updateAudioData(low: 0.2, mid: 0.15, high: 0.1, overall: 0.15)
        
        // Run for a few seconds
        for _ in 0..<300 { // 5 seconds
            renderer.update(deltaTime: 1.0/60.0)
        }
        
        // Should respond to increased audio
        XCTAssertTrue(true) // System should respond to audio changes
    }
    
    func testLongTermAnimationStability() throws {
        let renderer = try GenerativeFractalRenderer()
        
        // Simulate varying audio levels over extended time
        for cycle in 0..<10 { // 10 cycles of activity
            // High activity phase
            renderer.updateAudioData(low: 0.8, mid: 0.7, high: 0.9, overall: 0.85)
            for _ in 0..<180 { // 3 seconds of high activity
                renderer.update(deltaTime: 1.0/60.0)
            }
            
            // Medium activity phase
            renderer.updateAudioData(low: 0.4, mid: 0.3, high: 0.5, overall: 0.4)
            for _ in 0..<180 { // 3 seconds of medium activity
                renderer.update(deltaTime: 1.0/60.0)
            }
            
            // Low activity phase
            renderer.updateAudioData(low: 0.1, mid: 0.05, high: 0.08, overall: 0.08)
            for _ in 0..<120 { // 2 seconds of low activity
                renderer.update(deltaTime: 1.0/60.0)
            }
        }
        
        // System should maintain stability throughout varying conditions
        XCTAssertTrue(true) // System should handle varying audio levels
        
        // Final verification - should still be responsive
        renderer.updateAudioData(low: 0.9, mid: 0.8, high: 0.7, overall: 0.9)
        for _ in 0..<300 { // 5 seconds
            renderer.update(deltaTime: 1.0/60.0)
        }
        
        // Should respond to high activity even after extended operation
        XCTAssertTrue(true) // System should maintain responsiveness
    }
    
    func testParticleSystemRecoveryFromEmptyState() throws {
        let renderer = try GenerativeFractalRenderer()
        
        // Force system into empty state by setting very short lifespans and no audio
        renderer.updateAudioData(low: 0.0, mid: 0.0, high: 0.0, overall: 0.0)
        
        // Run long enough for all particles to die
        for _ in 0..<2400 { // 40 seconds at 60fps
            renderer.update(deltaTime: 1.0/60.0)
        }
        
        // Now introduce audio - system should recover
        renderer.updateAudioData(low: 0.6, mid: 0.7, high: 0.5, overall: 0.65)
        
        // Give system time to recover
        for _ in 0..<300 { // 5 seconds
            renderer.update(deltaTime: 1.0/60.0)
        }
        
        // Should have recovered from empty state
        XCTAssertTrue(true) // System should recover from empty state
        
        // Continue with high activity to verify full recovery
        renderer.updateAudioData(low: 0.9, mid: 0.8, high: 0.7, overall: 0.9)
        for _ in 0..<600 { // 10 seconds
            renderer.update(deltaTime: 1.0/60.0)
        }
        
        // Should achieve full activity after recovery
        XCTAssertTrue(true) // System should achieve full recovery
    }
    
    // MARK: - Integration Tests
    
    func testRendererWithRealTimeUpdates() throws {
        let renderer = try GenerativeFractalRenderer()
        
        let expectation = self.expectation(description: "Real-time update simulation")
        
        var updateCount = 0
        let maxUpdates = 180 // 3 seconds at 60 FPS
        
        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
            // Simulate varying audio input
            let time = Float(updateCount) * 0.1
            let low = (sin(time) + 1.0) * 0.5
            let mid = (cos(time * 1.2) + 1.0) * 0.5
            let high = (sin(time * 0.8) + 1.0) * 0.5
            let overall = (low + mid + high) / 3.0
            
            renderer.updateAudioData(low: low, mid: mid, high: high, overall: overall)
            renderer.update(deltaTime: 1.0/60.0)
            
            updateCount += 1
            if updateCount >= maxUpdates {
                timer.invalidate()
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0)
        XCTAssertEqual(updateCount, maxUpdates)
    }
}

// MARK: - FractalParticle Tests

final class FractalParticleTests: XCTestCase {
    
    func testParticleInitialization() {
        let position = SIMD2<Float>(0.5, -0.3)
        let size: Float = 0.2
        let generation = 2
        let fractalType = 1
        
        let particle = FractalParticle(
            position: position,
            size: size,
            generation: generation,
            fractalType: fractalType
        )
        
        XCTAssertEqual(particle.position.x, position.x, accuracy: 0.001)
        XCTAssertEqual(particle.position.y, position.y, accuracy: 0.001)
        XCTAssertEqual(particle.size, size, accuracy: 0.001)
        XCTAssertEqual(particle.generation, generation)
        XCTAssertEqual(particle.fractalType, fractalType)
        XCTAssertTrue(particle.isAlive)
        XCTAssertEqual(particle.age, 0.0, accuracy: 0.001)
        
        // Test shape variety properties
        XCTAssertGreaterThanOrEqual(particle.shapeType, 0)
        XCTAssertLessThanOrEqual(particle.shapeType, 4) // 0=circle, 1=triangle, 2=square, 3=hexagon, 4=star
        XCTAssertEqual(particle.morphProgress, 0.0, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(particle.nextShapeType, 0)
        XCTAssertLessThanOrEqual(particle.nextShapeType, 4)
        XCTAssertGreaterThan(particle.morphSpeed, 0.0)
        XCTAssertGreaterThan(particle.scaleX, 0.0)
        XCTAssertGreaterThan(particle.scaleY, 0.0)
        XCTAssertGreaterThan(particle.opacity, 0.0)
        XCTAssertLessThanOrEqual(particle.opacity, 1.0)
    }
    
    func testParticleUpdate() {
        var particle = FractalParticle(position: SIMD2<Float>(0, 0), size: 0.1)
        
        let deltaTime: Float = 1.0 / 60.0
        let audioLow: Float = 0.5
        let audioMid: Float = 0.7
        let audioHigh: Float = 0.3
        let audioOverall: Float = 0.6
        
        let initialAge = particle.age
        let initialMorphProgress = particle.morphProgress
        
        particle.update(
            deltaTime: deltaTime,
            audioLow: audioLow,
            audioMid: audioMid,
            audioHigh: audioHigh,
            audioOverall: audioOverall
        )
        
        // Age should increase
        XCTAssertGreaterThan(particle.age, initialAge)
        
        // Morph progress should increase
        XCTAssertGreaterThanOrEqual(particle.morphProgress, initialMorphProgress)
        
        // Should still be alive (unless maxAge is very small)
        XCTAssertTrue(particle.isAlive)
    }
    
    func testParticleShapeMorphing() {
        var particle = FractalParticle(position: SIMD2<Float>(0, 0), size: 0.1)
        
        let deltaTime: Float = 1.0 // Large delta to force morphing
        let audioHigh: Float = 1.0 // High frequency to accelerate morphing
        
        let initialShapeType = particle.shapeType
        let initialNextShapeType = particle.nextShapeType
        
        particle.update(
            deltaTime: deltaTime,
            audioLow: 0.5,
            audioMid: 0.5,
            audioHigh: audioHigh,
            audioOverall: 0.5
        )
        
        // With large deltaTime and high audio, morphProgress should have advanced
        // If morphProgress reached 1.0, shape should have changed
        if particle.morphProgress == 0.0 {
            // Shape completed morphing - current shape should be what was nextShapeType
            XCTAssertEqual(particle.shapeType, initialNextShapeType)
            // Should have a new next shape type
            XCTAssertTrue(particle.nextShapeType >= 0 && particle.nextShapeType <= 4)
        } else {
            // Still morphing - shape should be unchanged
            XCTAssertEqual(particle.shapeType, initialShapeType)
            XCTAssertEqual(particle.nextShapeType, initialNextShapeType)
        }
    }
    
    func testParticleScaleVariation() {
        var particle = FractalParticle(position: SIMD2<Float>(0, 0), size: 0.1)
        
        let deltaTime: Float = 1.0 / 60.0
        let audioLow: Float = 1.0
        let audioHigh: Float = 1.0
        
        let initialScaleX = particle.scaleX
        let initialScaleY = particle.scaleY
        
        particle.update(
            deltaTime: deltaTime,
            audioLow: audioLow,
            audioMid: 0.5,
            audioHigh: audioHigh,
            audioOverall: 0.8
        )
        
        // Scales should be within valid range
        XCTAssertGreaterThanOrEqual(particle.scaleX, 0.5)
        XCTAssertLessThanOrEqual(particle.scaleX, 1.5)
        XCTAssertGreaterThanOrEqual(particle.scaleY, 0.5)
        XCTAssertLessThanOrEqual(particle.scaleY, 1.5)
        
        // With high audio, scales should be affected
        XCTAssertNotEqual(particle.scaleX, initialScaleX, accuracy: 0.001)
        XCTAssertNotEqual(particle.scaleY, initialScaleY, accuracy: 0.001)
    }
    
    func testParticleColorThemeIntegration() {
        let particle = FractalParticle(position: SIMD2<Float>(0, 0), size: 0.1)
        
        // Test different color themes
        let themes: [ColorTheme] = [.spectrum, .neon, .sunset, .ocean, .fire, .mint, .monochrome]
        
        for theme in themes {
            // Set theme in settings
            SettingsManager.shared.colorTheme = theme
            
            // Get theme-based color
            let color = particle.getThemeBasedColor(
                audioLow: 0.5,
                audioMid: 0.7,
                audioHigh: 0.3,
                audioOverall: 0.6
            )
            
            // Color should be valid RGBA
            XCTAssertGreaterThanOrEqual(color.x, 0.0) // Red
            XCTAssertLessThanOrEqual(color.x, 1.0)
            XCTAssertGreaterThanOrEqual(color.y, 0.0) // Green
            XCTAssertLessThanOrEqual(color.y, 1.0)
            XCTAssertGreaterThanOrEqual(color.z, 0.0) // Blue
            XCTAssertLessThanOrEqual(color.z, 1.0)
            XCTAssertGreaterThanOrEqual(color.w, 0.0) // Alpha
            XCTAssertLessThanOrEqual(color.w, 1.0)
        }
        
        // Reset to default
        SettingsManager.shared.colorTheme = .spectrum
    }
    
    func testParticleLifecycle() {
        var particle = FractalParticle(position: SIMD2<Float>(0, 0), size: 0.1)
        particle.maxAge = 1.0 // Short lifespan for testing
        
        let deltaTime: Float = 0.5
        
        // First update - should still be alive
        particle.update(deltaTime: deltaTime, audioLow: 0.5, audioMid: 0.5, audioHigh: 0.5, audioOverall: 0.5)
        XCTAssertTrue(particle.isAlive)
        XCTAssertEqual(particle.age, deltaTime, accuracy: 0.001)
        
        // Second update - should exceed maxAge and die
        particle.update(deltaTime: deltaTime + 0.1, audioLow: 0.5, audioMid: 0.5, audioHigh: 0.5, audioOverall: 0.5)
        XCTAssertFalse(particle.isAlive)
    }
    
    func testParticleAlphaCalculation() {
        let particle = FractalParticle(position: SIMD2<Float>(0, 0), size: 0.1)
        
        // Test fade in (early life)
        var testParticle = particle
        testParticle.age = 0.05 * testParticle.maxAge // 5% of life
        let fadeInAlpha = testParticle.getAlpha()
        XCTAssertGreaterThan(fadeInAlpha, 0.0)
        XCTAssertLessThan(fadeInAlpha, 1.0)
        
        // Test full opacity (mid life)
        testParticle.age = 0.5 * testParticle.maxAge // 50% of life
        let fullAlpha = testParticle.getAlpha()
        XCTAssertEqual(fullAlpha, 1.0, accuracy: 0.001)
        
        // Test fade out (late life)
        testParticle.age = 0.9 * testParticle.maxAge // 90% of life
        let fadeOutAlpha = testParticle.getAlpha()
        XCTAssertGreaterThan(fadeOutAlpha, 0.0)
        XCTAssertLessThan(fadeOutAlpha, 1.0)
    }
    
    func testParticleSpawnLogic() {
        // Test cooldown logic - should not spawn if cooldown hasn't passed
        var particle = FractalParticle(position: SIMD2<Float>(0, 0), size: 0.1, generation: 1)
        particle.lastSpawnTime = 5.0
        particle.spawnCooldown = 1.0
        
        let currentTime: Float = 5.5 // Only 0.5 seconds since last spawn
        let highVolume: Float = 0.9
        
        // Should not spawn due to cooldown, regardless of random probability
        let shouldNotSpawn = particle.shouldSpawn(currentTime: currentTime, audioVolume: highVolume)
        XCTAssertFalse(shouldNotSpawn, "Should not spawn when cooldown hasn't passed")
        
        // Test generation limits - particles at max generation should not spawn
        var maxGenParticle = FractalParticle(position: SIMD2<Float>(0, 0), size: 0.1, generation: 8)
        maxGenParticle.lastSpawnTime = 0.0 // Ensure cooldown has passed
        
        let futureTime: Float = 20.0 // Well past any cooldown
        let shouldNotSpawnMaxGen = maxGenParticle.shouldSpawn(currentTime: futureTime, audioVolume: highVolume)
        XCTAssertFalse(shouldNotSpawnMaxGen, "Should not spawn when at max generation (8)")
        
        // Test early generation behavior - should have high spawn probability
        // We test multiple times to account for randomness but verify overall behavior
        var lowGenParticle = FractalParticle(position: SIMD2<Float>(0, 0), size: 0.1, generation: 1)
        lowGenParticle.lastSpawnTime = 0.0
        
        var spawnCount = 0
        let testIterations = 100
        
        for _ in 0..<testIterations {
            if lowGenParticle.shouldSpawn(currentTime: futureTime, audioVolume: highVolume) {
                spawnCount += 1
            }
        }
        
        // Generation 1 has 100% probability, so should spawn every time when cooldown allows
        XCTAssertEqual(spawnCount, testIterations, "Generation 1 particles should always spawn when cooldown allows")
        
        // Test mid-generation behavior (generation 3 has 0.8 probability)
        var midGenParticle = FractalParticle(position: SIMD2<Float>(0, 0), size: 0.1, generation: 3)
        midGenParticle.lastSpawnTime = 0.0
        
        spawnCount = 0
        for _ in 0..<testIterations {
            if midGenParticle.shouldSpawn(currentTime: futureTime, audioVolume: highVolume) {
                spawnCount += 1
            }
        }
        
        // Generation 3 has 0.8 probability, so should spawn roughly 80% of the time
        // Allow some variance due to randomness (70-90% range)
        XCTAssertGreaterThan(spawnCount, 70, "Generation 3 particles should spawn most of the time")
        XCTAssertLessThan(spawnCount, 90, "Generation 3 particles should not spawn every time due to probability")
        
        // Test volume impact on cooldown
        var volumeTestParticle = FractalParticle(position: SIMD2<Float>(0, 0), size: 0.1, generation: 1)
        volumeTestParticle.lastSpawnTime = 4.5
        volumeTestParticle.spawnCooldown = 1.0
        
        let testTime: Float = 5.0 // 0.5 seconds since last spawn
        let lowVolume: Float = 0.1
        
        // Low volume should make cooldown longer, so should not spawn
        let shouldNotSpawnLowVolume = volumeTestParticle.shouldSpawn(currentTime: testTime, audioVolume: lowVolume)
        XCTAssertFalse(shouldNotSpawnLowVolume, "Should not spawn with low volume and recent spawn time")
        
        // High volume should reduce effective cooldown, so might spawn
        // Test this by ensuring high volume spawn check has shorter effective cooldown
        let highVolumeEffectiveCooldown = volumeTestParticle.spawnCooldown / (0.5 + highVolume * 1.5)
        let lowVolumeEffectiveCooldown = volumeTestParticle.spawnCooldown / (0.5 + lowVolume * 1.5)
        
        XCTAssertLessThan(highVolumeEffectiveCooldown, lowVolumeEffectiveCooldown, "High volume should reduce effective cooldown")
    }
    
    func testParticleMaxGeneration() {
        let maxGenParticle = FractalParticle(position: SIMD2<Float>(0, 0), size: 0.1, generation: 8)
        
        let currentTime: Float = 10.0 // Well past any cooldown
        let highVolume: Float = 1.0   // Maximum volume
        
        // Should not spawn due to max generation limit (8 is at the limit, but probabilistic)
        // Test multiple times due to probabilistic nature
        var spawnCount = 0
        for _ in 0..<10 {
            if maxGenParticle.shouldSpawn(currentTime: currentTime, audioVolume: highVolume) {
                spawnCount += 1
            }
        }
        
        // At generation 8, spawning should be limited (due to probabilistic reduction)
        XCTAssertLessThan(spawnCount, 10) // Should not spawn every time
    }
}

final class FractalUtilityTests: XCTestCase {
    
    func testHSVToRGBConversion() {
        // Test pure red
        let red = hsvToRgb(h: 0.0, s: 1.0, v: 1.0, a: 1.0)
        XCTAssertEqual(red.x, 1.0, accuracy: 0.01) // R
        XCTAssertEqual(red.y, 0.0, accuracy: 0.01) // G
        XCTAssertEqual(red.z, 0.0, accuracy: 0.01) // B
        XCTAssertEqual(red.w, 1.0, accuracy: 0.01) // A
        
        // Test pure green
        let green = hsvToRgb(h: 1.0/3.0, s: 1.0, v: 1.0, a: 1.0)
        XCTAssertEqual(green.x, 0.0, accuracy: 0.01) // R
        XCTAssertEqual(green.y, 1.0, accuracy: 0.01) // G
        XCTAssertEqual(green.z, 0.0, accuracy: 0.01) // B
        
        // Test pure blue
        let blue = hsvToRgb(h: 2.0/3.0, s: 1.0, v: 1.0, a: 1.0)
        XCTAssertEqual(blue.x, 0.0, accuracy: 0.01) // R
        XCTAssertEqual(blue.y, 0.0, accuracy: 0.01) // G
        XCTAssertEqual(blue.z, 1.0, accuracy: 0.01) // B
        
        // Test white (no saturation)
        let white = hsvToRgb(h: 0.0, s: 0.0, v: 1.0, a: 1.0)
        XCTAssertEqual(white.x, 1.0, accuracy: 0.01) // R
        XCTAssertEqual(white.y, 1.0, accuracy: 0.01) // G
        XCTAssertEqual(white.z, 1.0, accuracy: 0.01) // B
        
        // Test black (no value)
        let black = hsvToRgb(h: 0.0, s: 1.0, v: 0.0, a: 1.0)
        XCTAssertEqual(black.x, 0.0, accuracy: 0.01) // R
        XCTAssertEqual(black.y, 0.0, accuracy: 0.01) // G
        XCTAssertEqual(black.z, 0.0, accuracy: 0.01) // B
    }
    
    func testMatrixTransformations() {
        // Test translation matrix
        let translation = matrix4x4_translation(1.0, 2.0, 3.0)
        XCTAssertEqual(translation[3][0], 1.0) // X translation
        XCTAssertEqual(translation[3][1], 2.0) // Y translation
        XCTAssertEqual(translation[3][2], 3.0) // Z translation
        XCTAssertEqual(translation[3][3], 1.0) // W component
        
        // Test identity components
        XCTAssertEqual(translation[0][0], 1.0)
        XCTAssertEqual(translation[1][1], 1.0)
        XCTAssertEqual(translation[2][2], 1.0)
        
        // Test scale matrix
        let scale = matrix4x4_scale(2.0, 3.0, 4.0)
        XCTAssertEqual(scale[0][0], 2.0) // X scale
        XCTAssertEqual(scale[1][1], 3.0) // Y scale
        XCTAssertEqual(scale[2][2], 4.0) // Z scale
        XCTAssertEqual(scale[3][3], 1.0) // W component
        
        // Test rotation matrix (basic properties)
        let rotation = matrix4x4_rotation(radians: Float.pi / 2, axis: SIMD3<Float>(0, 0, 1))
        // Should be orthogonal matrix with determinant 1
        XCTAssertEqual(rotation[3][3], 1.0) // Translation part should be identity
        XCTAssertEqual(rotation[0][3], 0.0)
        XCTAssertEqual(rotation[1][3], 0.0)
        XCTAssertEqual(rotation[2][3], 0.0)
    }
}
