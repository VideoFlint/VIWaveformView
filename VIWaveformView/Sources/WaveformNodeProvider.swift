//
//  WaveformNodeProvider.swift
//  VIWaveformView
//
//  Created by Vito on 2018/8/21.
//  Copyright © 2018 Vito. All rights reserved.
//

import UIKit

public typealias NodePresentation = UIView & VIWaveformPresentation


public protocol VIWaveformPresentation {
    func updateWaveformPoint(_ data: [Float])
}

public protocol VIWaveformNodeViewProvider: class {
    func generateWaveformNodeView() -> NodePresentation
}

public class BasicWaveFormNodeProvider: VIWaveformNodeViewProvider {
    public var generator: () -> NodePresentation
    public init(generator: @escaping @autoclosure () -> NodePresentation) {
        self.generator = generator
    }
    public func generateWaveformNodeView() -> NodePresentation {
        return generator()
    }
}

