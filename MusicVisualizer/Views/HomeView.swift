//
//  ContentView.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                
                EqualizerView(barCount: 21)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.ignoresSafeArea())
                    .animation(.easeInOut(duration: 0.3), value: isLandscape)
            }
            .navigationBarHidden(true)
            .statusBarHidden()
        }
        .preferredColorScheme(.dark)
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
