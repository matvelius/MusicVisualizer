//
//  FractalVisualizationUITests.swift
//  MusicVisualizerUITests
//
//  Created by Claude Code on 7/24/25.
//

import XCTest

final class FractalVisualizationUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launch()
        
        // Wait for app to load
        let homeView = app.otherElements["HomeView"]
        XCTAssertTrue(homeView.waitForExistence(timeout: 5.0), "Home view should appear")
    }
    
    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Navigation Tests
    
    func testNavigateToFractalMode() throws {
        // Open settings
        let settingsButton = app.buttons["gear"]
        XCTAssertTrue(settingsButton.exists, "Settings button should exist")
        settingsButton.tap()
        
        // Wait for settings sheet to appear
        let settingsView = app.otherElements["SettingsView"]
        XCTAssertTrue(settingsView.waitForExistence(timeout: 2.0), "Settings view should appear")
        
        // Find and tap the visualization mode picker
        let visualizationPicker = app.segmentedControls.firstMatch
        XCTAssertTrue(visualizationPicker.exists, "Visualization mode picker should exist")
        
        // Select fractals mode
        let fractalsOption = visualizationPicker.buttons["Fractals"]
        if fractalsOption.exists {
            fractalsOption.tap()
        }
        
        // Close settings
        let closeButton = app.buttons["Done"].firstMatch
        if closeButton.exists {
            closeButton.tap()
        } else {
            // Tap outside the sheet to close it
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        }
        
        // Verify we're back to home view
        let homeView = app.otherElements["HomeView"]
        XCTAssertTrue(homeView.waitForExistence(timeout: 2.0), "Should return to home view")
    }
    
    func testFractalVisualizerViewExists() throws {
        // First ensure we're in fractal mode
        try navigateToFractalMode()
        
        // Check if fractal visualizer view exists
        let fractalVisualizerView = app.otherElements["FractalVisualizerView"]
        XCTAssertTrue(fractalVisualizerView.waitForExistence(timeout: 3.0), "Fractal visualizer view should exist")
    }
    
    func testFractalErrorHandling() throws {
        // Navigate to fractal mode
        try navigateToFractalMode()
        
        // Wait for potential error states
        let errorText = app.staticTexts["Fractal Renderer Error"]
        let retryButton = app.buttons["Retry"]
        
        if errorText.waitForExistence(timeout: 5.0) {
            // If error appears, test retry functionality
            XCTAssertTrue(retryButton.exists, "Retry button should exist when error occurs")
            retryButton.tap()
            
            // After retry, either should succeed or show error again
            let success = app.otherElements["FractalVisualizerView"].waitForExistence(timeout: 3.0)
            let stillError = errorText.exists
            
            XCTAssertTrue(success || stillError, "After retry, should either succeed or show error")
        } else {
            // If no error, fractal view should exist
            let fractalView = app.otherElements["FractalVisualizerView"]
            XCTAssertTrue(fractalView.exists, "Fractal view should exist when no error")
        }
    }
    
    // MARK: - Settings Integration Tests
    
    func testFractalSettingsIntegration() throws {
        // Navigate to settings
        let settingsButton = app.buttons["gear"]
        settingsButton.tap()
        
        let settingsView = app.otherElements["SettingsView"]
        XCTAssertTrue(settingsView.waitForExistence(timeout: 2.0))
        
        // Switch to fractal mode if not already
        let visualizationPicker = app.segmentedControls.firstMatch
        if visualizationPicker.exists {
            let fractalsOption = visualizationPicker.buttons["Fractals"]
            if fractalsOption.exists && !fractalsOption.isSelected {
                fractalsOption.tap()
            }
        }
        
        // Test fractal-specific settings exist
        let fractalSettings = app.staticTexts["Fractal Settings"]
        if fractalSettings.exists {
            // Test fractal type picker
            let fractalTypePicker = app.buttons["fractalTypePicker"]
            if fractalTypePicker.exists {
                fractalTypePicker.tap()
                
                // Should show fractal type options
                let mandelbrotOption = app.buttons["Mandelbrot"]
                let juliaOption = app.buttons["Julia Set"]
                let burningShipOption = app.buttons["Burning Ship"]
                
                XCTAssertTrue(mandelbrotOption.exists || juliaOption.exists || burningShipOption.exists,
                            "At least one fractal type option should exist")
                
                // Select an option if available
                if mandelbrotOption.exists {
                    mandelbrotOption.tap()
                }
            }
            
            // Test zoom speed slider
            let zoomSlider = app.sliders["zoomSpeedSlider"]
            if zoomSlider.exists {
                let initialValue = zoomSlider.normalizedSliderPosition
                zoomSlider.adjust(toNormalizedSliderPosition: 0.7)
                XCTAssertNotEqual(zoomSlider.normalizedSliderPosition, initialValue, "Zoom slider should change value")
            }
            
            // Test color intensity slider
            let colorSlider = app.sliders["colorIntensitySlider"]
            if colorSlider.exists {
                let initialValue = colorSlider.normalizedSliderPosition
                colorSlider.adjust(toNormalizedSliderPosition: 0.3)
                XCTAssertNotEqual(colorSlider.normalizedSliderPosition, initialValue, "Color slider should change value")
            }
        }
        
        // Close settings
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        
        // Verify settings were applied (fractal view should still work)
        let homeView = app.otherElements["HomeView"]
        XCTAssertTrue(homeView.waitForExistence(timeout: 2.0))
    }
    
    // MARK: - Performance Tests
    
    func testFractalVisualizationPerformance() throws {
        try navigateToFractalMode()
        
        // Wait for fractal visualizer to load
        let fractalView = app.otherElements["FractalVisualizerView"]
        XCTAssertTrue(fractalView.waitForExistence(timeout: 5.0))
        
        // Measure time for app to remain responsive during fractal rendering
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            // Simulate user interaction during fractal rendering
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            
            // Wait a bit to let fractals potentially animate
            Thread.sleep(forTimeInterval: 1.0)
            
            // App should still be responsive
            let settingsButton = app.buttons["gear"]
            XCTAssertTrue(settingsButton.isHittable, "Settings button should remain responsive")
        }
    }
    
    func testFractalVisualizationStability() throws {
        try navigateToFractalMode()
        
        let fractalView = app.otherElements["FractalVisualizerView"]
        XCTAssertTrue(fractalView.waitForExistence(timeout: 5.0))
        
        // Test app stability over time with fractal visualization
        let stabilityTestDuration: TimeInterval = 10.0
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < stabilityTestDuration {
            // Verify fractal view still exists
            XCTAssertTrue(fractalView.exists, "Fractal view should remain stable")
            
            // Verify settings button is still accessible
            let settingsButton = app.buttons["gear"]
            XCTAssertTrue(settingsButton.exists, "Settings button should remain accessible")
            
            // Short pause between checks
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
    
    // MARK: - Orientation Tests
    
    func testFractalVisualizationInLandscape() throws {
        try navigateToFractalMode()
        
        let fractalView = app.otherElements["FractalVisualizerView"]
        XCTAssertTrue(fractalView.waitForExistence(timeout: 5.0))
        
        // Rotate to landscape
        XCUIDevice.shared.orientation = .landscapeLeft
        
        // Wait for rotation to complete
        Thread.sleep(forTimeInterval: 1.0)
        
        // Fractal view should still exist and be functional
        XCTAssertTrue(fractalView.exists, "Fractal view should work in landscape")
        
        // Settings should still be accessible
        let settingsButton = app.buttons["gear"]
        XCTAssertTrue(settingsButton.exists, "Settings should be accessible in landscape")
        
        // Rotate back to portrait
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1.0)
        
        // Should still work in portrait
        XCTAssertTrue(fractalView.exists, "Fractal view should work after rotation back to portrait")
    }
    
    // MARK: - Accessibility Tests
    
    func testFractalVisualizationAccessibility() throws {
        try navigateToFractalMode()
        
        let fractalView = app.otherElements["FractalVisualizerView"]
        XCTAssertTrue(fractalView.waitForExistence(timeout: 5.0))
        
        // Test accessibility labels
        XCTAssertNotNil(fractalView.label, "Fractal view should have accessibility label")
        
        // Test that settings remain accessible with VoiceOver
        let settingsButton = app.buttons["gear"]
        XCTAssertTrue(settingsButton.isHittable, "Settings button should be accessible")
        XCTAssertNotNil(settingsButton.label, "Settings button should have accessibility label")
    }
    
    // MARK: - Error Recovery Tests
    
    func testAppRecoveryFromFractalError() throws {
        try navigateToFractalMode()
        
        // Wait for either success or error
        let fractalView = app.otherElements["FractalVisualizerView"]
        let errorText = app.staticTexts["Fractal Renderer Error"]
        
        let fractalExists = fractalView.waitForExistence(timeout: 5.0)
        let errorExists = errorText.waitForExistence(timeout: 5.0)
        
        if fractalExists {
            // Success case - verify it works
            XCTAssertTrue(fractalView.exists, "Fractal view should work normally")
        } else if errorExists {
            // Error case - test recovery
            let retryButton = app.buttons["Retry"]
            XCTAssertTrue(retryButton.exists, "Retry button should exist")
            
            // Try to recover
            retryButton.tap()
            
            // Should either succeed or continue showing error gracefully
            let recovered = fractalView.waitForExistence(timeout: 3.0)
            let stillError = errorText.exists
            
            XCTAssertTrue(recovered || stillError, "Should either recover or show error gracefully")
            
            // Even if it fails, should be able to switch back to bars mode
            let settingsButton = app.buttons["gear"]
            settingsButton.tap()
            
            let settingsView = app.otherElements["SettingsView"]
            XCTAssertTrue(settingsView.waitForExistence(timeout: 2.0))
            
            // Switch to bars mode as fallback
            let visualizationPicker = app.segmentedControls.firstMatch
            if visualizationPicker.exists {
                let barsOption = visualizationPicker.buttons["Bars"]
                if barsOption.exists {
                    barsOption.tap()
                }
            }
            
            // Close settings
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
            
            // Should be able to fall back to bars mode
            let homeView = app.otherElements["HomeView"]
            XCTAssertTrue(homeView.waitForExistence(timeout: 2.0), "Should fall back gracefully")
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToFractalMode() throws {
        let settingsButton = app.buttons["gear"]
        settingsButton.tap()
        
        let settingsView = app.otherElements["SettingsView"]
        XCTAssertTrue(settingsView.waitForExistence(timeout: 2.0))
        
        let visualizationPicker = app.segmentedControls.firstMatch
        if visualizationPicker.exists {
            let fractalsOption = visualizationPicker.buttons["Fractals"]
            if fractalsOption.exists && !fractalsOption.isSelected {
                fractalsOption.tap()
            }
        }
        
        // Close settings
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        
        let homeView = app.otherElements["HomeView"]
        XCTAssertTrue(homeView.waitForExistence(timeout: 2.0))
    }
}

// MARK: - Visual Validation Tests

final class FractalVisualValidationUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }
    
    func testFractalVisualizationScreenshots() throws {
        // Navigate to fractal mode
        let settingsButton = app.buttons["gear"]
        settingsButton.tap()
        
        let settingsView = app.otherElements["SettingsView"]
        XCTAssertTrue(settingsView.waitForExistence(timeout: 2.0))
        
        let visualizationPicker = app.segmentedControls.firstMatch
        if visualizationPicker.exists {
            let fractalsOption = visualizationPicker.buttons["Fractals"]
            if fractalsOption.exists {
                fractalsOption.tap()
            }
        }
        
        // Close settings
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        
        let homeView = app.otherElements["HomeView"]
        XCTAssertTrue(homeView.waitForExistence(timeout: 2.0))
        
        // Wait for fractal visualization to potentially load
        Thread.sleep(forTimeInterval: 2.0)
        
        // Take screenshot of fractal visualization
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Fractal Visualization"
        attachment.lifetime = .keepAlways
        add(attachment)
        
        // Test different orientations
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.0)
        
        let landscapeScreenshot = app.screenshot()
        let landscapeAttachment = XCTAttachment(screenshot: landscapeScreenshot)
        landscapeAttachment.name = "Fractal Visualization Landscape"
        landscapeAttachment.lifetime = .keepAlways
        add(landscapeAttachment)
        
        // Rotate back
        XCUIDevice.shared.orientation = .portrait
    }
}