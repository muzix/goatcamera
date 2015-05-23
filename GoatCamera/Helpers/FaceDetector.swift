//
//  FaceDetector.swift
//  LiXiCamera
//
//  Created by Hoang Pham Huu on 2/4/15.
//  Copyright (c) 2015 thucdon24. All rights reserved.
//

import UIKit
import CoreImage

private let _sharedCIDetector = CIDetector(
    ofType: CIDetectorTypeFace,
    context: nil,
    options: [
        CIDetectorAccuracy: CIDetectorAccuracyLow,
        CIDetectorTracking: false,
        CIDetectorMinFeatureSize: NSNumber(float: 0.1)
    ])

class FaceDetector {
    
    class var sharedCIDetector: CIDetector {
        return _sharedCIDetector
    }
    
    class func detectFaces(inImage image: CIImage) -> [CIFaceFeature] {
        let detector = FaceDetector.sharedCIDetector
            let features = detector.featuresInImage(
            image,
            options: [
                CIDetectorImageOrientation: 1,
                CIDetectorEyeBlink: false,
                CIDetectorSmile: false
            ])
        
        return features as! [CIFaceFeature]
    }
}