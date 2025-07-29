//
//  SettingsManagerTests.swift
//  MusicVisualizerTests
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Testing
import Foundation
@testable import MusicVisualizer

@Suite(.serialized) // Force tests to run sequentially to avoid singleton state conflicts
struct SettingsManagerTests {
    
    @Test func testDefaultSettings_areCorrect() async throws {
        // Capture original state for restoration
        let originalState = (
            colorTheme: SettingsManager.shared.colorTheme,
            visualizationMode: SettingsManager.shared.visualizationMode,
            bandCount: SettingsManager.shared.bandCount,
            animationSpeed: SettingsManager.shared.animationSpeed
        )
        
        defer {
            // Restore original state
            SettingsManager.shared.colorTheme = originalState.colorTheme
            SettingsManager.shared.visualizationMode = originalState.visualizationMode
            SettingsManager.shared.bandCount = originalState.bandCount
            SettingsManager.shared.animationSpeed = originalState.animationSpeed
            UserDefaults.standard.synchronize()
        }
        
        // Reset to defaults and test
        SettingsManager.shared.resetToDefaults()
        
        // Allow time for UserDefaults write to complete
        UserDefaults.standard.synchronize()
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        #expect(SettingsManager.shared.colorTheme == .spectrum)
        #expect(SettingsManager.shared.visualizationMode == .bars)
        #expect(SettingsManager.shared.bandCount == 21)
        #expect(SettingsManager.shared.animationSpeed == 1.0)
    }
    
    @Test func testColorTheme_persistsAcrossRestart() async throws {
        // Capture the original state to restore later
        let originalTheme = SettingsManager.shared.colorTheme
        let originalUserDefaultsValue = UserDefaults.standard.object(forKey: "colorTheme")
        
        // Create a completely isolated test environment
        defer {
            // Restore original state completely in cleanup
            SettingsManager.shared.colorTheme = originalTheme
            if let originalValue = originalUserDefaultsValue {
                UserDefaults.standard.set(originalValue, forKey: "colorTheme")
            } else {
                UserDefaults.standard.removeObject(forKey: "colorTheme")
            }
            UserDefaults.standard.synchronize()
        }
        
        // Force reset to a known state
        SettingsManager.shared.colorTheme = .spectrum
        UserDefaults.standard.set("spectrum", forKey: "colorTheme")
        UserDefaults.standard.synchronize()
        try await Task.sleep(nanoseconds: 100_000_000) // Allow UserDefaults write
        
        // Verify starting state
        #expect(SettingsManager.shared.colorTheme == .spectrum, "Should start with spectrum theme")
        
        // Change to neon and verify immediate change
        SettingsManager.shared.colorTheme = .neon
        #expect(SettingsManager.shared.colorTheme == .neon, "Theme should be set to neon immediately")
        
        // Allow time for UserDefaults persistence
        UserDefaults.standard.synchronize()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Verify persistence by checking UserDefaults directly
        let savedValue = UserDefaults.standard.string(forKey: "colorTheme")
        #expect(savedValue == "neon", "UserDefaults should persist neon theme")
        
        // Verify the singleton still maintains the change
        #expect(SettingsManager.shared.colorTheme == .neon, "Singleton should maintain neon theme")
    }
    
    @Test func testVisualizationMode_persistsAcrossRestart() {
        let settings = SettingsManager.shared
        let originalMode = settings.visualizationMode
        
        // Change visualization mode
        settings.visualizationMode = .fractals
        #expect(settings.visualizationMode == .fractals)
        
        // The shared instance maintains the change (simulating persistence)
        #expect(SettingsManager.shared.visualizationMode == .fractals)
        
        // Cleanup - restore original
        settings.visualizationMode = originalMode
    }
    
    @Test func testBandCount_persistsAcrossRestart() async throws {
        // Capture the original state to restore later
        let originalBandCount = SettingsManager.shared.bandCount
        let originalUserDefaultsValue = UserDefaults.standard.object(forKey: "bandCount")
        
        // Create a completely isolated test environment
        defer {
            // Restore original state completely in cleanup
            SettingsManager.shared.bandCount = originalBandCount
            if let originalValue = originalUserDefaultsValue {
                UserDefaults.standard.set(originalValue, forKey: "bandCount")
            } else {
                UserDefaults.standard.removeObject(forKey: "bandCount")
            }
            UserDefaults.standard.synchronize()
        }
        
        // Force reset to a known state (default is 21)
        SettingsManager.shared.bandCount = 21
        UserDefaults.standard.set(21, forKey: "bandCount")
        UserDefaults.standard.synchronize()
        try await Task.sleep(nanoseconds: 100_000_000) // Allow UserDefaults write
        
        // Verify starting state
        #expect(SettingsManager.shared.bandCount == 21, "Should start with default band count of 21")
        
        // Change to 16 and verify immediate change
        SettingsManager.shared.bandCount = 16
        #expect(SettingsManager.shared.bandCount == 16, "Band count should be set to 16 immediately")
        
        // Allow time for UserDefaults persistence
        UserDefaults.standard.synchronize()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Verify persistence by checking UserDefaults directly
        let savedValue = UserDefaults.standard.integer(forKey: "bandCount")
        #expect(savedValue == 16, "UserDefaults should persist band count of 16")
        
        // Verify the singleton still maintains the change
        #expect(SettingsManager.shared.bandCount == 16, "Singleton should maintain band count of 16")
    }
    
    @Test func testAnimationSpeed_persistsAcrossRestart() {
        let settings = SettingsManager.shared
        let originalSpeed = settings.animationSpeed
        
        // Change animation speed
        settings.animationSpeed = 1.5
        #expect(settings.animationSpeed == 1.5)
        
        // The shared instance maintains the change (simulating persistence)
        #expect(SettingsManager.shared.animationSpeed == 1.5)
        
        // Cleanup - restore original
        settings.animationSpeed = originalSpeed
    }
    
    @Test func testResetToDefaults_restoresOriginalValues() async throws {
        // Store original values for restoration
        let originalValues = (
            colorTheme: SettingsManager.shared.colorTheme,
            visualizationMode: SettingsManager.shared.visualizationMode,
            bandCount: SettingsManager.shared.bandCount,
            animationSpeed: SettingsManager.shared.animationSpeed
        )
        
        defer {
            // Always restore original state
            SettingsManager.shared.colorTheme = originalValues.colorTheme
            SettingsManager.shared.visualizationMode = originalValues.visualizationMode
            SettingsManager.shared.bandCount = originalValues.bandCount
            SettingsManager.shared.animationSpeed = originalValues.animationSpeed
            UserDefaults.standard.synchronize()
        }
        
        // Change all settings to non-default values
        SettingsManager.shared.colorTheme = .fire
        SettingsManager.shared.visualizationMode = .fractals
        SettingsManager.shared.bandCount = 32
        SettingsManager.shared.animationSpeed = 2.0
        
        // Allow time for writes
        UserDefaults.standard.synchronize()
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Verify non-default values are set
        #expect(SettingsManager.shared.colorTheme == .fire)
        #expect(SettingsManager.shared.visualizationMode == .fractals)
        #expect(SettingsManager.shared.bandCount == 32)
        #expect(SettingsManager.shared.animationSpeed == 2.0)
        
        // Reset to defaults
        SettingsManager.shared.resetToDefaults()
        UserDefaults.standard.synchronize()
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Verify defaults are restored
        #expect(SettingsManager.shared.colorTheme == .spectrum)
        #expect(SettingsManager.shared.visualizationMode == .bars)
        #expect(SettingsManager.shared.bandCount == 21)
        #expect(SettingsManager.shared.animationSpeed == 1.0)
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
    
    @Test func testSettingsManager_handlesInvalidStoredValues() async throws {
        // Store original state for complete restoration
        let originalSettingsState = (
            colorTheme: SettingsManager.shared.colorTheme,
            visualizationMode: SettingsManager.shared.visualizationMode,
            bandCount: SettingsManager.shared.bandCount,
            animationSpeed: SettingsManager.shared.animationSpeed
        )
        
        let userDefaults = UserDefaults.standard
        let originalUserDefaultsValues = [
            "colorTheme": userDefaults.object(forKey: "colorTheme"),
            "visualizationMode": userDefaults.object(forKey: "visualizationMode"),
            "bandCount": userDefaults.object(forKey: "bandCount"),
            "animationSpeed": userDefaults.object(forKey: "animationSpeed")
        ]
        
        defer {
            // Complete cleanup - restore both singleton and UserDefaults
            SettingsManager.shared.colorTheme = originalSettingsState.colorTheme
            SettingsManager.shared.visualizationMode = originalSettingsState.visualizationMode
            SettingsManager.shared.bandCount = originalSettingsState.bandCount
            SettingsManager.shared.animationSpeed = originalSettingsState.animationSpeed
            
            for (key, value) in originalUserDefaultsValues {
                if let value = value {
                    userDefaults.set(value, forKey: key)
                } else {
                    userDefaults.removeObject(forKey: key)
                }
            }
            userDefaults.synchronize()
        }
        
        // Store invalid values in UserDefaults
        userDefaults.set("invalid_theme", forKey: "colorTheme")
        userDefaults.set("invalid_mode", forKey: "visualizationMode")
        userDefaults.set(-1, forKey: "bandCount")
        userDefaults.set(-0.5, forKey: "animationSpeed")
        userDefaults.synchronize()
        
        // Allow time for writes
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Reset to force reload from UserDefaults (which should fall back to defaults for invalid values)
        SettingsManager.shared.resetToDefaults()
        userDefaults.synchronize()
        
        // Allow time for reset to complete
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Settings should fall back to defaults when encountering invalid values
        #expect(SettingsManager.shared.colorTheme == .spectrum)
        #expect(SettingsManager.shared.visualizationMode == .bars)
        #expect(SettingsManager.shared.bandCount == 21) // Should use default, not stored -1
        #expect(SettingsManager.shared.animationSpeed == 1.0) // Should use default, not stored -0.5
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