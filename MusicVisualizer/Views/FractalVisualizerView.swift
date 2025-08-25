//
//  FractalVisualizerView.swift
//  MusicVisualizer
//
//  Created by Claude Code on 7/24/25.
//

import SwiftUI
import MetalKit
import Combine
import QuartzCore

struct FractalVisualizerView: View {
    let audioVisualizerService: AudioVisualizerService
    @State private var fractalRenderer: GenerativeFractalRenderer?
    @State private var gpuFractalRenderer: GPUFractalRenderer?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var settingsManager = SettingsManager.shared
    @State private var errorMessage: String?
    @State private var useGPURenderer: Bool = true // Phase 2: Enable GPU rendering by default
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if useGPURenderer {
                    if let gpuRenderer = gpuFractalRenderer {
                        GPUFractalMetalView(renderer: gpuRenderer)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage = errorMessage {
                        ErrorView(message: errorMessage) {
                            initializeGPUFractalRenderer()
                        }
                    } else {
                        LoadingView(message: "Initializing GPU Fractal Engine...")
                    }
                } else if let fractalRenderer = fractalRenderer {
                    GenerativeFractalMetalView(renderer: fractalRenderer)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    ErrorView(message: errorMessage) {
                        initializeFractalRenderer()
                    }
                } else {
                    LoadingView(message: "Initializing Generative Fractal Engine...")
                }
            }
        }
        .background(Color.black)
        .onAppear {
            if useGPURenderer {
                initializeGPUFractalRenderer()
            } else {
                initializeFractalRenderer()
            }
            setupAudioVisualization()
            setupBackgroundStateHandling()
        }
        .onDisappear {
            cleanupVisualization()
        }
        .accessibilityIdentifier("FractalVisualizerView")
        .accessibilityLabel("Fractal music visualizer")
    }
    
    private func initializeGPUFractalRenderer() {
        do {
            let renderer = try GPUFractalRenderer()
            self.gpuFractalRenderer = renderer
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            print("Failed to initialize GPUFractalRenderer: \(error)")
            
            // Fallback to CPU renderer
            print("Falling back to CPU particle renderer...")
            useGPURenderer = false
            initializeFractalRenderer()
        }
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
        // Connect audio data to fractal parameters - ultra-low latency path
        audioVisualizerService.onFrequencyDataUpdate = { frequencyData in
            // Process audio data for fractals (inline for speed)
            let audioData = self.processAudioForFractalsInline(frequencyData)
            
            // Update appropriate renderer based on current mode
            if self.useGPURenderer {
                if let renderer = self.gpuFractalRenderer {
                    // GPU renderer can handle cross-thread calls efficiently
                    renderer.updateAudioData(
                        low: audioData.low,
                        mid: audioData.mid,
                        high: audioData.high,
                        overall: audioData.overall
                    )
                }
            } else {
                if let renderer = self.fractalRenderer {
                    // CPU renderer update path
                    if Thread.isMainThread {
                        renderer.updateAudioData(
                            low: audioData.low,
                            mid: audioData.mid,
                            high: audioData.high,
                            overall: audioData.overall
                        )
                    } else {
                        DispatchQueue.main.async {
                            renderer.updateAudioData(
                                low: audioData.low,
                                mid: audioData.mid,
                                high: audioData.high,
                                overall: audioData.overall
                            )
                        }
                    }
                }
            }
        }
        
        // Monitor fractal type changes using UserDefaults
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { _ in
                if self.useGPURenderer {
                    self.gpuFractalRenderer?.updateFractalType()
                } else {
                    self.fractalRenderer?.updateFractalType()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupBackgroundStateHandling() {
        // Pause/resume fractal animation based on app state
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { _ in
                if self.useGPURenderer {
                    self.gpuFractalRenderer?.isAnimating = false
                } else {
                    self.fractalRenderer?.isAnimating = false
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in
                if self.useGPURenderer {
                    self.gpuFractalRenderer?.isAnimating = true
                } else {
                    self.fractalRenderer?.isAnimating = true
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { _ in
                if self.useGPURenderer {
                    self.gpuFractalRenderer?.isAnimating = false
                } else {
                    self.fractalRenderer?.isAnimating = false
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { _ in
                if self.useGPURenderer {
                    self.gpuFractalRenderer?.isAnimating = true
                } else {
                    self.fractalRenderer?.isAnimating = true
                }
            }
            .store(in: &cancellables)
    }
    
    private func cleanupVisualization() {
        cancellables.removeAll()
        if useGPURenderer {
            gpuFractalRenderer?.isAnimating = false
        } else {
            fractalRenderer?.isAnimating = false
        }
    }
    
    private func processAudioForFractalsInline(_ frequencyData: [Float]) -> (low: Float, mid: Float, high: Float, overall: Float) {
        guard !frequencyData.isEmpty else {
            return (low: 0.0, mid: 0.0, high: 0.0, overall: 0.0)
        }
        
        let count = frequencyData.count
        let lowEnd = count / 4
        let midStart = lowEnd
        let midEnd = count * 3 / 4
        let highStart = midEnd
        
        // Optimized frequency band calculation using unsafe buffer pointer
        var lowSum: Float = 0
        var midSum: Float = 0
        var highSum: Float = 0
        var overallSum: Float = 0
        
        frequencyData.withUnsafeBufferPointer { buffer in
            // Low frequencies
            for i in 0..<lowEnd {
                lowSum += buffer[i]
            }
            // Mid frequencies
            for i in midStart..<midEnd {
                midSum += buffer[i]
            }
            // High frequencies
            for i in highStart..<count {
                highSum += buffer[i]
            }
            // Overall sum
            for i in 0..<count {
                overallSum += buffer[i]
            }
        }
        
        // Calculate averages
        let lowFreq = lowSum / Float(lowEnd)
        let midFreq = midSum / Float(midEnd - midStart)
        let highFreq = highSum / Float(count - highStart)
        let overall = overallSum / Float(count)
        
        // Apply smoothing and scaling with faster operations
        let smoothedLow = min(1.0, max(0.0, lowFreq * 2.0))
        let smoothedMid = min(1.0, max(0.0, midFreq * 2.0))
        let smoothedHigh = min(1.0, max(0.0, highFreq * 2.0))
        let smoothedOverall = min(1.0, max(0.0, overall * 1.5))
        
        return (low: smoothedLow, mid: smoothedMid, high: smoothedHigh, overall: smoothedOverall)
    }
    
    private func processAudioForFractals(_ frequencyData: [Float]) -> (low: Float, mid: Float, high: Float, overall: Float) {
        return processAudioForFractalsInline(frequencyData)
    }
}

// MARK: - Helper Views

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Fractal Renderer Error")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityIdentifier("Fractal Renderer Error")
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Retry") {
                retryAction()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("Retry")
        }
        .padding()
    }
}

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(message)
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Metal View Integration

struct GenerativeFractalMetalView: UIViewRepresentable {
    let renderer: GenerativeFractalRenderer
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.delegate = context.coordinator
        
        // Ultra-low latency settings
        if #available(iOS 15.0, macOS 12.0, *) {
            metalView.preferredFramesPerSecond = 120  // Use ProMotion if available
        } else {
            metalView.preferredFramesPerSecond = 60
        }
        
        metalView.enableSetNeedsDisplay = false  // Manual control
        metalView.isPaused = false
        metalView.framebufferOnly = true  // Optimize for performance
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

// MARK: - GPU Metal View Integration

struct GPUFractalMetalView: UIViewRepresentable {
    let renderer: GPUFractalRenderer
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.delegate = context.coordinator
        
        // Ultra-low latency settings
        if #available(iOS 15.0, macOS 12.0, *) {
            metalView.preferredFramesPerSecond = 120  // Use ProMotion if available
        } else {
            metalView.preferredFramesPerSecond = 60
        }
        
        metalView.enableSetNeedsDisplay = false  // Manual control
        metalView.isPaused = false
        metalView.framebufferOnly = true  // Optimize for performance
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Update any necessary view properties
    }
    
    func makeCoordinator() -> GPUCoordinator {
        GPUCoordinator(renderer: renderer)
    }
    
    class GPUCoordinator: NSObject, MTKViewDelegate {
        let renderer: GPUFractalRenderer
        
        init(renderer: GPUFractalRenderer) {
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
            
            // Render GPU-computed fractals
            renderer.render(to: drawable, in: view)
        }
    }
}

// MARK: - Previews

#Preview("Fractal Visualizer") {
    FractalVisualizerView(audioVisualizerService: AudioVisualizerService(bandCount: 21))
        .background(Color.black)
}