package com.a3s.advayx_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.ContentValues
import android.content.Intent
import android.media.MediaRecorder
import android.os.Build
import android.os.Environment
import android.os.IBinder
import android.provider.CallLog
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class CallRecorderService : Service() {

    companion object {
        const val ACTION_START = "START_RECORDING"
        const val ACTION_STOP = "STOP_RECORDING"
    }

    private var recorder: MediaRecorder? = null
    private var currentFilePath: String? = null
    private var currentNumber: String? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == ACTION_START) {
            startForegroundNotification()
            startRecording(intent)
        } else if (action == ACTION_STOP) {
            stopRecording()
            stopSelf()
        }
        return START_STICKY
    }

    private fun startForegroundNotification() {
        val channelId = "advayx_record_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "AdvayX Recorder", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val notification = Notification.Builder(this, channelId)
            .setContentTitle("AdvayX Call Recorder")
            .setSmallIcon(android.R.drawable.presence_audio_online)
            .build()
        startForeground(101, notification)
    }

    private fun startRecording(intent: Intent?) {
        try {
            // Prepare folder
            val folder = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC), 
                "AdvayX_Recordings"
            )
            if (!folder.exists()) folder.mkdirs()

            val ts = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val number = intent?.getStringExtra("number") ?: "unknown"
            currentNumber = number

            val file = File(folder, "AdvayX_${number}_$ts.m4a")
            currentFilePath = file.absolutePath

            // Release any existing recorder instance
            releaseRecorder()

            recorder = MediaRecorder().apply {
                try {
                    // Try different audio sources in order of preference
                    val audioSource = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        MediaRecorder.AudioSource.VOICE_COMMUNICATION
                    } else {
                        MediaRecorder.AudioSource.VOICE_CALL
                    }
                    
                    setAudioSource(audioSource)
                    setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                    setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                    setAudioSamplingRate(44100)
                    setAudioEncodingBitRate(128000)
                    setOutputFile(currentFilePath)
                    
                    // Additional settings for better compatibility
                    setAudioChannels(1) // Mono recording
                    setMaxDuration(0) // No limit on duration
                    setOnErrorListener { _, what, extra ->
                        Log.e("AdvayX", "MediaRecorder error: $what, $extra")
                    }
                    
                    prepare()
                    start()
                    
                    Log.d("AdvayX", "Recording started: $currentFilePath")
                } catch (e: Exception) {
                    Log.e("AdvayX", "Error in MediaRecorder setup: ${e.message}")
                    releaseRecorder()
                    throw e
                }
            }

            // Insert minimal calllog entry (custom field)
            saveCallLog(number, currentFilePath ?: "")
        } catch (e: Exception) {
            Log.e("AdvayX", "startRecording error: ${e.message}")
        }
    }

    private fun releaseRecorder() {
        try {
            recorder?.apply {
                try {
                    stop()
                } catch (e: IllegalStateException) {
                    Log.e("AdvayX", "Error stopping recorder: ${e.message}")
                }
                reset()
                release()
            }
        } catch (e: Exception) {
            Log.e("AdvayX", "Error releasing recorder: ${e.message}")
        } finally {
            recorder = null
        }
    }

    private fun stopRecording() {
        val filePath = currentFilePath
        
        // Release the recorder
        releaseRecorder()
        
        // Send broadcast with recording path
        filePath?.let { path ->
            // Verify the file exists and has content before broadcasting
            val file = File(path)
            if (file.exists() && file.length() > 0) {
                val intent = Intent("com.a3s.advayx.RECORDING_COMPLETE")
                intent.putExtra("filePath", path)
                sendBroadcast(intent)
                Log.d("AdvayX", "Recording saved: $path (${file.length()} bytes)")
            } else {
                Log.e("AdvayX", "Recording file not found or empty: $path")
            }
        }
        
        recorder = null
        currentFilePath = null
        currentNumber = null
    }

    private fun saveCallLog(number: String, filePath: String) {
        try {
            val cv = ContentValues().apply {
                put(CallLog.Calls.NUMBER, number)
                put(CallLog.Calls.DATE, System.currentTimeMillis())
                put(CallLog.Calls.DURATION, 0)
                put(CallLog.Calls.TYPE, CallLog.Calls.OUTGOING_TYPE)
                put(CallLog.Calls.NEW, 1)
                put("recording_uri", filePath) // custom column
            }
            contentResolver.insert(CallLog.Calls.CONTENT_URI, cv)
        } catch (e: Exception) {
            Log.e("AdvayX", "saveCallLog error: ${e.message}")
        }
    }

    override fun onDestroy() {
        stopRecording()
        super.onDestroy()
    }
}
