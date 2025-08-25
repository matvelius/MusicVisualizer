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
    func processAudioBuffer(_ buffer: [Float]) -> [Float]
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
    
    init(bufferSize: Int = 512) {
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
    
    func processAudioBuffer(_ buffer: [Float]) -> [Float] {
        let frameCount = min(buffer.count, bufferSize)
        
        // Ultra-fast processing: minimize memory operations
        if frameCount <= 64 {
            // For small buffers, use optimized path
            return processSmallBuffer(buffer, frameCount: frameCount)
        }
        
        // Optimized copy using withUnsafeMutableBufferPointer for better performance
        realInput.withUnsafeMutableBufferPointer { realPtr in
            imaginaryInput.withUnsafeMutableBufferPointer { imagPtr in
                // Copy input data
                if frameCount > 0 {
                    buffer.withUnsafeBufferPointer { bufferPtr in
                        realPtr.baseAddress?.assign(from: bufferPtr.baseAddress!, count: frameCount)
                    }
                }
                // Zero-pad remaining
                if frameCount < bufferSize {
                    (realPtr.baseAddress! + frameCount).initialize(repeating: 0.0, count: bufferSize - frameCount)
                }
                // Clear imaginary input
                imagPtr.baseAddress?.initialize(repeating: 0.0, count: bufferSize)
            }
        }
        
        // Apply windowing function
        applyHannWindow()
        
        // Perform DFT
        vDSP_DFT_Execute(fftSetup, realInput, imaginaryInput, &realOutput, &imaginaryOutput)
        
        // Calculate magnitudes (only return first half due to symmetry)
        return calculateMagnitudes()
    }
    
    private func processSmallBuffer(_ buffer: [Float], frameCount: Int) -> [Float] {
        // For small buffers (like 64 samples), use minimal processing
        let paddedSize = max(128, nextPowerOfTwo(frameCount))
        
        // Create temporary arrays for small buffer processing
        var tempReal = Array(repeating: Float(0.0), count: paddedSize)
        var tempImag = Array(repeating: Float(0.0), count: paddedSize)
        var tempRealOut = Array(repeating: Float(0.0), count: paddedSize)
        var tempImagOut = Array(repeating: Float(0.0), count: paddedSize)
        
        // Copy and pad input
        for i in 0..<frameCount {
            tempReal[i] = buffer[i]
        }
        
        // Apply minimal windowing for small buffers
        for i in 0..<frameCount {
            let window = 0.5 * (1.0 - cos(2.0 * .pi * Float(i) / Float(frameCount - 1)))
            tempReal[i] *= window
        }
        
        // Create temporary FFT setup
        let tempSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(paddedSize), .FORWARD)!
        defer { vDSP_DFT_DestroySetup(tempSetup) }
        
        // Perform FFT
        vDSP_DFT_Execute(tempSetup, tempReal, tempImag, &tempRealOut, &tempImagOut)
        
        // Calculate magnitudes
        let halfSize = paddedSize / 2
        var magnitudes = [Float](repeating: 0.0, count: halfSize)
        
        for i in 0..<halfSize {
            let real = tempRealOut[i]
            let imaginary = tempImagOut[i]
            magnitudes[i] = sqrt(real * real + imaginary * imaginary)
        }
        
        return magnitudes
    }
    
    private func nextPowerOfTwo(_ n: Int) -> Int {
        var power = 1
        while power < n {
            power <<= 1
        }
        return power
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