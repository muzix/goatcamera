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

class CameraSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
   
    var session: AVCaptureSession!                      // Camera Session Object
    var sessionQueue: dispatch_queue_t!                 // Camera session serial queue
    var videoDeviceInput: AVCaptureDeviceInput!         // Video Input device
    var videoDeviceOutput: AVCaptureVideoDataOutput!    // Video Output
    var stillImageOutput: AVCaptureStillImageOutput!    // Still Image Output for capture still image
    var runtimeErrorHandlingObserver: AnyObject?        // Error Object
    var cameraGranted: Bool!                            // Camera access permission
    var isFrontCamera:Bool!                             // is using front camera ?
    
    // MARK: LIFE CYCLE
    /* Lifecycle
    ------------------------------------------*/
    
    override init() {
        super.init();
        
        self.isFrontCamera = true
        self.session = AVCaptureSession()
        self.session.sessionPreset = AVCaptureSessionPreset640x480
       
        self.authorizeCamera { () -> Void in
            //TODO
        }
        
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
    
}
