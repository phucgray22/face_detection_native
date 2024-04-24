import Foundation
import AVFoundation
import UIKit
import MLImage
import MLKit
import CoreVideo
import Flutter

@objc(CameraViewController)
class CameraViewController: UIViewController {
    @IBOutlet fileprivate weak var cameraView: UIView!
    @IBOutlet fileprivate weak var tutorialText: UILabel!
    @IBOutlet fileprivate weak var checkInButton: UIButton!
    @IBOutlet fileprivate weak var backButton: UIButton!
    @IBOutlet fileprivate weak var horizontalStack: UIStackView!
    @IBOutlet fileprivate weak var scrollView: UIScrollView!
    
    var flutterMethodChannel: FlutterMethodChannel?
    var steps: [Step] = []
    var detections: Detections = Detections()
    var currentFunctionType: Function = .training
    
    @IBAction func checkInClicked(_ sender: UIButton) {
        print("BACK")
        var listBase64: [String] = []
        
        for item in imageViews {
            guard let imageData = item.image?.jpegData(compressionQuality: 1)?.base64EncodedString() else {
                return
            }
            listBase64.append(imageData)
            
        }
        
        flutterMethodChannel?.invokeMethod("getListBase64", arguments: listBase64)
        self.dismiss(animated: true)
    }
    
    @IBAction func backClicked(_ sender: UIButton) {
        self.dismiss(animated: true)
    }
    
    @objc func stepStackViewTapped(_ sender: UITapGestureRecognizer) {
        if(!finished || detecting) {
            return
        }
        
        guard let stepStackView = sender.view as? CustomUIStackView else {
            return
        }
        
        let index: Int = stepStackView.tag
        let currentImageView = imageViews[index] as UIImageView
        currentImageView.image = UIImage()
        
        detecting = true
        loading = false
        currentStepIndex = index
        changeStep(step: steps[index])
        toggleCheckInButton(on: false)
    }
    
    private lazy var annotationOverlayView: UIView = {
        precondition(isViewLoaded)
        let annotationOverlayView = UIView(frame: .zero)
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return annotationOverlayView
    }()
    
    private lazy var previewOverlayView: UIImageView = {
        precondition(isViewLoaded)
        let previewOverlayView = UIImageView(frame: .zero)
        previewOverlayView.contentMode = UIView.ContentMode.scaleAspectFill
        previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return previewOverlayView
    }()
    
    private lazy var borderLayer: CAShapeLayer = {
        let borderLayer = CAShapeLayer()
        return borderLayer
    }()
    
    private var currentDetector: Detector = .onDeviceFace
    private var isUsingFrontCamera = true
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private lazy var captureSession = AVCaptureSession()
    private lazy var sessionQueue = DispatchQueue(label: Constant.sessionQueueLabel)
    private var lastFrame: CMSampleBuffer?
    private var lastDetector: Detector?
    //
    private var currentStepIndex = -1
    private var currentStep: Step? = nil
    private var loading = false
    private var finished = false
    private var detecting = false
    private var listStepIdSuccess: [String] = []
    private var imageViews: [UIImageView] = []
    private var labelViews: [UILabel] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
        }
        
        setupView()
        createStepStackViews()
        setupTap()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        setUpPreviewOverlayView()
        setUpCaptureSessionOutput()
        setUpCaptureSessionInput()
        
        addCircularBorder()
        addCircularMask()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        startSession()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        stopSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        previewLayer.frame = cameraView.frame
        
        scrollView.contentSize = CGSize(width: horizontalStack.frame.width, height: horizontalStack.frame.height)
    }
    
    private func setupTap() {
        for (index, stepStackView) in horizontalStack.arrangedSubviews.enumerated() {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(stepStackViewTapped(_:)))
            stepStackView.addGestureRecognizer(tapGesture)
            stepStackView.isUserInteractionEnabled = true
            stepStackView.tag = index // Set a tag to identify the stepStackView later
        }
    }
    
    private func setupView() {
        // CAMERA VIEW
        let cameraWidth = getCameraSize()
        let cameraHeight = cameraWidth
        
        if let widthConstraint = cameraView.constraints.first(where: { $0.firstAttribute == .width }) {
            widthConstraint.constant = cameraWidth
        } else {
            cameraView.widthAnchor.constraint(equalToConstant: cameraWidth).isActive = true
        }
        
        if let heightConstraint = cameraView.constraints.first(where: { $0.firstAttribute == .height }) {
            heightConstraint.constant = cameraHeight
        } else {
            cameraView.heightAnchor.constraint(equalToConstant: cameraHeight).isActive = true
        }
        
        // tutorial text
        if let widthConstraint = tutorialText.constraints.first(where: { $0.firstAttribute == .width }) {
            widthConstraint.constant = cameraWidth
        } else {
            tutorialText.widthAnchor.constraint(equalToConstant: cameraWidth).isActive = true
        }
        
        tutorialText.numberOfLines = 3
        
        checkInButton.layer.cornerRadius = 8
        backButton.layer.cornerRadius = 8
        
        toggleCheckInButton(on: false)
     
        annotationOverlayView.backgroundColor = .clear
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(annotationOverlayView)
        
        NSLayoutConstraint.activate([
            annotationOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
            annotationOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            annotationOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            annotationOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor)
        ])
    }
    
    private func getCameraSize() -> Double {
        let screenWidth = view.bounds.width
        //    return min(screenWidth * 0.95, 320)
        
        return 320
        
    }
    
    private func createStepStackViews() {
        horizontalStack.arrangedSubviews.forEach { $0.removeFromSuperview() } // Clear existing stack views
        //          horizontalStack.sizeToFit()
        imageViews.removeAll() // Clear existing image views
        
        for step in steps {
            let stepStackView = CustomUIStackView()
            stepStackView.id = step.id
            stepStackView.axis = .vertical
            stepStackView.spacing = 5
            stepStackView.translatesAutoresizingMaskIntoConstraints = false
            
            let imageView = UIImageView(frame: .zero)
            imageView.contentMode = .scaleAspectFit
            imageView.image = UIImage()
            imageView.tintColor = .gray
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageViews.append(imageView) // Add imageView to the array
            stepStackView.addArrangedSubview(imageView)
            
            let label = UILabel()
            label.text = step.description
            label.textAlignment = .center
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            label.isHidden = true
            labelViews.append(label)
            stepStackView.addArrangedSubview(label)
            
            imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            
            
            NSLayoutConstraint.activate([
                stepStackView.heightAnchor.constraint(equalToConstant: 144),
                stepStackView.widthAnchor.constraint(equalToConstant: 160),
                label.widthAnchor.constraint(equalTo: stepStackView.widthAnchor) // Constrain label width
            ])
            
            horizontalStack.addArrangedSubview(stepStackView)
        }
    }
    
    private func addCircularMask() {
        let diameter = getCameraSize()
        
        let maskLayer = CALayer()
        maskLayer.frame = cameraView.bounds
        let circleLayer = CAShapeLayer()
        circleLayer.frame = CGRectMake(0, 0, diameter, diameter)
        let circlePath = UIBezierPath(ovalIn: CGRectMake(0, 0, diameter, diameter))
        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = UIColor.black.cgColor
        circleLayer.fillRule = .evenOdd
        maskLayer.addSublayer(circleLayer)
        //
        let outerRectLayer = CAShapeLayer()
        outerRectLayer.frame = CGRectMake(0, 0, diameter, diameter)
        let outerCirclePath = UIBezierPath(rect: CGRectMake(0, 0, diameter, diameter))
        outerRectLayer.path = outerCirclePath.cgPath
        outerRectLayer.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor
        outerRectLayer.fillRule = .evenOdd
        
        maskLayer.addSublayer(outerRectLayer)
        
        cameraView.layer.mask = maskLayer
    }
    
    private func addCircularBorder() {
        let diameter = getCameraSize()
        
        let borderPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: diameter - 10, height: diameter - 10))
        
        borderLayer.path = borderPath.cgPath
        
        borderLayer.lineWidth = 10
        borderLayer.fillColor = UIColor.clear.cgColor
        //    borderLayer.strokeColor = UIColor.black.cgColor
        
        borderLayer.position = CGPoint(x: 5, y: 5)
        
        // Add borderLayer to annotationOverlayView
        annotationOverlayView.layer.addSublayer(borderLayer)
    }
    
    private func changeCircleColor(color: UIColor) {
        borderLayer.strokeColor = color.cgColor
    }
    
    private func setUpPreviewOverlayView() {
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        cameraView.addSubview(previewOverlayView)
        
        previewOverlayView.layer.cornerRadius = previewOverlayView.frame.width / 2
        previewOverlayView.clipsToBounds = true
        
        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: previewOverlayView.topAnchor),
            cameraView.leadingAnchor.constraint(equalTo: previewOverlayView.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: previewOverlayView.trailingAnchor),
            cameraView.bottomAnchor.constraint(equalTo: previewOverlayView.bottomAnchor)
        ])
    }
    
    private func setUpCaptureSessionOutput() {
        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            strongSelf.captureSession.beginConfiguration()
            // When performing latency tests to determine ideal capture settings,
            // run the app in 'release' mode to get accurate performance metrics
            strongSelf.captureSession.sessionPreset = AVCaptureSession.Preset.medium
            //        strongSelf.captureSession.sessionPreset = AVCaptureSession.Preset.photo
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true
            let outputQueue = DispatchQueue(label: Constant.videoDataOutputQueueLabel)
            output.setSampleBufferDelegate(strongSelf, queue: outputQueue)
            guard strongSelf.captureSession.canAddOutput(output) else {
                print("Failed to add capture session output.")
                return
            }
            strongSelf.captureSession.addOutput(output)
            strongSelf.captureSession.commitConfiguration()
        }
    }
    
    private func setUpCaptureSessionInput() {
        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            let cameraPosition: AVCaptureDevice.Position = strongSelf.isUsingFrontCamera ? .front : .back
            guard let device = strongSelf.captureDevice(forPosition: cameraPosition) else {
                print("Failed to get capture device for camera position: \(cameraPosition)")
                return
            }
            do {
                strongSelf.captureSession.beginConfiguration()
                let currentInputs = strongSelf.captureSession.inputs
                for input in currentInputs {
                    strongSelf.captureSession.removeInput(input)
                }
                
                let input = try AVCaptureDeviceInput(device: device)
                guard strongSelf.captureSession.canAddInput(input) else {
                    print("Failed to add capture session input.")
                    return
                }
                strongSelf.captureSession.addInput(input)
                strongSelf.captureSession.commitConfiguration()
            } catch {
                print("Failed to create capture device input: \(error.localizedDescription)")
            }
        }
    }
    
    private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if #available(iOS 10.0, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            )
            return discoverySession.devices.first { $0.position == position }
        }
        return nil
    }
    
    private func startSession() {
        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            strongSelf.captureSession.startRunning()
        }
    }
    
    private func stopSession() {
        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            strongSelf.captureSession.stopRunning()
        }
    }
    
    private func resetManagedLifecycleDetectors(activeDetector: Detector) {
        if activeDetector == self.lastDetector {
            return
        }
        self.lastDetector = activeDetector
    }
}

class CustomUIStackView: UIStackView {
    var id: String = ""
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer.")
            return
        }
        let activeDetector = self.currentDetector
        resetManagedLifecycleDetectors(activeDetector: activeDetector)
        
        lastFrame = sampleBuffer
        let visionImage = VisionImage(buffer: sampleBuffer)
        let orientation = UIUtilities.imageOrientation(
            fromDevicePosition: isUsingFrontCamera ? .front : .back
        )
        visionImage.orientation = orientation
        
        guard let inputImage = MLImage(sampleBuffer: sampleBuffer) else {
            print("Failed to create MLImage from sample buffer.")
            return
        }
        inputImage.orientation = orientation
        
        let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
        
        detectFacesOnDevice(in: visionImage, width: imageWidth, height: imageHeight)
    }
    
    private func changeTutorialText(text: String?) {
        if(tutorialText.text == text) {
            return
        }
        
        tutorialText.text = text
    }
    
    private func isFaceMatchCondition(stepID: String, face: Face?) -> Bool {
        if(face == nil) {
            return false
        }

        
        switch stepID {
        case "turnLeft":
            return isTurnLeft(face: face!)
        case "turnRight":
            return face!.headEulerAngleY >= detections.turnRightHeadEulerAngleY!
        case "smile":
            return face!.smilingProbability >= detections.smilingProbability!
        case "closeLeftEye":
            
            return (face!.leftEyeOpenProbability <= detections.closeProbability! &&
                    face!.rightEyeOpenProbability >= detections.openProbability! &&
                    face!.headEulerAngleY > detections.turnLeftHeadEulerAngleY! &&
                    face!.headEulerAngleY < detections.turnRightHeadEulerAngleY!
            )
        case "closeRightEye":
            
            return (face!.rightEyeOpenProbability <= detections.closeProbability! &&
                    face!.leftEyeOpenProbability >= detections.openProbability! &&
                    face!.headEulerAngleY > detections.turnLeftHeadEulerAngleY! &&
                    face!.headEulerAngleY < detections.turnRightHeadEulerAngleY!)
        default:
            return false
        }
    }
    
    private func changeStep(step: Step?) {
        currentStep = step
        tutorialText.text = step?.description ?? ""
    }
    
    func captureImage() -> UIImage? {
        guard let lastFrame = lastFrame else {
            return nil
        }
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame) else {
            return nil
        }
        
        let orientation: UIImage.Orientation = isUsingFrontCamera ? .leftMirrored : .right
        return UIUtilities.createUIImage(from: imageBuffer, orientation: orientation)
    }
    
    private func toggleCheckInButton(on: Bool) {
        if(on) {
            checkInButton.backgroundColor = UIColor.systemBlue
            checkInButton.isEnabled = true
            changeTutorialText(text: "XONG")
        } else {
            checkInButton.backgroundColor = UIColor.systemGray
            checkInButton.isEnabled = false
            changeTutorialText(text: "CHƯA HOÀN THÀNH")
        }
    }
    
    private func scrollToCurrentStep() {
        guard currentStepIndex >= 0, currentStepIndex < steps.count else {
            return
        }
        
        let currentStepStackView = horizontalStack.arrangedSubviews[currentStepIndex]
        scrollView.scrollRectToVisible(currentStepStackView.frame, animated: true)
    }
    
    private func handleStepSuccess() {
        if(loading) {
            return
        }
        
        if(detecting) {
            detecting = false
        }
        
        currentStepIndex += 1
        
        self.changeCircleColor(color: UIColor.green)
        
        loading = true
        
        if let capturedImage = captureImage() {
            for (index, labelView) in labelViews.enumerated() {
                if index == currentStepIndex - 1 {
                    labelView.isHidden = false
                }
            }
            
            for (index, imageView) in imageViews.enumerated() {
                if index == currentStepIndex - 1 {
                    imageView.image = capturedImage
                    scrollToCurrentStep()
                }
            }
            
            if(currentStepIndex < steps.count && !finished) {
                changeStep(step: steps[currentStepIndex])
                loading = false
            } else {
                finished = true
                currentStepIndex = steps.count
                toggleCheckInButton(on: true)
            }
        } else {
            print("Failed to capture image.")
        }
    }
    
    private func detectFacesOnDevice(in image: VisionImage, width: CGFloat, height: CGFloat) {
        let options = FaceDetectorOptions()
        
        options.landmarkMode = .all
        options.contourMode = .none
        options.classificationMode = .all
        options.performanceMode = .fast
        
        let faceDetector = FaceDetector.faceDetector(options: options)
        var faces: [Face] = []
        var detectionError: Error?
        
        do {
            faces = try faceDetector.results(in: image)
        } catch let error {
            detectionError = error
        }
        
        weak var weakSelf = self
        
        DispatchQueue.main.sync {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            strongSelf.updatePreviewOverlayViewWithLastFrame()
            
            if(currentStepIndex >= steps.count) {
                return
            }
            
            guard !faces.isEmpty else {
                self.changeCircleColor(color: UIColor(white: 1, alpha: 0))
                return
            }
            
            if currentFunctionType == .training {
                detectTraining(faces: faces)
            }
            
            if currentFunctionType == .checkIn {
                detectCheckIn(faces: faces)
            }
        }
    }
    
    private func isTurnLeft(face: Face) -> Bool {
        return face.headEulerAngleY <= detections.turnLeftHeadEulerAngleY!
    }
    
    private func isLookStraight(face: Face) -> Bool {
        let frame = face.frame
        
        let straightRange =
            Int(detections.lookStraight![0])...Int(detections.lookStraight![1])
        
        print("\(Int(frame.midX))")
        
        return straightRange.contains(Int(frame.midX)) && (0...20).contains(Int(face.headEulerAngleX))
    }
    
    private func isFaceInFrame(face: Face) -> FaceFrameState {
        let frame = face.frame
        
        let heightWidthRange = detections.height![0]...detections.height![1]
        
        let xRange = detections.top![0]...detections.top![1]
        let yRange = detections.left![0]...detections.left![1]
        
        let isValid =
            heightWidthRange.contains(Int(frame.height)) &&
            xRange.contains(Int(frame.origin.x)) &&
            yRange.contains(Int(frame.origin.y))
        
//        print("\(Int(frame.origin.x)) : \(Int(frame.origin.y))")
        
        if isValid {
            return .inFrame
        }
       
        if Int(frame.height) > detections.height![1] {
            return .tooClose
        }
        
        return .tooFar
    }
    
    private func detectTraining(faces: [Face]) {
        // TRAINING
        if(faces.count > 1) {
            self.changeTutorialText(text: "Quá nhiều người")
            self.changeCircleColor(color: UIColor.red)
            return
        }
        
        let face = faces.first
        
        let faceFrameState = isFaceInFrame(face: face!)
                
        if(faceFrameState == .inFrame) {
            if(isLookStraight(face: face!)) {
                self.changeCircleColor(color: UIColor.blue)
                
                if(currentStepIndex == -1) {
                    currentStepIndex+=1
                    changeStep(step: steps.first)
                } else {
                    changeTutorialText(text: currentStep?.description)
                    
                    if(
                        (currentStepIndex >= 0 && currentStepIndex < steps.count) &&
                        isFaceMatchCondition(stepID: steps[currentStepIndex].id, face: face)
                    ) {
                        handleStepSuccess()
                    }
                    
                }
            } else {
                self.changeTutorialText(text: "Vui lòng nhìn thẳng")
//                self.changeCircleColor(color: UIColor.red)
                self.changeCircleColor(color: UIColor(white: 1, alpha: 0))
            }
        }
        else if(faceFrameState == .tooClose) {
            self.changeTutorialText(text: "Mặt quá gần")
//            self.changeCircleColor(color: UIColor.red)
            self.changeCircleColor(color: UIColor(white: 1, alpha: 0))
        }
        else {
            self.changeTutorialText(text: "Di chuyển mặt vào gần khung tròn")
//            self.changeCircleColor(color: UIColor.orange)
            self.changeCircleColor(color: UIColor(white: 1, alpha: 0))
        }
    }
    
    private func detectCheckIn(faces: [Face]) {
        // CHECK IN
        var hasFace: Bool = false
        var lookStraight: Bool = true
        
        for face in faces {
            let faceFrameState = isFaceInFrame(face: face)
            
            if(faceFrameState == .inFrame) {
                if(isLookStraight(face: face)) {
                    hasFace = true
                    if(currentStepIndex == -1) {
                        currentStepIndex+=1
                        changeStep(step: steps.first)
                    } else {
                        changeTutorialText(text: currentStep?.description)
                        if(
                            (currentStepIndex >= 0 && currentStepIndex < steps.count) &&
                            isFaceMatchCondition(stepID: steps[currentStepIndex].id, face: face)
                        ) {
                            handleStepSuccess()
                            break
                        }
                        
                    }
                } else {
                    lookStraight = false
                }
                
                
            }
        }
        
        if hasFace {
            self.changeCircleColor(color: UIColor.blue)
        } 
        else if(!lookStraight) {
            self.changeTutorialText(text: "Vui lòng nhìn thẳng")
            self.changeCircleColor(color: UIColor(white: 1, alpha: 0))
        }
        else {
            self.changeTutorialText(text: "Di chuyển mặt vào gần khung tròn")
            self.changeCircleColor(color: UIColor(white: 1, alpha: 0))
        }
    }
    
    private func updatePreviewOverlayViewWithLastFrame() {
        guard let lastFrame = lastFrame,
              let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame)
        else {
            return
        }
        self.updatePreviewOverlayViewWithImageBuffer(imageBuffer)
        self.removeDetectionAnnotations()
    }
    
    private func removeDetectionAnnotations() {
        for annotationView in annotationOverlayView.subviews {
            annotationView.removeFromSuperview()
        }
    }
    
    private func updatePreviewOverlayViewWithImageBuffer(_ imageBuffer: CVImageBuffer?) {
        guard let imageBuffer = imageBuffer else {
            return
        }
        let orientation: UIImage.Orientation = isUsingFrontCamera ? .leftMirrored : .right
        let image = UIUtilities.createUIImage(from: imageBuffer, orientation: orientation)
        previewOverlayView.image = image
    }
    
    private func normalizedPoint(
        fromVisionPoint point: VisionPoint,
        width: CGFloat,
        height: CGFloat
    ) -> CGPoint {
        let cgPoint = CGPoint(x: point.x, y: point.y)
        var normalizedPoint = CGPoint(x: cgPoint.x / width, y: cgPoint.y / height)
        normalizedPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
        return normalizedPoint
    }
}

public enum FaceFrameState {
    case inFrame
    case tooClose
    case tooFar
    case notStraight
}

public enum Function {
    case training
    case checkIn
}

public enum Detector: String {
    case onDeviceFace = "Face Detection"
}

private enum Constant {
    static let alertControllerTitle = "Vision Detectors"
    static let alertControllerMessage = "Select a detector"
    static let cancelActionTitleText = "Cancel"
    static let videoDataOutputQueueLabel = "com.google.mlkit.visiondetector.VideoDataOutputQueue"
    static let sessionQueueLabel = "com.google.mlkit.visiondetector.SessionQueue"
    static let noResultsMessage = "No Results"
    static let localModelFile = (name: "bird", type: "tflite")
    static let labelConfidenceThreshold = 0.75
    static let smallDotRadius: CGFloat = 4.0
    static let lineWidth: CGFloat = 3.0
    static let originalScale: CGFloat = 1.0
    static let padding: CGFloat = 10.0
    static let resultsLabelHeight: CGFloat = 200.0
    static let resultsLabelLines = 5
    static let imageLabelResultFrameX = 0.4
    static let imageLabelResultFrameY = 0.1
    static let imageLabelResultFrameWidth = 0.5
    static let imageLabelResultFrameHeight = 0.8
    static let segmentationMaskAlpha: CGFloat = 0.5
}

struct Step {
    var id: String
    var description: String
}

struct Detections {
    var closeProbability: Double?
    var openProbability: Double?
    var smilingProbability: Double?
    var turnLeftHeadEulerAngleY: Double?
    var turnRightHeadEulerAngleY: Double?
    var lookUpHeadEulerAngleX: Double?
    var lookDownHeadEulerAngleX: Double?
    var lookStraight: [Double]?
    var height: [Int]?
    var width: [Int]?
    var top: [Int]?
    var left: [Int]?
}
