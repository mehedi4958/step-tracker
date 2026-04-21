import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
    const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Step Tracker',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.greenAccent,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            color: Colors.white,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          centerTitle: true,
        ),
      ),
      home: const StepTracker(),
    );
  }
}

class StepTracker extends StatefulWidget {
  const StepTracker({super.key});

  @override
  State<StepTracker> createState() => _StepTrackerState();
}

class _StepTrackerState extends State<StepTracker> {
  int _stepCount = 0;
  final int _dailyGoal = 5000;
  DateTime _lastStepTime = DateTime.now();
  final int _stepCoolDown = 350; // in milliseconds
  late String _dateToday;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  final List<double> _accelerometerSignalWindow = [];
  final int _signalWindowSize = 20;

  @override
  void initState() {
    super.initState();
    _dateToday = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadTodaysSteps();
  }

  Future<void> _loadTodaysSteps() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _stepCount = prefs.getInt(_dateToday) ?? 0;
    });
  }

  Future<void> _saveTodaysSteps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dateToday, _stepCount);
  }

  Future<void> _resetTodaysSteps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dateToday);
    if (!mounted) return;
    setState(() {
      _stepCount = 0;
    });
  }

  void _startListening() {
    const gravity = 9.81;
    _accelerometerSubscription = accelerometerEventStream().listen((onData) {
      double accelerationMagnitude = sqrt(
        onData.x * onData.x + onData.y * onData.y + onData.z * onData.z,
      );
      double accelerationValue = accelerationMagnitude - gravity;

      _accelerometerSignalWindow.add(accelerationValue);

      if (_accelerometerSignalWindow.length > _signalWindowSize) {
        _accelerometerSignalWindow.removeAt(0);
      }

      double average =
          _accelerometerSignalWindow.reduce((a, b) => a + b) /
          _accelerometerSignalWindow.length;

      double dynamicThreshold = average + 1.0;

      DateTime now = DateTime.now();

      if (accelerationValue > dynamicThreshold &&
          now.difference(_lastStepTime).inMilliseconds > _stepCoolDown) {
        _stepCount++;
        _lastStepTime = now;
        _saveTodaysSteps();
      }
    });

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Step Tracker'),
        actions: [
          IconButton(
            onPressed: _resetTodaysSteps,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildTodaysScreen(),
    );
  }

  Widget _buildTodaysScreen() {
    double progress = _stepCount / _dailyGoal;
    if (progress > 1.0) progress = 1.0;
    return Padding(
      padding: .all(16.0),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          Text(
            'Steps Today ($_dateToday)',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: .bold,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            '$_stepCount / $_dailyGoal',
            style: const TextStyle(fontSize: 20),
          ),

          const SizedBox(height: 20),

          LinearProgressIndicator(
            value: progress,
            minHeight: 20,
            backgroundColor: Colors.grey,
            color: Colors.greenAccent,
          ),

          const SizedBox(height: 40),

          ElevatedButton(
            onPressed: _accelerometerSubscription == null
                ? _startListening
                : null,
            child: Text(
              _accelerometerSubscription == null
                  ? 'Start Tracking'
                  : 'Tracking...',
            ),
          ),
        ],
      ),
    );
  }
}
