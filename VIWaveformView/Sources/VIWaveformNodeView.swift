//
//  VIWaveformNodeView.swift
//  VIWavefromView
//
//  Created by Vito on 28/09/2017.
//  Copyright © 2017 Vito. All rights reserved.
//

import UIKit
import AVFoundation

class VIWaveformNodeView: UIView {
    
    override open class var layerClass: Swift.AnyClass {
        return CAShapeLayer.self
    }
    
    var waveformLayer: CAShapeLayer {
        return layer as! CAShapeLayer
    }
    
    fileprivate(set) var pointInfo = [CGPoint]()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        waveformLayer.lineWidth = 1
        waveformLayer.fillColor = nil
        waveformLayer.backgroundColor = nil
        waveformLayer.isOpaque = true
        waveformLayer.strokeColor = UIColor.lightGray.cgColor
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        redraw()
    }
    
    // MARK: - Public
    
    public func redraw() {
        let frame = waveformLayer.bounds
        let path = self.createPath(with: self.pointInfo, pointCount: self.pointInfo.count, in: frame)
        self.waveformLayer.path = path
    }
    
    fileprivate func createPath(with points: [CGPoint], pointCount: Int, in rect: CGRect) -> CGPath {
        let path = UIBezierPath()
        
        guard pointCount > 0 else {
            return path.cgPath
        }
        
        guard rect.height > 0, rect.width > 0 else {
            return path.cgPath
        }
        
        path.move(to: CGPoint(x: 0, y: 0))
        let minValue = 1 / (rect.height / 2)
        for index in 0..<(pointCount / 2) {
            var point = points[index * 2]
            path.move(to: point)
            point.y = max(point.y, minValue)
            point.y = -point.y
            path.addLine(to: point)
        }
        let scaleX = (rect.width - 1) / CGFloat(pointCount - 1)
        let halfHeight = rect.height / 2
        let scaleY = halfHeight
        var transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        transform.ty = halfHeight
        path.apply(transform)
        return path.cgPath
    }
    
}

extension VIWaveformNodeView: VIWaveformPresentation {
    func updateWaveformPoint(_ data: [Float]) {
        pointInfo.removeAll()
        for (index, point) in data.enumerated() {
            let point = CGPoint(x: CGFloat(index), y: CGFloat(point))
            pointInfo.append(point)
        }
        redraw()
    }
}
