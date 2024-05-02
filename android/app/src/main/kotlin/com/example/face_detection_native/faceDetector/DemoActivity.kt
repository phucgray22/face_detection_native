package com.example.face_detection_native.faceDetector

import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.os.Bundle
import android.util.DisplayMetrics
import android.util.Log
import android.view.Gravity
import android.view.View
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.ImageCapture
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.view.children
import androidx.core.view.isVisible
import com.example.face_detection_native.KotlinContextSingleton
import com.example.face_detection_native.R
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import kotlinx.android.synthetic.main.activity_demo.checkInButton
import kotlinx.android.synthetic.main.activity_demo.circularOverlay
import kotlinx.android.synthetic.main.activity_demo.listImagesContainer
import kotlinx.android.synthetic.main.activity_demo.previewView
import kotlinx.android.synthetic.main.activity_demo.stepText
import kotlinx.android.synthetic.main.activity_demo.tsHeadEulerAngleX
import kotlinx.android.synthetic.main.activity_demo.tsHeadEulerAngleY
import kotlinx.android.synthetic.main.activity_demo.tsHeight
import kotlinx.android.synthetic.main.activity_demo.tsLeft
import kotlinx.android.synthetic.main.activity_demo.tsMidX
import kotlinx.android.synthetic.main.activity_demo.tsTop

class DemoActivity : AppCompatActivity(), View.OnClickListener {
    private lateinit var cameraManager: CameraManager
    private lateinit var circleProgress: GradientDrawable
    private lateinit var options: OpenCameraOptions
    private lateinit var horizontalScrollView: HorizontalScrollView

    private var smilingProbability: Double = 0.8
    private var openEyeProbability: Double = 0.9
    private var closeEyeProbability: Double = 0.1
    private var turnLeftHeadEulerAngleY: Double = 30.0
    private var turnRightHeadEulerAngleY: Double = -40.0
    private var lookUpHeadEulerAngleX: Double = 30.0;
    private var lookDownHeadEulerAngleX: Double = -15.0;
    private var lookStraightRange: ArrayList<Int> = arrayListOf(-20, 20)
    private var faceMidRange: ArrayList<Int> = arrayListOf(280, 350)
    private var faceSizeRange: ArrayList<Int> = arrayListOf(250, 360)
    private var faceTopRange: ArrayList<Int> = arrayListOf(130, 250)
    private var faceLeftRange: ArrayList<Int> = arrayListOf(0, 130)
    private var currentFunctionType: Function = Function.Training


    private var currentStepIndex: Int = -1
    private var currentStep: StepData? = null
    private var loading: Boolean = false
    private var finished: Boolean = false
    private var listImages: List<Bitmap> = mutableListOf()
    private var detecting: Boolean = false
    private var listStepIdSuccess: ArrayList<String> = arrayListOf()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Register UI File
        setContentView(R.layout.activity_demo)

        // Setup Camera
        createCameraManager()
        checkForPermission()

        options = intent.getSerializableExtra("options") as OpenCameraOptions

        when(options.function) {
            FUNCTION_TRAINING -> {
                currentFunctionType = Function.Training
            }
            FUNCTION_CHECK_IN -> {
                currentFunctionType = Function.CheckIn
            }
        }

        setupView()

        // load detections options
        loadDetectionOptions()
    }

    private fun setupView() {
        horizontalScrollView = findViewById(R.id.hScrollView)
        changeCameraSize()
        createImagesPlaceHolder()
        toggleCheckInButton(false)
    }

    private fun changeCameraSize() {
        val displayMetrics = DisplayMetrics()
        windowManager.defaultDisplay.getMetrics(displayMetrics)

//        val circleSize = minOf(displayMetrics.widthPixels * 0.95, MAX_CAMERA_SIZE).toInt()
        val circleSize = (displayMetrics.widthPixels * 0.9).toInt()

        // Update layout params for previewView
        val previewViewParams = previewView.layoutParams
        previewViewParams.width = circleSize
        previewViewParams.height = circleSize
        previewView.layoutParams = previewViewParams

        // Update layout params for circularOverlay
        val circularOverlayParams = circularOverlay.layoutParams
        circularOverlayParams.width = circleSize
        circularOverlayParams.height = circleSize
        circularOverlay.layoutParams = circularOverlayParams
    }

    private fun toggleCheckInButton(on: Boolean) {
        if(on) {
            checkInButton.setBackgroundColor(Color.BLUE)
            checkInButton.isEnabled = true
            stepText.text = DONE
        } else {
            checkInButton.setBackgroundColor(Color.GRAY)
            checkInButton.isEnabled = false

            if(finished) {
                stepText.text = NOT_DONE
            }
        }
    }

    private fun createImagesPlaceHolder() {
        for(i in 0 until options.steps.count()) {
            val step = options.steps[i]

            // Create a vertical LinearLayout for each step
            val stepLayout = LinearLayout(this)
            stepLayout.orientation = LinearLayout.VERTICAL

            val imageView = ImageView(this)

            val layoutParams = LinearLayout.LayoutParams(
                resources.getDimensionPixelSize(R.dimen.image_width),
                resources.getDimensionPixelSize(R.dimen.image_height)
            )

            imageView.layoutParams = layoutParams
            imageView.tag = options.steps[i].id
            imageView.isVisible = false

            imageView.setOnClickListener {
                onImagePressed(i)
            }

            //
            val textView = TextView(this)
            textView.text = step.description
            textView.gravity = Gravity.CENTER
//            textView.visibility = View.GONE
            textView.isVisible = false

            stepLayout.addView(imageView)
            stepLayout.addView(textView)

            listImagesContainer.addView(stepLayout)
        }
    }

    private fun onImagePressed(index: Int) {
        if(finished && !detecting) {
            detecting = true
            toggleCheckInButton(false)
            getImage(index)?.setImageBitmap(null)
            getImageText(index)?.setTextColor(Color.BLACK)
            currentStepIndex = index
            changeStep(options.steps.elementAt(index))
        }
    }

    private fun loadDetectionOptions() {
        val detections = options.detections

        detections.forEach { (key, value) ->
            when (key) {
                DETECTION_KEY_SMILING -> smilingProbability = value as Double
                DETECTION_KEY_OPEN_EYE -> openEyeProbability = value as Double
                DETECTION_KEY_CLOSE_EYE -> closeEyeProbability = value as Double
                DETECTION_KEY_TURN_LEFT -> turnLeftHeadEulerAngleY = value as Double
                DETECTION_KEY_TURN_RIGHT -> turnRightHeadEulerAngleY = value?.toString()?.toDouble()
                DETECTION_KEY_LOOK_UP -> lookUpHeadEulerAngleX = value as Double
                DETECTION_KEY_LOOK_DOWN -> lookDownHeadEulerAngleX = value as Double
                DETECTION_KEY_LOOK_STRAIGHT -> lookStraightRange = value as ArrayList<Int>
                DETECTION_KEY_FACE_MID -> faceMidRange = value as ArrayList<Int>
                DETECTION_KEY_FACE_SIZE -> faceSizeRange = value as ArrayList<Int>
                DETECTION_KEY_FACE_TOP -> faceTopRange = value as ArrayList<Int>
                DETECTION_KEY_FACE_LEFT -> faceLeftRange = value as ArrayList<Int>
                // Add more cases for other keys if needed
            }
        }

//        Log.d("debug123", "turnLeftHeadEulerAngleY: ${turnLeftHeadEulerAngleY}")
    }

    //
    private fun checkForPermission() {
        if (allPermissionsGranted()) {
            cameraManager.startCamera()
        } else {
            ActivityCompat.requestPermissions(
                this,
                REQUIRED_PERMISSIONS,
                REQUEST_CODE_PERMISSIONS
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<String>, grantResults:
        IntArray
    ) {
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            if (allPermissionsGranted()) {
                cameraManager.startCamera()
            } else {
                Toast.makeText(this, "Permissions not granted by the user.", Toast.LENGTH_SHORT)
                    .show()
                finish()
            }
        }
    }



    private fun changeCircleColor(color: Int = Color.BLUE) {
        val drawable = resources.getDrawable(R.drawable.circular_overlay) as LayerDrawable
        circleProgress = (drawable.findDrawableByLayerId(R.id.innerCircle) as GradientDrawable)!!
        circleProgress.setColor(color)
        circularOverlay.setImageDrawable(drawable)
    }

    private fun changeStep(step: StepData?) {
        currentStep = step
        stepText.text = step?.description
    }

    private fun handleStepSuccess() {
        if(loading) {
            return;
        }

        if(detecting) {
            detecting = false
        }

        loading = true
        currentStepIndex += 1

        takePhoto(
            currentIndex = currentStepIndex,
            callback = {
            loading = false

            if(currentStepIndex < options.steps.count() && !finished) {
                changeStep(options.steps[currentStepIndex])
            } else {
                finished = true
                currentStepIndex = options.steps.count()
                toggleCheckInButton(true)
            }

        })
    }

    private fun isLookStraight(face: Face): Boolean {
//        Log.d("debug123", "${face.boundingBox.exactCenterY().toInt()} in [${faceMidRange[0]} .. ${faceMidRange[1]}]")
//        Log.d("debug123", "${face.headEulerAngleX.toInt()} in [${lookStraightRange[0]} .. ${lookStraightRange[1]}]")

        return (face.boundingBox.exactCenterY().toInt() in faceMidRange[0]..faceMidRange[1]) &&
                (face.headEulerAngleX.toInt() in lookStraightRange[0]..lookStraightRange[1])
    }

    private fun getFaceFrameState(face: Face): FaceFrameState {
        val bouncingBox = face.boundingBox

//        Log.d("debug123", "${bouncingBox.height().toString()} : ${bouncingBox.top} : ${bouncingBox.left}")

        val isValid =
            bouncingBox.height() in faceSizeRange[0]..faceSizeRange[1] &&
            bouncingBox.top in faceTopRange[0]..faceTopRange[1] &&
            bouncingBox.left in faceLeftRange[0]..faceLeftRange[1]

        if(isValid) {
            return FaceFrameState.InFrame
        }

        if(bouncingBox.height() > faceSizeRange[1]) {
            return FaceFrameState.TooClose
        }

        return FaceFrameState.TooFar
    }

    private fun updateConfigValue(face: Face) {
        tsMidX.text = "boundingBox.exactCenterY: ${face.boundingBox.exactCenterY()}"
        tsHeight.text = "bouncingBox.height: ${face.boundingBox.height()}"
        tsLeft.text = "bouncingBox.left: ${face.boundingBox.left}"
        tsTop.text = "bouncingBox.top: ${face.boundingBox.top}"
        tsHeadEulerAngleX.text = "headEulerAngleX: ${face.headEulerAngleX}"
        tsHeadEulerAngleY.text = "headEulerAngleY: ${face.headEulerAngleY}"
    }

    private fun detectTraining(faces: List<Face>) {
        if(faces.isEmpty() || currentStepIndex >= options.steps.count()) {
            changeCircleColor(Color.TRANSPARENT)
            return
        }

        if(faces.count() > 1) {
            stepText.text = SO_MANY_PEOPLE
            changeCircleColor(Color.RED)
            return
        }

        val face = faces.first()

        updateConfigValue(face)


        when (getFaceFrameState(face)) {
            FaceFrameState.InFrame -> {

                if(isLookStraight(face)) {
                    changeCircleColor()

                    if(currentStepIndex == -1) {
                        currentStepIndex++

                        Utils.delayFun(
                            {
                                changeStep(options.steps.first())

                            }, 700
                        )
                    } else {
                        if(stepText.text != currentStep?.description) {
                            stepText.text = currentStep?.description
                        }

                        if((currentStepIndex >= 0 && currentStepIndex < options.steps.count()) && isFaceMatchCondition(options.steps[currentStepIndex]?.id, face)) {
                            handleStepSuccess()
                        }
                    }
                }
                else {
                    stepText.text = PLEASE_LOOK_STRAIGHT
                    changeCircleColor(Color.TRANSPARENT)
                }


            }

            FaceFrameState.TooFar -> {
                stepText.text = TOO_FAR
                changeCircleColor(Color.TRANSPARENT)
            }

            FaceFrameState.TooClose -> {
                stepText.text = TOO_CLOSE
                changeCircleColor(Color.TRANSPARENT)
            }
        }
    }

    private fun detectCheckIn(faces: List<Face>) {
        var hasFace = false

        if(faces.isNotEmpty()) {
            updateConfigValue(faces.first())
        }

        for(face in faces) {
            when (getFaceFrameState(face)) {
                FaceFrameState.InFrame -> {
                    if(isLookStraight(face)) {
                        hasFace = true

                        if(currentStepIndex == -1) {
                            currentStepIndex++

                            Utils.delayFun(
                                {
                                    changeStep(options.steps.first())

                                }, 700
                            )
                        } else {
                            if(stepText.text != currentStep?.description) {
                                stepText.text = currentStep?.description
                            }

                            if((currentStepIndex >= 0 && currentStepIndex < options.steps.count()) && isFaceMatchCondition(options.steps[currentStepIndex]?.id, face)) {
                                handleStepSuccess()
                            }
                        }
                    }
                }
            }
        }

        if(hasFace) {
            changeCircleColor()
        } else {
            stepText.text = TOO_FAR
            changeCircleColor(Color.TRANSPARENT)
        }
    }

    private fun onDetected(faces: List<Face>) {
        when(currentFunctionType) {
            Function.Training -> {
                detectTraining(faces)
            }
            Function.CheckIn -> {
                detectCheckIn(faces)
            }
        }

    }



    private fun isFaceMatchCondition(stepID: String, face: Face?): Boolean {
        if(face == null) return false

//        Log.d("debug123", "${face.headEulerAngleY} >= ${turnLeftHeadEulerAngleY}")

        val isMatched = when(stepID) {
            STEP_ID_TURN_LEFT -> {
                face.headEulerAngleY >= turnLeftHeadEulerAngleY
            }

            STEP_ID_TURN_RIGHT -> {
                face.headEulerAngleY <= turnRightHeadEulerAngleY
            }

            STEP_ID_LOOK_UP -> {
                face.headEulerAngleX >= lookUpHeadEulerAngleX
            }

            STEP_ID_LOOK_DOWN -> {
                face.headEulerAngleX >= lookDownHeadEulerAngleX
            }

            STEP_ID_SMILE -> {
                face.smilingProbability != null && face.smilingProbability!! >= smilingProbability
            }

            STEP_ID_LEFT_EYE -> {
                face.rightEyeOpenProbability != null &&
                face.rightEyeOpenProbability!! <= closeEyeProbability &&
                face.leftEyeOpenProbability != null &&
                face.leftEyeOpenProbability!! >= openEyeProbability &&
                face.headEulerAngleY < turnLeftHeadEulerAngleY &&
                face.headEulerAngleY > turnRightHeadEulerAngleY
            }

            STEP_ID_RIGHT_EYE -> {
                face.leftEyeOpenProbability != null &&
                face.leftEyeOpenProbability!! <= closeEyeProbability &&
                face.rightEyeOpenProbability != null &&
                face.rightEyeOpenProbability!! >= openEyeProbability &&
                face.headEulerAngleY < turnLeftHeadEulerAngleY &&
                face.headEulerAngleY > turnRightHeadEulerAngleY
            }

            else -> {
                false
            }
        }

        return isMatched
    }

    private var _imageCapture: ImageCapture? = null

    private fun setImageCapture(imageCapture: ImageCapture?) {
        _imageCapture = imageCapture;
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun takePhoto(currentIndex: Int, callback: () -> Unit) {
        val currentBitmap = previewView.bitmap

        val imageView = getImage(currentIndex - 1)

        imageView?.setImageBitmap(currentBitmap)

        imageView?.isVisible = true

        if(finished) {
            //
        } else {
            // Scroll to current image step
            horizontalScrollView.post { horizontalScrollView.fullScroll(View.FOCUS_RIGHT) }
        }

        val currentStep = options?.steps?.elementAt(currentIndex - 1)

        val imageText = getImageText(currentIndex - 1)

        imageText?.isVisible = true
        imageText?.setTextColor(Color.BLUE)

        listImages = listImages.plus(currentBitmap!!)

        if(!listStepIdSuccess.contains(currentStep?.id)) {
            listStepIdSuccess.add(currentStep?.id  )
        }

        callback()
    }

    private fun getImage(index: Int): ImageView? {
        if(index < listImagesContainer.childCount) {
            val column = listImagesContainer.children.elementAt(index) as LinearLayout?
            return column?.children?.elementAt(0) as ImageView?
        }

        return null
    }

    private fun getImageText(index: Int): TextView? {
        if(index < listImagesContainer.childCount) {
            val column = listImagesContainer.children.elementAt(index) as LinearLayout?
            return column?.children?.elementAt(1) as TextView?
        }
        return null
    }

    private fun createCameraManager() {
        cameraManager = CameraManager(
            context = this,
            finderView =  previewView,
            lifecycleOwner = this,
            onDetected = ::onDetected,
            setImageCapture = ::setImageCapture,
        )
    }

    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(baseContext, it) == PackageManager.PERMISSION_GRANTED
    }

    private val detector = FaceDetection.getClient(FaceDetectorOptions.Builder()
        .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
        .setContourMode(FaceDetectorOptions.CONTOUR_MODE_NONE)
        .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
        .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_NONE)
        .build())

    private fun countFace(image: InputImage, callback: (Int, Face?) -> Unit) {
        detector.process(image)
            .addOnSuccessListener { faces ->
                Log.d("debug123", "success: ${faces.count()}")

                if(faces?.isEmpty() == false && faces?.count() == 1) {
                    callback(faces.count(), faces[0])
                } else {
                    callback(0, null)
                }

//                detector.close()

            }
            .addOnFailureListener { e ->
                Log.d("debug123", e.message!!)
                callback(0, null)
//                detector.close()

            }


    }

    override fun onClick(v: View?) {
        when(v?.id) {
            R.id.checkInButton -> {
                KotlinContextSingleton.sendDataToCrossPlatform(listImages)
                detector?.close()
                onBackPressed()
            }
            else -> {

            }
        }
    }

    companion object {
        private const val MAX_CAMERA_SIZE = 600.0

        private const val REQUEST_CODE_PERMISSIONS = 10

        private val REQUIRED_PERMISSIONS = arrayOf(
            android.Manifest.permission.CAMERA
        )

        //

        private const val DETECTION_KEY_SMILING = "smilingProbability"
        private const val DETECTION_KEY_OPEN_EYE = "openEyeProbability"
        private const val DETECTION_KEY_CLOSE_EYE = "smilingProbability"
        private const val DETECTION_KEY_TURN_LEFT = "turnLeft"
        private const val DETECTION_KEY_TURN_RIGHT = "turnRight"
        private const val DETECTION_KEY_LOOK_UP = "lookUp"
        private const val DETECTION_KEY_LOOK_DOWN = "lookDown"
        private const val DETECTION_KEY_LOOK_STRAIGHT = "lookStraightRange"
        private const val DETECTION_KEY_FACE_MID = "faceMidRange"
        private const val DETECTION_KEY_FACE_SIZE = "faceSizeRange"
        private const val DETECTION_KEY_FACE_TOP = "faceTopRange"
        private const val DETECTION_KEY_FACE_LEFT = "faceLeftRange"

        private const val STEP_ID_TURN_LEFT = "turnLeft"
        private const val STEP_ID_TURN_RIGHT = "turnRight"
        private const val STEP_ID_LOOK_UP = "lookUp"
        private const val STEP_ID_LOOK_DOWN = "lookDown"
        private const val STEP_ID_SMILE = "smile"
        private const val STEP_ID_LEFT_EYE = "closeLeftEye"
        private const val STEP_ID_RIGHT_EYE = "closeRightEye"

        //

        private const val SO_MANY_PEOPLE = "Quá nhiều người"
        private const val PLEASE_LOOK_STRAIGHT = "Vui lòng nhìn thẳng"
        private const val TOO_CLOSE = "Mặt quá gần"
        private const val TOO_FAR = "Di chuyển mặt vào gần camera"
        private const val DONE = "Xong"
        private const val NOT_DONE = "Chưa hoàn thành"

        //
        private const val FUNCTION_TRAINING = "training"
        private const val FUNCTION_CHECK_IN = "checkIn"
    }

    enum class FaceFrameState {
        InFrame,
        TooClose,
        TooFar,
    }

    enum class Function {
        Training,
        CheckIn
    }


}
