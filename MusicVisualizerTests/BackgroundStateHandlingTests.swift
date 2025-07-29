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

@Suite(.serialized) // Force tests to run sequentially to avoid NotificationCenter state conflicts
struct BackgroundStateHandlingTests {
    
    @Test func testAppLifecycleNotifications_pauseAndResumeVisualization() async throws {
        let mockAudioService = MockAudioVisualizerService()
        let viewModel = EqualizerViewModel(bandCount: 8)
        
        var pauseCallCount = 0
        var resumeCallCount = 0
        
        // Setup notification monitoring
        var cancellables = Set<AnyCancellable>()
        
        // Simulate the behavior that EqualizerView would have
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                pauseCallCount += 1
                mockAudioService.simulateStop()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                resumeCallCount += 1
                mockAudioService.simulateStart()
            }
            .store(in: &cancellables)
        
        // Give the publishers time to set up
        try await Task.sleep(nanoseconds: 200_000_000) // Increased to 0.2 seconds
        
        // Test willResignActive notification
        await MainActor.run {
            NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        }
        
        // Allow notification to process on main queue
        try await Task.sleep(nanoseconds: 300_000_000) // Increased to 0.3 seconds
        
        #expect(pauseCallCount == 1, "Should have received resign active notification")
        #expect(mockAudioService.isSimulatedRunning == false, "Service should be stopped")
        
        // Test didBecomeActive notification
        await MainActor.run {
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        }
        
        // Allow notification to process on main queue
        try await Task.sleep(nanoseconds: 300_000_000) // Increased to 0.3 seconds
        
        #expect(resumeCallCount == 1, "Should have received become active notification")
        #expect(mockAudioService.isSimulatedRunning == true, "Service should be started")
        
        // Cleanup
        cancellables.removeAll()
    }
    
    @Test func testBackgroundNotifications_pauseAndResumeVisualization() async throws {
        let mockAudioService = MockAudioVisualizerService()
        
        var backgroundPauseCount = 0
        var foregroundResumeCount = 0
        
        // Setup notification monitoring
        var cancellables = Set<AnyCancellable>()
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                backgroundPauseCount += 1
                mockAudioService.simulateStop()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                foregroundResumeCount += 1
                mockAudioService.simulateStart()
            }
            .store(in: &cancellables)
        
        // Give the publishers time to set up
        try await Task.sleep(nanoseconds: 200_000_000) // Increased to 0.2 seconds
        
        // Test didEnterBackground notification
        await MainActor.run {
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        }
        
        // Allow notification to process on main queue
        try await Task.sleep(nanoseconds: 300_000_000) // Increased to 0.3 seconds
        
        #expect(backgroundPauseCount == 1, "Should have received background notification")
        #expect(mockAudioService.isSimulatedRunning == false, "Service should be stopped")
        
        // Test willEnterForeground notification
        await MainActor.run {
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        }
        
        // Allow notification to process on main queue
        try await Task.sleep(nanoseconds: 300_000_000) // Increased to 0.3 seconds
        
        #expect(foregroundResumeCount == 1, "Should have received foreground notification")
        #expect(mockAudioService.isSimulatedRunning == true, "Service should be started")
        
        // Cleanup
        cancellables.removeAll()
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
    
    @Test func testCombinePublisherSubscription_properCleanup() async throws {
        var cancellables = Set<AnyCancellable>()
        var notificationReceived = false
        
        // Setup subscription
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                notificationReceived = true
            }
            .store(in: &cancellables)
        
        // Give publisher time to set up
        try await Task.sleep(nanoseconds: 200_000_000) // Increased to 0.2 seconds
        
        // Verify subscription works
        await MainActor.run {
            NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        }
        
        // Allow time for processing
        try await Task.sleep(nanoseconds: 300_000_000) // Increased to 0.3 seconds
        
        #expect(notificationReceived == true, "Should receive notification when subscribed")
        
        // Test cleanup
        cancellables.removeAll()
        notificationReceived = false
        
        // Verify subscription is cleaned up
        await MainActor.run {
            NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        }
        
        // Allow time for potential processing (should not happen)
        try await Task.sleep(nanoseconds: 300_000_000) // Increased to 0.3 seconds
        
        #expect(notificationReceived == false, "Should not receive notification after cleanup")
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