import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/material.dart';

class FallDetectionService {
  static const int WINDOW_SIZE = 200; // 1 sec a 200Hz
  static const int NUM_SENSORS = 9;
  static const int NUM_FEATURES = 90;
  static const double FALL_THRESHOLD = 0.7; // 70% confiance

  Interpreter? _interpreter;
  List<double>? _scalerMean;
  List<double>? _scalerScale;

  final List<List<double>> _sensorBuffer = [];
  StreamSubscription? _accelSubscription;
  StreamSubscription? _gyroSubscription;

  List<double>? _lastAccel;
  List<double>? _lastGyro;

  bool _isInitialized = false;
  bool _isMonitoring = false;

  Function(bool isFall, double confidence)? onFallDetected;

  // Initialiser le modele
  Future<void> initialize() async {
    try {
      debugPrint('[FallDetection] Initialisation...');

      // Charger le modele TFLite
      _interpreter = await Interpreter.fromAsset('assets/models/fall_detection.tflite');
      debugPrint('[FallDetection] Modele charge');

      // Charger parametres scaler
      final scalerJson = await rootBundle.loadString('assets/models/scaler_params.json');
      final scalerData = json.decode(scalerJson);
      _scalerMean = List<double>.from(scalerData['mean']);
      _scalerScale = List<double>.from(scalerData['scale']);
      debugPrint('[FallDetection] Scaler charge (${_scalerMean!.length} features)');

      _isInitialized = true;
      debugPrint('[FallDetection] Initialisation reussie');
    } catch (e) {
      debugPrint('[FallDetection] ERREUR init: $e');
      rethrow;
    }
  }

  // Demarrer la surveillance
  void startMonitoring() {
    if (!_isInitialized) {
      debugPrint('[FallDetection] ERREUR: non initialise');
      return;
    }

    if (_isMonitoring) {
      debugPrint('[FallDetection] Deja en cours');
      return;
    }

    _isMonitoring = true;
    _sensorBuffer.clear();

    debugPrint('[FallDetection] Demarrage surveillance');

    // Accelerometre (simule 3 capteurs avec donnees identiques)
    _accelSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      _lastAccel = [event.x, event.y, event.z];
      _addSensorData();
    });

    // Gyroscope
    _gyroSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      _lastGyro = [event.x, event.y, event.z];
      _addSensorData();
    });
  }

  // Arreter la surveillance
  void stopMonitoring() {
    _isMonitoring = false;
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _sensorBuffer.clear();
    debugPrint('[FallDetection] Surveillance arretee');
  }

  // Ajouter donnees capteur
  void _addSensorData() {
    if (_lastAccel == null || _lastGyro == null) return;

    // Format: [accel_x, accel_y, accel_z, gyro_x, gyro_y, gyro_z, accel_x, accel_y, accel_z]
    // On repete accelerometre pour simuler 3 capteurs (dataset original avait 3 accelerometres)
    final data = [
      ..._lastAccel!,
      ..._lastGyro!,
      ..._lastAccel!,
    ];

    _sensorBuffer.add(data);

    // Garder seulement les dernieres donnees necessaires
    if (_sensorBuffer.length > WINDOW_SIZE + 100) {
      _sensorBuffer.removeAt(0);
    }

    // Analyser si on a assez de donnees
    if (_sensorBuffer.length >= WINDOW_SIZE) {
      _analyzeWindow();
    }
  }

  // Analyser fenetre
  void _analyzeWindow() {
    try {
      // Prendre derniere fenetre
      final window = _sensorBuffer.sublist(_sensorBuffer.length - WINDOW_SIZE);

      // Extraire features
      final features = _extractFeatures(window);

      // Normaliser
      final normalizedFeatures = _normalizeFeatures(features);

      // Prediction
      final input = [normalizedFeatures];
      final output = List.filled(1 * 2, 0.0).reshape([1, 2]);

      _interpreter!.run(input, output);

      final probADL = output[0][0];
      final probFall = output[0][1];

      debugPrint('[FallDetection] ADL: ${(probADL * 100).toStringAsFixed(1)}% | Fall: ${(probFall * 100).toStringAsFixed(1)}%');

      // Detecter chute
      if (probFall > FALL_THRESHOLD) {
        debugPrint('[FallDetection] ALERTE CHUTE detectee! Confiance: ${(probFall * 100).toStringAsFixed(1)}%');
        onFallDetected?.call(true, probFall);
      }
    } catch (e) {
      debugPrint('[FallDetection] ERREUR analyse: $e');
    }
  }

  // Extraire features (90 features)
  List<double> _extractFeatures(List<List<double>> window) {
    final features = <double>[];

    // Pour chaque capteur (9 capteurs)
    for (int sensorIdx = 0; sensorIdx < NUM_SENSORS; sensorIdx++) {
      final sensorData = window.map((row) => row[sensorIdx]).toList();

      // Features temporelles (7)
      final mean = _mean(sensorData);
      final std = _std(sensorData);
      final min = sensorData.reduce((a, b) => a < b ? a : b);
      final max = sensorData.reduce((a, b) => a > b ? a : b);
      final range = max - min;
      final q1 = _percentile(sensorData, 25);
      final q3 = _percentile(sensorData, 75);

      features.addAll([mean, std, min, max, range, q1, q3]);

      // Features frequentielles (3)
      final fftMagnitude = _fftMagnitude(sensorData);
      final fftMean = _mean(fftMagnitude);
      final fftStd = _std(fftMagnitude);
      final fftMax = fftMagnitude.reduce((a, b) => a > b ? a : b);

      features.addAll([fftMean, fftStd, fftMax]);
    }

    return features;
  }

  // Normaliser features
  List<double> _normalizeFeatures(List<double> features) {
    final normalized = <double>[];
    for (int i = 0; i < features.length; i++) {
      final norm = (features[i] - _scalerMean![i]) / _scalerScale![i];
      normalized.add(norm);
    }
    return normalized;
  }

  // Fonctions statistiques
  double _mean(List<double> data) {
    return data.reduce((a, b) => a + b) / data.length;
  }

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
    // FFT simplifie (approximation pour mobile)
    final magnitude = <double>[];
    final n = data.length;

    for (int k = 0; k < n ~/ 2; k++) {
      double real = 0;
      double imag = 0;

      for (int t = 0; t < n; t++) {
        final angle = -2 * pi * k * t / n;
        real += data[t] * cos(angle);
        imag += data[t] * sin(angle);
      }

      magnitude.add(sqrt(real * real + imag * imag));
    }

    return magnitude;
  }

  // Nettoyer
  void dispose() {
    stopMonitoring();
    _interpreter?.close();
    _isInitialized = false;
    debugPrint('[FallDetection] Service dispose');
  }
}