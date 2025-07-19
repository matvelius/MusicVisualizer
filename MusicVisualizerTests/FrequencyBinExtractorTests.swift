//
//  FrequencyBinExtractorTests.swift
//  MusicVisualizerTests
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Testing
@testable import MusicVisualizer

struct FrequencyBinExtractorTests {
    
    @Test func testExtractBins_withCorrectNumberOfBands() throws {
        let extractor = FrequencyBinExtractor(numberOfBands: 21, sampleRate: 44100, bufferSize: 1024)
        let frequencyData = Array(repeating: Float(1.0), count: 512) // Mock FFT output
        
        let bins = extractor.extractBins(from: frequencyData)
        
        #expect(bins.count == 21)
    }
    
    @Test func testExtractBins_withDifferentBandCounts() throws {
        let bandCounts = [8, 12, 16]
        
        for bandCount in bandCounts {
            let extractor = FrequencyBinExtractor(numberOfBands: bandCount, sampleRate: 44100, bufferSize: 1024)
            let frequencyData = Array(repeating: Float(1.0), count: 512)
            
            let bins = extractor.extractBins(from: frequencyData)
            
            #expect(bins.count == bandCount)
        }
    }
    
    @Test func testFrequencyRanges_coverExpectedSpectrum() throws {
        let extractor = FrequencyBinExtractor(numberOfBands: 21, sampleRate: 44100, bufferSize: 1024)
        
        let ranges = extractor.frequencyRanges
        
        #expect(ranges.count == 21)
        #expect(ranges.first?.lowerBound ?? 0 >= 20) // Should start around human hearing range
        #expect(ranges.last?.upperBound ?? 0 <= 22050) // Should not exceed Nyquist frequency
        
        // Verify ranges are in ascending order and don't overlap
        for i in 1..<ranges.count {
            #expect(ranges[i].lowerBound >= ranges[i-1].upperBound)
        }
    }
    
    @Test func testExtractBins_withLogarithmicFrequencyDistribution() throws {
        let extractor = FrequencyBinExtractor(numberOfBands: 21, sampleRate: 44100, bufferSize: 1024)
        
        // Create frequency data with energy concentrated in specific ranges
        var frequencyData = Array(repeating: Float(0.1), count: 512)
        
        // Add peaks at bass (100Hz), midrange (1kHz), and treble (8kHz) frequencies
        let nyquist = 44100.0 / 2.0
        let bassIndex = Int(100.0 / nyquist * 512)
        let midIndex = Int(1000.0 / nyquist * 512)
        let trebleIndex = Int(8000.0 / nyquist * 512)
        
        frequencyData[bassIndex] = Float(2.0)
        frequencyData[midIndex] = Float(3.0)
        frequencyData[trebleIndex] = Float(1.5)
        
        let bins = extractor.extractBins(from: frequencyData)
        
        // Verify we have some energy captured and all values are non-negative
        #expect(bins.allSatisfy { $0 >= 0.0 }) // All values should be non-negative
        #expect(bins.max() ?? 0 > 0.2) // Should capture some of the energy we added
    }
    
    @Test func testExtractBins_withEmptyInput_returnsZeros() throws {
        let extractor = FrequencyBinExtractor(numberOfBands: 21, sampleRate: 44100, bufferSize: 1024)
        let emptyData = Array(repeating: Float(0.0), count: 512)
        
        let bins = extractor.extractBins(from: emptyData)
        
        #expect(bins.allSatisfy { $0 == 0.0 })
        #expect(bins.count == 21)
    }
}
