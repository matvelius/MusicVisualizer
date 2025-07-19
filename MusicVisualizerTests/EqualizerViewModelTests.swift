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
    
    @Test func testUpdateFrequencyData_updatesBarHeights() throws {
        let viewModel = EqualizerViewModel(bandCount: 4)
        let frequencyData: [Float] = [0.1, 0.5, 0.8, 0.3]
        
        viewModel.updateFrequencyData(frequencyData)
        
        #expect(viewModel.barHeights.count == 4)
        #expect(viewModel.barHeights[0] > 0.0)
        #expect(viewModel.barHeights[1] > viewModel.barHeights[0]) // Higher frequency = higher bar
        #expect(viewModel.barHeights[2] > viewModel.barHeights[1])
        #expect(viewModel.barHeights[3] < viewModel.barHeights[2])
    }
    
    @Test func testUpdateFrequencyData_withEmptyData_resetsHeights() throws {
        let viewModel = EqualizerViewModel(bandCount: 4)
        
        // First set some data
        viewModel.updateFrequencyData([0.5, 0.7, 0.3, 0.9])
        #expect(viewModel.barHeights.contains { $0 > 0.0 })
        
        // Then clear it
        viewModel.updateFrequencyData([])
        #expect(viewModel.barHeights.allSatisfy { $0 == 0.0 })
    }
    
    @Test func testUpdateFrequencyData_withMismatchedDataSize_handlesGracefully() throws {
        let viewModel = EqualizerViewModel(bandCount: 4)
        
        // Test with more data than bands
        viewModel.updateFrequencyData([0.1, 0.2, 0.3, 0.4, 0.5, 0.6])
        #expect(viewModel.barHeights.count == 4) // Should only use first 4 values
        
        // Reset to clear any previous state
        viewModel.updateFrequencyData([])
        
        // Test with less data than bands
        viewModel.updateFrequencyData([1.0, 1.0]) // Use max values to overcome smoothing
        #expect(viewModel.barHeights.count == 4) // Should pad with zeros
        #expect(viewModel.barHeights[0] > 0.0)
        #expect(viewModel.barHeights[1] > 0.0)
        #expect(viewModel.barHeights[2] == 0.0) // Should be exactly zero for unset bands
        #expect(viewModel.barHeights[3] == 0.0)
    }
    
    @Test func testStartStopAnimation() throws {
        let viewModel = EqualizerViewModel()
        
        #expect(viewModel.isAnimating == false)
        
        viewModel.startAnimation()
        #expect(viewModel.isAnimating == true)
        
        viewModel.stopAnimation()
        #expect(viewModel.isAnimating == false)
    }
    
    @Test func testNormalizeFrequencyData_scalesCorrectly() throws {
        let viewModel = EqualizerViewModel(bandCount: 3)
        
        // Test with values that need scaling down
        viewModel.updateFrequencyData([2.0, 4.0, 1.0])
        
        // All values should be between 0.0 and 1.0
        #expect(viewModel.barHeights.allSatisfy { $0 >= 0.0 && $0 <= 1.0 })
        
        // Relative proportions should be maintained
        #expect(viewModel.barHeights[1] > viewModel.barHeights[0]) // 4.0 > 2.0
        #expect(viewModel.barHeights[0] > viewModel.barHeights[2]) // 2.0 > 1.0
    }
}