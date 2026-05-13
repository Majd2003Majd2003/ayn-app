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
  
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _autoListenEnabled = true;
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
      _statusMessage = "جاهز";
    });
    
    await _speak("أهلاً يا مجد الدين، أنا عَيْن، مساعدك الذكي");
    await Future.delayed(const Duration(milliseconds: 800));
    await _speak("سأستمع إليك دائماً، تكلم وسأرد");
    await Future.delayed(const Duration(milliseconds: 500));
    
    // بدء الاستماع التلقائي
    _startContinuousListening();
  }
  
  Future<void> _requestPermissions() async {
    await [Permission.microphone].request();
  }
  
  Future<void> _setupTts() async {
    await _tts.setLanguage("ar-SA");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    
    // عند انتهاء النطق، نعود للاستماع
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
          print("Speech error: ${error.errorMsg}");
          // إعادة المحاولة بعد الخطأ
          if (_autoListenEnabled) {
            Future.delayed(const Duration(seconds: 1), () {
              if (!_isListening && !_isSpeaking) {
                _startContinuousListening();
              }
            });
          }
        },
        onStatus: (status) {
          print("Speech status: $status");
          // عند انتهاء الاستماع، نعيد البدء
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
  
  Future<void> _speak(String text) async {
    // إيقاف الاستماع قبل النطق
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
    if (!_speechAvailable) return;
    if (_isListening) return;
    if (_isSpeaking) return;
    
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
      print("Listen error: $e");
      setState(() => _isListening = false);
    }
  }
  
  Future<void> _processCommand(String command) async {
    final cmd = command.toLowerCase().trim();
    print("Command received: $cmd");
    
    await _vibrate(duration: 100);
    
    // ==== أوامر الوقت ====
    if (cmd.contains("كم الساعه") || cmd.contains("كم الساعة") || 
        cmd.contains("الوقت") || cmd.contains("ساعه") || cmd.contains("ساعة")) {
      await _tellTime();
    }
    
    // ==== التحية والسلام ====
    else if (cmd.contains("مرحبا") || cmd.contains("اهلا") || cmd.contains("أهلا") ||
             cmd.contains("هلا") || cmd.contains("سلام") || cmd.contains("صباح") ||
             cmd.contains("مساء")) {
      await _speak("أهلاً وسهلاً يا مجد الدين، أنا في خدمتك");
    }
    
    // ==== سؤال عن الحال ====
    else if (cmd.contains("كيف حالك") || cmd.contains("كيفك") || 
             cmd.contains("شلونك") || cmd.contains("كيف الحال")) {
      await _speak("الحمد لله أنا بخير، كيف يمكنني مساعدتك");
    }
    
    // ==== التعريف ====
    else if (cmd.contains("اسمك") || cmd.contains("شو اسمك") || 
             cmd.contains("ما اسمك") || cmd.contains("مين انت") ||
             cmd.contains("من انت") || cmd.contains("شو انت") || 
             cmd.contains("عرفني عليك") || cmd.contains("عرف نفسك")) {
      await _speak("أنا عَيْن، مساعد ذكي للأشخاص ذوي الإعاقة البصرية، أساعدك على التنقل والقراءة");
    }
    
    // ==== الشكر ====
    else if (cmd.contains("شكرا") || cmd.contains("شكر") || 
             cmd.contains("مشكور") || cmd.contains("يعطيك العافية")) {
      await _speak("على الرحب والسعة، أنا هنا لمساعدتك دائماً");
    }
    
    // ==== العد ====
    else if (cmd.contains("عد") || cmd.contains("احسب") || cmd.contains("عد لي")) {
      await _speak("واحد، اثنان، ثلاثة، أربعة، خمسة، ستة، سبعة، ثمانية، تسعة، عشرة");
    }
    
    // ==== التاريخ ====
    else if (cmd.contains("التاريخ") || cmd.contains("اليوم") || 
             cmd.contains("شو اليوم") || cmd.contains("ايام")) {
      await _tellDate();
    }
    
    // ==== الإيقاف ====
    else if (cmd.contains("اسكت") || cmd.contains("توقف") || 
             cmd.contains("اوقف") || cmd.contains("صمت")) {
      await _tts.stop();
      _autoListenEnabled = false;
      await _vibrate(duration: 200);
      await Future.delayed(const Duration(seconds: 5));
      _autoListenEnabled = true;
      _startContinuousListening();
    }
    
    // ==== المساعدة ====
    else if (cmd.contains("ساعدني") || cmd.contains("مساعدة") || 
             cmd.contains("شو الاوامر") || cmd.contains("اوامر")) {
      await _speak("يمكنك أن تسألني عن الوقت، التاريخ، أو تقول مرحبا، شكراً، أو كيف حالك");
    }
    
    // ==== الوداع ====
    else if (cmd.contains("باي") || cmd.contains("مع السلامة") || 
             cmd.contains("الى اللقاء") || cmd.contains("وداعا")) {
      await _speak("مع السلامة يا مجد الدين، أنا هنا متى احتجتني");
    }
    
    // ==== اسمي / أنا ====
    else if (cmd.contains("اسمي") || cmd.contains("انا مجد")) {
      await _speak("أهلاً يا مجد الدين، يسعدني التحدث معك");
    }
    
    // ==== لم أفهم ====
    else {
      await _speak("لم أفهم تماماً، قل مرحبا أو اسألني عن الوقت");
    }
  }
  
  Future<void> _tellTime() async {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final period = hour >= 12 ? "مساءً" : "صباحاً";
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    String minuteText;
    if (minute == 0) {
      minuteText = "تماماً";
    } else {
      minuteText = "و $minute دقيقة";
    }
    
    await _speak("الساعة الآن $displayHour $minuteText $period");
  }
  
  Future<void> _tellDate() async {
    final now = DateTime.now();
    final months = [
      "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
      "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"
    ];
    final days = [
      "الإثنين", "الثلاثاء", "الأربعاء", "الخميس", 
      "الجمعة", "السبت", "الأحد"
    ];
    
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    
    await _speak("اليوم $dayName، ${now.day} $monthName ${now.year}");
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
                  fontSize: 100,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // الدائرة المتغيرة حسب الحالة
              Container(
                width: 250,
                height: 250,
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
                child: Icon(
                  centerIcon,
                  color: Colors.white,
                  size: 120,
                ),
              ),
              
              const SizedBox(height: 40),
              
              Text(
                statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
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
                      fontSize: 22,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              const Spacer(),
              
              const Text(
                "تكلم بأي وقت، أنا أستمع",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
              
              const SizedBox(height: 10),
              
              const Text(
                "AYN v1.2 — Always Listening",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
