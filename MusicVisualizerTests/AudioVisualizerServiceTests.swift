//
//  AudioVisualizerServiceTests.swift
//  MusicVisualizerTests
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Testing
import AVFoundation
@testable import MusicVisualizer

struct AudioVisualizerServiceTests {
    
    @Test func testInitialization_withDefaultBandCount() throws {
        let service = AudioVisualizerService()
        
        #expect(service.isRunning == false)
        #expect(service.bandCount == 8) // Default band count
    }
    
    @Test func testInitialization_withCustomBandCount() throws {
        let service = AudioVisualizerService(bandCount: 12)
        
        #expect(service.isRunning == false)
        #expect(service.bandCount == 12)
    }
    
    @Test func testStartVisualization_whenPermissionGranted_startsAudioEngine() async throws {
        let mockPermissionService = MockAudioPermissionServiceForVisualizer()
        let mockAudioEngine = MockAudioEngineServiceForVisualizer()
        let service = AudioVisualizerService(
            permissionService: mockPermissionService,
            audioEngineService: mockAudioEngine
        )
        
        mockPermissionService.shouldGrantPermission = true
        mockAudioEngine.shouldStartSuccessfully = true
        
        let result = await service.startVisualization()
        
        #expect(result == true)
        #expect(service.isRunning == true)
        #expect(mockPermissionService.requestPermissionCalled == true)
        #expect(mockAudioEngine.startEngineCalled == true)
    }
    
    @Test func testStartVisualization_whenPermissionDenied_returnsFalse() async throws {
        let mockPermissionService = MockAudioPermissionServiceForVisualizer()
        let mockAudioEngine = MockAudioEngineServiceForVisualizer()
        let service = AudioVisualizerService(
            permissionService: mockPermissionService,
            audioEngineService: mockAudioEngine
        )
        
        mockPermissionService.shouldGrantPermission = false
        
        let result = await service.startVisualization()
        
        #expect(result == false)
        #expect(service.isRunning == false)
        #expect(mockPermissionService.requestPermissionCalled == true)
        #expect(mockAudioEngine.startEngineCalled == false)
    }
    
    @Test func testStartVisualization_whenEngineFailsToStart_returnsFalse() async throws {
        let mockPermissionService = MockAudioPermissionServiceForVisualizer()
        let mockAudioEngine = MockAudioEngineServiceForVisualizer()
        let service = AudioVisualizerService(
            permissionService: mockPermissionService,
            audioEngineService: mockAudioEngine
        )
        
        mockPermissionService.shouldGrantPermission = true
        mockAudioEngine.shouldStartSuccessfully = false
        
        let result = await service.startVisualization()
        
        #expect(result == false)
        #expect(service.isRunning == false)
        #expect(mockAudioEngine.startEngineCalled == true)
    }
    
    @Test func testStopVisualization_stopsAudioEngine() throws {
        let mockAudioEngine = MockAudioEngineServiceForVisualizer()
        let service = AudioVisualizerService(audioEngineService: mockAudioEngine)
        
        // Simulate running state
        service.forceRunningState(true)
        
        service.stopVisualization()
        
        #expect(service.isRunning == false)
        #expect(mockAudioEngine.stopEngineCalled == true)
    }
    
    @Test func testAudioDataProcessing_convertsToFrequencyBands() throws {
        let mockFFTProcessor = MockFFTProcessorForVisualizer()
        let mockBinExtractor = MockFrequencyBinExtractorForVisualizer()
        let service = AudioVisualizerService(
            bandCount: 4,
            fftProcessor: mockFFTProcessor,
            binExtractor: mockBinExtractor
        )
        
        let inputBuffer = [Float](repeating: 0.5, count: 1024)
        mockFFTProcessor.mockMagnitudes = [0.1, 0.5, 0.8, 0.3, 0.2]
        mockBinExtractor.mockBins = [0.2, 0.6, 0.9, 0.4]
        
        var receivedData: [Float]?
        service.onFrequencyDataUpdate = { data in
            receivedData = data
        }
        
        service.processAudioBuffer(inputBuffer)
        
        #expect(mockFFTProcessor.processAudioBufferCalled == true)
        #expect(mockBinExtractor.extractBinsCalled == true)
        #expect(receivedData?.count == 4)
        #expect(receivedData?[0] == 0.2)
        #expect(receivedData?[1] == 0.6)
        #expect(receivedData?[2] == 0.9)
        #expect(receivedData?[3] == 0.4)
    }
    
    @Test func testFrequencyDataCallback_isCalledWhenDataUpdates() async throws {
        let mockFFTProcessor = MockFFTProcessorForVisualizer()
        let mockBinExtractor = MockFrequencyBinExtractorForVisualizer()
        let service = AudioVisualizerService(
            bandCount: 3,
            fftProcessor: mockFFTProcessor,
            binExtractor: mockBinExtractor
        )
        
        mockFFTProcessor.mockMagnitudes = [0.1, 0.5, 0.8, 0.3, 0.2]
        mockBinExtractor.mockBins = [0.2, 0.6, 0.9]
        
        var callbackCount = 0
        var lastReceivedData: [Float]?
        
        service.onFrequencyDataUpdate = { data in
            callbackCount += 1
            lastReceivedData = data
        }
        
        let testData: [Float] = [0.1, 0.5, 0.8]
        service.processAudioBuffer(testData)
        
        // Allow time for main queue dispatch
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(callbackCount >= 1)
        #expect(lastReceivedData?.count == 3)
        #expect(lastReceivedData == [0.2, 0.6, 0.9])
    }
}

// MARK: - Mock Classes for AudioVisualizerService

class MockAudioPermissionServiceForVisualizer: AudioPermissionServiceProtocol {
    var shouldGrantPermission = true
    var requestPermissionCalled = false
    
    func requestMicrophonePermission() async -> Bool {
        requestPermissionCalled = true
        return shouldGrantPermission
    }
    
    func hasMicrophonePermission() -> Bool {
        return shouldGrantPermission
    }
}

class MockAudioEngineServiceForVisualizer: AudioEngineServiceProtocol {
    var shouldStartSuccessfully = true
    var startEngineCalled = false
    var stopEngineCalled = false
    var installTapCalled = false
    var isRunning: Bool = false
    
    func startEngine() async -> Bool {
        startEngineCalled = true
        return shouldStartSuccessfully
    }
    
    func stopEngine() {
        stopEngineCalled = true
    }
    
    func installTap(tapBlock: @escaping AVAudioNodeTapBlock) {
        installTapCalled = true
    }
    
    func installTap(onBus bus: Int, bufferSize: Int, format: AVAudioFormat?, block: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void) {
        installTapCalled = true
    }
}

class MockFFTProcessorForVisualizer: FFTProcessorProtocol {
    var mockMagnitudes: [Float] = []
    var processAudioBufferCalled = false
    var bufferSize: Int = 1024
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) -> [Float] {
        processAudioBufferCalled = true
        return mockMagnitudes
    }
    
    func processAudioBuffer(_ buffer: [Float]) -> [Float] {
        processAudioBufferCalled = true
        return mockMagnitudes
    }
}

class MockFrequencyBinExtractorForVisualizer: FrequencyBinExtractorProtocol {
    var mockBins: [Float] = []
    var extractBinsCalled = false
    var numberOfBands: Int = 8
    var frequencyRanges: [Range<Double>] = []
    
    func extractBins(from frequencyData: [Float]) -> [Float] {
        extractBinsCalled = true
        return mockBins
    }
    
    func extractBins(from magnitudes: [Float], bandCount: Int) -> [Float] {
        extractBinsCalled = true
        return mockBins
    }
}