//
//  EqualizerViewModel.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Foundation
import SwiftUI
import Combine

@Observable
class EqualizerViewModel {
    var barHeights: [Double] = []
    var isAnimating: Bool = false
    
    private let bandCount: Int
    private let smoothingFactor: Double = 0.7
    private var previousValues: [Double] = []
    private var updateQueue = DispatchQueue(label: "equalizer.update", qos: .userInteractive)
    private var lastUpdateTime: CFTimeInterval = 0
    private let targetFPS: Double = 60
    private let frameInterval: CFTimeInterval = 1.0 / 60.0
    
    init(bandCount: Int = 21) {
        self.bandCount = bandCount
        self.barHeights = Array(repeating: 0.0, count: bandCount)
        self.previousValues = Array(repeating: 0.0, count: bandCount)
    }
    
    func updateFrequencyData(_ frequencyData: [Float]) {
        let currentTime = CACurrentMediaTime()
        
        // Throttle updates to maintain 60fps
        guard currentTime - lastUpdateTime >= frameInterval else { return }
        lastUpdateTime = currentTime
        
        guard !frequencyData.isEmpty else {
            // Reset to zero when no data
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.2)) {
                    self.barHeights = Array(repeating: 0.0, count: self.bandCount)
                }
            }
            previousValues = Array(repeating: 0.0, count: bandCount)
            return
        }
        
        // Process on background queue for better performance
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Handle mismatched data size efficiently
            let normalizedData = self.normalizeDataSize(frequencyData)
            
            // Fast normalization with optimized math
            let normalizedHeights = self.normalizeValues(normalizedData)
            
            // Apply smoothing with optimized calculation
            let smoothedHeights = self.applySmoothingFast(normalizedHeights)
            
            // Update UI on main queue with optimized animation
            DispatchQueue.main.async {
                withAnimation(.linear(duration: self.frameInterval)) {
                    self.barHeights = smoothedHeights
                }
            }
            
            self.previousValues = smoothedHeights
        }
    }
    
    private func normalizeDataSize(_ frequencyData: [Float]) -> [Float] {
        guard frequencyData.count != bandCount else { return frequencyData }
        
        var result = [Float]()
        result.reserveCapacity(bandCount)
        
        let dataCount = min(frequencyData.count, bandCount)
        result.append(contentsOf: frequencyData.prefix(dataCount))
        
        if result.count < bandCount {
            result.append(contentsOf: Array(repeating: 0.0, count: bandCount - result.count))
        }
        
        return result
    }
    
    private func normalizeValues(_ data: [Float]) -> [Double] {
        let maxValue = data.max() ?? 1.0
        guard maxValue > 0.001 else {
            return data.map { Double($0) }
        }
        
        let normalizedFactor = 1.0 / Double(maxValue)
        return data.map { Double($0) * normalizedFactor }
    }
    
    private func applySmoothingFast(_ normalizedHeights: [Double]) -> [Double] {
        var result = [Double]()
        result.reserveCapacity(bandCount)
        
        let oneMinusSmoothing = 1.0 - smoothingFactor
        
        for i in 0..<bandCount {
            let currentValue = normalizedHeights[i]
            let previousValue = previousValues[i]
            let smoothed = previousValue * smoothingFactor + currentValue * oneMinusSmoothing
            result.append(max(0.0, min(1.0, smoothed)))
        }
        
        return result
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