//
//  ContentView.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var settingsManager = SettingsManager.shared
    @State private var showingSettings = false
    @State private var sharedAudioService: AudioVisualizerService
    
    init() {
        self._sharedAudioService = State(initialValue: AudioVisualizerService(bandCount: 21))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                GeometryReader { geometry in
                    let isLandscape = geometry.size.width > geometry.size.height
                    
                    // Visualization based on current mode
                    Group {
                        switch settingsManager.visualizationMode {
                        case .bars:
                            EqualizerView(barCount: settingsManager.bandCount, audioVisualizerService: sharedAudioService)
                        case .fractals:
                            FractalVisualizerView(audioVisualizerService: sharedAudioService)
                        }
                    }
                    .animation(.easeInOut(duration: 0.5), value: settingsManager.visualizationMode)
                    .animation(.easeInOut(duration: 0.3), value: isLandscape)
                    .animation(.easeInOut(duration: 0.3), value: settingsManager.bandCount)
                }
                
                // Settings button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gear")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.8))
                                .padding()
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .statusBarHidden()
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            Task {
                await sharedAudioService.startVisualization()
            }
        }
    }
}

#Preview("Portrait") {
    HomeView()
        .previewInterfaceOrientation(.portrait)
}

#Preview("Landscape") {
    HomeView()
        .previewInterfaceOrientation(.landscapeLeft)
}
