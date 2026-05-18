import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    
    await _speak("أهلاً يا مجد الدين، أنا عَيْن، النسخة الجديدة مع البوصلة");
    await Future.delayed(const Duration(milliseconds: 800));
    await _speak("اسألني عن الوقت أو الاتجاه أو القبلة");
    
    _startContinuousListening();
  }
  
  Future<void> _requestPermissions() async {
    await [Permission.microphone].request();
  }
  
  Future<void> _setupTts() async {
    await _tts.setLanguage("ar-SA");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    
    _tts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
      if (_autoListenEnabled && !_isListening) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _startContinuousListening();
        });
      }
    });
    
    _tts.setStartHandler(() {
      setState(() => _isSpeaking = true);
    });
  }
  
  Future<void> _setupSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          if (_autoListenEnabled) {
            Future.delayed(const Duration(seconds: 1), () {
              if (!_isListening && !_isSpeaking) {
                _startContinuousListening();
              }
            });
          }
        },
        onStatus: (status) {
          if (status == "done" || status == "notListening") {
            setState(() => _isListening = false);
            if (_autoListenEnabled && !_isSpeaking) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (!_isListening && !_isSpeaking) {
                  _startContinuousListening();
                }
              });
            }
          }
        },
      );
    } catch (e) {
      _speechAvailable = false;
    }
  }
  
  void _setupCompass() {
    FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
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
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator) {
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
            final words = result.recognizedWords;
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
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        cancelOnError: false,
      );
    } catch (e) {
      setState(() => _isListening = false);
    }
  }
  
  Future<void> _processCommand(String command) async {
    final cmd = command.toLowerCase().trim();
    await _vibrate(duration: 100);
    
    if (cmd.contains("كم الساعه") || cmd.contains("كم الساعة") || 
        cmd.contains("الوقت") || cmd.contains("ساعه") || cmd.contains("ساعة")) {
      await _tellTime();
    }
    else if (cmd.contains("شمال") || cmd.contains("جنوب") || 
             cmd.contains("الاتجاه") || cmd.contains("وين")) {
      await _tellDirection();
    }
    else if (cmd.contains("قبلة") || cmd.contains("القبلة")) {
      await _tellQiblaSimple();
    }
    else if (cmd.contains("مرحبا") || cmd.contains("اهلا") || cmd.contains("هلا") ||
             cmd.contains("سلام") || cmd.contains("صباح") || cmd.contains("مساء")) {
      await _speak("أهلاً وسهلاً يا مجد الدين، أنا في خدمتك");
    }
    else if (cmd.contains("كيف حالك") || cmd.contains("كيفك") || 
             cmd.contains("شلونك")) {
      await _speak("الحمد لله أنا بخير، كيف يمكنني مساعدتك");
    }
    else if (cmd.contains("اسمك") || cmd.contains("من انت") || 
             cmd.contains("شو انت")) {
      await _speak("أنا عَيْن، مساعد ذكي للأشخاص ذوي الإعاقة البصرية");
    }
    else if (cmd.contains("شكرا") || cmd.contains("شكر") || cmd.contains("مشكور")) {
      await _speak("على الرحب والسعة");
    }
    else if (cmd.contains("عد") || cmd.contains("احسب")) {
      await _speak("واحد، اثنان، ثلاثة، أربعة، خمسة، ستة، سبعة، ثمانية، تسعة، عشرة");
    }
    else if (cmd.contains("التاريخ") || cmd.contains("اليوم")) {
      await _tellDate();
    }
    else if (cmd.contains("ساعدني") || cmd.contains("الاوامر")) {
      await _speak("يمكنك أن تسألني عن الوقت، التاريخ، الاتجاه، أو القبلة");
    }
    else if (cmd.contains("اسكت") || cmd.contains("توقف")) {
      await _tts.stop();
    }
    else {
      await _speak("لم أفهم، قل كم الساعة أو وين الشمال");
    }
  }
  
  Future<void> _tellTime() async {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final period = hour >= 12 ? "مساءً" : "صباحاً";
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    String minuteText = minute == 0 ? "تماماً" : "و $minute دقيقة";
    await _speak("الساعة الآن $displayHour $minuteText $period");
  }
  
  Future<void> _tellDate() async {
    final now = DateTime.now();
    final months = ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
                    "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"];
    final days = ["الإثنين", "الثلاثاء", "الأربعاء", "الخميس", 
                  "الجمعة", "السبت", "الأحد"];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    await _speak("اليوم $dayName، ${now.day} $monthName ${now.year}");
  }
  
  Future<void> _tellDirection() async {
    if (_currentHeading == null) {
      await _speak("البوصلة غير جاهزة، تأكد من الحساس");
      return;
    }
    
    final heading = _currentHeading!;
    String direction;
    
    if (heading < 22.5 || heading >= 337.5) {
      direction = "أنت متجه نحو الشمال";
    } else if (heading < 67.5) {
      direction = "أنت متجه نحو الشمال الشرقي";
    } else if (heading < 112.5) {
      direction = "أنت متجه نحو الشرق";
    } else if (heading < 157.5) {
      direction = "أنت متجه نحو الجنوب الشرقي";
    } else if (heading < 202.5) {
      direction = "أنت متجه نحو الجنوب";
    } else if (heading < 247.5) {
      direction = "أنت متجه نحو الجنوب الغربي";
    } else if (heading < 292.5) {
      direction = "أنت متجه نحو الغرب";
    } else {
      direction = "أنت متجه نحو الشمال الغربي";
    }
    
    await _speak(direction);
  }
  
  Future<void> _tellQiblaSimple() async {
    if (_currentHeading == null) {
      await _speak("البوصلة غير جاهزة");
      return;
    }
    
    // القبلة من سوريا تقريباً نحو الجنوب الجنوبي الشرقي = حوالي 165 درجة
    const double qiblaFromSyria = 165;
    
    final heading = _currentHeading!;
    final diff = ((qiblaFromSyria - heading) + 360) % 360;
    
    String direction;
    if (diff < 15 || diff > 345) {
      direction = "أنت متجه نحو القبلة الآن، تكبيرة الإحرام";
    } else if (diff < 90) {
      direction = "القبلة على يمينك، استدر إلى اليمين";
    } else if (diff < 180) {
      direction = "القبلة خلفك على اليمين";
    } else if (diff < 270) {
      direction = "القبلة خلفك على اليسار";
    } else {
      direction = "القبلة على يسارك، استدر إلى اليسار";
    }
    
    await _speak(direction);
  }
  
  @override
  void dispose() {
    _tts.stop();
    _speech.stop();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    Color circleColor;
    String statusText;
    IconData centerIcon;
    
    if (_isSpeaking) {
      circleColor = Colors.purple.shade700;
      statusText = "أتحدث...";
      centerIcon = Icons.volume_up;
    } else if (_isListening) {
      circleColor = Colors.red.shade700;
      statusText = "أستمع إليك...";
      centerIcon = Icons.mic;
    } else {
      circleColor = Colors.blue.shade700;
      statusText = _statusMessage;
      centerIcon = Icons.hearing;
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "عَيْن",
                style: TextStyle(
                  fontSize: 90,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.explore,
                    color: _currentHeading != null ? Colors.green : Colors.grey,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentHeading != null 
                        ? "${_currentHeading!.round()}°" 
                        : "البوصلة غير جاهزة",
                    style: TextStyle(
                      color: _currentHeading != null ? Colors.green : Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: circleColor,
                  boxShadow: [
                    BoxShadow(
                      color: circleColor.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(centerIcon, color: Colors.white, size: 110),
              ),
              
              const SizedBox(height: 30),
              
              Text(
                statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 20),
              
              if (_lastWords.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    "سمعت: $_lastWords",
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              const Spacer(),
              
              const Text(
                "AYN v1.3 — Compass Edition",
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
