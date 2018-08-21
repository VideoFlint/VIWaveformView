//
//  VIAudioSampleOperation.swift
//  VIWavefromView
//
//  Created by Vito on 09/10/2017.
//  Copyright © 2017 Vito. All rights reserved.
//

import Foundation
import AVFoundation
import Accelerate

public class VIAudioSample {
    var samples: [CGFloat] = []
    var sampleMax: CGFloat = 0
}

public class VIAudioSampleOperation {
    
    /// How many point will display on the screen for per second audio data
    public var widthPerSecond: CGFloat = 10 {
        didSet {
            loaders.forEach { (loader) in
                loader.widthPerSecond = widthPerSecond
            }
        }
    }
    
    public var audioSamples: [VIAudioSample] {
        return loaders.map({ $0.audioSample })
    }
    private var loaders: [AssetTrackSampleLoader] = []
    
    public var operationQueue: DispatchQueue = {
        let queue = DispatchQueue.init(label: "com.waveformview.audiosample", qos: DispatchQoS.default, attributes: DispatchQueue.Attributes.concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.workItem, target: nil)
        return queue
    }()
    
    public init(widthPerSecond: CGFloat) {
        self.widthPerSecond = widthPerSecond
    }
    
    func loadSamples(from asset: AVAsset, progress: (([VIAudioSample]) -> Void)? = nil, completion: (([VIAudioSample]?, Error?) -> Void)?) -> Cancellable? {
        do {
            let reader = try AVAssetReader(asset: asset)
            
            let loaders = asset.tracks(withMediaType: .audio).map { (track) -> AssetTrackSampleLoader in
                let loader = AssetTrackSampleLoader(track: track)
                loader.widthPerSecond = widthPerSecond
                return loader
            }
            self.loaders = loaders
            loaders.forEach { (loader) in
                if let output = loader.trackOutput {
                    reader.add(output)
                }
            }
            
            // 16-bit samples
            reader.startReading()
            
            operationQueue.async {
                
                var progressHint = 0
                func invokeProgressIfNeed() {
                    if progressHint >= 10 {
                        progressHint = 0
                        progress?(self.audioSamples)
                    }
                    progressHint += 1
                }
                
                while reader.status == .reading {
                    var needBreak = true
                    loaders.forEach({ (loader) in
                        if loader.processingBuffer() {
                            needBreak = false
                        }
                    })
                    invokeProgressIfNeed()
                    if needBreak {
                        break
                    }
                }
                
                if reader.status != .completed {
                    print("VIWaveformView failed to read audio: \(String(describing: reader.error))")
                    let error = reader.error ?? NSError(domain: "com.sampleoperation",
                                                        code: 0,
                                                        userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Unknown error", comment: "")])
                    completion?(nil, error)
                    return
                }
                
                reader.cancelReading()
                completion?(self.audioSamples, nil)
            }
            return Cancellable.init(cancelBlock: {
                reader.cancelReading()
            })
        } catch  {
            completion?(nil, error)
            return nil
        }
    }
}

public class AssetTrackSampleLoader {
    
    public var widthPerSecond: CGFloat = 10
    
    public private(set) var audioSample = VIAudioSample()
    
    private var filter: [Float] = []
    private var samplesPerPixel: Int = 0 {
        didSet {
            if samplesPerPixel > 0 {
                self.filter = [Float](repeating: 1.0 / Float(samplesPerPixel), count: samplesPerPixel)
            } else {
                self.filter = []
            }
        }
    }
    private var sampleBuffer = Data()
    
    public private(set) var trackOutput: AVAssetReaderTrackOutput?
    public var track: AVAssetTrack
    public init(track: AVAssetTrack) {
        self.track = track
        generateTrackOutput()
    }
    
    private func generateTrackOutput() {
        if let formatDescriptions = track.formatDescriptions as? [CMAudioFormatDescription],
            let audioFormatDesc = formatDescriptions.first,
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDesc)
        {
            samplesPerPixel = Int(asbd.pointee.mSampleRate * Double(asbd.pointee.mChannelsPerFrame) / Double(widthPerSecond))
            
            let outputSettingsDict: [String : Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsNonInterleaved: false,
                AVNumberOfChannelsKey: Int(asbd.pointee.mChannelsPerFrame)
            ]
            
            let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettingsDict)
            readerOutput.alwaysCopiesSampleData = false
            self.trackOutput = readerOutput
        }
    }
    
    public func processingBuffer() -> Bool {
        guard let trackOutput = trackOutput else {
            return false
        }
        
        guard let readSampleBuffer = trackOutput.copyNextSampleBuffer() else {
            // Process the remaining samples at the end which didn't fit into samplesPerPixel
            processRemaining()
            return false
        }
        // Append audio sample buffer into our current sample buffer
        appendSampleBuffer(readSampleBuffer)
        CMSampleBufferInvalidate(readSampleBuffer)
        return true
    }
    
    private func appendSampleBuffer(_ readSampleBuffer: CMSampleBuffer) {
        guard let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer) else { return }
        var readBufferLength = 0
        var readBufferPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(readBuffer, atOffset: 0, lengthAtOffsetOut: &readBufferLength, totalLengthOut: nil, dataPointerOut: &readBufferPointer)
        sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
        
        let totalSamples = sampleBuffer.count / MemoryLayout<Int16>.size
        let downSampledLength = totalSamples / samplesPerPixel
        let samplesToProcess = downSampledLength * samplesPerPixel
        
        guard samplesToProcess > 0 else { return }
        
        processSamples(fromData: &sampleBuffer,
                       sampleMax: &audioSample.sampleMax,
                       outputSamples: &audioSample.samples,
                       samplesToProcess: samplesToProcess,
                       downSampledLength: downSampledLength,
                       samplesPerPixel: samplesPerPixel,
                       filter: filter)
    }
    
    private func processRemaining() {
        let samplesToProcess = sampleBuffer.count / MemoryLayout<Int16>.size
        if samplesToProcess > 0 {
            let downSampledLength = 1
            let samplesPerPixel = samplesToProcess
            let filter = [Float](repeating: 1.0 / Float(samplesPerPixel), count: samplesPerPixel)
            
            processSamples(fromData: &sampleBuffer,
                           sampleMax: &audioSample.sampleMax,
                           outputSamples: &audioSample.samples,
                           samplesToProcess: samplesToProcess,
                           downSampledLength: downSampledLength,
                           samplesPerPixel: samplesPerPixel,
                           filter: filter)
        }
    }
    
    private func processSamples(fromData sampleBuffer: inout Data, sampleMax: inout CGFloat, outputSamples: inout [CGFloat], samplesToProcess: Int, downSampledLength: Int, samplesPerPixel: Int, filter: [Float]) {
        sampleBuffer.withUnsafeBytes { (samples: UnsafePointer<Int16>) in
            var processingBuffer = [Float](repeating: 0.0, count: samplesToProcess)
            
            let sampleCount = vDSP_Length(samplesToProcess)
            
            //Convert 16bit int samples to floats
            vDSP_vflt16(samples, 1, &processingBuffer, 1, sampleCount)
            
            //Take the absolute values to get amplitude
            vDSP_vabs(processingBuffer, 1, &processingBuffer, 1, sampleCount)
            
            //Downsample and average
            var downSampledData = [Float](repeating: 0.0, count: downSampledLength)
            vDSP_desamp(processingBuffer,
                        vDSP_Stride(samplesPerPixel),
                        filter, &downSampledData,
                        vDSP_Length(downSampledLength),
                        vDSP_Length(samplesPerPixel))
            
            let downSampledDataCG = downSampledData.map { (value: Float) -> CGFloat in
                let element = CGFloat(value)
                if element > sampleMax { sampleMax = element }
                return element
            }
            
            // Remove processed samples
            sampleBuffer.removeFirst(samplesToProcess * MemoryLayout<Int16>.size)
            
            outputSamples += downSampledDataCG
        }
    }
}


public class Cancellable {
    public var cancelBlock: (() -> Void)?
    public init(cancelBlock: (() -> Void)? = nil) {
        self.cancelBlock = cancelBlock
    }
    
    public func cancel() {
        cancelBlock?()
    }
}
