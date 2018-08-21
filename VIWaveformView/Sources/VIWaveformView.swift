//
//  VIWaveformView.swift
//  VIWavefromView
//
//  Created by Vito on 28/09/2017.
//  Copyright © 2017 Vito. All rights reserved.
//

import UIKit
import AVFoundation

private let VIWaveFormCellIdentifier = "VIWaveFormCellIdentifier"

public class VIWaveformView: UIView {

    public fileprivate(set) var collectionView: UICollectionView!
    
    public fileprivate(set) var viewModel = WaveformScrollViewModel()
    public var waveformNodeViewProvider: VIWaveformNodeViewProvider = {
        return BasicWaveFormNodeProvider(generator: VIWaveformNodeView())
    }()
    
    public var operationQueue: DispatchQueue?
    
    fileprivate(set) var actualWidthPerSecond: CGFloat = 0
    public var minWidthPerSecond: CGFloat = 5
    /// TimeLine Min width
    public var minWidth: CGFloat = 100
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        let frame = bounds
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        collectionView = UICollectionView(frame: frame, collectionViewLayout: layout)
        collectionView.backgroundColor = UIColor.clear
        addSubview(collectionView)
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.register(WaveformCell.self, forCellWithReuseIdentifier: VIWaveFormCellIdentifier)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        collectionView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        collectionView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        collectionView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }
    
    public func updatePoints(_ points: [Float]) {
        viewModel.points = points
        collectionView.reloadData()
    }
    
}

public extension VIWaveformView {
    public func loadVoice(from asset: AVAsset, completion: @escaping ((Error?) -> Void)) -> Cancellable {
        let width = frame.width + 300
        let cancellable = Cancellable()
        asset.loadValuesAsynchronously(forKeys: ["duration", "tracks"], completionHandler: { [weak self] in
            guard let strongSelf = self else { return }
            
            var error: NSError?
            let tracksStatus = asset.statusOfValue(forKey: "tracks", error: &error)
            if tracksStatus != .loaded {
                completion(error)
                return
            }
            let durationStatus = asset.statusOfValue(forKey: "duration", error: &error)
            if durationStatus != .loaded {
                completion(error)
                return
            }
            
            let duration = asset.duration.seconds
            
            // if fill the timeline view don't have enough time, per point respresent less time
            if CGFloat(duration) * strongSelf.minWidthPerSecond < strongSelf.minWidth {
                strongSelf.actualWidthPerSecond = strongSelf.minWidth / CGFloat(duration)
            } else {
                strongSelf.actualWidthPerSecond = strongSelf.minWidthPerSecond
            }
            let operation = VIAudioSampleOperation(widthPerSecond: strongSelf.actualWidthPerSecond)
            if let queue = strongSelf.operationQueue {
                operation.operationQueue = queue
            }
            func updatePoints(with audioSamples: [VIAudioSample]) {
                var points: [Float] = []
                if let audioSample = audioSamples.first {
                    points = audioSample.samples.map({ (sample) -> Float in
                        return Float(sample / 20000.0)
                    })
                }
                strongSelf.viewModel.points = points
            }
            
            var firstUpdate = true
            let operationTask = operation.loadSamples(from: asset, progress: { [weak self] (audioSamples) in
                guard let strongSelf = self else { return }
                if firstUpdate {
                    updatePoints(with: audioSamples)
                    
                    let dataWidth = CGFloat(strongSelf.viewModel.items.count * strongSelf.viewModel.itemPointCount)
                    
                    if dataWidth > width {
                        firstUpdate = false
                        
                        DispatchQueue.main.async {
                            strongSelf.collectionView.reloadData()
                        }
                    }
                }
            }, completion: { (audioSamples, error) in
                guard let audioSamples = audioSamples else {
                    DispatchQueue.main.async {
                        completion(error)
                    }
                    return
                }
                updatePoints(with: audioSamples)
                
                DispatchQueue.main.async {
                    strongSelf.collectionView.reloadData()
                    completion(nil)
                }
            })
            cancellable.cancelBlock = {
                operationTask?.cancel()
            }
        })
        cancellable.cancelBlock = {
            asset.cancelLoading()
        }
        return cancellable
    }
}

extension VIWaveformView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.items.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VIWaveFormCellIdentifier, for: indexPath)
        if let cell = cell as? WaveformCell {
            cell.waveformNodeViewProvider = waveformNodeViewProvider
            let item = viewModel.items[indexPath.item]
            cell.configure(points: item)
        }
        return cell
    }
    
    private func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var size = CGSize.zero
        let item = viewModel.items[indexPath.item]
        size.width = CGFloat(item.count)
        size.height = collectionView.frame.height
        return size
    }
    
}

class WaveformCell: UICollectionViewCell {
    
    var waveformView: NodePresentation!
    var waveformNodeViewProvider: VIWaveformNodeViewProvider? {
        willSet {
            if let newValue = newValue {
                if newValue !== waveformNodeViewProvider {
                    waveformView = newValue.generateWaveformNodeView()
                    contentView.addSubview(waveformView)
                    
                    waveformView.translatesAutoresizingMaskIntoConstraints = false
                    waveformView.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
                    waveformView.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
                    waveformView.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
                    waveformView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
                }
            } else {
                contentView.subviews.forEach({ $0.removeFromSuperview() })
            }
        }
    }
    
    func configure(points: [Float]) {
        waveformView.updateWaveformPoint(points)
    }
    
}

public class WaveformScrollViewModel {
    
    public var points = [Float]() {
        didSet {
            var items = [[Float]]()
            
            let itemCount = { () -> Int in
                if points.count == 0 {
                    return 0
                }
                return ((points.count - 1) / itemPointCount) + 1
            }()
            
            for index in 0..<itemCount {
                var item = [Float]()
                let startPosition = index * itemPointCount
                for i in startPosition..<(startPosition + itemPointCount) {
                    if i >= points.count {
                        item.append(0)
                        break
                    }
                    
                    if i == 0 {
                        item.append(0)
                    }
                    
                    let value = points[i]
                    item.append(value)
                }
                items.append(item)
            }
            
            self.items = items
        }
    }
    
    public var itemPointCount = 50
    public var items: [[Float]] = []
}


