package com.example.haptic_beat

import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val channelName = "com.example.haptic_beat/haptics"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
      val intensity = (call.argument<Double>("intensity") ?: 1.0).coerceIn(0.0, 1.0)

      when (call.method) {
        "triggerKick" -> {
          triggerHaptic(HapticPattern.KICK, intensity)
          result.success(null)
        }
        "triggerBass" -> {
          triggerHaptic(HapticPattern.BASS, intensity)
          result.success(null)
        }
        "triggerSnare" -> {
          triggerHaptic(HapticPattern.SNARE, intensity)
          result.success(null)
        }
        "triggerImpact" -> {
          triggerHaptic(HapticPattern.IMPACT, intensity)
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun triggerHaptic(pattern: HapticPattern, intensity: Double) {
    val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val manager = getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager
      manager.defaultVibrator
    } else {
      getSystemService(VIBRATOR_SERVICE) as Vibrator
    }

    if (!vibrator.hasVibrator()) {
      return
    }

    val amplitude = amplitudeFor(intensity)
    val patternData = when (pattern) {
      HapticPattern.KICK -> HapticPatternData(
        longArrayOf(0, 34, 18, 38),
        intArrayOf(0, amplitude, 0, (amplitude * 0.48).toInt())
      )
      HapticPattern.BASS -> HapticPatternData(
        longArrayOf(0, 96, 24, 42),
        intArrayOf(0, (amplitude * 0.62).toInt(), 0, (amplitude * 0.28).toInt())
      )
      HapticPattern.SNARE -> HapticPatternData(
        longArrayOf(0, 22, 28, 24),
        intArrayOf(0, (amplitude * 0.78).toInt(), 0, amplitude)
      )
      HapticPattern.IMPACT -> HapticPatternData(
        longArrayOf(0, 44, 22, 68),
        intArrayOf(0, amplitude, 0, (amplitude * 0.58).toInt())
      )
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      vibrator.vibrate(
        VibrationEffect.createWaveform(patternData.timings, patternData.amplitudes, -1)
      )
    } else {
      @Suppress("DEPRECATION")
      vibrator.vibrate(patternData.timings.sum())
    }
  }

  private fun amplitudeFor(intensity: Double): Int {
    return (36 + intensity * 219).toInt().coerceIn(1, 255)
  }

  private enum class HapticPattern {
    KICK,
    BASS,
    SNARE,
    IMPACT,
  }

  private data class HapticPatternData(
    val timings: LongArray,
    val amplitudes: IntArray,
  )
}
