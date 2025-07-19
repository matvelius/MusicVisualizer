//
//  AudioVisualizerService.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Foundation
import AVFoundation

@Observable
class AudioVisualizerService {
    private(set) var isRunning = false
    let bandCount: Int
    
    // Dependencies
    private let permissionService: AudioPermissionServiceProtocol
    private let audioEngineService: AudioEngineServiceProtocol
    private let fftProcessor: FFTProcessorProtocol
    private let binExtractor: FrequencyBinExtractorProtocol
    
    // Callback for frequency data updates
    var onFrequencyDataUpdate: (([Float]) -> Void)?
    
    init(
        bandCount: Int = 8,
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
        let bufferSize = 1024
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        
        audioEngineService.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
            self?.handleAudioBuffer(buffer)
        }
    }
    
    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let bufferArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        processAudioBuffer(bufferArray)
    }
    
    func processAudioBuffer(_ buffer: [Float]) {
        // Process through FFT
        let magnitudes = fftProcessor.processAudioBuffer(buffer)
        
        // Extract frequency bins
        let frequencyBins = binExtractor.extractBins(from: magnitudes, bandCount: bandCount)
        
        // Notify listeners
        DispatchQueue.main.async { [weak self] in
            self?.onFrequencyDataUpdate?(frequencyBins)
        }
    }
    
    // MARK: - Testing Support
    
    func forceRunningState(_ running: Bool) {
        isRunning = running
    }
}