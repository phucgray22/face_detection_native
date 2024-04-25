import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
      if let controller = window?.rootViewController as? FlutterViewController {
          let channel = FlutterMethodChannel(
            name: "irhp/channel",
            binaryMessenger: controller.binaryMessenger
          )
          channel.setMethodCallHandler({ [weak self] (
            call: FlutterMethodCall,
            result: @escaping FlutterResult) -> Void in
              switch call.method {
              case "openCamera":
                  
                  guard let args = call.arguments as? [String:Any] else {
                      return
                  }
                  
                  guard let stepsMap = args["steps"] as? [[String: Any]] else {
                      return
                  }
                  
                  guard let detectionsMap = args["detections"] as? [String: Any] else {
                      return
                  }
                  
                  let currentFunctionType = (args["function"] as? String) ?? "training"

                  
                  DispatchQueue.main.async {
                      guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
                          print("%% Error: Unable to get root view controller.")
                          return
                      }
                      
                      let storyboard = UIStoryboard(name: "CameraView", bundle: nil)
                      let cameraViewController = storyboard.instantiateViewController(withIdentifier: "CameraView") as! CameraViewController
                      cameraViewController.flutterMethodChannel = channel
                      
                      //
                      switch currentFunctionType {
                      case "training":
                          cameraViewController.currentFunctionType = .training
                      case "checkIn":
                          cameraViewController.currentFunctionType = .checkIn
                      default:
                          cameraViewController.currentFunctionType = .training
                      }
                      
//
                      
                      //
                      var steps: [Step] = []
                      
                      for stepDict in stepsMap {
                        guard let id = stepDict["id"] as? String,
                              let description = stepDict["description"] as? String else {
                          continue  // Skip to the next step in the loop
                        }
                        
                        let step = Step(id: id, description: description)
                        steps.append(step)
                      }
                      
                      cameraViewController.steps = steps
                      
                      //
                      var detections: Detections = Detections()
                      
                      detections.smilingProbability = (detectionsMap["smilingProbability"] as? Double) ?? 0.9
                      detections.closeProbability = (detectionsMap["closeEyeProbability"] as? Double) ?? 0.1
                      detections.openProbability = (detectionsMap["openProbability"] as? Double) ?? 0.9
                      
                      detections.turnLeftHeadEulerAngleY = (detectionsMap["turnleft"] as? Double) ?? -20.0
                      detections.turnRightHeadEulerAngleY = (detectionsMap["turnRight"] as? Double) ?? 40.0
//                      detections.lookUpHeadEulerAngleX = (detectionsMap["lookUp"] as? Double) ?? 30.0
//                      detections.lookDownHeadEulerAngleX = (detectionsMap["lookDown"] as? Double) ?? -15.0
                      detections.lookStraight = (detectionsMap["lookStraight"] as? [Double]) ?? [200, 300]
                      detections.mid = (detectionsMap["mid"] as? [Double]) ?? [-12, 12]
                      
                      detections.height = (detectionsMap["faceSize"] as? [Int]) ?? [250, 290]
                      detections.width = (detectionsMap["faceSize"] as? [Int]) ?? [250, 290]
                      detections.top = (detectionsMap["faceTop"] as? [Int]) ?? [0, 150]
                      detections.left = (detectionsMap["faceLeft"] as? [Int]) ?? [10, 80]
                      
                      cameraViewController.detections = detections
                      
                      
                      cameraViewController.modalPresentationStyle = .fullScreen
                      rootViewController.present(cameraViewController, animated: true, completion: nil)
                  }
                  
                  
                  break
              default:
                  result(FlutterMethodNotImplemented)
              }
          })
      }
      
      


      
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
