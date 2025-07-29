//
//  SettingsManager.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Foundation
import Combine

@Observable
class SettingsManager {
    static let shared = SettingsManager()
    
    // User Preferences
    @ObservationIgnored private let userDefaults = UserDefaults.standard
    
    // Settings Keys
    private enum Keys {
        static let colorTheme = "colorTheme"
        static let visualizationMode = "visualizationMode"
        static let bandCount = "bandCount"
        static let animationSpeed = "animationSpeed"
        static let noiseGateEnabled = "noiseGateEnabled"
        static let noiseGateThreshold = "noiseGateThreshold"
        static let highPassFilterEnabled = "highPassFilterEnabled"
        static let highPassCutoffFrequency = "highPassCutoffFrequency"
        static let fractalType = "fractalType"
        static let fractalZoomSpeed = "fractalZoomSpeed"
        static let fractalColorIntensity = "fractalColorIntensity"
    }
    
    // Current Settings
    var colorTheme: ColorTheme {
        didSet {
            userDefaults.set(colorTheme.rawValue, forKey: Keys.colorTheme)
        }
    }
    
    var visualizationMode: VisualizationMode {
        didSet {
            userDefaults.set(visualizationMode.rawValue, forKey: Keys.visualizationMode)
        }
    }
    
    var bandCount: Int {
        didSet {
            userDefaults.set(bandCount, forKey: Keys.bandCount)
        }
    }
    
    var animationSpeed: Double {
        didSet {
            userDefaults.set(animationSpeed, forKey: Keys.animationSpeed)
        }
    }
    
    // Audio Filter Settings
    var noiseGateEnabled: Bool {
        didSet {
            userDefaults.set(noiseGateEnabled, forKey: Keys.noiseGateEnabled)
        }
    }
    
    var noiseGateThreshold: Float {
        didSet {
            userDefaults.set(noiseGateThreshold, forKey: Keys.noiseGateThreshold)
        }
    }
    
    var highPassFilterEnabled: Bool {
        didSet {
            userDefaults.set(highPassFilterEnabled, forKey: Keys.highPassFilterEnabled)
        }
    }
    
    var highPassCutoffFrequency: Float {
        didSet {
            userDefaults.set(highPassCutoffFrequency, forKey: Keys.highPassCutoffFrequency)
        }
    }
    
    // Fractal Settings
    var fractalType: Int {
        didSet {
            userDefaults.set(fractalType, forKey: Keys.fractalType)
        }
    }
    
    var fractalZoomSpeed: Float {
        didSet {
            userDefaults.set(fractalZoomSpeed, forKey: Keys.fractalZoomSpeed)
        }
    }
    
    var fractalColorIntensity: Float {
        didSet {
            userDefaults.set(fractalColorIntensity, forKey: Keys.fractalColorIntensity)
        }
    }
    
    private init() {
        // Load saved settings or use defaults
        if let savedTheme = userDefaults.string(forKey: Keys.colorTheme),
           let theme = ColorTheme(rawValue: savedTheme) {
            self.colorTheme = theme
        } else {
            self.colorTheme = .spectrum
        }
        
        if let savedMode = userDefaults.string(forKey: Keys.visualizationMode),
           let mode = VisualizationMode(rawValue: savedMode) {
            self.visualizationMode = mode
        } else {
            self.visualizationMode = .bars
        }
        
        // Validate and load bandCount (must be positive)
        let savedBandCount = userDefaults.object(forKey: Keys.bandCount) as? Int ?? 21
        self.bandCount = savedBandCount > 0 ? savedBandCount : 21
        
        // Validate and load animationSpeed (must be positive)  
        let savedAnimationSpeed = userDefaults.object(forKey: Keys.animationSpeed) as? Double ?? 1.0
        self.animationSpeed = savedAnimationSpeed > 0 ? savedAnimationSpeed : 1.0
        
        // Load audio filter settings
        self.noiseGateEnabled = userDefaults.object(forKey: Keys.noiseGateEnabled) as? Bool ?? false
        self.noiseGateThreshold = userDefaults.object(forKey: Keys.noiseGateThreshold) as? Float ?? 0.01
        self.highPassFilterEnabled = userDefaults.object(forKey: Keys.highPassFilterEnabled) as? Bool ?? false
        self.highPassCutoffFrequency = userDefaults.object(forKey: Keys.highPassCutoffFrequency) as? Float ?? 80.0
        
        // Load fractal settings
        self.fractalType = userDefaults.object(forKey: Keys.fractalType) as? Int ?? 0
        self.fractalZoomSpeed = userDefaults.object(forKey: Keys.fractalZoomSpeed) as? Float ?? 1.0
        self.fractalColorIntensity = userDefaults.object(forKey: Keys.fractalColorIntensity) as? Float ?? 1.0
    }
    
    // Reset to defaults
    func resetToDefaults() {
        colorTheme = .spectrum
        visualizationMode = .bars
        bandCount = 21
        animationSpeed = 1.0
        noiseGateEnabled = false
        noiseGateThreshold = 0.01
        highPassFilterEnabled = false
        highPassCutoffFrequency = 80.0
        fractalType = 0
        fractalZoomSpeed = 1.0
        fractalColorIntensity = 1.0
    }
}

// MARK: - Visualization Mode

enum VisualizationMode: String, CaseIterable, Identifiable {
    case bars = "bars"
    case fractals = "fractals"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .bars:
            return "Bars"
        case .fractals:
            return "Fractals"
        }
    }
}