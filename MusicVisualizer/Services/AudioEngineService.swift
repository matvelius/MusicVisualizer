//
//  AudioEngineService.swift
//  MusicVisualizer
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import Foundation
import AVFoundation

protocol AudioEngineServiceProtocol {
    var isRunning: Bool { get }
    func startEngine() async -> Bool
    func stopEngine()
    func installTap(tapBlock: @escaping AVAudioNodeTapBlock)
    func installTap(onBus bus: Int, bufferSize: Int, format: AVAudioFormat?, block: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void)
}

@Observable
class AudioEngineService: AudioEngineServiceProtocol {
    private let audioEngine = AVAudioEngine()
    private let permissionService: AudioPermissionServiceProtocol
    private var inputNode: AVAudioInputNode?
    
    var isRunning: Bool {
        return audioEngine.isRunning
    }
    
    init(permissionService: AudioPermissionServiceProtocol = AudioPermissionService()) {
        self.permissionService = permissionService
    }
    
    func startEngine() async -> Bool {
        guard await permissionService.requestMicrophonePermission() else {
            return false
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            #if targetEnvironment(simulator)
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth])
            #else
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            #endif
            
            try audioSession.setActive(true)
            
            inputNode = audioEngine.inputNode
            
            try audioEngine.start()
            return true
        } catch {
            return false
        }
    }
    
    func stopEngine() {
        // Remove taps before stopping the engine
        removeTaps()
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false)
        } catch {
            // Handle error silently for now
        }
    }
    
    func installTap(tapBlock: @escaping AVAudioNodeTapBlock) {
        guard let inputNode = inputNode else { return }
        
        // Remove any existing taps first to prevent "nullptr == Tap()" crash
        inputNode.removeTap(onBus: 0)
        
        let bufferSize: UInt32 = 1024
        let sampleRate = inputNode.outputFormat(forBus: 0).sampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format, block: tapBlock)
    }
    
    func installTap(onBus bus: Int, bufferSize: Int, format: AVAudioFormat?, block: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void) {
        let inputNode = audioEngine.inputNode
        
        // Remove any existing taps first to prevent "nullptr == Tap()" crash
        inputNode.removeTap(onBus: bus)
        
        inputNode.installTap(onBus: bus, bufferSize: UInt32(bufferSize), format: format, block: block)
    }
    
    private func removeTaps() {
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
    }
}