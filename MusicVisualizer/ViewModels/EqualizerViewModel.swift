//
//  EqualizerViewModel.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Foundation
import SwiftUI

@Observable
class EqualizerViewModel {
    var barHeights: [Double] = []
    var isAnimating: Bool = false
    
    private let bandCount: Int
    private let smoothingFactor: Double = 0.8
    private var previousValues: [Double] = []
    
    init(bandCount: Int = 8) {
        self.bandCount = bandCount
        self.barHeights = Array(repeating: 0.0, count: bandCount)
        self.previousValues = Array(repeating: 0.0, count: bandCount)
    }
    
    func updateFrequencyData(_ frequencyData: [Float]) {
        guard !frequencyData.isEmpty else {
            // Reset to zero when no data
            barHeights = Array(repeating: 0.0, count: bandCount)
            previousValues = Array(repeating: 0.0, count: bandCount)
            return
        }
        
        // Handle mismatched data size
        var normalizedData = Array(repeating: Float(0.0), count: bandCount)
        let dataCount = min(frequencyData.count, bandCount)
        
        for i in 0..<dataCount {
            normalizedData[i] = frequencyData[i]
        }
        
        // Normalize values to 0.0 - 1.0 range
        let maxValue = normalizedData.max() ?? 1.0
        let normalizedHeights: [Double]
        
        if maxValue > 0 {
            normalizedHeights = normalizedData.map { Double($0) / Double(maxValue) }
        } else {
            normalizedHeights = normalizedData.map { Double($0) }
        }
        
        // Apply smoothing for more natural animation
        var smoothedHeights: [Double] = []
        for i in 0..<bandCount {
            let currentValue = normalizedHeights[i]
            let previousValue = previousValues[i]
            let smoothed = previousValue * smoothingFactor + currentValue * (1.0 - smoothingFactor)
            smoothedHeights.append(max(0.0, min(1.0, smoothed)))
        }
        
        // Update with animation
        withAnimation(.easeInOut(duration: 0.1)) {
            barHeights = smoothedHeights
        }
        
        previousValues = smoothedHeights
    }
    
    func startAnimation() {
        isAnimating = true
    }
    
    func stopAnimation() {
        isAnimating = false
        
        // Fade out bars when stopping
        withAnimation(.easeOut(duration: 0.5)) {
            barHeights = Array(repeating: 0.0, count: bandCount)
        }
        previousValues = Array(repeating: 0.0, count: bandCount)
    }
}