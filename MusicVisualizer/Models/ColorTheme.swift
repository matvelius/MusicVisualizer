//
//  ColorTheme.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import SwiftUI

enum ColorTheme: String, CaseIterable, Identifiable {
    case spectrum = "spectrum"
    case neon = "neon"
    case monochrome = "monochrome"
    case sunset = "sunset"
    case ocean = "ocean"
    case fire = "fire"
    case mint = "mint"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .spectrum:
            return "Spectrum"
        case .neon:
            return "Neon"
        case .monochrome:
            return "Monochrome"
        case .sunset:
            return "Sunset"
        case .ocean:
            return "Ocean"
        case .fire:
            return "Fire"
        case .mint:
            return "Mint"
        }
    }
    
    func color(for index: Int, totalBands: Int) -> Color {
        let normalizedIndex = Double(index) / Double(max(totalBands - 1, 1))
        
        switch self {
        case .spectrum:
            return spectrumColor(at: normalizedIndex)
        case .neon:
            return neonColor(at: normalizedIndex)
        case .monochrome:
            return monochromeColor(at: normalizedIndex)
        case .sunset:
            return sunsetColor(at: normalizedIndex)
        case .ocean:
            return oceanColor(at: normalizedIndex)
        case .fire:
            return fireColor(at: normalizedIndex)
        case .mint:
            return mintColor(at: normalizedIndex)
        }
    }
    
    // MARK: - Color Generators
    
    private func spectrumColor(at position: Double) -> Color {
        let hue = position * 0.7 // Use first 70% of hue spectrum (red to blue)
        return Color(hue: hue, saturation: 0.8, brightness: 0.9)
    }
    
    private func neonColor(at position: Double) -> Color {
        let colors: [Color] = [
            Color(red: 1.0, green: 0.0, blue: 1.0), // Magenta
            Color(red: 0.0, green: 1.0, blue: 1.0), // Cyan
            Color(red: 1.0, green: 1.0, blue: 0.0), // Yellow
            Color(red: 0.0, green: 1.0, blue: 0.0), // Green
            Color(red: 1.0, green: 0.0, blue: 0.0)  // Red
        ]
        return interpolateColors(colors, at: position)
    }
    
    private func monochromeColor(at position: Double) -> Color {
        let brightness = 0.3 + position * 0.7 // Range from dark to bright
        return Color(white: brightness)
    }
    
    private func sunsetColor(at position: Double) -> Color {
        let colors: [Color] = [
            Color(red: 1.0, green: 0.4, blue: 0.0), // Deep orange
            Color(red: 1.0, green: 0.6, blue: 0.2), // Orange
            Color(red: 1.0, green: 0.8, blue: 0.4), // Light orange
            Color(red: 1.0, green: 0.9, blue: 0.7), // Pale yellow
            Color(red: 0.9, green: 0.5, blue: 0.8)  // Pink
        ]
        return interpolateColors(colors, at: position)
    }
    
    private func oceanColor(at position: Double) -> Color {
        let colors: [Color] = [
            Color(red: 0.0, green: 0.2, blue: 0.4), // Deep blue
            Color(red: 0.0, green: 0.4, blue: 0.6), // Medium blue
            Color(red: 0.2, green: 0.6, blue: 0.8), // Light blue
            Color(red: 0.4, green: 0.8, blue: 1.0), // Cyan
            Color(red: 0.6, green: 1.0, blue: 1.0)  // Light cyan
        ]
        return interpolateColors(colors, at: position)
    }
    
    private func fireColor(at position: Double) -> Color {
        let colors: [Color] = [
            Color(red: 0.8, green: 0.0, blue: 0.0), // Dark red
            Color(red: 1.0, green: 0.2, blue: 0.0), // Red
            Color(red: 1.0, green: 0.5, blue: 0.0), // Orange
            Color(red: 1.0, green: 0.8, blue: 0.0), // Yellow-orange
            Color(red: 1.0, green: 1.0, blue: 0.4)  // Yellow
        ]
        return interpolateColors(colors, at: position)
    }
    
    private func mintColor(at position: Double) -> Color {
        let colors: [Color] = [
            Color(red: 0.0, green: 0.5, blue: 0.3), // Dark green
            Color(red: 0.2, green: 0.7, blue: 0.5), // Medium green
            Color(red: 0.4, green: 0.9, blue: 0.7), // Light green
            Color(red: 0.6, green: 1.0, blue: 0.9), // Mint
            Color(red: 0.8, green: 1.0, blue: 1.0)  // Light mint
        ]
        return interpolateColors(colors, at: position)
    }
    
    // MARK: - Helper Methods
    
    private func interpolateColors(_ colors: [Color], at position: Double) -> Color {
        guard colors.count > 1 else { return colors.first ?? .white }
        
        let clampedPosition = max(0, min(1, position))
        let scaledPosition = clampedPosition * Double(colors.count - 1)
        let lowerIndex = Int(scaledPosition)
        let upperIndex = min(lowerIndex + 1, colors.count - 1)
        let fraction = scaledPosition - Double(lowerIndex)
        
        if lowerIndex == upperIndex {
            return colors[lowerIndex]
        }
        
        return interpolateColor(from: colors[lowerIndex], to: colors[upperIndex], fraction: fraction)
    }
    
    private func interpolateColor(from startColor: Color, to endColor: Color, fraction: Double) -> Color {
        let startComponents = UIColor(startColor).rgbaComponents
        let endComponents = UIColor(endColor).rgbaComponents
        
        let red = startComponents.red + (endComponents.red - startComponents.red) * fraction
        let green = startComponents.green + (endComponents.green - startComponents.green) * fraction
        let blue = startComponents.blue + (endComponents.blue - startComponents.blue) * fraction
        let alpha = startComponents.alpha + (endComponents.alpha - startComponents.alpha) * fraction
        
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

// MARK: - UIColor Extension

private extension UIColor {
    var rgbaComponents: (red: Double, green: Double, blue: Double, alpha: Double) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return (red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }
}