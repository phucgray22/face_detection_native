package com.example.face_detection_native.faceDetector

import java.io.Serializable
import java.util.HashMap

data class StepData(val id: String, val description: String): Serializable
data class OpenCameraOptions(val steps: Array<StepData>, val detections: HashMap<String, Object>): Serializable {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as OpenCameraOptions

        if (!steps.contentEquals(other.steps)) return false

        return true
    }

    override fun hashCode(): Int {
        return steps.contentHashCode()
    }
}