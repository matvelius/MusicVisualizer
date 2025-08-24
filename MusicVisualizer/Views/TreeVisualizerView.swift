//
//  TreeVisualizerView.swift
//  MusicVisualizer
//
//  Created by Claude Code on 7/29/25.
//

import SwiftUI
import MetalKit
import Combine

struct TreeVisualizerView: View {
    let audioVisualizerService: AudioVisualizerService
    @State private var treeRenderer: TreeVisualizationRenderer?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var settingsManager = SettingsManager.shared
    @State private var errorMessage: String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let treeRenderer = treeRenderer {
                    TreeVisualizationMetalView(renderer: treeRenderer)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Tree Renderer Error")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .accessibilityIdentifier("Tree Renderer Error")
                        
                        Text(errorMessage)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Retry") {
                            initializeTreeRenderer()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("Retry")
                    }
                    .padding()
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Growing the Tree of Life...")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Debug info overlay (only in debug builds)
                #if DEBUG
                if let treeRenderer = treeRenderer {
                    VStack {
                        HStack {
                            Text(treeRenderer.debugInfo)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding()
                }
                #endif
            }
        }
        .background(Color.black)
        .onAppear {
            initializeTreeRenderer()
            setupAudioVisualization()
            setupBackgroundStateHandling()
        }
        .onDisappear {
            cleanupVisualization()
        }
        .accessibilityIdentifier("TreeVisualizerView")
        .accessibilityLabel("Tree music visualizer")
    }
    
    private func initializeTreeRenderer() {
        do {
            let renderer = try TreeVisualizationRenderer()
            self.treeRenderer = renderer
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            print("Failed to initialize TreeVisualizationRenderer: \(error)")
        }
    }
    
    private func setupAudioVisualization() {
        // Connect audio data to tree parameters
        audioVisualizerService.onFrequencyDataUpdate = { [weak treeRenderer] frequencyData in
            guard let renderer = treeRenderer else { return }
            
            // Process audio data for tree parameters
            let audioData = processAudioForTree(frequencyData)
            
            // Update tree renderer with audio data
            renderer.updateAudioData(
                low: audioData.low,
                mid: audioData.mid,
                high: audioData.high,
                overall: audioData.overall
            )
        }
        
        // Monitor color theme changes
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak treeRenderer] _ in
                // Tree renderer will automatically pick up theme changes through SettingsManager
            }
            .store(in: &cancellables)
    }
    
    private func setupBackgroundStateHandling() {
        // Pause/resume tree animation based on app state
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { _ in
                treeRenderer?.isAnimating = false
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in
                treeRenderer?.isAnimating = true
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { _ in
                treeRenderer?.isAnimating = false
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { _ in
                treeRenderer?.isAnimating = true
            }
            .store(in: &cancellables)
    }
    
    private func cleanupVisualization() {
        cancellables.removeAll()
        treeRenderer?.isAnimating = false
    }
    
    private func processAudioForTree(_ frequencyData: [Float]) -> (low: Float, mid: Float, high: Float, overall: Float) {
        guard !frequencyData.isEmpty else {
            return (low: 0.0, mid: 0.0, high: 0.0, overall: 0.0)
        }
        
        let count = frequencyData.count
        let lowEnd = count / 4
        let midStart = lowEnd
        let midEnd = count * 3 / 4
        let highStart = midEnd
        
        // Calculate frequency band averages
        let lowFreq = Array(frequencyData[0..<lowEnd]).reduce(0, +) / Float(lowEnd)
        let midFreq = Array(frequencyData[midStart..<midEnd]).reduce(0, +) / Float(midEnd - midStart)
        let highFreq = Array(frequencyData[highStart..<count]).reduce(0, +) / Float(count - highStart)
        
        // Calculate overall amplitude
        let overall = frequencyData.reduce(0, +) / Float(count)
        
        // Apply smoothing and scaling optimized for tree growth
        let smoothedLow = min(1.0, max(0.0, lowFreq * 1.8))    // Affects root growth
        let smoothedMid = min(1.0, max(0.0, midFreq * 2.2))    // Affects branching
        let smoothedHigh = min(1.0, max(0.0, highFreq * 2.5))  // Affects leaf color
        let smoothedOverall = min(1.0, max(0.0, overall * 1.2)) // Affects overall growth speed
        
        return (low: smoothedLow, mid: smoothedMid, high: smoothedHigh, overall: smoothedOverall)
    }
}

// MARK: - Metal View Integration

struct TreeVisualizationMetalView: UIViewRepresentable {
    let renderer: TreeVisualizationRenderer
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.delegate = context.coordinator
        metalView.preferredFramesPerSecond = 60
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = false
        metalView.framebufferOnly = false
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Update any necessary view properties
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(renderer: renderer)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        let renderer: TreeVisualizationRenderer
        
        init(renderer: TreeVisualizationRenderer) {
            self.renderer = renderer
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle size changes if needed
        }
        
        func draw(in view: MTKView) {
            guard renderer.isAnimating,
                  let drawable = view.currentDrawable else {
                return
            }
            
            // Render tree visualization
            renderer.render(to: drawable, in: view)
        }
    }
}

// MARK: - Previews

#Preview("Tree Visualizer") {
    TreeVisualizerView(audioVisualizerService: AudioVisualizerService(bandCount: 21))
        .background(Color.black)
}