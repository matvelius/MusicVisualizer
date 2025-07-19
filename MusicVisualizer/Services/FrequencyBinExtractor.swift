//
//  FrequencyBinExtractor.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Foundation

protocol FrequencyBinExtractorProtocol {
    var numberOfBands: Int { get }
    var frequencyRanges: [Range<Double>] { get }
    func extractBins(from frequencyData: [Float]) -> [Float]
    func extractBins(from magnitudes: [Float], bandCount: Int) -> [Float]
}

@Observable
class FrequencyBinExtractor: FrequencyBinExtractorProtocol {
    let numberOfBands: Int
    let frequencyRanges: [Range<Double>]
    private let sampleRate: Double
    private let bufferSize: Int
    private let frequencyResolution: Double
    
    init(numberOfBands: Int = 8, sampleRate: Double = 44100, bufferSize: Int = 1024) {
        self.numberOfBands = numberOfBands
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        self.frequencyResolution = sampleRate / Double(bufferSize)
        self.frequencyRanges = Self.createLogarithmicFrequencyRanges(
            bandCount: numberOfBands,
            minFreq: 20.0,
            maxFreq: sampleRate / 2.0
        )
    }
    
    func extractBins(from frequencyData: [Float]) -> [Float] {
        guard frequencyData.count > 0 else {
            return Array(repeating: 0.0, count: numberOfBands)
        }
        
        var bins = Array(repeating: Float(0.0), count: numberOfBands)
        
        for (bandIndex, range) in frequencyRanges.enumerated() {
            let startBin = max(0, Int(range.lowerBound / frequencyResolution))
            let endBin = min(frequencyData.count - 1, Int(range.upperBound / frequencyResolution))
            
            if startBin <= endBin {
                // Calculate average magnitude for this frequency range
                var sum: Float = 0.0
                var count = 0
                
                for binIndex in startBin...endBin {
                    sum += frequencyData[binIndex]
                    count += 1
                }
                
                bins[bandIndex] = count > 0 ? sum / Float(count) : 0.0
            }
        }
        
        return bins
    }
    
    func extractBins(from magnitudes: [Float], bandCount: Int) -> [Float] {
        // Create temporary extractor with the requested band count
        let tempExtractor = FrequencyBinExtractor(numberOfBands: bandCount)
        return tempExtractor.extractBins(from: magnitudes)
    }
    
    // Create logarithmically spaced frequency ranges for better perceptual distribution
    private static func createLogarithmicFrequencyRanges(
        bandCount: Int,
        minFreq: Double,
        maxFreq: Double
    ) -> [Range<Double>] {
        guard bandCount > 0 else { return [] }
        
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let logStep = (logMax - logMin) / Double(bandCount)
        
        var ranges: [Range<Double>] = []
        
        for i in 0..<bandCount {
            let logStart = logMin + Double(i) * logStep
            let logEnd = logMin + Double(i + 1) * logStep
            
            let freqStart = pow(10.0, logStart)
            let freqEnd = pow(10.0, logEnd)
            
            ranges.append(freqStart..<freqEnd)
        }
        
        return ranges
    }
}