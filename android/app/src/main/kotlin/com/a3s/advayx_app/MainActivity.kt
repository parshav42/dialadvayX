package com.a3s.advayx_app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "advayx.recorder"
    private val EVENT_CHANNEL = "advayx.recorder.events"
    private var eventSink: EventChannel.EventSink? = null
    private var recorder: MediaRecorder? = null
    private var currentRecordingPath: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize method channels
        setupMethodChannels(flutterEngine)
        setupEventChannel(flutterEngine)
    }

    private fun setupMethodChannels(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val i = Intent(context, CallRecorderService::class.java)
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                ContextCompat.startForegroundService(context, i)
                            } else {
                                startService(i)
                            }
                            result.success("Service started")
                        } catch (e: Exception) {
                            result.error("SERVICE_ERROR", "Failed to start service", e.localizedMessage)
                        }
                    }
                    "stopService" -> {
                        try {
                            val i = Intent(context, CallRecorderService::class.java)
                            stopService(i)
                            result.success("Service stopped")
                        } catch (e: Exception) {
                            result.error("SERVICE_ERROR", "Failed to stop service", e.localizedMessage)
                        }
                    }
                    "startRecording" -> {
                        try {
                            val callId = call.argument<String>("callId") ?: ""
                            val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                            val recordingPath = startRecording(callId, phoneNumber)
                            result.success(recordingPath)
                        } catch (e: Exception) {
                            result.error("RECORD_ERROR", "Failed to start recording", e.localizedMessage)
                        }
                    }
                    "stopRecording" -> {
                        try {
                            val recordingPath = stopRecording()
                            result.success(recordingPath)
                        } catch (e: Exception) {
                            result.error("RECORD_ERROR", "Failed to stop recording", e.localizedMessage)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun setupEventChannel(engine: FlutterEngine) {
        EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private fun startRecording(callId: String, phoneNumber: String): String? {
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.RECORD_AUDIO
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            Log.e("MainActivity", "Recording permission not granted")
            return null
        }

        val folder = File(getExternalFilesDir(Environment.DIRECTORY_MUSIC), "AdvayX_Recordings")
        if (!folder.exists()) {
            folder.mkdirs()
        }

        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val fileName = "${callId}_${phoneNumber}_$timestamp.m4a"
        val file = File(folder, fileName)
        currentRecordingPath = file.absolutePath

        recorder = MediaRecorder().apply {
            setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioSamplingRate(44100)
            setAudioEncodingBitRate(128000)
            setOutputFile(file.absolutePath)
            prepare()
            start()
        }

        return currentRecordingPath
    }

    private fun stopRecording(): String? {
        return try {
            recorder?.apply {
                stop()
                release()
            }
            recorder = null
            val path = currentRecordingPath
            currentRecordingPath = null
            path
        } catch (e: Exception) {
            Log.e("MainActivity", "Error stopping recording", e)
            null
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "advayx_channel",
                "AdvayX Call Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Channel for AdvayX call recording service"
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        // Stop the recording service when the activity is destroyed
        try {
            val serviceIntent = Intent(this, CallRecorderService::class.java)
            serviceIntent.action = CallRecorderService.ACTION_STOP
            startService(serviceIntent)
        } catch (e: Exception) {
            Log.e("AdvayX", "Error stopping service: ${e.message}")
        }
        
        // Release resources
        recorder?.release()
        recorder = null
        
        super.onDestroy()
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == 1001) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            if (allGranted) {
                // Permissions granted, you might want to restart the service
                Log.d("AdvayX", "All permissions granted")
            } else {
                Log.e("AdvayX", "Some permissions were not granted")
            }
        }
    }
}