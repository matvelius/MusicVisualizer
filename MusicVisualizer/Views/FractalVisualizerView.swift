//
//  FractalVisualizerView.swift
//  MusicVisualizer
//
//  Created by Claude Code on 7/24/25.
//

import SwiftUI
import MetalKit
import Combine

struct FractalVisualizerView: View {
    let audioVisualizerService: AudioVisualizerService
    @State private var fractalRenderer: GenerativeFractalRenderer?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var settingsManager = SettingsManager.shared
    @State private var errorMessage: String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let fractalRenderer = fractalRenderer {
                    GenerativeFractalMetalView(renderer: fractalRenderer)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Fractal Renderer Error")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .accessibilityIdentifier("Fractal Renderer Error")
                        
                        Text(errorMessage)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Retry") {
                            initializeFractalRenderer()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("Retry")
                    }
                    .padding()
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Initializing Generative Fractal Engine...")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .background(Color.black)
        .onAppear {
            initializeFractalRenderer()
            setupAudioVisualization()
            setupBackgroundStateHandling()
        }
        .onDisappear {
            cleanupVisualization()
        }
        .accessibilityIdentifier("FractalVisualizerView")
        .accessibilityLabel("Fractal music visualizer")
    }
    
    private func initializeFractalRenderer() {
        do {
            let renderer = try GenerativeFractalRenderer()
            self.fractalRenderer = renderer
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            print("Failed to initialize GenerativeFractalRenderer: \(error)")
        }
    }
    
    private func setupAudioVisualization() {
        // Connect audio data to fractal parameters
        audioVisualizerService.onFrequencyDataUpdate = { [weak fractalRenderer] frequencyData in
            guard let renderer = fractalRenderer else { return }
            
            // Process audio data for fractal parameters
            let audioData = processAudioForFractals(frequencyData)
            
            // Update fractal renderer with audio data
            renderer.updateAudioData(
                low: audioData.low,
                mid: audioData.mid,
                high: audioData.high,
                overall: audioData.overall
            )
        }
        
        // Monitor fractal type changes using UserDefaults
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak fractalRenderer] _ in
                fractalRenderer?.updateFractalType()
            }
            .store(in: &cancellables)
    }
    
    private func setupBackgroundStateHandling() {
        // Pause/resume fractal animation based on app state
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { _ in
                fractalRenderer?.isAnimating = false
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in
                fractalRenderer?.isAnimating = true
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { _ in
                fractalRenderer?.isAnimating = false
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { _ in
                fractalRenderer?.isAnimating = true
            }
            .store(in: &cancellables)
    }
    
    private func cleanupVisualization() {
        cancellables.removeAll()
        fractalRenderer?.isAnimating = false
    }
    
    private func processAudioForFractals(_ frequencyData: [Float]) -> (low: Float, mid: Float, high: Float, overall: Float) {
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
        
        // Apply smoothing and scaling
        let smoothedLow = min(1.0, max(0.0, lowFreq * 2.0))
        let smoothedMid = min(1.0, max(0.0, midFreq * 2.0))
        let smoothedHigh = min(1.0, max(0.0, highFreq * 2.0))
        let smoothedOverall = min(1.0, max(0.0, overall * 1.5))
        
        return (low: smoothedLow, mid: smoothedMid, high: smoothedHigh, overall: smoothedOverall)
    }
}

// MARK: - Metal View Integration

struct GenerativeFractalMetalView: UIViewRepresentable {
    let renderer: GenerativeFractalRenderer
    
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
        let renderer: GenerativeFractalRenderer
        
        init(renderer: GenerativeFractalRenderer) {
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
            
            // Render generative fractals
            renderer.render(to: drawable, in: view)
        }
    }
}

// MARK: - Previews

#Preview("Fractal Visualizer") {
    FractalVisualizerView(audioVisualizerService: AudioVisualizerService(bandCount: 21))
        .background(Color.black)
}