import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/material.dart';

class FallDetectionService {
  static const int WINDOW_SIZE = 200;
  static const int NUM_SENSORS = 9;
  static const int NUM_FEATURES = 90;
  static const double FALL_THRESHOLD = 0.7;

  Interpreter? _interpreter;
  List<double>? _scalerMean;
  List<double>? _scalerScale;

  final List<List<double>> _sensorBuffer = [];
  StreamSubscription? _accelSubscription;
  StreamSubscription? _gyroSubscription;

  List<double>? _lastAccel;
  List<double>? _lastGyro;

  bool isInitialized = false; // PUBLIC MAINTENANT
  bool _isMonitoring = false;

  Function(bool isFall, double confidence)? onFallDetected;

  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/fall_detection.tflite');
      final scalerJson = await rootBundle.loadString('assets/models/scaler_params.json');
      final scalerData = json.decode(scalerJson);
      _scalerMean = List<double>.from(scalerData['mean']);
      _scalerScale = List<double>.from(scalerData['scale']);
      isInitialized = true;
    } catch (e) {
      debugPrint('[FallDetection] Erreur init: $e');
      rethrow;
    }
  }

  void startMonitoring() {
    if (!isInitialized || _isMonitoring) return;

    _isMonitoring = true;
    _sensorBuffer.clear();

    _accelSubscription = accelerometerEvents.listen((event) {
      _lastAccel = [event.x, event.y, event.z];
      _addSensorData();
    });

    _gyroSubscription = gyroscopeEvents.listen((event) {
      _lastGyro = [event.x, event.y, event.z];
      _addSensorData();
    });
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _sensorBuffer.clear();
  }

  void _addSensorData() {
    if (_lastAccel == null || _lastGyro == null) return;

    final data = [..._lastAccel!, ..._lastGyro!, ..._lastAccel!];
    _sensorBuffer.add(data);

    if (_sensorBuffer.length > WINDOW_SIZE + 100) {
      _sensorBuffer.removeAt(0);
    }

    if (_sensorBuffer.length >= WINDOW_SIZE) {
      _analyzeWindow();
    }
  }

  void _analyzeWindow() {
    try {
      final window = _sensorBuffer.sublist(_sensorBuffer.length - WINDOW_SIZE);
      final features = _extractFeatures(window);
      final normalizedFeatures = _normalizeFeatures(features);

      final input = [normalizedFeatures];
      final output = List.filled(1 * 2, 0.0).reshape([1, 2]);

      _interpreter!.run(input, output);

      final probFall = output[0][1];

      if (probFall > FALL_THRESHOLD) {
        onFallDetected?.call(true, probFall);
      }
    } catch (e) {
      debugPrint('[FallDetection] Erreur analyse: $e');
    }
  }

  List<double> _extractFeatures(List<List<double>> window) {
    final features = <double>[];
    for (int sensorIdx = 0; sensorIdx < NUM_SENSORS; sensorIdx++) {
      final sensorData = window.map((row) => row[sensorIdx]).toList();
      final mean = _mean(sensorData);
      final std = _std(sensorData);
      final min = sensorData.reduce((a, b) => a < b ? a : b);
      final max = sensorData.reduce((a, b) => a > b ? a : b);
      final range = max - min;
      final q1 = _percentile(sensorData, 25);
      final q3 = _percentile(sensorData, 75);
      features.addAll([mean, std, min, max, range, q1, q3]);
      final fftMagnitude = _fftMagnitude(sensorData);
      final fftMean = _mean(fftMagnitude);
      final fftStd = _std(fftMagnitude);
      final fftMax = fftMagnitude.reduce((a, b) => a > b ? a : b);
      features.addAll([fftMean, fftStd, fftMax]);
    }
    return features;
  }

  List<double> _normalizeFeatures(List<double> features) {
    final normalized = <double>[];
    for (int i = 0; i < features.length; i++) {
      normalized.add((features[i] - _scalerMean![i]) / _scalerScale![i]);
    }
    return normalized;
  }

  double _mean(List<double> data) => data.reduce((a, b) => a + b) / data.length;

  double _std(List<double> data) {
    final mean = _mean(data);
    final variance = data.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / data.length;
    return sqrt(variance);
  }

  double _percentile(List<double> data, double p) {
    final sorted = List<double>.from(data)..sort();
    final index = (p / 100) * (sorted.length - 1);
    final lower = index.floor();
    final upper = index.ceil();
    final weight = index - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }

  List<double> _fftMagnitude(List<double> data) {
    final magnitude = <double>[];
    final n = data.length;
    for (int k = 0; k < n ~/ 2; k++) {
      double real = 0, imag = 0;
      for (int t = 0; t < n; t++) {
        final angle = -2 * pi * k * t / n;
        real += data[t] * cos(angle);
        imag += data[t] * sin(angle);
      }
      magnitude.add(sqrt(real * real + imag * imag));
    }
    return magnitude;
  }

  void dispose() {
    stopMonitoring();
    _interpreter?.close();
    isInitialized = false;
  }
}