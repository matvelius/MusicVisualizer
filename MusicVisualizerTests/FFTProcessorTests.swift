//
//  FFTProcessorTests.swift
//  MusicVisualizerTests
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Testing
import AVFoundation
import Accelerate
@testable import MusicVisualizer

struct FFTProcessorTests {
    
    @Test func testProcessAudioBuffer_withValidData_returnsFrequencyData() throws {
        let processor = FFTProcessor(bufferSize: 1024)
        let mockBuffer = createMockAudioBuffer(frameLength: 1024, sampleRate: 44100)
        
        let frequencyData = processor.processAudioBuffer(mockBuffer)
        
        #expect(frequencyData.count == 512) // Half of buffer size for real FFT output
        #expect(frequencyData.allSatisfy { $0 >= 0.0 }) // All magnitudes should be non-negative
    }
    
    @Test func testProcessAudioBuffer_withSilentAudio_returnsLowMagnitudes() throws {
        let processor = FFTProcessor(bufferSize: 1024)
        let silentBuffer = createSilentAudioBuffer(frameLength: 1024, sampleRate: 44100)
        
        let frequencyData = processor.processAudioBuffer(silentBuffer)
        
        #expect(frequencyData.allSatisfy { $0 < 0.1 }) // Silent audio should have very low magnitudes
    }
    
    @Test func testProcessAudioBuffer_withToneSignal_showsPeakAtExpectedFrequency() throws {
        let processor = FFTProcessor(bufferSize: 1024)
        let toneBuffer = createToneAudioBuffer(frameLength: 1024, sampleRate: 44100, frequency: 440.0)
        
        let frequencyData = processor.processAudioBuffer(toneBuffer)
        
        // Should have a peak around 440Hz bin
        let expectedBin = Int(440.0 / (44100.0 / 1024.0))
        let peakBin = frequencyData.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        
        #expect(abs(peakBin - expectedBin) <= 2) // Allow for some tolerance
    }
    
    @Test func testBufferSize_isValidPowerOfTwo() throws {
        let processor = FFTProcessor(bufferSize: 1024)
        
        let bufferSize = processor.bufferSize
        
        #expect(bufferSize == 1024)
        #expect((bufferSize & (bufferSize - 1)) == 0) // Check if power of 2
    }
    
    // Helper functions for creating test audio data
    private func createMockAudioBuffer(frameLength: UInt32, sampleRate: Double) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength)!
        buffer.frameLength = frameLength
        
        // Fill with random data to simulate real audio
        let channelData = buffer.floatChannelData![0]
        for i in 0..<Int(frameLength) {
            channelData[i] = Float.random(in: -1.0...1.0) * 0.1
        }
        
        return buffer
    }
    
    private func createSilentAudioBuffer(frameLength: UInt32, sampleRate: Double) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength)!
        buffer.frameLength = frameLength
        
        // Fill with zeros (silence)
        let channelData = buffer.floatChannelData![0]
        for i in 0..<Int(frameLength) {
            channelData[i] = 0.0
        }
        
        return buffer
    }
    
    private func createToneAudioBuffer(frameLength: UInt32, sampleRate: Double, frequency: Double) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength)!
        buffer.frameLength = frameLength
        
        // Generate a sine wave at the specified frequency
        let channelData = buffer.floatChannelData![0]
        for i in 0..<Int(frameLength) {
            let sample = sin(2.0 * .pi * frequency * Double(i) / sampleRate)
            channelData[i] = Float(sample * 0.5) // Moderate amplitude
        }
        
        return buffer
    }
}