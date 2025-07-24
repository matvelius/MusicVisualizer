//
//  AudioVisualizerService.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Foundation
import AVFoundation
import Accelerate

// MARK: - Performance Optimizations for 60fps

@Observable
class AudioVisualizerService {
    private(set) var isRunning = false
    let bandCount: Int
    
    // Dependencies
    private let permissionService: AudioPermissionServiceProtocol
    private let audioEngineService: AudioEngineServiceProtocol
    private let fftProcessor: FFTProcessorProtocol
    private let binExtractor: FrequencyBinExtractorProtocol
    
    // Audio Filter Properties
    private let settingsManager = SettingsManager.shared
    private var highPassFilter: ConfigurableFilter?
    
    // Performance optimization: throttle updates to 60fps
    private var lastUpdateTime: CFTimeInterval = 0
    private let targetFrameInterval: CFTimeInterval = 1.0 / 60.0
    private let audioProcessingQueue = DispatchQueue(label: "audio.processing", qos: .userInteractive)
    
    // Callback for frequency data updates
    var onFrequencyDataUpdate: (([Float]) -> Void)?
    
    init(
        bandCount: Int = 21,
        permissionService: AudioPermissionServiceProtocol = AudioPermissionService(),
        audioEngineService: AudioEngineServiceProtocol = AudioEngineService(),
        fftProcessor: FFTProcessorProtocol = FFTProcessor(),
        binExtractor: FrequencyBinExtractorProtocol = FrequencyBinExtractor()
    ) {
        self.bandCount = bandCount
        self.permissionService = permissionService
        self.audioEngineService = audioEngineService
        self.fftProcessor = fftProcessor
        self.binExtractor = binExtractor
        
        // Initialize high-pass filter
        setupAudioFilters()
    }
    
    @MainActor
    func startVisualization() async -> Bool {
        // Check microphone permission
        let hasPermission = await permissionService.requestMicrophonePermission()
        guard hasPermission else {
            return false
        }
        
        // Start audio engine
        let engineStarted = await audioEngineService.startEngine()
        guard engineStarted else {
            return false
        }
        
        // Install audio tap for real-time processing
        setupAudioTap()
        
        isRunning = true
        return true
    }
    
    func stopVisualization() {
        audioEngineService.stopEngine()
        isRunning = false
    }
    
    private func setupAudioTap() {
        // Optimize buffer size for 60fps: 44100 / 60 ≈ 735, round up to power of 2
        let bufferSize = 1024
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        
        audioEngineService.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
            // Process on audio queue to avoid blocking
            self?.handleAudioBuffer(buffer)
        }
    }
    
    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let bufferArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        processAudioBuffer(bufferArray)
    }
    
    func processAudioBuffer(_ buffer: [Float]) {
        // Skip processing if we're not running
        guard isRunning else { return }
        
        // Throttle processing to maintain 60fps performance
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastUpdateTime >= targetFrameInterval else { return }
        lastUpdateTime = currentTime
        
        // Process on dedicated queue to avoid blocking audio thread
        audioProcessingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Apply audio filters
            var processedBuffer = buffer
            
            // Apply high-pass filter if enabled
            if self.settingsManager.highPassFilterEnabled {
                processedBuffer = self.applyHighPassFilter(to: processedBuffer)
            }
            
            // Apply noise gate if enabled
            if self.settingsManager.noiseGateEnabled {
                processedBuffer = self.applyNoiseGate(to: processedBuffer)
            }
            
            // Process through FFT
            let magnitudes = self.fftProcessor.processAudioBuffer(processedBuffer)
            
            // Extract frequency bins
            let frequencyBins = self.binExtractor.extractBins(from: magnitudes, bandCount: self.bandCount)
            
            // Notify listeners on main queue
            DispatchQueue.main.async {
                self.onFrequencyDataUpdate?(frequencyBins)
            }
        }
    }
    
    // MARK: - Audio Filters
    
    private func setupAudioFilters() {
        // Initialize high-pass filter with current settings
        if settingsManager.highPassFilterEnabled {
            highPassFilter = HighPassFilter(cutoffFrequency: settingsManager.highPassCutoffFrequency, sampleRate: 44100)
        }
    }
    
    private func applyHighPassFilter(to buffer: [Float]) -> [Float] {
        guard let filter = highPassFilter else {
            // Create filter if needed
            highPassFilter = HighPassFilter(cutoffFrequency: settingsManager.highPassCutoffFrequency, sampleRate: 44100)
            return highPassFilter?.process(buffer) ?? buffer
        }
        
        // Update filter cutoff if settings changed
        filter.updateCutoffFrequency(settingsManager.highPassCutoffFrequency)
        return filter.process(buffer)
    }
    
    private func applyNoiseGate(to buffer: [Float]) -> [Float] {
        let threshold = settingsManager.noiseGateThreshold
        var processedBuffer = buffer
        
        // Calculate RMS (Root Mean Square) to determine signal level
        let rms = sqrt(buffer.map { $0 * $0 }.reduce(0, +) / Float(buffer.count))
        
        // If signal is below threshold, attenuate or silence it
        if rms < threshold {
            // Gradually attenuate based on how far below threshold we are
            let attenuation = max(0.0, rms / threshold)
            processedBuffer = buffer.map { $0 * attenuation }
        }
        
        return processedBuffer
    }
    
    // MARK: - Testing Support
    
    func forceRunningState(_ running: Bool) {
        isRunning = running
    }
}

// MARK: - Audio Filter Protocols and Implementations

protocol AudioFilter: AnyObject {
    func process(_ buffer: [Float]) -> [Float]
}

protocol ConfigurableFilter: AudioFilter {
    func updateCutoffFrequency(_ frequency: Float)
}

class HighPassFilter: ConfigurableFilter {
    private let sampleRate: Float
    private var cutoffFrequency: Float
    private var previousInput: Float = 0.0
    private var previousOutput: Float = 0.0
    
    init(cutoffFrequency: Float, sampleRate: Float) {
        self.cutoffFrequency = cutoffFrequency
        self.sampleRate = sampleRate
    }
    
    func updateCutoffFrequency(_ newFrequency: Float) {
        cutoffFrequency = newFrequency
    }
    
    func process(_ buffer: [Float]) -> [Float] {
        // Simple first-order high-pass filter
        // y[n] = a * (y[n-1] + x[n] - x[n-1])
        // where a = RC / (RC + dt) and RC = 1 / (2 * π * fc)
        
        let dt = 1.0 / sampleRate
        let rc = 1.0 / (2.0 * Float.pi * cutoffFrequency)
        let alpha = rc / (rc + dt)
        
        var filteredBuffer = [Float]()
        filteredBuffer.reserveCapacity(buffer.count)
        
        for sample in buffer {
            let output = alpha * (previousOutput + sample - previousInput)
            filteredBuffer.append(output)
            
            previousInput = sample
            previousOutput = output
        }
        
        return filteredBuffer
    }
}