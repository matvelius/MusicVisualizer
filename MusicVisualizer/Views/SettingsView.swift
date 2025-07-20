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