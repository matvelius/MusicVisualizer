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
            EqualizerView(barCount: 21)
            .padding()
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    HomeView()
}
