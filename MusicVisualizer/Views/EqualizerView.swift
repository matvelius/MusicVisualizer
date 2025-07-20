//
//  EqualizerView.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import SwiftUI
import Combine

struct EqualizerView: View {
    @State private var viewModel = EqualizerViewModel()
    @State private var audioVisualizerService: AudioVisualizerService
    @State private var cancellables = Set<AnyCancellable>()
    
    let barCount: Int
    let minBarHeight: CGFloat = 2
    
    // Adaptive spacing and sizing based on orientation and device
    private func adaptiveBarSpacing(for geometry: GeometryProxy) -> CGFloat {
        let isLandscape = geometry.size.width > geometry.size.height
        let padding = adaptivePadding(for: geometry)
        let availableWidth = geometry.size.width - padding.leading - padding.trailing
        
        // Calculate optimal spacing based on available width and bar count
        let baseSpacing: CGFloat = isLandscape ? 2 : 4
        let maxSpacing: CGFloat = isLandscape ? 4 : 8
        let calculatedSpacing = availableWidth / CGFloat(barCount) * 0.08
        
        return min(maxSpacing, max(baseSpacing, calculatedSpacing))
    }
    
    private func adaptivePadding(for geometry: GeometryProxy) -> EdgeInsets {
        let isLandscape = geometry.size.width > geometry.size.height
        let isCompact = geometry.size.width < 768 // iPhone size threshold
        
        if isLandscape {
            return EdgeInsets(
                top: 8,
                leading: isCompact ? 16 : 32,
                bottom: 8,
                trailing: isCompact ? 16 : 32
            )
        } else {
            return EdgeInsets(
                top: isCompact ? 16 : 24,
                leading: 16,
                bottom: isCompact ? 16 : 24,
                trailing: 16
            )
        }
    }
    
    init(barCount: Int = 21) {
        self.barCount = barCount
        self._audioVisualizerService = State(initialValue: AudioVisualizerService(bandCount: barCount))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let spacing = adaptiveBarSpacing(for: geometry)
            let padding = adaptivePadding(for: geometry)
            
            HStack(spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    EqualizerBar(
                        height: barHeight(for: index, in: geometry),
                        color: barColor(for: index),
                        index: index,
                        isLandscape: isLandscape
                    )
                    .drawingGroup() // Optimize rendering by rasterizing
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(padding)
            .animation(.easeInOut(duration: 0.3), value: isLandscape)
        }
        .drawingGroup() // Rasterize entire equalizer for better performance
        .accessibilityIdentifier("EqualizerView")
        .accessibilityLabel("Audio frequency equalizer")
        .onAppear {
            setupVisualization()
            setupBackgroundStateHandling()
        }
        .onDisappear {
            cleanupVisualization()
        }
    }
    
    private func barHeight(for index: Int, in geometry: GeometryProxy) -> CGFloat {
        let isLandscape = geometry.size.width > geometry.size.height
        let padding = adaptivePadding(for: geometry)
        let maxHeight = geometry.size.height - padding.top - padding.bottom
        
        let heightRatio = viewModel.barHeights.indices.contains(index) ? viewModel.barHeights[index] : 0.0
        let calculatedHeight = CGFloat(heightRatio) * maxHeight
        
        // In landscape, ensure minimum height is more visible
        let adaptiveMinHeight = isLandscape ? minBarHeight * 1.5 : minBarHeight
        return max(adaptiveMinHeight, calculatedHeight)
    }
    
    private func barColor(for index: Int) -> Color {
        let hue = Double(index) / Double(barCount) * 0.7 // Use first 70% of hue spectrum (red to blue)
        return Color(hue: hue, saturation: 0.8, brightness: 0.9)
    }
    
    // MARK: - Background State Handling
    
    private func setupVisualization() {
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
    
    private func setupBackgroundStateHandling() {
        // Listen for app state changes
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { _ in
                pauseVisualization()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in
                resumeVisualization()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { _ in
                pauseVisualization()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { _ in
                resumeVisualization()
            }
            .store(in: &cancellables)
    }
    
    private func pauseVisualization() {
        audioVisualizerService.stopVisualization()
        viewModel.stopAnimation()
    }
    
    private func resumeVisualization() {
        viewModel.startAnimation()
        Task {
            await audioVisualizerService.startVisualization()
        }
    }
    
    private func cleanupVisualization() {
        cancellables.removeAll()
        viewModel.stopAnimation()
        audioVisualizerService.stopVisualization()
    }
}

struct EqualizerBar: View {
    let height: CGFloat
    let color: Color
    let index: Int
    let isLandscape: Bool
    
    // Pre-compute gradient for better performance
    private var optimizedGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [color.opacity(0.8), color]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // Adaptive corner radius and shadow based on orientation
    private var adaptiveCornerRadius: CGFloat {
        isLandscape ? 2 : 3
    }
    
    private var adaptiveShadowRadius: CGFloat {
        isLandscape ? 1 : 2
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: adaptiveCornerRadius)
            .fill(optimizedGradient)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .shadow(color: color.opacity(0.3), radius: adaptiveShadowRadius, x: 0, y: 1)
            .accessibilityHidden(true)
            .animation(.linear(duration: 1.0/60.0), value: height) // Explicit 60fps animation
    }
}

#Preview("Equalizer View - 21 Bands") {
    EqualizerView(barCount: 21)
        .frame(height: 300)
        .background(Color.black)
}

#Preview("Equalizer View - iPad Portrait") {
    EqualizerView(barCount: 21)
        .frame(width: 768, height: 1024)
        .background(Color.black)
}

#Preview("Equalizer View - iPad Landscape") {
    EqualizerView(barCount: 21)
        .frame(width: 1024, height: 768)
        .background(Color.black)
}

#Preview("Equalizer View - iPhone") {
    EqualizerView(barCount: 21)
        .frame(width: 390, height: 844)
        .background(Color.black)
}

#Preview("Equalizer Bar - Portrait") {
    VStack(spacing: 20) {
        EqualizerBar(height: 50, color: .blue, index: 0, isLandscape: false)
        EqualizerBar(height: 100, color: .green, index: 1, isLandscape: false)  
        EqualizerBar(height: 150, color: .red, index: 2, isLandscape: false)
    }
    .padding()
}

#Preview("Equalizer Bar - Landscape") {
    HStack(spacing: 10) {
        EqualizerBar(height: 30, color: .blue, index: 0, isLandscape: true)
        EqualizerBar(height: 60, color: .green, index: 1, isLandscape: true)  
        EqualizerBar(height: 90, color: .red, index: 2, isLandscape: true)
    }
    .padding()
}