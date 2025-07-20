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
        
        self.bandCount = userDefaults.object(forKey: Keys.bandCount) as? Int ?? 21
        self.animationSpeed = userDefaults.object(forKey: Keys.animationSpeed) as? Double ?? 1.0
    }
    
    // Reset to defaults
    func resetToDefaults() {
        colorTheme = .spectrum
        visualizationMode = .bars
        bandCount = 21
        animationSpeed = 1.0
    }
}

// MARK: - Visualization Mode

enum VisualizationMode: String, CaseIterable, Identifiable {
    case bars = "bars"
    case circular = "circular"
    case waveform = "waveform"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .bars:
            return "Bars"
        case .circular:
            return "Circular"
        case .waveform:
            return "Waveform"
        }
    }
}