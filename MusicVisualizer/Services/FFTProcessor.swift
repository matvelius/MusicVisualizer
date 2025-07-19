//
//  FFTProcessor.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Foundation
import AVFoundation
import Accelerate

protocol FFTProcessorProtocol {
    var bufferSize: Int { get }
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) -> [Float]
}

@Observable
class FFTProcessor: FFTProcessorProtocol {
    let bufferSize: Int
    private let log2BufferSize: vDSP_Length
    private let fftSetup: vDSP_DFT_Setup
    private var realInput: [Float]
    private var imaginaryInput: [Float]
    private var realOutput: [Float]
    private var imaginaryOutput: [Float]
    
    init(bufferSize: Int = 1024) {
        self.bufferSize = bufferSize
        self.log2BufferSize = vDSP_Length(log2(Float(bufferSize)))
        
        // Ensure buffer size is a power of 2
        guard (bufferSize & (bufferSize - 1)) == 0 else {
            fatalError("Buffer size must be a power of 2")
        }
        
        // Create DFT setup for forward transform
        self.fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(bufferSize), .FORWARD)!
        
        // Initialize arrays
        self.realInput = Array(repeating: 0.0, count: bufferSize)
        self.imaginaryInput = Array(repeating: 0.0, count: bufferSize)
        self.realOutput = Array(repeating: 0.0, count: bufferSize)
        self.imaginaryOutput = Array(repeating: 0.0, count: bufferSize)
    }
    
    deinit {
        vDSP_DFT_DestroySetup(fftSetup)
    }
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData?[0],
              buffer.frameLength > 0 else {
            return Array(repeating: 0.0, count: bufferSize / 2)
        }
        
        let frameCount = min(Int(buffer.frameLength), bufferSize)
        
        // Copy audio data to real input, pad with zeros if necessary
        for i in 0..<bufferSize {
            if i < frameCount {
                realInput[i] = channelData[i]
            } else {
                realInput[i] = 0.0
            }
            imaginaryInput[i] = 0.0
        }
        
        // Apply windowing function (Hann window) to reduce spectral leakage
        applyHannWindow()
        
        // Perform DFT
        vDSP_DFT_Execute(fftSetup, realInput, imaginaryInput, &realOutput, &imaginaryOutput)
        
        // Calculate magnitudes (only return first half due to symmetry)
        return calculateMagnitudes()
    }
    
    private func applyHannWindow() {
        for i in 0..<bufferSize {
            let window = 0.5 * (1.0 - cos(2.0 * .pi * Float(i) / Float(bufferSize - 1)))
            realInput[i] *= window
        }
    }
    
    private func calculateMagnitudes() -> [Float] {
        let halfSize = bufferSize / 2
        var magnitudes = [Float](repeating: 0.0, count: halfSize)
        
        for i in 0..<halfSize {
            let real = realOutput[i]
            let imaginary = imaginaryOutput[i]
            magnitudes[i] = sqrt(real * real + imaginary * imaginary)
        }
        
        return magnitudes
    }
}