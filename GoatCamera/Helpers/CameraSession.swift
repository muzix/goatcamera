//
//  CameraSession.swift
//  GoatCamera
//
//  Created by Hoang Pham Huu on 3/21/15.
//  Copyright (c) 2015 goatcamera. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMedia
import CoreImage

@objc protocol CameraSessionDelegate {
    optional func cameraSessionDidOutputSampleBuffer(sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!)
    optional func capturingImage()
    optional func capturedImage()
    optional func cameraSessionDidReady()
}

class CameraSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
   
    var session: AVCaptureSession!                      // Camera Session Object
    var sessionQueue: dispatch_queue_t!                 // Camera session serial queue
    var videoDeviceInput: AVCaptureDeviceInput!         // Video Input device
    var videoDeviceOutput: AVCaptureVideoDataOutput!    // Video Output
    var stillImageOutput: AVCaptureStillImageOutput!    // Still Image Output for capture still image
    var runtimeErrorHandlingObserver: AnyObject?        // Error Object
    var cameraGranted: Bool!                            // Camera access permission
    var isFrontCamera:Bool!                             // is using front camera ?
    
    var sessionDelegate: CameraSessionDelegate?
    
    private var AVCaptureStillImageIsCapturingStillImageContext = 0
    
    // MARK: LIFE CYCLE
    /* Lifecycle
    ------------------------------------------*/
    
    override init() {
        super.init();
        
        self.isFrontCamera = true
        self.session = AVCaptureSession()
        self.session.sessionPreset = AVCaptureSessionPreset640x480
       
//        self.authorizeCamera { () -> Void in
//            //TODO
//        }
        
        self.authorizeCamera { [unowned self] () -> Void in
            self.sessionQueue = dispatch_queue_create("CameraSessionController Session", DISPATCH_QUEUE_SERIAL)
            
            dispatch_async(self.sessionQueue, {
                self.session.beginConfiguration()
                self.addFrontVideoInput()
                self.addVideoOutput()
                self.addStillImageOutput()
                self.session.commitConfiguration()
                self.sessionDelegate?.cameraSessionDidReady?()
            })
        };
        
    }
    
    deinit {
        self.stillImageOutput.removeObserver(self, forKeyPath: "capturingStillImage")
    }
    
    // MARK: INSTANCE METHODS
    /* Instance Methods
    ------------------------------------------*/
    
    func authorizeCamera(completionHandler: () -> Void) {
        AVCaptureDevice.requestAccessForMediaType(
            AVMediaTypeVideo,
            completionHandler: {
                (granted: Bool) -> Void in
                self.cameraGranted = granted
                // If permission hasn't been granted, notify the user.
                if !granted {
                    dispatch_async(dispatch_get_main_queue(), {
                        UIAlertView(
                            title: "Could not use camera!",
                            message: "This application does not have permission to use camera. Please update your privacy settings.",
                            delegate: self,
                            cancelButtonTitle: "OK").show()
                    })
                } else {
                    completionHandler()
                }
            }
        );
    }
    
    class func deviceWithMediaType(mediaType: NSString, position: AVCaptureDevicePosition) -> AVCaptureDevice {
        var devices: NSArray = AVCaptureDevice.devicesWithMediaType(mediaType as String)
        var captureDevice: AVCaptureDevice = devices.firstObject as! AVCaptureDevice
        
        for object:AnyObject in devices {
            let device = object as! AVCaptureDevice
            if (device.position == position) {
                captureDevice = device
                break
            }
        }
        
        return captureDevice
    }
    
    func removeVideoInput() -> Bool {
        let currentVideoInputs:NSArray = self.session.inputs as NSArray;
        let count = currentVideoInputs.count
        if (count > 0) {
            self.session.removeInput(currentVideoInputs[0] as! AVCaptureInput)
            self.videoDeviceInput = nil
        }
        return true
    }
    
    // Setup camera input device (front facing camera) and add input feed to our AVCaptureSession session.
    func addFrontVideoInput() -> Bool {
        removeVideoInput()
        
        var success: Bool = false
        var error: NSError?
        
        var videoDevice: AVCaptureDevice = CameraSession.deviceWithMediaType(AVMediaTypeVideo, position: AVCaptureDevicePosition.Front)
        
        self.videoDeviceInput = AVCaptureDeviceInput.deviceInputWithDevice(videoDevice, error: &error) as! AVCaptureDeviceInput;
        if (error == nil) {
            if self.session.canAddInput(self.videoDeviceInput) {
                self.session.addInput(self.videoDeviceInput)
                success = true
                isFrontCamera = true
            }
        }
        
        // change framerate
        var maxFramerate = 0
        for vFormat in videoDevice.formats {
            let description:CMFormatDescriptionRef = vFormat.formatDescription
            let frameRateRanges:NSArray = vFormat.videoSupportedFrameRateRanges as NSArray
            let frameRateRange:AVFrameRateRange = frameRateRanges[0] as! AVFrameRateRange
            var maxrate:Int = Int(frameRateRange.maxFrameRate)
            if maxrate >= maxFramerate {
                
                maxFramerate = maxrate
                videoDevice.lockForConfiguration(nil)
                videoDevice.activeFormat = vFormat as! AVCaptureDeviceFormat
                videoDevice.activeVideoMinFrameDuration = CMTimeMake(1,Int32(maxFramerate))
                videoDevice.activeVideoMaxFrameDuration = CMTimeMake(1,Int32(maxFramerate))
                videoDevice.unlockForConfiguration()
                
            }
        }
        NSLog("Max framerate: %d", maxFramerate)
        
        return success
    }
    
    func addBackVideoInput() -> Bool {
        removeVideoInput()
        
        var success: Bool = false
        var error: NSError?
        
        var videoDevice: AVCaptureDevice = CameraSession.deviceWithMediaType(AVMediaTypeVideo, position: AVCaptureDevicePosition.Back)
        
        self.videoDeviceInput = AVCaptureDeviceInput.deviceInputWithDevice(videoDevice, error: &error) as! AVCaptureDeviceInput;
        if (error == nil) {
            if self.session.canAddInput(self.videoDeviceInput) {
                self.session.addInput(self.videoDeviceInput)
                success = true
                isFrontCamera = false
            }
            
            // change framerate
                        var maxFramerate = 0
                        for vFormat in videoDevice.formats {
                            let description:CMFormatDescriptionRef = vFormat.formatDescription
                            let frameRateRanges:NSArray = vFormat.videoSupportedFrameRateRanges as NSArray
                            let frameRateRange:AVFrameRateRange = frameRateRanges[0] as! AVFrameRateRange
                            var maxrate:Int = Int(frameRateRange.maxFrameRate)
                            if maxrate >= maxFramerate {
                                
                                    maxFramerate = maxrate
                                    videoDevice.lockForConfiguration(nil)
                                    videoDevice.activeFormat = vFormat as! AVCaptureDeviceFormat
                                    videoDevice.activeVideoMinFrameDuration = CMTimeMake(1,Int32(maxFramerate))
                                    videoDevice.activeVideoMaxFrameDuration = CMTimeMake(1,Int32(maxFramerate))
                                    videoDevice.unlockForConfiguration()
                                
                            }
                        }
                        NSLog("Max framerate: %d", maxFramerate)
        }
        
        return success
    }
    
    func removeVideoOutput() -> Bool {
        if self.videoDeviceOutput != nil {
            self.session.removeOutput(self.videoDeviceOutput)
            self.videoDeviceOutput = nil
        }
        if self.stillImageOutput != nil {
            self.stillImageOutput.removeObserver(self, forKeyPath: "capturingStillImage")
            self.session.removeOutput(self.stillImageOutput)
            self.stillImageOutput = nil
        }
        return true
    }
    
    // Setup capture output for our video device input.
    func addVideoOutput() {
        var settings: [String: Int] = [
            //kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ]
        
        self.videoDeviceOutput = AVCaptureVideoDataOutput()
        self.videoDeviceOutput.videoSettings = settings
        self.videoDeviceOutput.alwaysDiscardsLateVideoFrames = true
        
        self.videoDeviceOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
        
        if self.session.canAddOutput(self.videoDeviceOutput) {
            self.session.addOutput(self.videoDeviceOutput)
        }
        
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        self.sessionDelegate?.cameraSessionDidOutputSampleBuffer?(sampleBuffer, fromConnection:connection)
    }
    
    func addStillImageOutput() {
        self.stillImageOutput = AVCaptureStillImageOutput()
        self.stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        self.stillImageOutput.addObserver(self, forKeyPath: "capturingStillImage", options: NSKeyValueObservingOptions.New, context:&AVCaptureStillImageIsCapturingStillImageContext)
        
        if self.session.canAddOutput(self.stillImageOutput) {
            self.session.addOutput(self.stillImageOutput)
        }
    }
    
    func startCamera() {
        dispatch_async(self.sessionQueue, {
            self.runtimeErrorHandlingObserver = NSNotificationCenter.defaultCenter().addObserverForName(AVCaptureSessionRuntimeErrorNotification, object: self.sessionQueue, queue: nil, usingBlock: {
                [unowned self] (note: NSNotification!) -> Void in
                dispatch_async(self.sessionQueue, {
                    self.session.startRunning()
                })
            })
            self.session.startRunning()
        })
    }
    
    func teardownCamera() {
        dispatch_async(self.sessionQueue, {
            self.session.stopRunning()
            self.stillImageOutput.removeObserver(self, forKeyPath: "capturingStillImage")
            NSNotificationCenter.defaultCenter().removeObserver(self.runtimeErrorHandlingObserver!)
        })
    }
    
    func switchCamera() {
        self.sessionQueue = dispatch_queue_create("CameraSessionController Session", DISPATCH_QUEUE_SERIAL)
        dispatch_async(self.sessionQueue, {
            self.session.beginConfiguration()
            if (self.isFrontCamera == true) {
                self.addBackVideoInput()
            } else {
                self.addFrontVideoInput()
            }
            self.removeVideoOutput()
            self.addVideoOutput()
            self.addStillImageOutput()
            self.session.commitConfiguration()
        })
    }
    
    func captureImage(completion:((image: UIImage?, error: NSError?) -> Void)?) {
        if completion == nil || self.stillImageOutput == nil{
            return
        }
        
        //dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
        dispatch_async(self.sessionQueue, {
            NSLog("Connections %d", self.stillImageOutput.connections.count)
            self.stillImageOutput.captureStillImageAsynchronouslyFromConnection(self.stillImageOutput.connectionWithMediaType(AVMediaTypeVideo), completionHandler: {
                (imageDataSampleBuffer: CMSampleBuffer?, error: NSError?) -> Void in
                if imageDataSampleBuffer == nil || error != nil {
                    completion!(image:nil, error:nil)
                }
                else if imageDataSampleBuffer != nil {
                    var imageData: NSData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                    var image: UIImage = UIImage(data: imageData)!
                    completion!(image:image, error:nil)
                }
            })
        })
    }
    
    // MARK: KVO
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        switch (keyPath, context) {
        case("capturingStillImage", &AVCaptureStillImageIsCapturingStillImageContext):
            println("isCapturingImage!")
            if let theChange = change as? [NSString: Bool]{
                if let isCapturingStillImage = theChange[NSKeyValueChangeNewKey]{
                    if (isCapturingStillImage) {
                        println("FLASH LIGHT!")
                        self.sessionDelegate?.capturingImage?()
                    } else {
                        println("FLASH OFF!")
                        self.sessionDelegate?.capturedImage?()
                    }
                    
                }
            }
        case(_, &AVCaptureStillImageIsCapturingStillImageContext):
            assert(false, "unknown key path")
            
        default:
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
}
