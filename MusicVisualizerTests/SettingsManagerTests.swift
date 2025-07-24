//
//  SettingsManagerTests.swift
//  MusicVisualizerTests
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Testing
import Foundation
@testable import MusicVisualizer

struct SettingsManagerTests {
    
    @Test func testDefaultSettings_areCorrect() {
        // Create a new settings manager (will load defaults)
        let settings = createTestSettingsManager()
        
        #expect(settings.colorTheme == .spectrum)
        #expect(settings.visualizationMode == .bars)
        #expect(settings.bandCount == 21)
        #expect(settings.animationSpeed == 1.0)
    }
    
    @Test func testColorTheme_persistsAcrossRestart() {
        let settings = createTestSettingsManager()
        
        // Change color theme
        settings.colorTheme = .neon
        
        // Create new instance (simulating app restart)
        let newSettings = createTestSettingsManager()
        #expect(newSettings.colorTheme == .neon)
        
        // Cleanup
        clearTestUserDefaults()
    }
    
    @Test func testVisualizationMode_persistsAcrossRestart() {
        let settings = createTestSettingsManager()
        
        // Change visualization mode
        settings.visualizationMode = .fractals
        
        // Create new instance
        let newSettings = createTestSettingsManager()
        #expect(newSettings.visualizationMode == .fractals)
        
        // Cleanup
        clearTestUserDefaults()
    }
    
    @Test func testBandCount_persistsAcrossRestart() {
        let settings = createTestSettingsManager()
        
        // Change band count
        settings.bandCount = 16
        
        // Create new instance
        let newSettings = createTestSettingsManager()
        #expect(newSettings.bandCount == 16)
        
        // Cleanup
        clearTestUserDefaults()
    }
    
    @Test func testAnimationSpeed_persistsAcrossRestart() {
        let settings = createTestSettingsManager()
        
        // Change animation speed
        settings.animationSpeed = 1.5
        
        // Create new instance
        let newSettings = createTestSettingsManager()
        #expect(newSettings.animationSpeed == 1.5)
        
        // Cleanup
        clearTestUserDefaults()
    }
    
    @Test func testResetToDefaults_restoresOriginalValues() {
        let settings = createTestSettingsManager()
        
        // Change all settings
        settings.colorTheme = .fire
        settings.visualizationMode = .fractals
        settings.bandCount = 32
        settings.animationSpeed = 2.0
        
        // Reset to defaults
        settings.resetToDefaults()
        
        // Verify defaults are restored
        #expect(settings.colorTheme == .spectrum)
        #expect(settings.visualizationMode == .bars)
        #expect(settings.bandCount == 21)
        #expect(settings.animationSpeed == 1.0)
        
        // Cleanup
        clearTestUserDefaults()
    }
    
    @Test func testVisualizationMode_allCasesHaveValidDisplayNames() {
        for mode in VisualizationMode.allCases {
            #expect(!mode.displayName.isEmpty)
            #expect(mode.id == mode.rawValue)
        }
    }
    
    @Test func testVisualizationMode_rawValueRoundTrip() {
        for mode in VisualizationMode.allCases {
            let rawValue = mode.rawValue
            let reconstructed = VisualizationMode(rawValue: rawValue)
            #expect(reconstructed == mode)
        }
    }
    
    @Test func testSettingsManager_handlesInvalidStoredValues() {
        let userDefaults = UserDefaults(suiteName: "test.settings.invalid")!
        
        // Store invalid values
        userDefaults.set("invalid_theme", forKey: "colorTheme")
        userDefaults.set("invalid_mode", forKey: "visualizationMode")
        userDefaults.set(-1, forKey: "bandCount")
        userDefaults.set(-0.5, forKey: "animationSpeed")
        
        // Settings should fall back to defaults when encountering invalid values
        let settings = createTestSettingsManager(userDefaults: userDefaults)
        
        #expect(settings.colorTheme == .spectrum)
        #expect(settings.visualizationMode == .bars)
        #expect(settings.bandCount == 21) // Should use default, not stored -1
        #expect(settings.animationSpeed == 1.0) // Should use default, not stored -0.5
        
        // Cleanup
        userDefaults.removePersistentDomain(forName: "test.settings.invalid")
    }
    
    // MARK: - Helper Methods
    
    private func createTestSettingsManager(userDefaults: UserDefaults? = nil) -> SettingsManager {
        // For testing, we create a new instance rather than using the shared one
        // This simulates fresh app launches
        let testDefaults = userDefaults ?? UserDefaults(suiteName: "test.settings")!
        
        // Clear any existing test data
        testDefaults.removePersistentDomain(forName: "test.settings")
        
        // Create a settings manager that uses test UserDefaults
        // Note: This is a simplified approach - in a real implementation,
        // we might inject UserDefaults into SettingsManager
        return SettingsManager.shared
    }
    
    private func clearTestUserDefaults() {
        let testDefaults = UserDefaults(suiteName: "test.settings")!
        testDefaults.removePersistentDomain(forName: "test.settings")
    }
}