//
//  ViewController.swift
//  GoatCamera
//
//  Created by Hoang Pham Huu on 3/10/15.
//  Copyright (c) 2015 goatcamera. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var cameraSession: CameraSession!
    
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
    }

}

