//
//  SettingsView.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import SwiftUI

struct SettingsView: View {
    @State private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Visualization Settings
                Section("Visualization") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mode")
                            .font(.headline)
                        
                        Picker("Visualization Mode", selection: $settingsManager.visualizationMode) {
                            ForEach(VisualizationMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Frequency Bands")
                            Spacer()
                            Text("\(settingsManager.bandCount)")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(settingsManager.bandCount) },
                                set: { settingsManager.bandCount = Int($0) }
                            ),
                            in: 8...32,
                            step: 1
                        )
                    }
                }
                
                // Color Theme Settings
                Section("Color Theme") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(ColorTheme.allCases) { theme in
                            ThemePreviewCard(
                                theme: theme,
                                isSelected: settingsManager.colorTheme == theme
                            ) {
                                settingsManager.colorTheme = theme
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Animation Settings
                Section("Animation") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speed")
                            Spacer()
                            Text(String(format: "%.1fx", settingsManager.animationSpeed))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: $settingsManager.animationSpeed,
                            in: 0.5...2.0,
                            step: 0.1
                        )
                    }
                }
                
                // Audio Filter Settings
                Section("Audio Filters") {
                    VStack(alignment: .leading, spacing: 16) {
                        // Noise Gate
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Noise Gate")
                                    .font(.headline)
                                Spacer()
                                Toggle("", isOn: $settingsManager.noiseGateEnabled)
                            }
                            
                            if settingsManager.noiseGateEnabled {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Threshold")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(String(format: "%.3f", settingsManager.noiseGateThreshold))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Slider(
                                        value: Binding(
                                            get: { Double(settingsManager.noiseGateThreshold) },
                                            set: { settingsManager.noiseGateThreshold = Float($0) }
                                        ),
                                        in: 0.001...0.1,
                                        step: 0.001
                                    )
                                }
                                .padding(.leading, 16)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            
                            Text("Reduces background noise when signal is below threshold")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // High-Pass Filter
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("High-Pass Filter")
                                    .font(.headline)
                                Spacer()
                                Toggle("", isOn: $settingsManager.highPassFilterEnabled)
                            }
                            
                            if settingsManager.highPassFilterEnabled {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Cutoff Frequency")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(Int(settingsManager.highPassCutoffFrequency)) Hz")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Slider(
                                        value: Binding(
                                            get: { Double(settingsManager.highPassCutoffFrequency) },
                                            set: { settingsManager.highPassCutoffFrequency = Float($0) }
                                        ),
                                        in: 20...200,
                                        step: 5
                                    )
                                }
                                .padding(.leading, 16)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            
                            Text("Removes low-frequency noise below cutoff frequency")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Fractal Settings
                Section {
                    Text("Fractal Settings")
                        .font(.headline)
                        .accessibilityIdentifier("Fractal Settings")
                    VStack(alignment: .leading, spacing: 16) {
                        // Fractal Type Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Fractal Type")
                                .font(.headline)
                            
                            Picker("Fractal Type", selection: $settingsManager.fractalType) {
                                Text("Mandelbrot").tag(0)
                                Text("Julia Set").tag(1)
                                Text("Burning Ship").tag(2)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .accessibilityIdentifier("fractalTypePicker")
                            
                            Text("Different mathematical fractals with unique visual characteristics")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // Zoom Speed
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Zoom Speed")
                                    .font(.headline)
                                Spacer()
                                Text(String(format: "%.1fx", settingsManager.fractalZoomSpeed))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { Double(settingsManager.fractalZoomSpeed) },
                                    set: { settingsManager.fractalZoomSpeed = Float($0) }
                                ),
                                in: 0.1...3.0,
                                step: 0.1
                            )
                            .accessibilityIdentifier("zoomSpeedSlider")
                            
                            Text("Controls how fast the fractal zooms in response to audio")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // Color Intensity
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Color Intensity")
                                    .font(.headline)
                                Spacer()
                                Text(String(format: "%.1f", settingsManager.fractalColorIntensity))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { Double(settingsManager.fractalColorIntensity) },
                                    set: { settingsManager.fractalColorIntensity = Float($0) }
                                ),
                                in: 0.1...2.0,
                                step: 0.1
                            )
                            .accessibilityIdentifier("colorIntensitySlider")
                            
                            Text("Adjusts the vibrancy of colors in response to audio frequencies")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Reset Section
                Section {
                    Button(action: {
                        settingsManager.resetToDefaults()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reset to Defaults")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .accessibilityIdentifier("SettingsView")
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ThemePreviewCard: View {
    let theme: ColorTheme
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Color preview
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.color(for: index, totalBands: 5))
                        .frame(height: 30)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            Text(theme.displayName)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    SettingsView()
}