//
//  CircularEqualizerView.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import SwiftUI
import Combine

struct CircularEqualizerView: View {
    @State private var viewModel = EqualizerViewModel()
    @State private var cancellables = Set<AnyCancellable>()
    @State private var settingsManager = SettingsManager.shared
    
    let barCount: Int
    let audioVisualizerService: AudioVisualizerService
    let minBarHeight: CGFloat = 10
    let maxBarHeight: CGFloat = 80
    
    init(barCount: Int = 21, audioVisualizerService: AudioVisualizerService) {
        self.barCount = barCount
        self.audioVisualizerService = audioVisualizerService
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = (size - maxBarHeight * 2) / 2
            
            ZStack {
                // Central circle
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                
                // Circular bars
                ForEach(0..<barCount, id: \.self) { index in
                    CircularBar(
                        index: index,
                        totalBars: barCount,
                        center: center,
                        radius: radius,
                        height: barHeight(for: index),
                        color: barColor(for: index)
                    )
                }
            }
            .animation(.easeInOut(duration: 0.3), value: geometry.size)
        }
        .onAppear {
            setupVisualization()
            setupBackgroundStateHandling()
        }
        .onDisappear {
            cleanupVisualization()
        }
    }
    
    func barHeight(for index: Int) -> CGFloat {
        let heightRatio = viewModel.barHeights.indices.contains(index) ? viewModel.barHeights[index] : 0.0
        let calculatedHeight = CGFloat(heightRatio) * maxBarHeight
        return max(minBarHeight, calculatedHeight)
    }
    
    func barColor(for index: Int) -> Color {
        return settingsManager.colorTheme.color(for: index, totalBands: barCount)
    }
    
    // MARK: - Background State Handling
    
    private func setupVisualization() {
        viewModel = EqualizerViewModel(bandCount: barCount)
        viewModel.startAnimation()
        
        audioVisualizerService.onFrequencyDataUpdate = { frequencyData in
            viewModel.updateFrequencyData(frequencyData)
        }
        
        // Don't start the service here - let HomeView manage the service lifecycle
        
        #if DEBUG
        if !audioVisualizerService.isRunning {
            let testData: [Float] = Array(0..<barCount).map { index in
                Float(0.3 + 0.1 * sin(Double(index) * 0.5))
            }
            viewModel.updateFrequencyData(testData)
        }
        #endif
    }
    
    private func setupBackgroundStateHandling() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { _ in pauseVisualization() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in resumeVisualization() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { _ in pauseVisualization() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { _ in resumeVisualization() }
            .store(in: &cancellables)
    }
    
    private func pauseVisualization() {
        // Don't stop the service, just pause the animation
        viewModel.stopAnimation()
    }
    
    private func resumeVisualization() {
        // Just resume the animation
        viewModel.startAnimation()
    }
    
    private func cleanupVisualization() {
        cancellables.removeAll()
        viewModel.stopAnimation()
        // Don't stop the service - let HomeView manage it
    }
}

struct CircularBar: View {
    let index: Int
    let totalBars: Int
    let center: CGPoint
    let radius: CGFloat
    let height: CGFloat
    let color: Color
    
    var angle: Double {
        let anglePerBar = 360.0 / Double(totalBars)
        return Double(index) * anglePerBar - 90 // Start from top
    }
    
    var barPosition: CGPoint {
        let radians = angle * Double.pi / 180
        return CGPoint(
            x: center.x + CGFloat(cos(radians)) * radius,
            y: center.y + CGFloat(sin(radians)) * radius
        )
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [color.opacity(0.6), color]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: height, height: 6)
            .position(barPosition)
            .rotationEffect(.degrees(angle + 90))
            .animation(.linear(duration: 1.0/60.0), value: height)
    }
}

#Preview("Circular Equalizer - 21 Bands") {
    CircularEqualizerView(barCount: 21, audioVisualizerService: AudioVisualizerService(bandCount: 21))
        .background(Color.black)
}

#Preview("Circular Equalizer - 12 Bands") {
    CircularEqualizerView(barCount: 12, audioVisualizerService: AudioVisualizerService(bandCount: 12))
        .background(Color.black)
}