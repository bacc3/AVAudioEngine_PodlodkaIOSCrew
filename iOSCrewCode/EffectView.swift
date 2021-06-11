//
//  EffectView.swift
//  iOSCrewCode
//
//  Created by Vasiliy Korchagin on 04.06.2021.
//

import UIKit

protocol EffectViewActionsDelegate: AnyObject {
    func effectView(_ effectView: EffectView, didChangePitchValue value: Float)
}

class EffectView: UIView {
    weak var actionsDelegate: EffectViewActionsDelegate?
    var name: String = "" {
        didSet {
            label.text = name
        }
    }
    
    private var label: UILabel!
    private var segmentedControl: UISegmentedControl!
    private var segmentedControlItems = ["-0.5", "0", "0.5"]
    
    private enum Constants {
        static let baseInset: CGFloat = 8
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        configureView()
        addSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let labelFrame = calcLabelFrame(label, rootSize: size)
        let segmentedControlFrame = calcSegmentedControlFrame(segmentedControl, below: labelFrame)
        
        return CGSize(width: labelFrame.width, height: segmentedControlFrame.maxY)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        label.frame = calcLabelFrame(label, rootSize: bounds.size)
        segmentedControl.frame = calcSegmentedControlFrame(segmentedControl, below: label.frame)
    }
    
    // MARK: - Actions
    
    @objc private func didSegmentedControlValueChanged(_ segmentedControl: UISegmentedControl) {
        let pitchValueString = segmentedControlItems[segmentedControl.selectedSegmentIndex]
        actionsDelegate?.effectView(self, didChangePitchValue: Float(pitchValueString) ?? 0)
    }
    
    // MARK: - Private
    
    private func configureView() {
        backgroundColor = .white
    }
    
    // MARK: Adding Subviews
    
    private func addSubviews() {
        label = UILabel()
        addSubview(label)
        segmentedControl = makeSegmentedControl()
        addSubview(segmentedControl)
    }
    
    private func makeSegmentedControl() -> UISegmentedControl {
        let segmentedControl = UISegmentedControl(items: segmentedControlItems)
        segmentedControl.selectedSegmentIndex = 1
        segmentedControl.addTarget(
            self,
            action: #selector(didSegmentedControlValueChanged(_:)),
            for: .valueChanged)
        
        return segmentedControl
    }
    
    // MARK: Calc frames
    
    private func calcLabelFrame(_ label: UILabel, rootSize: CGSize) -> CGRect {
        var frame = CGRect.zero
        frame.origin.x = 2 * Constants.baseInset
        frame.size.width = rootSize.width - 2 * frame.minX
        let maxSize = CGSize(width: frame.width, height: rootSize.height - frame.minY)
        frame.size.height = label.sizeThatFits(maxSize).height
        
        return frame
    }
    
    private func calcSegmentedControlFrame(
        _ segmentedControl: UISegmentedControl,
        below topFrame: CGRect) -> CGRect {
        var frame = segmentedControl.frame
        frame.size.width = topFrame.width
        frame.origin.x = topFrame.minX
        frame.origin.y = topFrame.maxY + 2 * Constants.baseInset
        
        return frame
    }
}
