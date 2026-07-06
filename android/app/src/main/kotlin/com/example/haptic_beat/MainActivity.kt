package com.example.haptic_beat

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
  private val channelName = "com.example.haptic_beat/haptics"
  private val analysisChannelName = "com.example.haptic_beat/audio_analysis"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
      val intensity = (call.argument<Double>("intensity") ?: 1.0).coerceIn(0.0, 1.0)

      when (call.method) {
        "prepare" -> {
          result.success(null)
        }
        "startPattern" -> {
          val offsetsMs = call.argument<List<Int>>("offsetsMs") ?: emptyList()
          val intensities = call.argument<List<Double>>("intensities") ?: emptyList()
          val strength = (call.argument<Double>("strength") ?: 1.0).coerceIn(0.0, 1.0)
          result.success(startHapticPattern(offsetsMs, intensities, strength))
        }
        "cancelPattern" -> {
          vibrator()?.cancel()
          result.success(null)
        }
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

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, analysisChannelName).setMethodCallHandler { call, result ->
      when (call.method) {
        "analyzeFile" -> {
          val path = call.argument<String>("path")
          if (path.isNullOrBlank()) {
            result.error("invalid_path", "No audio file path was provided.", null)
            return@setMethodCallHandler
          }

          Thread {
            try {
              val analysis = analyzeAudioFile(path)
              runOnUiThread { result.success(analysis.toMap()) }
            } catch (error: Throwable) {
              runOnUiThread {
                result.error("analysis_failed", error.message ?: "Audio analysis failed.", null)
              }
            }
          }.start()
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun triggerHaptic(pattern: HapticPattern, intensity: Double) {
    val vibrator = vibrator() ?: return

    if (!vibrator.hasVibrator()) {
      return
    }

    val amplitude = amplitudeFor(intensity)
    val patternData = when (pattern) {
      HapticPattern.KICK -> HapticPatternData(
        longArrayOf(0, 34, 18, 38),
        intArrayOf(0, amplitude, 0, (amplitude * 0.62).toInt())
      )
      HapticPattern.BASS -> HapticPatternData(
        longArrayOf(0, 96, 24, 42),
        intArrayOf(0, (amplitude * 0.78).toInt(), 0, (amplitude * 0.42).toInt())
      )
      HapticPattern.SNARE -> HapticPatternData(
        longArrayOf(0, 22, 28, 24),
        intArrayOf(0, (amplitude * 0.9).toInt(), 0, amplitude)
      )
      HapticPattern.IMPACT -> HapticPatternData(
        longArrayOf(0, 44, 22, 68),
        intArrayOf(0, amplitude, 0, (amplitude * 0.72).toInt())
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

  private fun startHapticPattern(
    offsetsMs: List<Int>,
    intensities: List<Double>,
    strength: Double,
  ): Boolean {
    val vibrator = vibrator() ?: return false
    if (!vibrator.hasVibrator() || offsetsMs.isEmpty()) {
      return false
    }

    val timings = ArrayList<Long>()
    val amplitudes = ArrayList<Int>()
    var cursorMs = 0

    for (index in offsetsMs.indices) {
      val offsetMs = offsetsMs[index].coerceAtLeast(cursorMs)
      val waitMs = offsetMs - cursorMs
      if (waitMs > 0) {
        timings.add(waitMs.toLong())
        amplitudes.add(0)
      }

      val rawIntensity = intensities.getOrNull(index) ?: 0.62
      val intensity = (rawIntensity * strength).coerceIn(0.0, 1.0)
      val pulseMs = when {
        intensity >= 0.84 -> 56
        intensity >= 0.62 -> 42
        else -> 30
      }
      timings.add(pulseMs.toLong())
      amplitudes.add(amplitudeFor(intensity))
      cursorMs = offsetMs + pulseMs
    }

    if (timings.isEmpty()) {
      return false
    }

    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      vibrator.vibrate(
        VibrationEffect.createWaveform(timings.toLongArray(), amplitudes.toIntArray(), -1)
      )
      true
    } else {
      @Suppress("DEPRECATION")
      vibrator.vibrate(timings.toLongArray(), -1)
      true
    }
  }

  private fun amplitudeFor(intensity: Double): Int {
    val shaped = sqrt(intensity.coerceIn(0.0, 1.0))
    return (58 + shaped * 197).toInt().coerceIn(1, 255)
  }

  private fun vibrator(): Vibrator? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val manager = getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager
      manager.defaultVibrator
    } else {
      @Suppress("DEPRECATION")
      getSystemService(VIBRATOR_SERVICE) as Vibrator
    }
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

  private fun analyzeAudioFile(path: String): AudioAnalysisResult {
    val extractor = MediaExtractor()
    var codec: MediaCodec? = null

    try {
      extractor.setDataSource(path)
      val trackIndex = selectAudioTrack(extractor)
      if (trackIndex < 0) {
        return AudioAnalysisResult.empty()
      }

      extractor.selectTrack(trackIndex)
      val format = extractor.getTrackFormat(trackIndex)
      val mime = format.getString(MediaFormat.KEY_MIME) ?: return AudioAnalysisResult.empty()
      var sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
      var channelCount = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT).coerceAtLeast(1)
      val durationMs = if (format.containsKey(MediaFormat.KEY_DURATION)) {
        format.getLong(MediaFormat.KEY_DURATION) / 1000L
      } else {
        0L
      }

      codec = MediaCodec.createDecoderByType(mime)
      codec.configure(format, null, null, 0)
      codec.start()

      val info = MediaCodec.BufferInfo()
      val collector = EnergyCollector(sampleRate)
      var sawInputEnd = false
      var sawOutputEnd = false
      var pcmEncoding = AudioFormat.ENCODING_PCM_16BIT

      while (!sawOutputEnd) {
        if (!sawInputEnd) {
          val inputIndex = codec.dequeueInputBuffer(10_000)
          if (inputIndex >= 0) {
            val inputBuffer = codec.getInputBuffer(inputIndex)
            val sampleSize = if (inputBuffer == null) {
              -1
            } else {
              inputBuffer.clear()
              extractor.readSampleData(inputBuffer, 0)
            }

            if (sampleSize < 0) {
              codec.queueInputBuffer(
                inputIndex,
                0,
                0,
                0,
                MediaCodec.BUFFER_FLAG_END_OF_STREAM
              )
              sawInputEnd = true
            } else {
              codec.queueInputBuffer(
                inputIndex,
                0,
                sampleSize,
                extractor.sampleTime,
                0
              )
              extractor.advance()
            }
          }
        }

        when (val outputIndex = codec.dequeueOutputBuffer(info, 10_000)) {
          MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
            val outputFormat = codec.outputFormat
            sampleRate = outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            channelCount = outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT).coerceAtLeast(1)
            pcmEncoding = if (outputFormat.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
              outputFormat.getInteger(MediaFormat.KEY_PCM_ENCODING)
            } else {
              AudioFormat.ENCODING_PCM_16BIT
            }
            collector.updateSampleRate(sampleRate)
          }
          MediaCodec.INFO_TRY_AGAIN_LATER -> {
          }
          else -> {
            if (outputIndex >= 0) {
              val outputBuffer = codec.getOutputBuffer(outputIndex)
              if (outputBuffer != null && info.size > 0) {
                outputBuffer.position(info.offset)
                outputBuffer.limit(info.offset + info.size)
                collector.consume(outputBuffer.slice(), channelCount, pcmEncoding)
              }

              if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                sawOutputEnd = true
              }
              codec.releaseOutputBuffer(outputIndex, false)
            }
          }
        }
      }

      collector.finish()
      val safeDurationMs = if (durationMs > 0) {
        durationMs
      } else {
        collector.durationMs()
      }

      return buildBeatMap(collector.energies, EnergyCollector.frameDurationMs, safeDurationMs)
    } finally {
      try {
        codec?.stop()
      } catch (_: Throwable) {
      }
      try {
        codec?.release()
      } catch (_: Throwable) {
      }
      extractor.release()
    }
  }

  private fun selectAudioTrack(extractor: MediaExtractor): Int {
    for (index in 0 until extractor.trackCount) {
      val format = extractor.getTrackFormat(index)
      val mime = format.getString(MediaFormat.KEY_MIME)
      if (mime?.startsWith("audio/") == true) {
        return index
      }
    }
    return -1
  }

  private fun buildBeatMap(
    energies: List<Double>,
    frameMs: Int,
    durationMs: Long,
  ): AudioAnalysisResult {
    if (energies.size < 24) {
      return AudioAnalysisResult.empty()
    }

    val smooth = DoubleArray(energies.size)
    for (index in energies.indices) {
      val previous = energies.getOrElse(index - 1) { energies[index] }
      val current = energies[index]
      val next = energies.getOrElse(index + 1) { energies[index] }
      smooth[index] = (previous + current * 2.0 + next) / 4.0
    }

    val onset = DoubleArray(smooth.size)
    for (index in 1 until smooth.size) {
      onset[index] = max(0.0, smooth[index] - smooth[index - 1])
    }

    val candidates = pickTransientCandidates(onset, smooth, frameMs)
    if (candidates.size < 4) {
      return fallbackBeatMap(durationMs, 128)
    }

    val bpm = estimateBpm(candidates).coerceIn(55, 190)
    val confidence = estimateConfidence(candidates, bpm)
    val strongCandidates = thinCandidates(candidates, minSpacingMs = 160)
    val beatTimes = ArrayList<Int>(strongCandidates.size)
    val beatIntensities = ArrayList<Double>(strongCandidates.size)

    for (candidate in strongCandidates) {
      beatTimes.add(candidate.timeMs)
      beatIntensities.add(candidate.intensity)
    }

    return AudioAnalysisResult(
      bpm = bpm,
      confidence = confidence,
      beatTimesMs = beatTimes,
      beatIntensities = beatIntensities,
    )
  }

  private fun pickTransientCandidates(
    onset: DoubleArray,
    smoothEnergy: DoubleArray,
    frameMs: Int,
  ): List<BeatCandidate> {
    val mean = onset.average()
    val variance = onset.fold(0.0) { sum, value -> sum + (value - mean) * (value - mean) } / onset.size
    val deviation = sqrt(variance)
    val maxOnset = onset.maxOrNull() ?: 0.0
    val threshold = max(mean + deviation * 0.48, maxOnset * 0.12)
    val candidates = ArrayList<BeatCandidate>()

    for (index in 2 until onset.size - 2) {
      val value = onset[index]
      if (value < threshold) {
        continue
      }

      if (value < onset[index - 1] || value < onset[index + 1]) {
        continue
      }

      val localEnergy = smoothEnergy[index]
      val normalized = if (maxOnset <= 0.0) 0.0 else value / maxOnset
      val intensity = (0.42 + normalized * 0.56 + localEnergy * 0.28).coerceIn(0.38, 1.0)
      candidates.add(BeatCandidate(timeMs = index * frameMs, intensity = intensity))
    }

    return thinCandidates(candidates, minSpacingMs = 140)
  }

  private fun thinCandidates(
    candidates: List<BeatCandidate>,
    minSpacingMs: Int,
  ): List<BeatCandidate> {
    val thinned = ArrayList<BeatCandidate>()

    for (candidate in candidates) {
      val lastIndex = thinned.lastIndex
      if (lastIndex >= 0 && candidate.timeMs - thinned[lastIndex].timeMs < minSpacingMs) {
        if (candidate.intensity > thinned[lastIndex].intensity) {
          thinned[lastIndex] = candidate
        }
      } else {
        thinned.add(candidate)
      }
    }

    return thinned
  }

  private fun estimateBpm(candidates: List<BeatCandidate>): Int {
    val histogram = HashMap<Int, Double>()

    for (outer in candidates.indices) {
      for (inner in outer + 1 until min(candidates.size, outer + 18)) {
        val interval = candidates[inner].timeMs - candidates[outer].timeMs
        if (interval > 2600) {
          break
        }

        for (division in 1..4) {
          val baseInterval = interval.toDouble() / division.toDouble()
          if (baseInterval < 315.0 || baseInterval > 1090.0) {
            continue
          }

          val bpm = (60_000.0 / baseInterval).roundToInt().coerceIn(55, 190)
          val weight = candidates[outer].intensity * candidates[inner].intensity / division
          histogram[bpm] = (histogram[bpm] ?: 0.0) + weight
        }
      }
    }

    return histogram.maxByOrNull { it.value }?.key ?: 128
  }

  private fun estimateConfidence(candidates: List<BeatCandidate>, bpm: Int): Double {
    val beatMs = 60_000.0 / bpm.toDouble()
    var aligned = 0.0
    var total = 0.0

    for (index in 1 until candidates.size) {
      val interval = candidates[index].timeMs - candidates[index - 1].timeMs
      if (interval <= 0) {
        continue
      }

      val nearest = (interval / beatMs).roundToInt().coerceAtLeast(1)
      val expected = beatMs * nearest
      val error = abs(interval - expected) / beatMs
      val score = (1.0 - error.coerceIn(0.0, 1.0)) * candidates[index].intensity
      aligned += score
      total += candidates[index].intensity
    }

    return if (total <= 0.0) {
      0.55
    } else {
      (aligned / total).coerceIn(0.42, 0.97)
    }
  }

  private fun fallbackBeatMap(durationMs: Long, bpm: Int): AudioAnalysisResult {
    val beatMs = (60_000.0 / bpm.toDouble()).roundToInt()
    val beatTimes = ArrayList<Int>()
    val beatIntensities = ArrayList<Double>()
    var timeMs = 0
    var index = 0

    while (timeMs <= durationMs.coerceAtLeast(180_000L)) {
      beatTimes.add(timeMs)
      beatIntensities.add(if (index % 4 == 0) 0.76 else 0.52)
      timeMs += beatMs
      index += 1
    }

    return AudioAnalysisResult(
      bpm = bpm,
      confidence = 0.38,
      beatTimesMs = beatTimes,
      beatIntensities = beatIntensities,
    )
  }

  private class EnergyCollector(initialSampleRate: Int) {
    private var sampleRate = initialSampleRate
    private var frameSamples = samplesPerFrame(initialSampleRate)
    private var frameEnergy = 0.0
    private var frameSampleCount = 0
    private var totalSamples = 0L
    val energies = ArrayList<Double>()

    fun updateSampleRate(nextSampleRate: Int) {
      sampleRate = nextSampleRate
      frameSamples = samplesPerFrame(nextSampleRate)
    }

    fun consume(buffer: ByteBuffer, channelCount: Int, pcmEncoding: Int) {
      buffer.order(ByteOrder.LITTLE_ENDIAN)
      when (pcmEncoding) {
        AudioFormat.ENCODING_PCM_FLOAT -> consumeFloat(buffer, channelCount)
        else -> consume16Bit(buffer, channelCount)
      }
    }

    fun finish() {
      if (frameSampleCount > 0) {
        energies.add(sqrt(frameEnergy / frameSampleCount.toDouble()).coerceIn(0.0, 1.0))
      }
    }

    fun durationMs(): Long {
      return if (sampleRate <= 0) {
        0L
      } else {
        (totalSamples * 1000L) / sampleRate
      }
    }

    private fun consume16Bit(buffer: ByteBuffer, channelCount: Int) {
      val bytesPerAudioFrame = channelCount * 2
      while (buffer.remaining() >= bytesPerAudioFrame) {
        var mixed = 0.0
        for (channel in 0 until channelCount) {
          mixed += buffer.short.toDouble() / Short.MAX_VALUE.toDouble()
        }
        addMonoSample(mixed / channelCount.toDouble())
      }
    }

    private fun consumeFloat(buffer: ByteBuffer, channelCount: Int) {
      val bytesPerAudioFrame = channelCount * 4
      while (buffer.remaining() >= bytesPerAudioFrame) {
        var mixed = 0.0
        for (channel in 0 until channelCount) {
          mixed += buffer.float.toDouble().coerceIn(-1.0, 1.0)
        }
        addMonoSample(mixed / channelCount.toDouble())
      }
    }

    private fun addMonoSample(sample: Double) {
      val shaped = abs(sample).coerceIn(0.0, 1.0)
      frameEnergy += shaped * shaped
      frameSampleCount += 1
      totalSamples += 1

      if (frameSampleCount >= frameSamples) {
        energies.add(sqrt(frameEnergy / frameSampleCount.toDouble()).coerceIn(0.0, 1.0))
        frameEnergy = 0.0
        frameSampleCount = 0
      }
    }

    companion object {
      const val frameDurationMs = 20

      private fun samplesPerFrame(sampleRate: Int): Int {
        return max(256, sampleRate * frameDurationMs / 1000)
      }
    }
  }

  private data class BeatCandidate(
    val timeMs: Int,
    val intensity: Double,
  )

  private data class AudioAnalysisResult(
    val bpm: Int,
    val confidence: Double,
    val beatTimesMs: List<Int>,
    val beatIntensities: List<Double>,
  ) {
    fun toMap(): Map<String, Any> {
      return mapOf(
        "bpm" to bpm,
        "confidence" to confidence,
        "beatTimesMs" to beatTimesMs,
        "beatIntensities" to beatIntensities,
      )
    }

    companion object {
      fun empty(): AudioAnalysisResult {
        return AudioAnalysisResult(
          bpm = 128,
          confidence = 0.0,
          beatTimesMs = emptyList(),
          beatIntensities = emptyList(),
        )
      }
    }
  }
}
