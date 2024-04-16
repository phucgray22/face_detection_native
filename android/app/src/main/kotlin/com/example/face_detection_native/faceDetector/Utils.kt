package com.example.face_detection_native.faceDetector

import android.os.Handler
import android.os.Looper

object Utils {
    @JvmStatic
    fun delayFun(callback: () -> Unit, delayMillis: Int = 1000) {
        Handler(Looper.getMainLooper()).postDelayed(
            {
                callback()
            },
            delayMillis.toLong() // value in milliseconds
        )
    }
}