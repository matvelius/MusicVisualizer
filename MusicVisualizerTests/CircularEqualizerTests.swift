//
//  CircularEqualizerTests.swift
//  MusicVisualizerTests
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Testing
import SwiftUI
@testable import MusicVisualizer

struct CircularEqualizerTests {
    
    @Test func testCircularBarAngleCalculation() {
        let bar = CircularBar(
            index: 0,
            totalBars: 4,
            center: CGPoint(x: 100, y: 100),
            radius: 50,
            height: 20,
            color: .blue
        )
        
        // First bar should start at -90 degrees (top)
        let expectedAngle = -90.0
        let actualAngle = bar.angle
        #expect(actualAngle == expectedAngle)
    }
    
    @Test func testCircularBarAngleDistribution() {
        let totalBars = 8
        var angles: [Double] = []
        
        for index in 0..<totalBars {
            let bar = CircularBar(
                index: index,
                totalBars: totalBars,
                center: CGPoint(x: 100, y: 100),
                radius: 50,
                height: 20,
                color: .blue
            )
            angles.append(bar.angle)
        }
        
        // Check that angles are evenly distributed
        let expectedAngleStep = 360.0 / Double(totalBars)
        
        for i in 1..<angles.count {
            let actualStep = angles[i] - angles[i-1]
            #expect(abs(actualStep - expectedAngleStep) < 0.001, "Angles should be evenly distributed")
        }
    }
    
    @Test func testCircularBarPositionCalculation() {
        let center = CGPoint(x: 100, y: 100)
        let radius: CGFloat = 50
        
        // Test bar at 0 degrees (after -90 offset, this is top)
        let topBar = CircularBar(
            index: 0,
            totalBars: 4,
            center: center,
            radius: radius,
            height: 20,
            color: .blue
        )
        
        let topPosition = topBar.barPosition
        
        // At -90 degrees, x should be at center, y should be above center
        #expect(abs(topPosition.x - center.x) < 1.0, "Top bar should be horizontally centered")
        #expect(topPosition.y < center.y, "Top bar should be above center")
    }
    
    @Test func testCircularEqualizer_initialization() {
        let audioService = AudioVisualizerService(bandCount: 12)
        let equalizer = CircularEqualizerView(barCount: 12, audioVisualizerService: audioService)
        
        #expect(equalizer.barCount == 12)
        #expect(equalizer.minBarHeight > 0)
        #expect(equalizer.maxBarHeight > equalizer.minBarHeight)
    }
    
    @Test func testCircularEqualizer_barHeightCalculation() {
        let audioService = AudioVisualizerService(bandCount: 5)
        let equalizer = CircularEqualizerView(barCount: 5, audioVisualizerService: audioService)
        
        // Test with no data (should return minimum height)
        let minHeight = equalizer.barHeight(for: 0)
        #expect(minHeight == equalizer.minBarHeight)
        
        // Test with out of bounds index
        let outOfBoundsHeight = equalizer.barHeight(for: 10)
        #expect(outOfBoundsHeight == equalizer.minBarHeight)
    }
    
    @Test func testCircularEqualizer_colorIntegration() {
        let audioService = AudioVisualizerService(bandCount: 8)
        let equalizer = CircularEqualizerView(barCount: 8, audioVisualizerService: audioService)
        
        // Test that colors are generated for all bars
        for index in 0..<equalizer.barCount {
            let color = equalizer.barColor(for: index)
            #expect(color != Color.clear, "Each bar should have a valid color")
        }
    }
    
    @Test func testCircularBar_geometryCalculations() {
        let totalBars = 6
        let center = CGPoint(x: 150, y: 150)
        let radius: CGFloat = 75
        
        var positions: [CGPoint] = []
        
        for index in 0..<totalBars {
            let bar = CircularBar(
                index: index,
                totalBars: totalBars,
                center: center,
                radius: radius,
                height: 25,
                color: .red
            )
            positions.append(bar.barPosition)
        }
        
        // All positions should be approximately at the specified radius from center
        for position in positions {
            let distance = sqrt(pow(position.x - center.x, 2) + pow(position.y - center.y, 2))
            #expect(abs(distance - radius) < 1.0, "All bars should be at the correct radius")
        }
        
        // Positions should be unique (no two bars at the same position)
        let uniquePositions = Set(positions.map { "\($0.x),\($0.y)" })
        #expect(uniquePositions.count == totalBars, "All bar positions should be unique")
    }
    
    @Test func testCircularBar_angleRange() {
        let totalBars = 12
        
        for index in 0..<totalBars {
            let bar = CircularBar(
                index: index,
                totalBars: totalBars,
                center: CGPoint(x: 100, y: 100),
                radius: 50,
                height: 20,
                color: .green
            )
            
            // Angles should be within expected range
            #expect(bar.angle >= -90, "Angle should not be less than -90")
            #expect(bar.angle < 270, "Angle should be less than 270") // -90 + 360 = 270
        }
    }
}