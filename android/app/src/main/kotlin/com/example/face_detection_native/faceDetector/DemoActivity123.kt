//package com.example.face_detection_native.faceDetector
//
//import android.R.attr.height
//import android.R.attr.width
//import android.annotation.SuppressLint
//import android.content.pm.PackageManager
//import android.graphics.Bitmap
//import android.graphics.BitmapFactory
//import android.graphics.Color
//import android.graphics.ImageDecoder
//import android.graphics.ImageFormat
//import android.graphics.Rect
//import android.graphics.YuvImage
//import android.graphics.drawable.GradientDrawable
//import android.graphics.drawable.LayerDrawable
//import android.os.Bundle
//import android.util.DisplayMetrics
//import android.util.Log
//import android.view.Gravity
//import android.view.View
//import android.widget.HorizontalScrollView
//import android.widget.ImageView
//import android.widget.LinearLayout
//import android.widget.TextView
//import android.widget.Toast
//import androidx.appcompat.app.AppCompatActivity
//import androidx.camera.core.ImageCapture
//import androidx.camera.core.ImageProxy
//import androidx.core.app.ActivityCompat
//import androidx.core.content.ContextCompat
//import androidx.core.view.children
//import androidx.core.view.isVisible
//import com.example.face_detection_native.KotlinContextSingleton
//import com.example.face_detection_native.R
//import com.google.mlkit.vision.common.InputImage
//import com.google.mlkit.vision.face.Face
//import com.google.mlkit.vision.face.FaceDetection
//import com.google.mlkit.vision.face.FaceDetectorOptions
//import kotlinx.android.synthetic.main.activity_demo.checkInButton
//import kotlinx.android.synthetic.main.activity_demo.circularOverlay
//import kotlinx.android.synthetic.main.activity_demo.listImagesContainer
//import kotlinx.android.synthetic.main.activity_demo.previewView
//import kotlinx.android.synthetic.main.activity_demo.stepText
//import java.io.ByteArrayOutputStream
//import java.nio.ByteBuffer
//
//
//class DemoActivity : AppCompatActivity(), View.OnClickListener {
//    private lateinit var cameraManager: CameraManager
//    private lateinit var circleProgress: GradientDrawable
//    private lateinit var options: OpenCameraOptions
//    private lateinit var horizontalScrollView: HorizontalScrollView
//
//    private var smilingProbability: Double = 0.7
//    private var turnLeftHeadEulerAngleY: Double = 30.0
//    private var turnRightHeadEulerAngleY: Double = -40.0
//    private var closeEyeProbability: Double = 0.05
//    private var openEyeProbability: Double = 0.05
//    private var faceHeightRange: ArrayList<Int> = arrayListOf(150, 400)
//    private var faceWidthRange: ArrayList<Int> = arrayListOf(150, 400)
//    private var faceTopRange: ArrayList<Int> = arrayListOf(100, 290)
//    private var faceLeftRange: ArrayList<Int> = arrayListOf(10, 220)
//
//    private var currentStepIndex: Int = -1
//    private var currentStep: StepData? = null
//    private var loading: Boolean = false
//    private var finished: Boolean = false
//    private var listImages: List<Bitmap> = mutableListOf()
//    private var detecting: Boolean = false
//    private var listStepIdSuccess: ArrayList<String> = arrayListOf()
//    private var currentBitmap: Bitmap? = null
//
//    override fun onCreate(savedInstanceState: Bundle?) {
//        super.onCreate(savedInstanceState)
//        // Register UI File
//        setContentView(R.layout.activity_demo)
//
//        // Setup Camera
//        createCameraManager()
//        checkForPermission()
//
//        options = intent.getSerializableExtra("options") as OpenCameraOptions
//        horizontalScrollView = findViewById(R.id.hScrollView)
//
//
//        setupView()
//
//        // load detections options
//        loadDetectionOptions()
//    }
//
//    private fun setupView() {
//        //
//        changeCameraSize()
//
//        // create list images placeholder (to load later)
//        createImagesPlaceHolder()
//
//        //
//        toggleCheckInButton(false)
//    }
//
//    private fun changeCameraSize() {
//        val displayMetrics = DisplayMetrics()
//        windowManager.defaultDisplay.getMetrics(displayMetrics)
//        val circleSize = minOf(displayMetrics.widthPixels * 0.95, MAX_CAMERA_SIZE).toInt()
//
//
//        // Update layout params for previewView
//        val previewViewParams = previewView.layoutParams
//        previewViewParams.width = circleSize
//        previewViewParams.height = circleSize
//        previewView.layoutParams = previewViewParams
//
//        // Update layout params for circularOverlay
//        val circularOverlayParams = circularOverlay.layoutParams
//        circularOverlayParams.width = circleSize
//        circularOverlayParams.height = circleSize
//        circularOverlay.layoutParams = circularOverlayParams
//    }
//
//    private fun toggleCheckInButton(on: Boolean) {
//        if(on) {
//            checkInButton.setBackgroundColor(Color.BLUE)
//            checkInButton.isEnabled = true
//            stepText.text = "XONG"
//        } else {
//            checkInButton.setBackgroundColor(Color.GRAY)
//            checkInButton.isEnabled = false
//
//            if(finished) {
//                stepText.text = "CHƯA HOÀN THÀNH"
//            }
//        }
//    }
//
//    private fun createImagesPlaceHolder() {
//        for(i in 0 until options.steps.count()) {
//            val step = options.steps[i]
//
//            // Create a vertical LinearLayout for each step
//            val stepLayout = LinearLayout(this)
//            stepLayout.orientation = LinearLayout.VERTICAL
//
//            val imageView = ImageView(this)
//
//            val layoutParams = LinearLayout.LayoutParams(
//                resources.getDimensionPixelSize(R.dimen.image_width),
//                resources.getDimensionPixelSize(R.dimen.image_height)
//            )
//
//            imageView.layoutParams = layoutParams
//
//            imageView.tag = options.steps[i].id
//            imageView.isVisible = false
//
//            imageView.setOnClickListener {
//                onImagePressed(i)
//            }
//
//
//            //
//            val textView = TextView(this)
//            textView.text = step.description
//            textView.gravity = Gravity.CENTER
//            textView.visibility = View.GONE
//
//            stepLayout.addView(imageView)
//            stepLayout.addView(textView)
//
//            listImagesContainer.addView(stepLayout)
//        }
//    }
//
//    private fun onImagePressed(index: Int) {
//        if(finished && !detecting) {
//            detecting = true
//            toggleCheckInButton(false)
//            getImage(index)?.setImageBitmap(null)
//            getImageText(index)?.setTextColor(Color.BLACK)
//            currentStepIndex = index
//            changeStep(options.steps.elementAt(index))
//        }
//    }
//
//    private fun loadDetectionOptions() {
//        var detections = options.detections
//
//        if(detections.containsKey("smiling")) {
//            val obj = detections["smiling"] as HashMap<String, Object>
//
//            if(obj.containsKey("smilingProbability")) {
//                smilingProbability = obj["smilingProbability"].toString()?.toDouble()
//            }
//        }
//
//        if(detections.containsKey("turnLeft")) {
//            val obj = detections["turnLeft"] as HashMap<String, Object>
//
//            if(obj.containsKey("headEulerAngleY")) {
//                turnLeftHeadEulerAngleY = obj["headEulerAngleY"].toString()?.toDouble()
//            }
//        }
//
//        if(detections.containsKey("turnRight")) {
//            val obj = detections["turnRight"] as HashMap<String, Object>
//
//            if(obj.containsKey("headEulerAngleY")) {
//                turnRightHeadEulerAngleY = obj["headEulerAngleY"].toString()?.toDouble()
//            }
//        }
//
//        if(detections.containsKey("closeLeftEye")) {
//            val obj = detections["closeLeftEye"] as HashMap<String, Object>
//
//            if(obj.containsKey("closeProbability")) {
//                closeEyeProbability = obj["closeProbability"].toString()?.toDouble()
//            }
//
//            if(obj.containsKey("openProbability")) {
//                openEyeProbability = obj["openProbability"].toString()?.toDouble()
//            }
//        }
//
//        if(detections.containsKey("faceInCamera")) {
//            val obj = detections["faceInCamera"] as HashMap<String, Object>
//
//            if(obj.containsKey("height")) {
//                var height = obj["height"] as ArrayList<Int>
//
//                if(height.count() == 2) {
//                    faceHeightRange = height
//                }
//            }
//
//            if(obj.containsKey("width")) {
//                var width = obj["width"] as ArrayList<Int>
//
//                if(width.count() == 2) {
//                    faceWidthRange = width
//                }
//            }
//
//            if(obj.containsKey("top")) {
//                var top = obj["top"] as ArrayList<Int>
//
//                if(top.count() == 2) {
//                    faceTopRange = top
//                }
//            }
//
//            if(obj.containsKey("left")) {
//                var left = obj["left"] as ArrayList<Int>
//
//                if(left.count() == 2) {
//                    faceLeftRange = left
//                }
//            }
//        }
//    }
//
//    //
//    private fun checkForPermission() {
//        if (allPermissionsGranted()) {
//            cameraManager.startCamera()
//        } else {
//            ActivityCompat.requestPermissions(
//                this,
//                REQUIRED_PERMISSIONS,
//                REQUEST_CODE_PERMISSIONS
//            )
//        }
//    }
//
//    override fun onRequestPermissionsResult(
//        requestCode: Int, permissions: Array<String>, grantResults:
//        IntArray
//    ) {
//        if (requestCode == REQUEST_CODE_PERMISSIONS) {
//            if (allPermissionsGranted()) {
//                cameraManager.startCamera()
//            } else {
//                Toast.makeText(this, "Permissions not granted by the user.", Toast.LENGTH_SHORT)
//                    .show()
//                finish()
//            }
//        }
//    }
//
//
//
//    private fun changeCircleColor(color: Int = Color.BLUE) {
//        val drawable = resources.getDrawable(R.drawable.circular_overlay) as LayerDrawable
//        circleProgress = (drawable.findDrawableByLayerId(R.id.innerCircle) as GradientDrawable)!!
//        circleProgress.setColor(color)
//        circularOverlay.setImageDrawable(drawable)
//    }
//
//    private fun changeStep(step: StepData?) {
//        currentStep = step
//        stepText.text = step?.description
//    }
//
//    private fun handleStepSuccess() {
//        if(loading) {
//            return;
//        }
//
//        if(detecting) {
//            detecting = false
//        }
//
//        loading = true
//        currentStepIndex += 1
//
//        takePhoto(
//            currentIndex = currentStepIndex,
//            callback = {
//            loading = false
//
//            if(currentStepIndex < options.steps.count() && !finished) {
//                changeStep(options.steps[currentStepIndex])
//            } else {
//                finished = true
//                currentStepIndex = options.steps.count()
//                toggleCheckInButton(true)
//            }
//
//        })
//    }
//
//    private fun onDetected(faces: List<Face>, imageProxy: ImageProxy) {
//
//        if(faces.isEmpty() || currentStepIndex >= options.steps.count()) {
//            changeCircleColor(Color.TRANSPARENT)
//            return;
//        }
//
//        if(faces.count() > 1) {
//            stepText.text = "Quá nhiều người"
//            changeCircleColor(Color.RED)
//            return;
//        }
//
//        val face = faces.first()
//        val bouncingBox = face.boundingBox
//
//        if(
//            bouncingBox.height() in faceHeightRange[0]..faceHeightRange[1] &&
//            bouncingBox.width() in faceWidthRange[0]..faceWidthRange[1] &&
//            bouncingBox.top in faceTopRange[0]..faceTopRange[1] &&
//            bouncingBox.left in faceLeftRange[0]..faceLeftRange[1]
//            ) {
//            if(!loading) {
//                changeCircleColor()
//            }
//
//            if(currentStepIndex == -1) {
//                currentStepIndex++
//
//                Utils.delayFun(
//                    {
//                        changeStep(options.steps.first())
//
//                    }, 700
//                )
//            } else {
//                if(stepText.text != currentStep?.description) {
//                    stepText.text = currentStep?.description
//                }
//
//                if(!loading) {
//
//                }
//
//
//
//                if((currentStepIndex >= 0 && currentStepIndex < options.steps.count()) && isFaceMatchCondition(options.steps[currentStepIndex]?.id, face, imageProxy)) {
//                    handleStepSuccess()
//                } else {
////                    currentStepIndex--
//                }
//            }
//
//        } else {
//            if(!loading) {
//                stepText.text = "Di chuyển mặt vào gần camera"
//                changeCircleColor(Color.TRANSPARENT)
//            }
//        }
//    }
//
//
//
//    private fun isFaceMatchCondition(stepID: String, face: Face?, imageProxy: ImageProxy): Boolean {
//        if(face == null) return false
//
//        val isMatched = when(stepID) {
//            "turnLeft" -> {
//                face.headEulerAngleY >= turnLeftHeadEulerAngleY
//            }
//
//            "turnRight" -> {
//                face.headEulerAngleY <= turnRightHeadEulerAngleY
//            }
//
//            "smile" -> {
//                face.smilingProbability != null && face.smilingProbability!! >= smilingProbability
//            }
//
//            "closeLeftEye" -> {
//                face.rightEyeOpenProbability != null &&
//                face.rightEyeOpenProbability!! <= closeEyeProbability &&
//                face.leftEyeOpenProbability != null &&
//                face.leftEyeOpenProbability!! >= openEyeProbability &&
//                face.headEulerAngleY < turnLeftHeadEulerAngleY &&
//                face.headEulerAngleY > turnRightHeadEulerAngleY
//            }
//
//            "closeRightEye" -> {
//                face.leftEyeOpenProbability != null &&
//                face.leftEyeOpenProbability!! <= closeEyeProbability &&
//                face.rightEyeOpenProbability != null &&
//                face.rightEyeOpenProbability!! >= openEyeProbability &&
//                face.headEulerAngleY < turnLeftHeadEulerAngleY &&
//                face.headEulerAngleY > turnRightHeadEulerAngleY
//            }
//
//            else -> {
//                false
//            }
//        }
//
//        if(isMatched) {
//
//        }
//
//        return isMatched
//    }
//
//    private var _imageCapture: ImageCapture? = null
//
//    private fun setImageCapture(imageCapture: ImageCapture?) {
//        _imageCapture = imageCapture;
//    }
//
//    @SuppressLint("UnsafeOptInUsageError")
//    private fun takePhoto(currentIndex: Int, callback: () -> Unit) {
//        var currentBitmap = previewView.bitmap
////        var currentBitmap = previewView.getDrawingCache(true).copy(Bitmap.Config.ALPHA_8, false)
//
//        val imageView = getImage(currentIndex - 1)
//
//        imageView?.setImageBitmap(currentBitmap)
//
//        imageView?.isVisible = true
//
//        if(finished) {
//            //
//        } else {
//            horizontalScrollView.post { horizontalScrollView.fullScroll(View.FOCUS_RIGHT) }
//        }
//
//        //
//        var currentStep = options?.steps?.elementAt(currentIndex - 1)
//
//
//        var imageText = getImageText(currentIndex - 1)
//
//        imageText?.visibility = View.VISIBLE
//        imageText?.setTextColor(Color.BLUE)
//
//        listImages = listImages.plus(currentBitmap!!)
//
//        if(!listStepIdSuccess.contains(currentStep?.id)) {
//            listStepIdSuccess.add(currentStep?.id  )
//        }
//
////        InputImage.fromBitmap(currentBitmap, frame?.imageInfo?.rotationDegrees!!)
////        InputImage.fromMediaImage(frame.image!!, frame?.imageInfo?.rotationDegrees!!)
////        val byteBuffer = frame.image!!.planes[0].buffer
////
////        val byteArray = ByteArray(byteBuffer.remaining())
//
////        frame.image.
////      ctory.decodeByteArray(byteArray, 0, byteArray.size)
//
//        // Step 2: Create Image from Bitmap
////        val image = ImageDecoder.createSource(bitmap).decodeBitmap()
////        byteBuffer.get(byteArray)
////        val bitmap = BitmapFa
////        val image123 = InputImage.fromByteArray(byteArray, frame.image?.width!!, frame.image?.height!!, frame?.imageInfo?.rotationDegrees!!, InputImage.IMAGE_FORMAT_NV21)
//
//
//
////        countFace(InputImage.fromMediaImage(frame.image!!,frame?.imageInfo?.rotationDegrees!! )) { faceCount, face ->
////            var currentStep = options?.steps?.elementAt(currentIndex - 1)
////
////            imageText?.visibility = View.VISIBLE
////
////            if(faceCount == 1 && isFaceMatchCondition(currentStep.id, face)) {
////                getImageText(currentIndex - 1)?.setTextColor(Color.BLUE)
////
////                if(!listStepIdSuccess.contains(currentStep?.id)) {
////                    listStepIdSuccess.add(currentStep?.id  )
////                }
////
////                if(listStepIdSuccess?.count() == options?.steps?.count() && finished) {
////                    toggleCheckInButton(true)
////                }
////
////            } else {
////                if(listStepIdSuccess.contains(currentStep?.id)) {
////                    listStepIdSuccess.remove(currentStep?.id)
////                }
////
////                toggleCheckInButton(false)
////
////                val snackBar = Snackbar.make(
////                    findViewById(android.R.id.content), // Pass the root view of your layout
////                    "Ảnh ${"${currentStep?.description}"} không hợp lê",
////                    Snackbar.LENGTH_SHORT
////                )
////
////                imageText?.setTextColor(Color.RED)
////
////                snackBar.view.setBackgroundColor(Color.rgb(255,102,102))
////                snackBar.setTextColor(Color.rgb(102,0,0))
////
////                snackBar.show()
////            }
////
////
////        }
//
//        callback()
//
////        val imageCapture = _imageCapture ?: return
////
////        imageCapture.takePicture(ContextCompat.getMainExecutor(this), object : ImageCapture.OnImageCapturedCallback() {
////            override fun onCaptureSuccess(image: ImageProxy) {
////                val buffer = image.planes[0].buffer
////                val imageData = ByteArray(buffer.remaining())
////                buffer.get(imageData)
////
////                val bitmap = BitmapFactory.decodeByteArray(imageData, 0, imageData.size)
////
////                val imageView = getImage(currentIndex - 1)
////
////                imageView?.setImageBitmap(bitmap)
////
////                imageView?.isVisible = true
////
////                if(finished) {
////                    //
////                } else {
////                    horizontalScrollView.post { horizontalScrollView.fullScroll(View.FOCUS_RIGHT) }
////                }
////
////
////                countFace(InputImage.fromBitmap(bitmap, image.imageInfo.rotationDegrees)) { faceCount, face ->
////                    var currentStep = options?.steps?.elementAt(currentIndex - 1)
////
////                    var imageText = getImageText(currentStepIndex - 1)
////
////                    imageText?.visibility = View.VISIBLE
////
////                    if(faceCount == 1 && isFaceMatchCondition(currentStep.id, face)) {
////                        getImageText(currentIndex - 1)?.setTextColor(Color.BLUE)
////                        listImages = listImages.plus(bitmap)
////
////                        if(!listStepIdSuccess.contains(currentStep?.id)) {
////                            listStepIdSuccess.add(currentStep?.id  )
////                        }
////
////                        if(listStepIdSuccess?.count() == options?.steps?.count() && finished) {
////                            toggleCheckInButton(true)
////                        }
////
////                    } else {
////                        if(listStepIdSuccess.contains(currentStep?.id)) {
////                            listStepIdSuccess.remove(currentStep?.id)
////                        }
////
////                        toggleCheckInButton(false)
////
////                        val snackBar = Snackbar.make(
////                            findViewById(android.R.id.content), // Pass the root view of your layout
////                            "Ảnh ${"${currentStep?.description}"} không hợp lê",
////                            Snackbar.LENGTH_SHORT
////                        )
////
////                        getImageText(options?.steps?.indexOf(currentStep))?.setTextColor(Color.RED)
////
//////                        if(finished) {
//////                            getImageText(options?.steps?.indexOf(currentStep))?.setTextColor(Color.RED)
//////                        } else {
//////                            getImageText(options?.steps?.indexOf(currentStep))?.setTextColor(Color.RED)
//////                        }
////
////                        snackBar.view.setBackgroundColor(Color.rgb(255,102,102))
////                        snackBar.setTextColor(Color.rgb(102,0,0))
////
////                        snackBar.show()
////                    }
////
////
////                }
////
////                callback()
////
////                image.close()
////            }
////
////            override fun onError(exception: ImageCaptureException) {
////                Log.e("debug123", "Error capturing image: ${exception.message}", exception)
////            }
////        })
//    }
//
//    private fun getImage(index: Int): ImageView? {
//        if(index < listImagesContainer.childCount) {
//            val column = listImagesContainer.children.elementAt(index) as LinearLayout?
//            return column?.children?.elementAt(0) as ImageView?
//        }
//
//        return null
//    }
//
//    private fun getImageText(index: Int): TextView? {
//        if(index < listImagesContainer.childCount) {
//            val column = listImagesContainer.children.elementAt(index) as LinearLayout?
//            return column?.children?.elementAt(1) as TextView?
//        }
//        return null
//    }
//
//    private fun createCameraManager() {
//        cameraManager = CameraManager(
//            context = this,
//            finderView =  previewView,
//            lifecycleOwner = this,
////            graphicOverlay =  graphicOverlay,
//            onDetected = ::onDetected,
//            setImageCapture = ::setImageCapture,
////            getFrame = ::getFrame
//        )
//
////        cameraManager.preview.setPreviewCallback(imageView)
////        cameraManager.
//    }
//
//    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
//        ContextCompat.checkSelfPermission(baseContext, it) == PackageManager.PERMISSION_GRANTED
//    }
//
//    companion object {
//        private const val MAX_CAMERA_SIZE = 600.0
//
//        private const val REQUEST_CODE_PERMISSIONS = 10
//
//        private val REQUIRED_PERMISSIONS = arrayOf(
//            android.Manifest.permission.CAMERA
//            )
//    }
//
//    private val detector = FaceDetection.getClient(FaceDetectorOptions.Builder()
//        .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
//        .setContourMode(FaceDetectorOptions.CONTOUR_MODE_NONE)
//        .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
//        .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_NONE)
//        .build())
//
//    private fun countFace(image: InputImage, callback: (Int, Face?) -> Unit) {
//        detector.process(image)
//            .addOnSuccessListener { faces ->
//                Log.d("debug123", "success: ${faces.count()}")
//
//                if(faces?.isEmpty() == false && faces?.count() == 1) {
//                    callback(faces.count(), faces[0])
//                } else {
//                    callback(0, null)
//                }
//
////                detector.close()
//
//            }
//            .addOnFailureListener { e ->
//                Log.d("debug123", e.message!!)
//                callback(0, null)
////                detector.close()
//
//            }
//
//
//    }
//
//    override fun onClick(v: View?) {
//        when(v?.id) {
//            R.id.checkInButton -> {
//                KotlinContextSingleton.sendDataToCrossPlatform(listImages)
//                detector?.close()
//                onBackPressed()
//            }
//            else -> {
//
//            }
//        }
//    }
//}