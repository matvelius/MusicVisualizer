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
    // @State private var gpuTreeRenderer: GPUTreeRenderer? // Temporarily disabled
    @State private var cancellables = Set<AnyCancellable>()
    @State private var settingsManager = SettingsManager.shared
    @State private var errorMessage: String?
    @State private var useGPURenderer: Bool = false // Phase 4: Enable GPU tree rendering (temporarily disabled)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Phase 4: Using CPU tree renderer with ProMotion optimizations
                if let treeRenderer = treeRenderer {
                    TreeVisualizationMetalView(renderer: treeRenderer)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    ErrorView(message: errorMessage) {
                        initializeCPUTreeRenderer()
                    }
                } else {
                    LoadingView(message: "Growing the Tree of Life...")
                }
                
                // Debug info overlay (only in debug builds)
                #if DEBUG
                VStack {
                    HStack {
                        if useGPURenderer {
                            Text("GPU Tree Renderer Active")
                                .font(.caption)
                                .foregroundColor(.green.opacity(0.8))
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                        } else if let treeRenderer = treeRenderer {
                            Text(treeRenderer.debugInfo)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding()
                #endif
            }
        }
        .background(Color.black)
        .onAppear {
            initializeCPUTreeRenderer()
            setupAudioVisualization()
            setupBackgroundStateHandling()
        }
        .onDisappear {
            cleanupVisualization()
        }
        .accessibilityIdentifier("TreeVisualizerView")
        .accessibilityLabel("Tree music visualizer")
    }
    
    // Phase 4 GPU renderer functions - temporarily disabled
    /*
    private func initializeRenderers() {
        if useGPURenderer {
            initializeGPUTreeRenderer()
        } else {
            initializeCPUTreeRenderer()
        }
    }
    
    private func initializeGPUTreeRenderer() {
        do {
            let renderer = try GPUTreeRenderer()
            self.gpuTreeRenderer = renderer
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            print("Failed to initialize GPUTreeRenderer: \(error)")
            
            // Fallback to CPU renderer
            print("Falling back to CPU tree renderer...")
            useGPURenderer = false
            initializeCPUTreeRenderer()
        }
    }
    */
    
    private func initializeCPUTreeRenderer() {
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
        audioVisualizerService.onFrequencyDataUpdate = { frequencyData in
            // Process audio data for tree parameters
            let audioData = self.processAudioForTree(frequencyData)
            
            // Update tree renderer with audio data  
            self.treeRenderer?.updateAudioData(
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
                self.treeRenderer?.isAnimating = false
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in
                self.treeRenderer?.isAnimating = true
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { _ in
                self.treeRenderer?.isAnimating = false
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { _ in
                self.treeRenderer?.isAnimating = true
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

// MARK: - Error and Loading Views (references from FractalVisualizerView)
// ErrorView and LoadingView are defined in FractalVisualizerView.swift - no duplication needed

// MARK: - Metal View Integration

struct TreeVisualizationMetalView: UIViewRepresentable {
    let renderer: TreeVisualizationRenderer
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.delegate = context.coordinator
        
        // Apply Phase 4 ProMotion optimizations
        configureProMotionDisplay(metalView)
        
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = false
        metalView.framebufferOnly = false
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        return metalView
    }
    
    private func configureProMotionDisplay(_ metalView: MTKView) {
        // Phase 4: ProMotion display configuration for Tree visualization
        if #available(iOS 15.0, macOS 12.0, *) {
            if let screen = UIScreen.main as UIScreen? {
                let maxRefreshRate = screen.maximumFramesPerSecond
                
                if maxRefreshRate >= 120 {
                    // ProMotion display detected
                    metalView.preferredFramesPerSecond = maxRefreshRate
                    print("ProMotion Tree Rendering: \(maxRefreshRate)Hz")
                    
                    if #available(iOS 15.0, *) {
                        // Display sync handled by CAMetalLayer
                    }
                } else {
                    metalView.preferredFramesPerSecond = 60
                }
            } else {
                metalView.preferredFramesPerSecond = 120
            }
        } else {
            metalView.preferredFramesPerSecond = 60
        }
        
        // Configure for optimal tree rendering
        if let metalLayer = metalView.layer as? CAMetalLayer {
            // displaySyncEnabled not available - handled by preferredFramesPerSecond
            metalLayer.presentsWithTransaction = false
        }
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

// MARK: - GPU Tree Metal View

struct GPUTreeMetalView: UIViewRepresentable {
    let renderer: GPUTreeRenderer
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.delegate = context.coordinator
        
        // Apply Phase 4 ProMotion optimizations for GPU tree rendering
        configureProMotionDisplay(metalView)
        
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = false
        metalView.framebufferOnly = true  // GPU rendering can be more aggressive
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        // Configure for triple buffering
        if let metalLayer = metalView.layer as? CAMetalLayer {
            metalLayer.maximumDrawableCount = 3
        }
        
        return metalView
    }
    
    private func configureProMotionDisplay(_ metalView: MTKView) {
        // Phase 4: Advanced ProMotion configuration for GPU tree rendering
        if #available(iOS 15.0, macOS 12.0, *) {
            if let screen = UIScreen.main as UIScreen? {
                let maxRefreshRate = screen.maximumFramesPerSecond
                
                if maxRefreshRate >= 120 {
                    metalView.preferredFramesPerSecond = maxRefreshRate
                    print("GPU Tree ProMotion: \(maxRefreshRate)Hz")
                    
                    if #available(iOS 15.0, *) {
                        // Display sync handled by CAMetalLayer
                    }
                } else {
                    metalView.preferredFramesPerSecond = 60
                }
            } else {
                metalView.preferredFramesPerSecond = 120
            }
        } else {
            metalView.preferredFramesPerSecond = 60
        }
        
        // GPU-specific optimizations
        if let metalLayer = metalView.layer as? CAMetalLayer {
            // displaySyncEnabled not available - handled by preferredFramesPerSecond
            metalLayer.presentsWithTransaction = false
            metalLayer.allowsNextDrawableTimeout = false
        }
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Update any necessary view properties
    }
    
    func makeCoordinator() -> GPUTreeCoordinator {
        GPUTreeCoordinator(renderer: renderer)
    }
    
    class GPUTreeCoordinator: NSObject, MTKViewDelegate {
        let renderer: GPUTreeRenderer
        
        init(renderer: GPUTreeRenderer) {
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
            
            // Render GPU-computed tree visualization
            renderer.render(to: drawable, in: view)
        }
    }
}

// MARK: - Previews

#Preview("Tree Visualizer") {
    TreeVisualizerView(audioVisualizerService: AudioVisualizerService(bandCount: 21))
        .background(Color.black)
}