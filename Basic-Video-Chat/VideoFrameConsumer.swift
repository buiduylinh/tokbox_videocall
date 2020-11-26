//
//  VideoFrameConsumer.swift
//  Basic-Video-Chat
//
//  Created by Danh Hung on 9/28/20.
//  Copyright © 2020 tokbox. All rights reserved.
//

import AVFoundation
import BBMetalImage

protocol VideoFrameConsumerDelegate {
    func videoFrameConsumer(_ consumer: VideoFrameConsumer, didCapture pixelBuffer: CVPixelBuffer, timestamp: CMTime?)
}

class VideoFrameConsumer: BBMetalImageConsumer {
    private var pixelBufferPool: CVPixelBufferPool
    private var videoPixelBuffer: CVPixelBuffer!
    
    private var computePipeline: MTLComputePipelineState!
    private var outputTexture: MTLTexture!
    private let threadgroupSize: MTLSize
    private var threadgroupCount: MTLSize
    
    private var delegate: VideoFrameConsumerDelegate?
        
    init(preset: AVCaptureSession.Preset, delegate: VideoFrameConsumerDelegate?) {
        let (width, height) = preset.dimension()
        
        // Initial CVPixelBufferPool
        let attributes: NSDictionary = [
            kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String : width,
            kCVPixelBufferHeightKey as String : height
        ]
        var outputPool: CVPixelBufferPool? = nil
        guard CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes, &outputPool) == kCVReturnSuccess else {
            fatalError("Can not create pixcel buffer pool")
        }
        pixelBufferPool = outputPool!
        
        // Initial MTLComputePipelineState
        let library = try! BBMetalDevice.sharedDevice.makeDefaultLibrary(bundle: Bundle(for: BBMetalVideoWriter.self))
        let kernelFunction = library.makeFunction(name: "passThroughKernel")!
        computePipeline = try! BBMetalDevice.sharedDevice.makeComputePipelineState(function: kernelFunction)
        
        // Initial output MTLTexture
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = .bgra8Unorm
        descriptor.width = width
        descriptor.height = height
        descriptor.usage = [.shaderRead, .shaderWrite]
        outputTexture = BBMetalDevice.sharedDevice.makeTexture(descriptor: descriptor)
        
        // Initial metal threadgroupSize and threadgroupCount
        threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        threadgroupCount = MTLSize(width: (width + threadgroupSize.width - 1) / threadgroupSize.width,
                                   height: (height + threadgroupSize.height - 1) / threadgroupSize.height,
                                   depth: 1)
        
        self.delegate = delegate
    }
    
    func add(source: BBMetalImageSource) {}
    func remove(source: BBMetalImageSource) {}
    
    func newTextureAvailable(_ texture: BBMetalTexture, from source: BBMetalImageSource) {
        guard delegate != nil else { return }
        
        if videoPixelBuffer == nil {
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &videoPixelBuffer) == kCVReturnSuccess else {
                print("Can not create pixel buffer")
                return
            }
        }
        
        // Render to output texture
        guard let commandBuffer = BBMetalDevice.sharedCommandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder() else {
                CVPixelBufferUnlockBaseAddress(videoPixelBuffer, [])
                print("Can not create compute command buffer or encoder")
                return
        }
        
        encoder.setComputePipelineState(computePipeline)
        encoder.setTexture(outputTexture, index: 0)
        encoder.setTexture(texture.metalTexture, index: 1)
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted() // Wait to make sure that output texture contains new data
        
        // Copy data from metal texture to pixel buffer
        guard videoPixelBuffer != nil,
            CVPixelBufferLockBaseAddress(videoPixelBuffer, []) == kCVReturnSuccess else {
                print("Pixel buffer can not lock base address")
                return
        }
        guard let baseAddress = CVPixelBufferGetBaseAddress(videoPixelBuffer) else {
            CVPixelBufferUnlockBaseAddress(videoPixelBuffer, [])
            print("Can not get pixel buffer base address")
            return
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(videoPixelBuffer)
        let region = MTLRegionMake2D(0, 0, outputTexture.width, outputTexture.height)
        outputTexture.getBytes(baseAddress, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        delegate!.videoFrameConsumer(self, didCapture: videoPixelBuffer, timestamp: texture.sampleTime)
        
        CVPixelBufferUnlockBaseAddress(videoPixelBuffer, [])
    }
}
