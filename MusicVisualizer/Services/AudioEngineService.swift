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
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        inputNode?.removeTap(onBus: 0)
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false)
        } catch {
            // Handle error silently for now
        }
    }
    
    func installTap(tapBlock: @escaping AVAudioNodeTapBlock) {
        guard let inputNode = inputNode else { return }
        
        let bufferSize: UInt32 = 1024
        let sampleRate = inputNode.outputFormat(forBus: 0).sampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format, block: tapBlock)
    }
}