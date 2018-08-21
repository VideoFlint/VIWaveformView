//
//  ViewController.swift
//  VIWaveformView
//
//  Created by Vito on 2018/8/11.
//  Copyright © 2018 Vito. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        view.backgroundColor = UIColor(red:0.10, green:0.14, blue:0.29, alpha:1.00)
        
        setupWaveformView()
        view.addSubview(waveformView)
        
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        waveformView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 15).isActive = true
        waveformView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -15).isActive = true
        waveformView.topAnchor.constraint(equalTo: view.topAnchor, constant: 65).isActive = true
        waveformView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        
        waveformView.layoutIfNeeded()
        if let url = Bundle.main.url(forResource: "Moon River", withExtension: "mp3") {
            let asset = AVAsset.init(url: url)
            _ = waveformView.loadVoice(from: asset, completion: { (asset) in
            })
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    var waveformView: VIWaveformView!
    func setupWaveformView() {
        waveformView = VIWaveformView()
        waveformView.backgroundColor = UIColor(red:0.10, green:0.14, blue:0.29, alpha:1.00)
        waveformView.minWidth = UIScreen.main.bounds.width
        
        waveformView.waveformNodeViewProvider = BasicWaveFormNodeProvider(generator: { () -> NodePresentation in
            let view = VIWaveformNodeView()
            view.waveformLayer.strokeColor = UIColor(red:0.86, green:0.35, blue:0.62, alpha:1.00).cgColor
            return view
        }())
    }

}

