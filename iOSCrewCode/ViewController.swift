//
//  ViewController.swift
//  iOSCrewCode
//
//  Created by Vasiliy Korchagin on 03.06.2021.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    private var audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var pitchNode = AVAudioUnitTimePitch()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        registerForNotifications()
    }
    
    // MARK: - Private
    
    private func play() {
        prepareAudioSession()
        if !audioEngine.isRunning {
            configureAudioEngine()
            startAudioEngine()
        }
        playerNode.scheduleFile(audioFile, at: AVAudioTime(hostTime: 0)) {
            DispatchQueue.main.async {
                self.isAudioPlaying = false
            }
        }
        playerNode.play()
        isAudioPlaying = true
    }
    
    private func configureAudioEngine() {
        audioEngine.attach(playerNode)
        audioEngine.attach(pitchNode)
        
        audioEngine.connect(playerNode, to: pitchNode, format: nil)
        audioEngine.connect(pitchNode, to: audioEngine.outputNode, format: nil)
        
        audioEngine.prepare()
    }
    
    private func startAudioEngine() {
        do {
            try audioEngine.start()
        } catch let error {
            fatalError("Failed to start audioEngine: \(error.localizedDescription) ")
        }
    }
    
    private func prepareAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error {
            fatalError("Failed to set category: \(error.localizedDescription)")
        }
    }
    
    private func stop() {
        playerNode.stop()
        isAudioPlaying = false
    }
    
    private func render() {
        audioEngine.stop()
        do {
            let maxFrameCount: AVAudioFrameCount = 4096
            try audioEngine.enableManualRenderingMode(.offline,
                                                  format: audioFile.processingFormat,
                                                  maximumFrameCount: maxFrameCount)
        } catch let error {
            fatalError("Failed to enable manual rendering: \(error.localizedDescription)")
        }
        configureAudioEngine()
        startAudioEngine()
        playerNode.scheduleFile(audioFile, at: AVAudioTime(hostTime: 0))
        playerNode.play()
        
        guard
            let buffer = AVAudioPCMBuffer(
            pcmFormat: audioEngine.manualRenderingFormat,
            frameCapacity: audioEngine.manualRenderingMaximumFrameCount)
        else {
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("audioProcessed.wav")
        let outputAudioFile: AVAudioFile
        do {
            outputAudioFile = try AVAudioFile(forWriting: outputURL, settings: audioFile.fileFormat.settings)
        } catch let error {
            fatalError("Failed to create audio file: \(error.localizedDescription)")
        }
        
        while audioEngine.manualRenderingSampleTime < audioFile.length {
            do {
                let frameCount = audioFile.length - audioEngine.manualRenderingSampleTime
                let frameCountToRender = min(AVAudioFrameCount(frameCount), buffer.frameCapacity)
                
                let status = try audioEngine.renderOffline(frameCountToRender, to: buffer)
                
                switch status {
                case .success:
                    try outputAudioFile.write(from: buffer)
                case .error:
                    fatalError("Failed to write buffer to file")
                default:
                    break
                }
            } catch let error {
                fatalError("Manual rendering failed: \(error.localizedDescription)")
            }
        }
        
        audioEngine.disableManualRenderingMode()
        playerNode.stop()
        audioEngine.stop()
        
        guard let view = view as? View else { return }
        view.renderedFileURL = outputURL

    }
    
    // MARK: - Notifications
    
    func registerForNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesWereReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance())
    }
     
    @objc func handleInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            return
        }
        switch type {
        case .began:
            isAudioPlayingBeforeInterruption = isAudioPlaying
            if isAudioPlayingBeforeInterruption {
                stop()
            }
        case .ended:
            guard
                let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt
            else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume),
               isAudioPlayingBeforeInterruption {
                play()
            }
        default:
            break
        }
    }
    
    @objc func handleMediaServicesWereReset(_ notification: Notification) {
        stop()
        audioEngine.stop()
        
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        pitchNode = AVAudioUnitTimePitch()
        
        configureAudioEngine()
        startAudioEngine()
    }
    
    @objc func handleRouteChange(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else {
            return
        }
        switch reason {
        case .oldDeviceUnavailable:
            stop()
        default:
            break
        }
        isHeadphonesConnected = isHeadphonesConnected(route: AVAudioSession.sharedInstance().currentRoute)
    }
    
    private func isHeadphonesConnected(route: AVAudioSessionRouteDescription) -> Bool {
        let headphoneIndex = route.outputs.first {
            $0.portType == AVAudioSession.Port.headphones
        }
        
        return headphoneIndex != nil
    }
    
    
    
    
    // MARK: - Noninteresting code
    
    private func setEffectValue(_ value: Float) {
        pitchNode.pitch = 1200 * value
    }
    
    private var isAudioPlaying = false {
        didSet {
            if isAudioPlaying {
                addDisplayLink()
            } else {
                removeDisplayLink()
            }
            guard let view = view as? View else { return }
            view.isAudioPlaying = isAudioPlaying
            view.currentTime = 0
            view.playingProgress = 0
        }
    }
    
    private var isHeadphonesConnected = false {
        didSet {
            guard let view = view as? View else { return }
            view.isHeadphonesConnected = isHeadphonesConnected
        }
    }
    private var isAudioPlayingBeforeInterruption = false

    private var audioFileDuration: TimeInterval = 0 {
        didSet {
            guard let view = self.view as? View else { return }
            view.duration = audioFileDuration
        }
    }
    
    private var displayLink: CADisplayLink?
    
    private var audioFile: AVAudioFile! {
        didSet {
            audioFileDuration = Double(audioFile.length) / playerNode.outputFormat(forBus: 0).sampleRate
        }
    }
    
    override func loadView() {
        let view = View()
        view.actionsDelegate = self
        self.view = view
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        
        defer {
            audioFile = makeAudioFile()
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        defer {
            audioFile = makeAudioFile()
        }
    }
    
    private func makeAudioFile() -> AVAudioFile? {
        guard
            let url = Bundle.main.url(forResource: "testAudio", withExtension: "wav")
        else {
            return nil
        }
        let audioFile = try? AVAudioFile(forReading: url)
        
        return audioFile
    }
    
    // MARK: - DisplayLink
    
    private func addDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
        displayLink?.add(to: .current, forMode: .default)
    }
    
    @objc private func displayLinkDidFire() {
        guard let view = view as? View else { return }
        view.currentTime = playerNode.currentTime
        view.playingProgress = playerNode.currentTime / audioFileDuration
    }
    
    private func removeDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
}

extension ViewController: ViewActionsDelegate {
    func view(_ view: View, didChangePitchValue value: Float) {
        setEffectValue(value)
    }
    
    func view(_ view: View, didTouchUpInsidePlayButton button: UIButton) {
        if isAudioPlaying {
            stop()
        } else {
            play()
        }
    }
    
    func view(_ view: View, didTouchUpInsideManualRenderButton button: UIButton) {
        render()
    }
}

extension AVAudioPlayerNode {
    var currentTime: TimeInterval {
        get {
            if let nodeTime: AVAudioTime = lastRenderTime,
               let playerTime: AVAudioTime = playerTime(forNodeTime: nodeTime) {
                
                return max(0, Double(playerTime.sampleTime) / outputFormat(forBus: 0).sampleRate)
            }
            
            return 0
        }
    }
}

