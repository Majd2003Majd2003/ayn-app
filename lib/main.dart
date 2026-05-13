// ============================================================
//  تطبيق عَيْن (AYN) — مساعد المكفوفين
//  النسخة المبسطة v1.0
//  المهندس: مجد الدين الدكاك
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';

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
  
  bool _isReady = false;
  bool _isListening = false;
  String _lastWords = "";
  String _statusMessage = "جاري التهيئة...";
  
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    await _requestPermissions();
    await _setupTts();
    await _setupSpeech();
    
    setState(() {
      _isReady = true;
      _statusMessage = "جاهز";
    });
    
    await _speak("أهلاً يا مجد الدين، أنا عَيْن، مساعدك الذكي");
    await Future.delayed(const Duration(seconds: 1));
    await _speak("اضغط في أي مكان على الشاشة للتحدث معي");
  }
  
  Future<void> _requestPermissions() async {
    await [Permission.microphone].request();
  }
  
  Future<void> _setupTts() async {
    await _tts.setLanguage("ar-SA");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }
  
  Future<void> _setupSpeech() async {
    bool available = await _speech.initialize(
      onError: (error) => print("Speech error: $error"),
      onStatus: (status) => print("Speech status: $status"),
    );
    
    if (!available) {
      _speak("لا يمكنني الاستماع، تحقق من الإعدادات");
    }
  }
  
  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }
  
  Future<void> _vibrate({int duration = 100}) async {
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator) {
      Vibration.vibrate(duration: duration);
    }
  }
  
  Future<void> _vibrateSuccess() async {
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator) {
      Vibration.vibrate(pattern: [0, 100, 100, 100]);
    }
  }
  
  Future<void> _startListening() async {
    if (!_speech.isAvailable) {
      await _speak("الاستماع غير متاح");
      return;
    }
    
    await _vibrate(duration: 50);
    
    setState(() {
      _isListening = true;
      _statusMessage = "أستمع إليك...";
      _lastWords = "";
    });
    
    await _speak("نعم");
    
    await _speech.listen(
      onResult: _onSpeechResult,
      localeId: "ar-SA",
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );
  }
  
  void _onSpeechResult(result) {
    if (result.finalResult) {
      setState(() {
        _lastWords = result.recognizedWords;
        _isListening = false;
        _statusMessage = "جاهز";
      });
      _processCommand(result.recognizedWords);
    }
  }
  
  Future<void> _processCommand(String command) async {
    final cmd = command.toLowerCase().trim();
    print("Command: $cmd");
    
    await _vibrateSuccess();
    
    if (cmd.contains("كم الساعة") || cmd.contains("الوقت") || cmd.contains("ساعة")) {
      await _tellTime();
    }
    else if (cmd.contains("مرحبا") || cmd.contains("السلام") || cmd.contains("اهلا")) {
      await _speak("أهلاً وسهلاً يا مجد الدين، كيف حالك");
    }
    else if (cmd.contains("اسمك") || cmd.contains("ما اسمك")) {
      await _speak("أنا عَيْن، مساعدك الذكي للتنقل والقراءة");
    }
    else if (cmd.contains("شكرا") || cmd.contains("شكراً")) {
      await _speak("على الرحب والسعة، أنا هنا لمساعدتك");
    }
    else if (cmd.contains("من انت") || cmd.contains("شو انت")) {
      await _speak("أنا عَيْن، مساعد ذكي للأشخاص ذوي الإعاقة البصرية");
    }
    else if (cmd.contains("عد") || cmd.contains("احسب")) {
      await _speak("واحد، اثنان، ثلاثة، أربعة، خمسة");
    }
    else if (cmd.contains("اسكت") || cmd.contains("توقف")) {
      await _tts.stop();
    }
    else {
      await _speak("سمعت: $cmd. لكني لم أفهم، حاول مرة أخرى");
    }
  }
  
  Future<void> _tellTime() async {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final period = hour >= 12 ? "مساءً" : "صباحاً";
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    await _speak("الساعة $displayHour و $minute دقيقة $period");
  }
  
  void _onScreenTap() {
    if (_isListening) return;
    _startListening();
  }
  
  @override
  void dispose() {
    _tts.stop();
    _speech.stop();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onScreenTap,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "عَيْن",
                  style: TextStyle(
                    fontSize: 100,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening 
                        ? Colors.red.shade700 
                        : Colors.blue.shade700,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                    size: 100,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                if (_lastWords.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      "سمعت: $_lastWords",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const Spacer(),
                const Text(
                  "اضغط في أي مكان للتحدث",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                  "AYN v1.0 — Majd Aldin",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
