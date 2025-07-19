//
//  AudioPermissionService.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Foundation
import AVFoundation

protocol AudioPermissionServiceProtocol {
    func requestMicrophonePermission() async -> Bool
    func hasMicrophonePermission() -> Bool
}

@Observable
class AudioPermissionService: AudioPermissionServiceProtocol {
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func hasMicrophonePermission() -> Bool {
        return AVAudioApplication.shared.recordPermission == .granted
    }
}