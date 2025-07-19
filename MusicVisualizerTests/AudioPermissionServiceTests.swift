//
//  AudioPermissionServiceTests.swift
//  MusicVisualizerTests
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Testing
import AVFoundation
@testable import MusicVisualizer

struct AudioPermissionServiceTests {
    
    @Test func testRequestPermission_whenGranted_returnsTrue() async throws {
        let service = MockAudioPermissionService()
        service.mockPermissionStatus = .granted
        
        let result = await service.requestMicrophonePermission()
        
        #expect(result == true)
    }
    
    @Test func testRequestPermission_whenDenied_returnsFalse() async throws {
        let service = MockAudioPermissionService()
        service.mockPermissionStatus = .denied
        
        let result = await service.requestMicrophonePermission()
        
        #expect(result == false)
    }
    
    @Test func testCheckCurrentPermission_whenGranted_returnsTrue() async throws {
        let service = MockAudioPermissionService()
        service.mockPermissionStatus = .granted
        
        let hasPermission = service.hasMicrophonePermission()
        
        #expect(hasPermission == true)
    }
    
    @Test func testCheckCurrentPermission_whenDenied_returnsFalse() async throws {
        let service = MockAudioPermissionService()
        service.mockPermissionStatus = .denied
        
        let hasPermission = service.hasMicrophonePermission()
        
        #expect(hasPermission == false)
    }
}

// Mock for testing
class MockAudioPermissionService: AudioPermissionServiceProtocol {
    var mockPermissionStatus: AVAudioSession.RecordPermission = .undetermined
    
    func requestMicrophonePermission() async -> Bool {
        return mockPermissionStatus == .granted
    }
    
    func hasMicrophonePermission() -> Bool {
        return mockPermissionStatus == .granted
    }
}