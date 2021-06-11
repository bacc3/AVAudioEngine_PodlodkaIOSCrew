//
//  ViewControllerWithNonInterestingCode.swift
//  iOSCrewCode
//
//  Created by Vasiliy Korchagin on 08.06.2021.
//

import UIKit
import AVFoundation

class ViewControllerWithNonInterestingCode: UIViewController {
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

    private var audioFile: AVAudioFile! {
        didSet {
            audioFileDuration = Double(audioFile.length) / playerNode.outputFormat(forBus: 0).sampleRate
        }
    }
    private var audioFileDuration: TimeInterval = 0 {
        didSet {
            guard let view = self.view as? View else { return }
            view.duration = audioFileDuration
        }
    }
    
    private var displayLink: CADisplayLink?
    
    override func loadView() {
        let view = View()
        view.actionsDelegate = self
        self.view = view
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        audioFile = makeAudioFile()
        registerForNotifications()
    }
    
    // MARK: - Private
    
    private func play() {
        prepareAudioSessionForPlaying()
        if !audioEngine.isRunning {
            configureAudioEngine()
            startAudioEngine()
        }
        // It’s important to start the engine before you try to schedule any files to play.
        // If you want to play a file a second time, then you need to schedule it again. If you’re looking to loop audio, it may make sense to load the file into a buffer (which has options via scheduleBuffer) or deal with it in the completionHandler
        playerNode.scheduleFile(audioFile, at: AVAudioTime(hostTime: 0)) { [weak self] in
            DispatchQueue.main.async {
                self?.isAudioPlaying = false
            }
        }
        playerNode.play()
        isAudioPlaying = true
    }
    
    private func stop() {
        playerNode.stop()
        isAudioPlaying = false
    }
    
    private func setEffectValue(_ value: Float) {
        // The pitch is measured in “cents”, a logarithmic value used for measuring musical intervals.
        // One octave is equal to 1200 cents.
        pitchNode.pitch = 1200 * value
    }
    
    private func render() {
        // You must stop the engine before calling this method
        audioEngine.stop()
        do {
            // The maximum number of frames the engine renders in any single render call.
            let maxFrames: AVAudioFrameCount = 4096
            try audioEngine.enableManualRenderingMode(
                .offline,
                format: audioFile.processingFormat,
                maximumFrameCount: maxFrames)
        } catch {
            fatalError("Enabling manual rendering mode failed: \(error).")
        }
        configureAudioEngine()
        startAudioEngine()
        playerNode.scheduleFile(audioFile, at: nil)
        playerNode.play()
        
        // The output buffer to which the engine renders the processed data.
        let buffer = AVAudioPCMBuffer(
            pcmFormat: audioEngine.manualRenderingFormat,
            frameCapacity: audioEngine.manualRenderingMaximumFrameCount)!
        
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let outputURL = temporaryDirectoryURL.appendingPathComponent("audio-processed.wav")
        let outputFile: AVAudioFile
        do {
            outputFile = try AVAudioFile(forWriting: outputURL, settings: audioFile.fileFormat.settings)
        } catch {
            fatalError("Unable to open output audio file: \(error).")
        }
        
        while audioEngine.manualRenderingSampleTime < audioFile.length {
            do {
                let frameCount = audioFile.length - audioEngine.manualRenderingSampleTime
                let framesToRender = min(AVAudioFrameCount(frameCount), buffer.frameCapacity)
                
                let status = try audioEngine.renderOffline(framesToRender, to: buffer)
                
                switch status {
                case .success:
                    // The data rendered successfully. Write it to the output file.
                    try outputFile.write(from: buffer)
                case .error:
                    // An error occurred while rendering the audio.
                    fatalError("The manual rendering failed.")
                default:
                    break
                }
            } catch {
                fatalError("The manual rendering failed: \(error).")
            }
        }
        audioEngine.disableManualRenderingMode()
        // Stop the player node and engine.
        playerNode.stop()
        audioEngine.stop()
        guard let view = view as? View else { return }
        view.renderedFileURL = outputURL
    }
    
    // MARK: - AudioEngine
    
    private func configureAudioEngine() {
        audioEngine.attach(playerNode)
        audioEngine.attach(pitchNode)
        
        audioEngine.connect(playerNode, to: pitchNode, format: nil)
        audioEngine.connect(pitchNode, to: audioEngine.mainMixerNode, format: nil)
        
        audioEngine.prepare()
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
    
    private func startAudioEngine() {
        do {
            try audioEngine.start()
        } catch let error {
            fatalError("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    // MARK: - AudioSession
    
    private func prepareAudioSessionForPlaying() {
        configureAudioSession()
        activateAudioSession()
    }
    
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch let error as NSError {
            fatalError("Failed to set the audio session category and mode: \(error.localizedDescription)")
        }
    }
    
    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(true)
        } catch let error as NSError {
            fatalError("Unable to change audio session state:  \(error.localizedDescription)")
        }
    }
    
    // MARK: - Notifications
    
    func registerForNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruption(_:)),
                                               name: AVAudioSession.interruptionNotification,
                                               object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleMediaServicesWereReset(_:)),
                                               name: AVAudioSession.mediaServicesWereResetNotification,
                                               object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self,
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
        if type == .began {
            isAudioPlayingBeforeInterruption = isAudioPlaying
            if isAudioPlaying {
                stop()
            }
        } else if type == .ended {
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
        }
    }
    
    @objc func handleMediaServicesWereReset(_ notification: Notification) {
//        Dispose of orphaned audio objects (such as players, recorders, converters, or audio queues) and create new ones
//        Reset any internal audio states being tracked, including all properties of AVAudioSession
//        When appropriate, reactivate the AVAudioSession instance using the setActive:error: method
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
            let reason = AVAudioSession.RouteChangeReason(rawValue:reasonValue)
        else {
            return
        }
        switch reason {
        case .newDeviceAvailable:
            let session = AVAudioSession.sharedInstance()
            isHeadphonesConnected = isHeadphonesConnected(route: session.currentRoute)
        case .oldDeviceUnavailable:
            let previousRouteKey = AVAudioSessionRouteChangePreviousRouteKey
            if let previousRoute = info[previousRouteKey] as? AVAudioSessionRouteDescription {
                isHeadphonesConnected = !isHeadphonesConnected(route: previousRoute)
            }
            stop()
        default:
            break
        }
    }
    
    private func isHeadphonesConnected(route: AVAudioSessionRouteDescription) -> Bool {
        let headphonesPortIndex = route.outputs.first {
            $0.portType == AVAudioSession.Port.headphones
        }
        
        return headphonesPortIndex != nil
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

extension ViewControllerWithNonInterestingCode: ViewActionsDelegate {
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

