//
//  EqualizerViewModelTests.swift
//  MusicVisualizerTests
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Testing
@testable import MusicVisualizer

struct EqualizerViewModelTests {
    
    @Test func testInitialization_withDefaultBandCount() throws {
        let viewModel = EqualizerViewModel()
        
        #expect(viewModel.barHeights.count == 21) // Default band count
        #expect(viewModel.barHeights.allSatisfy { $0 == 0.0 }) // Should start at zero
        #expect(viewModel.isAnimating == false) // Should not be animating initially
    }
    
    @Test func testInitialization_withCustomBandCount() throws {
        let viewModel = EqualizerViewModel(bandCount: 12)
        
        #expect(viewModel.barHeights.count == 12)
        #expect(viewModel.barHeights.allSatisfy { $0 == 0.0 })
    }
    
    @Test func testUpdateFrequencyData_updatesBarHeights() async throws {
        let viewModel = EqualizerViewModel(bandCount: 4)
        let frequencyData: [Float] = [0.1, 0.5, 0.8, 0.3]
        
        viewModel.updateFrequencyData(frequencyData)
        
        // Allow time for async processing and main queue dispatch
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1.0 second
        
        #expect(viewModel.barHeights.count == 4)
        #expect(viewModel.barHeights[0] > 0.0)
        #expect(viewModel.barHeights[1] > viewModel.barHeights[0]) // Higher frequency = higher bar
        #expect(viewModel.barHeights[2] > viewModel.barHeights[1])
        #expect(viewModel.barHeights[3] < viewModel.barHeights[2])
    }
    
    @Test func testUpdateFrequencyData_withEmptyData_resetsHeights() async throws {
        let viewModel = EqualizerViewModel(bandCount: 4)
        
        // First set some data  
        viewModel.updateFrequencyData([1.0, 1.0, 1.0, 1.0]) // Use max values
        try await Task.sleep(nanoseconds: 1_500_000_000) // Wait longer for update (1.5 seconds)
        
        let hasNonZeroValues = viewModel.barHeights.contains { $0 > 0.0 }
        #expect(hasNonZeroValues, "Should have some non-zero values after setting data")
        
        // Then clear it
        viewModel.updateFrequencyData([])
        try await Task.sleep(nanoseconds: 1_500_000_000) // Wait longer for clear update (1.5 seconds)
        
        let allZero = viewModel.barHeights.allSatisfy { $0 <= 0.01 } // Allow small epsilon
        #expect(allZero, "Heights should be essentially zero after clearing data")
    }
    
    @Test func testUpdateFrequencyData_withMismatchedDataSize_handlesGracefully() async throws {
        let viewModel = EqualizerViewModel(bandCount: 4)
        
        // Test with more data than bands
        viewModel.updateFrequencyData([1.0, 1.0, 1.0, 1.0, 1.0, 1.0]) // Use max values
        try await Task.sleep(nanoseconds: 1_000_000_000) // Wait longer for update (1.0 second)
        #expect(viewModel.barHeights.count == 4, "Should maintain correct band count")
        
        // Clear state
        viewModel.updateFrequencyData([])
        try await Task.sleep(nanoseconds: 1_000_000_000) // Wait for reset (1.0 second)
        
        // Test with less data than bands
        viewModel.updateFrequencyData([1.0, 1.0]) // Use max values
        try await Task.sleep(nanoseconds: 300_000_000) // Wait for update (0.3 seconds)
        #expect(viewModel.barHeights.count == 4, "Should maintain correct band count")
        #expect(viewModel.barHeights[0] > 0.1, "First band should have significant value")
        #expect(viewModel.barHeights[1] > 0.1, "Second band should have significant value")
        #expect(viewModel.barHeights[2] <= 0.01, "Third band should be essentially zero")
        #expect(viewModel.barHeights[3] <= 0.01, "Fourth band should be essentially zero")
    }
    
    @Test func testStartStopAnimation() throws {
        let viewModel = EqualizerViewModel()
        
        #expect(viewModel.isAnimating == false)
        
        viewModel.startAnimation()
        #expect(viewModel.isAnimating == true)
        
        viewModel.stopAnimation()
        #expect(viewModel.isAnimating == false)
    }
    
    @Test func testNormalizeFrequencyData_scalesCorrectly() async throws {
        let viewModel = EqualizerViewModel(bandCount: 3)
        
        // Test with values that need scaling down
        viewModel.updateFrequencyData([2.0, 4.0, 1.0])
        
        // Allow time for async processing and main queue dispatch
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1.0 second
        
        // All values should be between 0.0 and 1.0
        #expect(viewModel.barHeights.allSatisfy { $0 >= 0.0 && $0 <= 1.0 })
        
        // Relative proportions should be maintained
        #expect(viewModel.barHeights[1] > viewModel.barHeights[0]) // 4.0 > 2.0
        #expect(viewModel.barHeights[0] > viewModel.barHeights[2]) // 2.0 > 1.0
    }
}