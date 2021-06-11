//
//  View.swift
//  iOSCrewCode
//
//  Created by Vasiliy Korchagin on 04.06.2021.
//

import UIKit

protocol ViewActionsDelegate: AnyObject {
    func view(_ view: View, didTouchUpInsidePlayButton button: UIButton)
    func view(_ view: View, didChangePitchValue value: Float)
    func view(_ view: View, didTouchUpInsideManualRenderButton button: UIButton)
}

class View: UIView {
    weak var actionsDelegate: ViewActionsDelegate?
    
    var isHeadphonesConnected: Bool = false {
        didSet {
            earpodsImageView.alpha = isHeadphonesConnected
                ? Constants.EarpodsImageView.Alpha.connected
                : Constants.EarpodsImageView.Alpha.disconnected
        }
    }
    var isAudioPlaying = false {
        didSet {
            playButton.setImage(playButtonImage(isAudioPlaying: isAudioPlaying), for: .normal)
        }
    }
    var playingProgress: Double = 0 {
        didSet {
            progressSlider.value = Float(playingProgress)
        }
    }
    var duration: TimeInterval = 0 {
        didSet {
            durationLabel.text = String(format: "%.2f", duration)
        }
    }
    var currentTime: TimeInterval = 0 {
        didSet {
            currentTimeLabel.text = String(format: "%.2f", currentTime)
        }
    }
    var renderedFileURL: URL? = nil {
        didSet {
            let text: String
            if let renderedFileURL = renderedFileURL {
                text = renderedFileURL.path
            } else {
                text = ""
            }
            renderedFileURLTextView.text = text
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
    
    private var earpodsImageView: UIImageView!
    private var progressSlider: UISlider!
    private var currentTimeLabel: UILabel!
    private var durationLabel: UILabel!
    private var playButton: UIButton!
    private var effectView: EffectView!
    private var manualRenderButton: UIButton!
    private var renderedFileURLTextView: UITextView!
    
    private enum Constants {
        static let baseInset: CGFloat = 8
        enum EarpodsImageView {
            enum Alpha {
                static let connected: CGFloat = 1
                static let disconnected: CGFloat = 0.3
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        configureView()
        addSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        earpodsImageView.frame = calcEarpodsImageViewFrame(earpodsImageView)
        progressSlider.frame = calcProgressSliderFrame(
            progressSlider,
            below: earpodsImageView.frame)
        currentTimeLabel.frame = calcCurrentTimeLabelFrame(
            currentTimeLabel,
            below: progressSlider.frame)
        durationLabel.frame = calcDurationLabelFrame(
            durationLabel,
            toTheRightOf: currentTimeLabel.frame)
        playButton.frame = calcPlayButtonFrame(playButton, below: currentTimeLabel.frame)
        effectView.frame = calcEffectViewFrame(effectView, below: playButton.frame)
        manualRenderButton.frame = calcManualRenderButtonFrame(manualRenderButton, below: effectView.frame)
        renderedFileURLTextView.frame = calcRenderedFileURLTextViewFrame(
            renderedFileURLTextView,
            below: manualRenderButton.frame)
    }
    
    // MARK: - Actions
    
    @objc private func didTouchUpInsidePlayButton(_ button: UIButton) {
        actionsDelegate?.view(self, didTouchUpInsidePlayButton: button)
    }
    
    @objc private func didTouchUpInsideManualRenderButton(_ button: UIButton) {
        actionsDelegate?.view(self, didTouchUpInsideManualRenderButton: button)
    }
    
    // MARK: - Private
    
    private func configureView() {
        backgroundColor = .white
    }
    
    private func playButtonImage(isAudioPlaying: Bool) -> UIImage? {
        if isAudioPlaying {
            
            return UIImage(systemName: "stop.circle.fill")
        } else {
            
            return UIImage(systemName: "play.fill")
        }
    }
    
    // MARK: Adding Subviews
    
    private func addSubviews() {
        earpodsImageView = makeEarpodsImageView()
        addSubview(earpodsImageView)
        progressSlider = makeProgressSlider()
        addSubview(progressSlider)
        currentTimeLabel = makeTimeLabel()
        addSubview(currentTimeLabel)
        durationLabel = makeTimeLabel(aligment: .right)
        addSubview(durationLabel)
        playButton = makePlayButton()
        addSubview(playButton)
        effectView = makeEffectView()
        addSubview(effectView)
        manualRenderButton = makeManualRenderButton()
        addSubview(manualRenderButton)
        renderedFileURLTextView = makeRenderedFileURLTextView()
        addSubview(renderedFileURLTextView)
    }
    
    private func makeEarpodsImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.tintColor = .black
        imageView.image = UIImage(systemName: "earpods")
        imageView.alpha = isHeadphonesConnected
            ? Constants.EarpodsImageView.Alpha.connected
            : Constants.EarpodsImageView.Alpha.disconnected
        
        return imageView
    }
    
    private func makeProgressSlider() -> UISlider {
        let slider = UISlider()
        slider.isUserInteractionEnabled = false
        
        return slider
    }
    
    private func makeTimeLabel(aligment: NSTextAlignment = .left) -> UILabel {
        let label = UILabel()
        label.textAlignment = aligment
        label.text = "0"
        label.textColor = .black
        
        return label
    }
    
    private func makePlayButton() -> UIButton {
        let button = UIButton()
        button.setImage(playButtonImage(isAudioPlaying: isAudioPlaying), for: .normal)
        button.addTarget(
            self,
            action: #selector(didTouchUpInsidePlayButton(_:)),
            for: .touchUpInside)
        button.tintColor = .black
        button.contentVerticalAlignment = .fill
        button.contentHorizontalAlignment = .fill
        
        return button
    }
    
    private func makeEffectView() -> EffectView {
        let effectView = EffectView()
        effectView.actionsDelegate = self
        effectView.name = "Pitch"
        
        return effectView
    }
    
    private func makeManualRenderButton() -> UIButton {
        let button = UIButton()
        button.setTitle("Manual Render", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.addTarget(
            self,
            action: #selector(didTouchUpInsideManualRenderButton(_:)),
            for: .touchUpInside)
        
        return button
    }
    
    private func makeRenderedFileURLTextView() -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.font = UIFont.systemFont(ofSize: 14)
        
        return textView
    }
    
    // MARK: Calc frames
    
    private func calcEarpodsImageViewFrame(_ earpodsImageView: UIImageView) -> CGRect {
        guard let superview = earpodsImageView.superview else { return .zero }
        var frame = CGRect.zero
        frame.size.width = 5 * Constants.baseInset
        frame.size.height = frame.width
        frame.origin.x = superview.frame.width - frame.width - 2 * Constants.baseInset
        frame.origin.y = superview.safeAreaInsets.top + 4 * Constants.baseInset
        
        return frame
    }
    
    private func calcProgressSliderFrame(_ slider: UISlider, below topFrame: CGRect) -> CGRect {
        guard let superview = slider.superview else { return .zero }
        var frame = slider.frame
        frame.origin.x = 2 * Constants.baseInset
        frame.origin.y = topFrame.maxY + 2 * Constants.baseInset
        frame.size.width = superview.frame.width - 2 * frame.minX
        
        return frame
    }
    
    private func calcCurrentTimeLabelFrame(
        _ label: UILabel,
        below topFrame: CGRect
    ) -> CGRect {
        guard let superviewHeight = label.superview?.frame.height else { return .zero }
        var frame = CGRect.zero
        frame.origin.x = topFrame.minX
        frame.origin.y = topFrame.maxY + 2 * Constants.baseInset
        frame.size.width = topFrame.width / 2
        let maxSize = CGSize(width: frame.width, height: superviewHeight - frame.minY)
        frame.size.height = label.sizeThatFits(maxSize).height
        
        return frame
    }

    private func calcDurationLabelFrame(
        _ label: UILabel,
        toTheRightOf leftFrame: CGRect
    ) -> CGRect {
        var frame = leftFrame
        frame.origin.x = leftFrame.maxX
        
        return frame
    }
    
    private func calcPlayButtonFrame(_ button: UIButton, below topFrame: CGRect) -> CGRect {
        guard let superviewWidth = button.superview?.frame.width else { return .zero }
        var frame = CGRect.zero
        frame.size.width = 5 * Constants.baseInset
        frame.size.height = frame.width
        frame.origin.x = (superviewWidth - frame.width) / 2
        frame.origin.y = topFrame.maxY + 2 * Constants.baseInset
        
        return frame
    }
    
    private func calcEffectViewFrame(_ effectView: EffectView, below topFrame: CGRect) -> CGRect {
        guard let superview = effectView.superview else { return .zero }
        var frame = CGRect.zero
        frame.origin.x = 2 * Constants.baseInset
        frame.origin.y = topFrame.maxY + 10 * Constants.baseInset
        frame.size.width = superview.frame.width - 2 * frame.minX
        let maxSize = CGSize(width: frame.width, height: superview.frame.height - frame.minY)
        frame.size.height = effectView.sizeThatFits(maxSize).height
        
        return frame
    }
    
    private func calcManualRenderButtonFrame(_ button: UIButton, below topFrame: CGRect) -> CGRect {
        guard let superview = button.superview else { return .zero }
        button.sizeToFit()
        var frame = button.frame
        frame.origin.x = (superview.frame.width - frame.width) / 2
        frame.origin.y = topFrame.maxY + 10 * Constants.baseInset
        
        return frame
    }
    
    private func calcRenderedFileURLTextViewFrame(
        _ textView: UITextView,
        below topFrame: CGRect) -> CGRect {
        guard let superview = textView.superview else { return .zero }
        var frame = CGRect.zero
        frame.origin.x = 2 * Constants.baseInset
        frame.origin.y = topFrame.maxY + 2 * Constants.baseInset
        frame.size.width = superview.frame.width - 2 * frame.minX
        let maxSize = CGSize(width: frame.width, height: superview.frame.height - frame.minY)
        frame.size.height = textView.sizeThatFits(maxSize).height
        
        return frame
    }
}

extension View: EffectViewActionsDelegate {
    func effectView(_ effectView: EffectView, didChangePitchValue value: Float) {
        actionsDelegate?.view(self, didChangePitchValue: value)
    }
}
