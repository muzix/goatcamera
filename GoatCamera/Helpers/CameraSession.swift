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
    
    deinit {}
    
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
        var devices: NSArray = AVCaptureDevice.devicesWithMediaType(mediaType)
        var captureDevice: AVCaptureDevice = devices.firstObject as AVCaptureDevice
        
        for object:AnyObject in devices {
            let device = object as AVCaptureDevice
            if (device.position == position) {
                captureDevice = device
                break
            }
        }
        
        return captureDevice
    }
    
    func removeVideoInput() -> Bool {
        let currentVideoInputs:NSArray = self.session.inputs as NSArray;
        if (currentVideoInputs.count > 0) {
            self.session.removeInput(currentVideoInputs[0] as AVCaptureInput)
        }
        return true
    }
    
    // Setup camera input device (front facing camera) and add input feed to our AVCaptureSession session.
    func addFrontVideoInput() -> Bool {
        removeVideoInput()
        
        var success: Bool = false
        var error: NSError?
        
        var videoDevice: AVCaptureDevice = CameraSession.deviceWithMediaType(AVMediaTypeVideo, position: AVCaptureDevicePosition.Front)
        
        self.videoDeviceInput = AVCaptureDeviceInput.deviceInputWithDevice(videoDevice, error: &error) as AVCaptureDeviceInput;
        if (error == nil) {
            if self.session.canAddInput(self.videoDeviceInput) {
                self.session.addInput(self.videoDeviceInput)
                success = true
                isFrontCamera = true
            }
        }
        
        return success
    }
    
    func removeVideoOutput() -> Bool {
        let currentVideoOutputs:NSArray = self.session.outputs as NSArray;
        if (currentVideoOutputs.count > 0) {
            self.session.removeOutput(currentVideoOutputs[0] as AVCaptureOutput)
        }
        
        return true
    }
    
    // Setup capture output for our video device input.
    func addVideoOutput() {
        var settings: [String: Int] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            //kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
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
            NSNotificationCenter.defaultCenter().removeObserver(self.runtimeErrorHandlingObserver!)
        })
    }
    
}
