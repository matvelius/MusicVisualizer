//
//  ColorThemeTests.swift
//  MusicVisualizerTests
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Testing
import SwiftUI
@testable import MusicVisualizer

struct ColorThemeTests {
    
    @Test func testAllColorThemes_haveValidDisplayNames() {
        for theme in ColorTheme.allCases {
            #expect(!theme.displayName.isEmpty)
            #expect(theme.id == theme.rawValue)
        }
    }
    
    @Test func testSpectrumTheme_generatesValidColors() {
        let theme = ColorTheme.spectrum
        let bandCount = 10
        
        for index in 0..<bandCount {
            let color = theme.color(for: index, totalBands: bandCount)
            #expect(color != Color.clear)
        }
    }
    
    @Test func testNeonTheme_generatesBrightColors() {
        let theme = ColorTheme.neon
        let color1 = theme.color(for: 0, totalBands: 5)
        let color2 = theme.color(for: 4, totalBands: 5)
        
        // Colors should be different
        #expect(color1 != color2)
    }
    
    @Test func testMonochromeTheme_generatesGrayscaleColors() {
        let theme = ColorTheme.monochrome
        let color1 = theme.color(for: 0, totalBands: 5)
        let color2 = theme.color(for: 4, totalBands: 5)
        
        // Should generate different shades
        #expect(color1 != color2)
    }
    
    @Test func testColorInterpolation_withEdgeCases() {
        let theme = ColorTheme.sunset
        
        // Test with single band
        let singleColor = theme.color(for: 0, totalBands: 1)
        #expect(singleColor != Color.clear)
        
        // Test with zero index
        let firstColor = theme.color(for: 0, totalBands: 10)
        #expect(firstColor != Color.clear)
        
        // Test with last index
        let lastColor = theme.color(for: 9, totalBands: 10)
        #expect(lastColor != Color.clear)
    }
    
    @Test func testAllThemes_generateUniqueColorsAcrossBands() {
        for theme in ColorTheme.allCases {
            let bandCount = 8
            var colors: Set<String> = []
            
            for index in 0..<bandCount {
                let color = theme.color(for: index, totalBands: bandCount)
                let colorDescription = color.description
                colors.insert(colorDescription)
            }
            
            // For most themes, we should have some variety in colors
            // (monochrome might have fewer unique colors, so we test for at least 2)
            #expect(colors.count >= 2, "Theme \(theme.displayName) should generate varied colors")
        }
    }
    
    @Test func testColorTheme_caseiterable() {
        // Ensure we have all expected themes
        let expectedThemes: [ColorTheme] = [.spectrum, .neon, .monochrome, .sunset, .ocean, .fire, .mint]
        #expect(ColorTheme.allCases.count == expectedThemes.count)
        
        for expectedTheme in expectedThemes {
            #expect(ColorTheme.allCases.contains(expectedTheme))
        }
    }
    
    @Test func testColorStability_acrossMultipleCalls() {
        let theme = ColorTheme.ocean
        let index = 3
        let totalBands = 10
        
        let color1 = theme.color(for: index, totalBands: totalBands)
        let color2 = theme.color(for: index, totalBands: totalBands)
        
        // Same inputs should produce same outputs
        #expect(color1 == color2)
    }
}