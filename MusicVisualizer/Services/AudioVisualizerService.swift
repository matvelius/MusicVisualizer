//
//  AudioVisualizerService.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Foundation
import AVFoundation

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
            
            // Process through FFT
            let magnitudes = self.fftProcessor.processAudioBuffer(buffer)
            
            // Extract frequency bins
            let frequencyBins = self.binExtractor.extractBins(from: magnitudes, bandCount: self.bandCount)
            
            // Notify listeners on main queue
            DispatchQueue.main.async {
                self.onFrequencyDataUpdate?(frequencyBins)
            }
        }
    }
    
    // MARK: - Testing Support
    
    func forceRunningState(_ running: Bool) {
        isRunning = running
    }
}