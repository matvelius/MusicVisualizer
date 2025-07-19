//
//  EqualizerView.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import SwiftUI

struct EqualizerView: View {
    @State private var viewModel = EqualizerViewModel()
    @State private var audioVisualizerService: AudioVisualizerService
    
    let barCount: Int
    let barSpacing: CGFloat = 4
    let minBarHeight: CGFloat = 2
    
    init(barCount: Int = 8) {
        self.barCount = barCount
        self._audioVisualizerService = State(initialValue: AudioVisualizerService(bandCount: barCount))
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    EqualizerBar(
                        height: barHeight(for: index, in: geometry),
                        color: barColor(for: index),
                        index: index
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
        }
        .accessibilityIdentifier("EqualizerView")
        .accessibilityLabel("Audio frequency equalizer")
        .onAppear {
            viewModel = EqualizerViewModel(bandCount: barCount)
            viewModel.startAnimation()
            
            // Connect audio visualizer service to view model
            audioVisualizerService.onFrequencyDataUpdate = { frequencyData in
                viewModel.updateFrequencyData(frequencyData)
            }
            
            // Start real-time audio visualization
            Task {
                await audioVisualizerService.startVisualization()
            }
            
            // Add some test data for UI testing when no audio is available
            #if DEBUG
            if !audioVisualizerService.isRunning {
                let testData: [Float] = Array(0..<barCount).map { index in
                    Float(0.3 + 0.1 * sin(Double(index) * 0.5)) // Varying heights for visibility
                }
                viewModel.updateFrequencyData(testData)
            }
            #endif
        }
        .onDisappear {
            viewModel.stopAnimation()
            audioVisualizerService.stopVisualization()
        }
    }
    
    private func barHeight(for index: Int, in geometry: GeometryProxy) -> CGFloat {
        let maxHeight = geometry.size.height - 40 // Leave some padding
        let heightRatio = viewModel.barHeights.indices.contains(index) ? viewModel.barHeights[index] : 0.0
        return max(minBarHeight, CGFloat(heightRatio) * maxHeight)
    }
    
    private func barColor(for index: Int) -> Color {
        let hue = Double(index) / Double(barCount) * 0.7 // Use first 70% of hue spectrum (red to blue)
        return Color(hue: hue, saturation: 0.8, brightness: 0.9)
    }
}

struct EqualizerBar: View {
    let height: CGFloat
    let color: Color
    let index: Int
    
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [color.opacity(0.8), color]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 1)
            .accessibilityHidden(true)
    }
}

#Preview("Equalizer View - 8 Bands") {
    EqualizerView(barCount: 8)
        .frame(height: 300)
        .background(Color.black)
}

#Preview("Equalizer View - 12 Bands") {
    EqualizerView(barCount: 12)
        .frame(height: 200)
        .background(Color.black)
}

#Preview("Equalizer Bar") {
    VStack(spacing: 20) {
        EqualizerBar(height: 50, color: .blue, index: 0)
        EqualizerBar(height: 100, color: .green, index: 1)  
        EqualizerBar(height: 150, color: .red, index: 2)
    }
    .padding()
}