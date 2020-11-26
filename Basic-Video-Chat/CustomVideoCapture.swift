//
//  CustomVideoCapture.swift
//  Basic-Video-Chat
//
//  Created by Danh Hung on 9/28/20.
//  Copyright © 2020 tokbox. All rights reserved.
//

import Foundation
import OpenTok
import BBMetalImage

class CustomVideoCapture: NSObject, OTVideoCapture {
    var videoCaptureConsumer: OTVideoCaptureConsumer?
    
    private var captureWidth: Int = 352
    private var captureHeight: Int = 288
    private var capturing = false
    private var videoFrame: OTVideoFrame!
    private var videoFrameOrientation: OTVideoOrientation = .up
    
    private var camera: BBMetalCamera?
    let contrast = BBMetalContrastFilter(contrast: 3)
    var beauty: BBMetalBeautyFilter!
    let preset: AVCaptureSession.Preset = .vga640x480
    var videoConsummer: VideoFrameConsumer!
    var smoothDegree: Float = 0
    
    func initCapture() {
        // Setup camera to capture image
        camera = BBMetalCamera(sessionPreset: preset, position: .front)
        (captureWidth, captureHeight) = preset.dimension()
        videoFrame = OTVideoFrame(format: OTVideoFormat(argbWithWidth: UInt32(captureWidth), height: UInt32(captureHeight)))
        beauty = BBMetalBeautyFilter(smoothDegree: 0.5)
        videoConsummer = VideoFrameConsumer(preset: preset, delegate: self)
        // Setup filters
        camera?
            .add(consumer: beauty)
            .add(consumer: videoConsummer)
    }
    
    func releaseCapture() {
        camera = nil
        videoFrame = nil
    }
    
    func start() -> Int32 {
        camera?.start()
        capturing = true
        return 0
    }
    
    func stop() -> Int32 {
        capturing = false
        camera?.stop()
        return 0
    }
    
    func isCaptureStarted() -> Bool {
        return capturing
    }
    
    func captureSettings(_ videoFormat: OTVideoFormat) -> Int32 {
        videoFormat.pixelFormat = .ARGB
        videoFormat.imageWidth = UInt32(captureWidth)
        videoFormat.imageHeight = UInt32(captureHeight)
        return 0
    }
    
    func changeBeauty(_ degree: Float) {
        self.smoothDegree = degree
        self.beauty.smoothDegree = degree
    }
    
    func switchCamera() {
        self.camera?.switchCameraPosition()
    }
    
    func enableFilter(_ enable: Bool) {
        camera?.removeAllConsumers()
        beauty = nil
        videoConsummer = nil
        videoConsummer = VideoFrameConsumer(preset: preset, delegate: self)
        if enable {
            beauty = BBMetalBeautyFilter(smoothDegree: self.smoothDegree)
            camera?.add(consumer: beauty)
                    .add(consumer: videoConsummer)
        } else {
            camera?.add(consumer: videoConsummer)
        }
    }
}

extension CustomVideoCapture: VideoFrameConsumerDelegate {
    func videoFrameConsumer(_ consumer: VideoFrameConsumer, didCapture pixelBuffer: CVPixelBuffer, timestamp: CMTime?) {
        guard capturing, videoCaptureConsumer != nil else { return }
        
        videoFrame.timestamp = timestamp ?? CMTime.invalid
        videoFrame.format?.imageWidth = UInt32(CVPixelBufferGetWidth(pixelBuffer))
        videoFrame.format?.imageHeight = UInt32(CVPixelBufferGetHeight(pixelBuffer))
        videoFrame.format?.estimatedCaptureDelay = 100
        videoFrame.orientation = videoFrameOrientation
                
        videoFrame.clearPlanes()
        
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!
        videoFrame.planes?.addPointer(baseAddress)
        videoCaptureConsumer!.consumeFrame(videoFrame)
    }
}

extension AVCaptureSession.Preset {
    func dimension() -> (width: Int, height: Int) {
        switch self {
        case AVCaptureSession.Preset.cif352x288: return (288, 352)
        case AVCaptureSession.Preset.vga640x480, AVCaptureSession.Preset.high: return (480, 640)
        case AVCaptureSession.Preset.low: return (144, 192)
        case AVCaptureSession.Preset.medium: return (360, 480)
        case AVCaptureSession.Preset.hd1280x720: return (720, 1280)
        default: return (288, 352)
        }
    }
}
