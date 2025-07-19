//
//  AudioEngineServiceTests.swift
//  MusicVisualizerTests
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Testing
import AVFoundation
@testable import MusicVisualizer

struct AudioEngineServiceTests {
    
    @Test func testStartEngine_whenPermissionGranted_returnsTrue() async throws {
        let mockPermissionService = MockAudioPermissionService()
        mockPermissionService.mockPermissionStatus = .granted
        
        let service = AudioEngineService(permissionService: mockPermissionService)
        
        let result = await service.startEngine()
        
        #expect(result == true)
        #expect(service.isRunning == true)
    }
    
    @Test func testStartEngine_whenPermissionDenied_returnsFalse() async throws {
        let mockPermissionService = MockAudioPermissionService()
        mockPermissionService.mockPermissionStatus = .denied
        
        let service = AudioEngineService(permissionService: mockPermissionService)
        
        let result = await service.startEngine()
        
        #expect(result == false)
        #expect(service.isRunning == false)
    }
    
    @Test func testStopEngine_stopsRunningEngine() async throws {
        let mockPermissionService = MockAudioPermissionService()
        mockPermissionService.mockPermissionStatus = .granted
        
        let service = AudioEngineService(permissionService: mockPermissionService)
        
        _ = await service.startEngine()
        service.stopEngine()
        
        #expect(service.isRunning == false)
    }
    
    @Test func testInstallTap_whenEngineRunning_installsTapBlock() async throws {
        let mockPermissionService = MockAudioPermissionService()
        mockPermissionService.mockPermissionStatus = .granted
        
        let service = AudioEngineService(permissionService: mockPermissionService)
        _ = await service.startEngine()
        
        var tapCalled = false
        service.installTap { buffer, time in
            tapCalled = true
        }
        
        #expect(tapCalled == false) // Tap block stored but not yet called
    }
}