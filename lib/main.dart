import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:async';

void main() {
  runApp(const AynApp());
}

class AynApp extends StatelessWidget {
  const AynApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AYN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _autoListenEnabled = true;
  String _lastWords = "";
  String _statusMessage = "جاري التهيئة...";
  double? _currentHeading;
  StreamSubscription? _compassSubscription;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _requestPermissions();
    await _setupTts();
    await _setupSpeech();
    _setupCompass();

    setState(() {
      _statusMessage = "جاهز";
    });

    await _speak("أهلاً يا مجد الدين، أنا عَيْن، النسخة المطورة جاهزة لخدمتك");
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _setupTts() async {
    await _tts.setLanguage("ar-SA");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);

    _tts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
      if (_autoListenEnabled) {
        Timer(const Duration(milliseconds: 500), () => _startContinuousListening());
      }
    });

    _tts.setStartHandler(() {
      setState(() => _isSpeaking = true);
    });
  }

  Future<void> _setupSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) => _handleSpeechError(error.errorMsg),
        onStatus: (status) => _handleSpeechStatus(status),
      );
    } catch (e) {
      _speechAvailable = false;
    }
  }

  void _handleSpeechStatus(String status) {
    if (status == "done" || status == "notListening") {
      setState(() => _isListening = false);
      if (_autoListenEnabled && !_isSpeaking) {
        Timer(const Duration(milliseconds: 700), () => _startContinuousListening());
      }
    }
  }

  void _handleSpeechError(String error) {
    setState(() => _isListening = false);
    if (_autoListenEnabled) {
      Timer(const Duration(seconds: 1), () => _startContinuousListening());
    }
  }

  void _setupCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (mounted && event.heading != null) {
        setState(() => _currentHeading = event.heading);
      }
    });
  }

  Future<void> _speak(String text) async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }
    await _tts.speak(text);
  }

  Future<void> _vibrate({int duration = 80}) async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: duration);
    }
  }

  Future<void> _startContinuousListening() async {
    if (!_speechAvailable || _isListening || _isSpeaking) return;

    try {
      setState(() {
        _isListening = true;
        _statusMessage = "أستمع...";
      });

      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            final words = result.recognizedWords.trim();
            if (words.isNotEmpty) {
              setState(() {
                _lastWords = words;
                _isListening = false;
              });
              _processCommand(words);
            }
          }
        },
        localeId: "ar-SA",
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      setState(() => _isListening = false);
    }
  }

  Future<void> _processCommand(String command) async {
    final cmd = command.toLowerCase();
    await _vibrate(duration: 100);

    if (cmd.contains("ساعه") || cmd.contains("ساعة") || cmd.contains("وقت")) {
      await _tellTime();
    } else if (cmd.contains("شمال") || cmd.contains("اتجاه") || cmd.contains("وين")) {
      await _tellDirection();
    } else if (cmd.contains("قبلة") || cmd.contains("القبلة")) {
      await _tellQibla();
    } else if (cmd.contains("تاريخ") || cmd.contains("يوم")) {
      await _tellDate();
    } else if (cmd.contains("مرحبا") || cmd.contains("هلا") || cmd.contains("يا هلا")) {
      await _speak("أهلاً بك يا مجد، أنا عَيْن، كيف أساعدك؟");
    } else if (cmd.contains("من انت") || cmd.contains("اسمك")) {
      await _speak("أنا عين، مساعدك الذكي المبني ليكون عيناك في عالم التكنولوجيا");
    } else if (cmd.contains("توقف") || cmd.contains("اسكت")) {
      await _tts.stop();
      _autoListenEnabled = false; // خيار لتعطيل الاستماع التلقائي مؤقتاً
      await _speak("تم إيقاف الاستماع التلقائي");
    } else {
      await _speak("لم أفهم طلبك، حاول مرة أخرى");
    }
  }

  Future<void> _tellTime() async {
    final now = DateTime.now();
    final period = now.hour >= 12 ? "مساءً" : "صباحاً";
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    await _speak("الساعة الآن $hour و ${now.minute} دقيقة $period");
  }

  Future<void> _tellDate() async {
    final now = DateTime.now();
    final months = ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"];
    await _speak("اليوم هو ${now.day} من شهر ${months[now.month - 1]} لعام ${now.year}");
  }

  Future<void> _tellDirection() async {
    if (_currentHeading == null) {
      await _speak("عذراً، حساس البوصلة غير مفعل");
      return;
    }
    final heading = _currentHeading!;
    String dir = "";
    if (heading < 22.5 || heading >= 337.5) dir = "الشمال";
    else if (heading < 67.5) dir = "الشمال الشرقي";
    else if (heading < 112.5) dir = "الشرق";
    else if (heading < 157.5) dir = "الجنوب الشرقي";
    else if (heading < 202.5) dir = "الجنوب";
    else if (heading < 247.5) dir = "الجنوب الغربي";
    else if (heading < 292.5) dir = "الغرب";
    else dir = "الشمال الغربي";

    await _speak("أنت تتجه الآن نحو $dir");
  }

  Future<void> _tellQibla() async {
    if (_currentHeading == null) {
      await _speak("البوصلة معطلة");
      return;
    }
    const double qibla = 165.0; // تقريباً لسوريا
    final diff = (qibla - _currentHeading! + 360) % 360;

    if (diff < 15 || diff > 345) {
      await _speak("أنت الآن باتجاه القبلة تماماً");
      await _vibrate(duration: 500);
    } else if (diff < 180) {
      await _speak("القبلة على يمينك قليلاً");
    } else {
      await _speak("القبلة على يسارك قليلاً");
    }
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor = _isSpeaking ? Colors.purple : (_isListening ? Colors.red : Colors.blue);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: Colors.black),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("عَيْن", style: TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: themeColor.withOpacity(0.2),
                  border: Border.all(color: themeColor, width: 4),
                  boxShadow: [BoxShadow(color: themeColor.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)],
                ),
                child: Icon(_isListening ? Icons.mic : (_isSpeaking ? Icons.volume_up : Icons.remove_red_eye), color: Colors.white, size: 80),
              ),
              const SizedBox(height: 40),
              Text(_statusMessage, style: const TextStyle(color: Colors.white, fontSize: 24)),
              if (_lastWords.isNotEmpty) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text("$_lastWords", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 18, fontStyle: FontStyle.italic)),
                ),
              ],
              const Spacer(),
              const Text("AYN v1.3 - Mechatronics Edition", style: TextStyle(color: Colors.white24, fontSize: 12)),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
