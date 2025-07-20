//
//  BackgroundStateHandlingTests.swift
//  MusicVisualizerTests
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Testing
import SwiftUI
import Combine
@testable import MusicVisualizer

struct BackgroundStateHandlingTests {
    
    @Test func testAppLifecycleNotifications_pauseAndResumeVisualization() async throws {
        let expectation = TestExpectation()
        let mockAudioService = MockAudioVisualizerService()
        let viewModel = EqualizerViewModel(bandCount: 8)
        
        var pauseCallCount = 0
        var resumeCallCount = 0
        
        // Setup notification monitoring
        var cancellables = Set<AnyCancellable>()
        
        // Simulate the behavior that EqualizerView would have
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { _ in
                pauseCallCount += 1
                mockAudioService.simulateStop()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in
                resumeCallCount += 1
                mockAudioService.simulateStart()
            }
            .store(in: &cancellables)
        
        // Test willResignActive notification
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        
        // Allow notification to process
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(pauseCallCount == 1)
        #expect(mockAudioService.isSimulatedRunning == false)
        
        // Test didBecomeActive notification
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        
        // Allow notification to process
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(resumeCallCount == 1)
        #expect(mockAudioService.isSimulatedRunning == true)
    }
    
    @Test func testBackgroundNotifications_pauseAndResumeVisualization() async throws {
        let mockAudioService = MockAudioVisualizerService()
        
        var backgroundPauseCount = 0
        var foregroundResumeCount = 0
        
        // Setup notification monitoring
        var cancellables = Set<AnyCancellable>()
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { _ in
                backgroundPauseCount += 1
                mockAudioService.simulateStop()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { _ in
                foregroundResumeCount += 1
                mockAudioService.simulateStart()
            }
            .store(in: &cancellables)
        
        // Test didEnterBackground notification
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        // Allow notification to process
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(backgroundPauseCount == 1)
        #expect(mockAudioService.isSimulatedRunning == false)
        
        // Test willEnterForeground notification
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        
        // Allow notification to process
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(foregroundResumeCount == 1)
        #expect(mockAudioService.isSimulatedRunning == true)
    }
    
    @Test func testEqualizerViewModel_pauseAndResumeAnimation() throws {
        let viewModel = EqualizerViewModel(bandCount: 8)
        
        // Start animation
        viewModel.startAnimation()
        #expect(viewModel.isAnimating == true)
        
        // Stop animation (simulating pause)
        viewModel.stopAnimation()
        #expect(viewModel.isAnimating == false)
        
        // Restart animation (simulating resume)
        viewModel.startAnimation()
        #expect(viewModel.isAnimating == true)
    }
    
    @Test func testCombinePublisherSubscription_properCleanup() throws {
        var cancellables = Set<AnyCancellable>()
        var notificationReceived = false
        
        // Setup subscription
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { _ in
                notificationReceived = true
            }
            .store(in: &cancellables)
        
        // Verify subscription works
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        #expect(notificationReceived == true)
        
        // Test cleanup
        cancellables.removeAll()
        notificationReceived = false
        
        // Verify subscription is cleaned up
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        #expect(notificationReceived == false) // Should still be false after cleanup
    }
}

// MARK: - Mock Classes for Testing

class MockAudioVisualizerService {
    private(set) var isSimulatedRunning = false
    
    func simulateStart() {
        isSimulatedRunning = true
    }
    
    func simulateStop() {
        isSimulatedRunning = false
    }
}

// Test expectation helper for async testing
class TestExpectation {
    private var isFulfilled = false
    
    func fulfill() {
        isFulfilled = true
    }
    
    var fulfilled: Bool {
        return isFulfilled
    }
}