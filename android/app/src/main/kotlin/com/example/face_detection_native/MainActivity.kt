package com.example.face_detection_native

import android.content.Intent
import android.graphics.Bitmap
import android.util.Base64
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import androidx.annotation.NonNull
import com.example.face_detection_native.faceDetector.DemoActivity
import com.example.face_detection_native.faceDetector.OpenCameraOptions
import com.example.face_detection_native.faceDetector.StepData
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.Serializable
import java.util.HashMap

const val CHANNEL = "irhp/channel";

class MainActivity: FlutterActivity() {


  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)


    KotlinContextSingleton.setFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                    call, result ->


                if(call.method == "openCamera") {


                    val args = call.arguments as Map<*, *>?
                    val steps = (args?.get("steps") as List<Map<String, String>>)
                        .map { StepData(it["id"] ?: "", it["description"] ?: "") }
                        .toTypedArray()
                    val detections = args?.get("detections") as HashMap<String, Any>



//                    // Construct the OpenCameraOptions object
                    val options = OpenCameraOptions(steps, detections as HashMap<String, Object>)

                    val intent = Intent(this, DemoActivity::class.java)
                    intent.putExtra("options", options as Serializable)
                    startActivity(intent)

//                    result.success("Camera opened successfully")
        }
        else {
          result.notImplemented()
        }
    }
  }

}


object KotlinContextSingleton {

    private var flutterEngine: FlutterEngine? = null


    fun setFlutterEngine(engine: FlutterEngine) {
        flutterEngine = engine
    }

    fun sendDataToCrossPlatform(listImages: List<Bitmap>) {
        val base64Images = mutableListOf<String>()

        listImages.forEach { bitmap ->
            val byteArrayOutputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 100, byteArrayOutputStream)
            val byteArray = byteArrayOutputStream.toByteArray()
            val base64Image = Base64.encodeToString(byteArray, Base64.DEFAULT)
            base64Images.add(base64Image)
        }

        MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger!!, CHANNEL).invokeMethod("getListBase64", base64Images)
    }
}