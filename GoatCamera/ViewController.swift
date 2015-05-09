//
//  ViewController.swift
//  GoatCamera
//
//  Created by Hoang Pham Huu on 3/10/15.
//  Copyright (c) 2015 goatcamera. All rights reserved.
//

import UIKit
import QuartzCore
import CoreImage
import AVFoundation
import ImageIO

class ViewController: UIViewController, CameraSessionDelegate {

    var cameraSession: CameraSession!
    var previewLayer : AVCaptureVideoPreviewLayer!
    @IBOutlet weak var previewView: UIView!
    
    var stickerLayer : CALayer?
    var mustacheLayer: CALayer?
    let mustacheImage: UIImage? = UIImage(named: "mustache")
    let plistName:String = "data.plist"
    
    // View for produce flash effect while capturing image
    var flashView    : UIView?
    
    @IBOutlet weak var imgThumb: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.setupCameraView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setupCameraView() {
        cameraSession = CameraSession()
        cameraSession.sessionDelegate = self
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.cameraSession.session)
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        self.previewView.layer.addSublayer(self.previewLayer)
        updatePreviewLayerFrame()
    }
    
    func updatePreviewLayerFrame() {
        previewLayer.frame = self.previewView.layer.bounds
    }
    
    // MARK: CAMERA SESSION DELEGATE
    func cameraSessionDidReady() {
        cameraSession.startCamera()
    }
    
    func cameraSessionDidOutputSampleBuffer(sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        if (connection.supportsVideoOrientation) {
            connection.videoOrientation = AVCaptureVideoOrientation.Portrait
        }
        if (connection.supportsVideoMirroring) {
            if self.cameraSession.isFrontCamera == true {
                connection.videoMirrored = true
            }
        }
        updateStickerPosition(sampleBuffer)
    }
    
    func capturingImage() {
        flashView = UIView(frame: previewView.frame)
        flashView?.backgroundColor = UIColor.whiteColor()
        flashView?.alpha = 0.0
        if let flashViewUnwrap = flashView? {
            self.view.window?.addSubview(flashViewUnwrap)
        }
        
        UIView.animateWithDuration(0.4, animations: { [unowned self] ()-> Void in
            self.flashView?.alpha = 1.0
            return
        })
    }
    
    func capturedImage() {
        UIView.animateWithDuration(0.4, animations: { [unowned self] () -> Void in
            self.flashView?.alpha = 0.0
            return
            }, completion: { [unowned self] (finished:Bool) -> Void in
                self.flashView?.removeFromSuperview()
                self.flashView = nil
                return
        })
    }
    
    
    // MARK: STICKER CREATE
    func updateStickerPosition(sampleBuffer: CMSampleBuffer) {
        var pixelBuffer: CVImageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer)!
        var sourceImageColor: CIImage = CIImage(CVPixelBuffer: pixelBuffer)
        
        var width = sourceImageColor.extent().size.width
        var height = sourceImageColor.extent().size.height
       
        // Size of detection Image
        var cleanAperture:CGRect = CGRectMake(0, 0, CGFloat(width), CGFloat(height))
        
        let faceFeatures = FaceDetector.detectFaces(inImage: sourceImageColor)
        
        dispatch_async(dispatch_get_main_queue(), { [unowned self] () -> Void in
            self.drawStickers(faceFeatures, clearAperture: cleanAperture, orientation: UIDeviceOrientation.Portrait)
        })
        
    }
    
    func drawStickers(features: NSArray, clearAperture: CGRect, orientation: UIDeviceOrientation) {
        var currentSublayer = 0
        var featuresCount = features.count
        var currentFeature = 0
        
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        if (featuresCount == 0) {
            stickerLayer?.hidden = true
            CATransaction.commit()
            return
        }
        
        var parentFrameSize = self.view.frame.size
        var gravity = self.previewLayer?.videoGravity
        
        // Take max scaleFactor
        var scaleFactorWidth = self.previewLayer.frame.width / clearAperture.width
        var scaleFactorHeight = self.previewLayer.frame.height / clearAperture.height
        var scaleFactor = scaleFactorHeight > scaleFactorWidth ? scaleFactorHeight : scaleFactorWidth
        
        for faceFeature in features {
            if !faceFeature.hasMouthPosition {
                continue
            }
            
            // Add new stickerLayer if not exist. Scale stickerLayer to fit previewLayer
            if (stickerLayer == nil) {
                stickerLayer = CALayer()
                stickerLayer?.frame = CGRectMake(0,
                    0,
                    clearAperture.width,
                    clearAperture.height)
                stickerLayer?.position = self.previewLayer.position
                stickerLayer?.transform = CATransform3DMakeScale(scaleFactor, scaleFactor, 1)
                self.previewLayer.addSublayer(stickerLayer)
            }
            
            stickerLayer?.hidden = false
            
            // Add mustacheLayer into stickerLayer
            if (mustacheLayer == nil) {
                mustacheLayer = CALayer()
                mustacheLayer?.contents = self.mustacheImage?.CGImage
                //                mustacheLayer.borderColor = UIColor.redColor().CGColor
                //                mustacheLayer.borderWidth = 1
                self.stickerLayer?.addSublayer(mustacheLayer)
            }
            
            // Calculate mouthRect
            var faceRect = faceFeature.bounds
            
            faceRect = CGRectMake(0, 0, faceRect.width, faceRect.height)
            
            let mustacheWidth = faceRect.width / 2
            let mustacheHeight = mustacheWidth / mustacheImage!.size.width * mustacheImage!.size.height
            let mustacheSize = CGSize(
                width: mustacheWidth,
                height: mustacheHeight)
            
            
            let mustacheRect = CGRect(
                x: faceFeature.mouthPosition.x - mustacheSize.width * 0.5 + 5,
                y: (clearAperture.height - faceFeature.mouthPosition.y) - mustacheSize.height * 0.5 - 12,
                width: mustacheSize.width,
                height: mustacheSize.height)
            
            
            mustacheLayer?.frame = mustacheRect
            
            currentFeature++
        }
        
        CATransaction.commit()
        
    }
    
    // MARK: CUSTOM IMAGE STICKER RENDER
    
    func renderFinalImage(capturedImage: UIImage, stickerLayer: CALayer?) -> UIImage? {
        var flippedImage: UIImage!
        if self.cameraSession.isFrontCamera == true {
            flippedImage = UIImage(CGImage: capturedImage.CGImage, scale: capturedImage.scale, orientation: UIImageOrientation.LeftMirrored)!
        } else {
            flippedImage = capturedImage
        }
        
        UIGraphicsBeginImageContext(capturedImage.size);
        
        flippedImage.drawAtPoint(CGPointZero, blendMode: kCGBlendModeNormal, alpha: 1.0)
        if let stickerLayerUnwrap = stickerLayer { stickerLayerUnwrap.renderInContext(UIGraphicsGetCurrentContext()) }
        
        var outputImage = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
        
        return outputImage;
    }
    
    
    // MARK: IBOUTLET ACTION
    @IBAction func btnCameraTouch(sender: UIButton) {
        if (cameraSession != nil) {
            cameraSession.captureImage({ [unowned self] (image, error) -> Void in
                // todo
                var finalImage = self.renderFinalImage(image!, stickerLayer: self.stickerLayer)
                UIImageWriteToSavedPhotosAlbum(finalImage, nil, nil, nil)
                self.saveImageToApplicationFolder(finalImage!)
                var image = self.loadLastImageFromApplicationFolder()
                if let tmpImage = image? {
                    self.imgThumb.image = tmpImage
                }
            })
        }
    }
    
    @IBAction func btnRotateCamTouch(sender: UIButton) {
        if (cameraSession != nil) {
            self.cameraSession.switchCamera()
        }
    }
    
    // MARK: SAVE/LOAD IMAGE TO APPLICATION FOLDER
    
    func saveImageToApplicationFolder(finalImage: UIImage) {
        let today = NSDate()
        let dateFormat = NSDateFormatter()
        dateFormat.dateFormat = "MMddyyyy_HHmmssSS"
        let dateString = dateFormat.stringFromDate(today)
        let imageName = NSString(format: "%@-%@.png", "GoatCam", dateString)
        println(imageName)
        let destinationPath = FCFileManager.pathForDocumentsDirectoryWithPath("/" + imageName)
        let data = UIImagePNGRepresentation(finalImage)
        data.writeToFile(destinationPath, atomically: true)
        saveFileList(imageName, creationDate: today)
    }
    
    func removeImageFromApplicationFolder(imageName: String) {
        let imagePath = FCFileManager.pathForDocumentsDirectoryWithPath("/" + imageName)
        if (FCFileManager.existsItemAtPath(imagePath)) {
            FCFileManager.removeFilesInDirectoryAtPath(imagePath)
        }
        var dataList:NSMutableArray?
        var plistPath = FCFileManager.pathForDocumentsDirectoryWithPath(plistName)
        if (!FCFileManager.existsItemAtPath(plistPath)) {
            return
        } else {
            dataList = NSMutableArray(contentsOfFile: plistPath)
        }
        
        let filter:NSPredicate = NSPredicate(format: "name != %@",imageName)!
        if let tmpDataList = dataList? {
            let filteredArray: NSArray = tmpDataList.filteredArrayUsingPredicate(filter) as NSArray
            filteredArray.writeToFile(plistPath, atomically: true)
        }
        
    }
    
    func saveFileList(fileName:String, creationDate:NSDate) {
        var dataList:NSMutableArray?
        var plistPath = FCFileManager.pathForDocumentsDirectoryWithPath(plistName)
        if (!FCFileManager.existsItemAtPath(plistPath)) {
            dataList = NSMutableArray()
        } else {
            dataList = NSMutableArray(contentsOfFile: plistPath)
        }
        var data = NSMutableDictionary()
        data.setObject(fileName, forKey: "name")
        data.setObject(creationDate, forKey: "time")
        dataList?.addObject(data)
        dataList?.writeToFile(plistPath, atomically: true)
    }
    
    func loadLastImageFromApplicationFolder() -> UIImage? {
        let plistPath = FCFileManager.pathForDocumentsDirectoryWithPath(plistName)
        var dataList = NSMutableArray()
        if (FCFileManager.existsItemAtPath(plistPath)) {
            dataList = NSMutableArray(contentsOfFile: plistPath)!
        } else {
            return nil
        }
        if (dataList.count <= 0) {
            return nil
        }
        
        // sort array by creation date
        var descriptor:NSSortDescriptor = NSSortDescriptor(key: "time", ascending: true)
        var sortedList: NSArray = dataList.sortedArrayUsingDescriptors([descriptor])
        
        var imageInfo:NSDictionary = sortedList.objectAtIndex(sortedList.count - 1) as NSDictionary
        var imageName:String = imageInfo.objectForKey("name") as String
        let destinationPath = FCFileManager.pathForDocumentsDirectoryWithPath("/" + imageName)
        var image = UIImage(contentsOfFile: destinationPath)
        return image
    }
    
}

