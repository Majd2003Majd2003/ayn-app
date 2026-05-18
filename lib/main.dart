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
    
    setState(() => _statusMessage = "جاهز");
    
    await _speak("أهلاً يا مجد الدين، أنا عَيْن، النسخة الثالثة");
    await Future.delayed(const Duration(milliseconds: 800));
    await _speak("يمكنني إخبارك بالوقت والتاريخ، حساب العمليات، أو حساب القبلة");
    
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
              if (!_isListening && !_isSpeaking) _startContinuousListening();
            });
          }
        },
        onStatus: (status) {
          if (status == "done" || status == "notListening") {
            setState(() => _isListening = false);
            if (_autoListenEnabled && !_isSpeaking) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (!_isListening && !_isSpeaking) _startContinuousListening();
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
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }
    await _tts.speak(text);
  }
  
  Future<void> _vibrate({int duration = 80}) async {
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator) Vibration.vibrate(duration: duration);
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
    else if (cmd.contains("التاريخ") || cmd.contains("اليوم") || 
             cmd.contains("شو اليوم")) {
      await _tellDate();
    }
    else if (cmd.contains("القبلة") || cmd.contains("قبلة")) {
      await _tellQiblaInfo();
    }
    else if (cmd.contains("مرحبا") || cmd.contains("اهلا") || cmd.contains("هلا") ||
             cmd.contains("سلام") || cmd.contains("صباح") || cmd.contains("مساء")) {
      await _greetWithTime();
    }
    else if (cmd.contains("كيف حالك") || cmd.contains("كيفك") || 
             cmd.contains("شلونك")) {
      await _speak("الحمد لله أنا بخير، كيف يمكنني مساعدتك");
    }
    else if (cmd.contains("اسمك") || cmd.contains("من انت") || 
             cmd.contains("شو انت")) {
      await _speak("أنا عَيْن، مساعد ذكي للأشخاص ذوي الإعاقة البصرية، مشروع المهندس مجد الدين الدكاك");
    }
    else if (cmd.contains("شكرا") || cmd.contains("شكر") || cmd.contains("مشكور")) {
      await _speak("على الرحب والسعة، أنا هنا لمساعدتك دائماً");
    }
    else if (cmd.contains("عد لي") || cmd.contains("احسب") || cmd.contains("عد")) {
      await _speak("واحد، اثنان، ثلاثة، أربعة، خمسة، ستة، سبعة، ثمانية، تسعة، عشرة");
    }
    else if (cmd.contains("جمع") && _hasNumbers(cmd)) {
      await _calculateAdd(cmd);
    }
    else if ((cmd.contains("ناقص") || cmd.contains("طرح")) && _hasNumbers(cmd)) {
      await _calculateSubtract(cmd);
    }
    else if ((cmd.contains("ضرب") || cmd.contains("في")) && _hasNumbers(cmd)) {
      await _calculateMultiply(cmd);
    }
    else if (cmd.contains("كم يوم") || cmd.contains("كم باقي") || 
             cmd.contains("متى رمضان") || cmd.contains("متى العيد")) {
      await _tellDaysUntilEvent(cmd);
    }
    else if (cmd.contains("الفصل") || cmd.contains("شو الفصل") || 
             cmd.contains("فصل")) {
      await _tellSeason();
    }
    else if (cmd.contains("الشهر") || cmd.contains("شو الشهر")) {
      await _tellMonth();
    }
    else if (cmd.contains("ساعدني") || cmd.contains("الاوامر") || cmd.contains("اوامر")) {
      await _tellHelp();
    }
    else if (cmd.contains("اسكت") || cmd.contains("توقف")) {
      await _tts.stop();
    }
    else {
      await _speak("لم أفهم، اسألني عن الوقت أو التاريخ أو القبلة أو قل ساعدني");
    }
  }
  
  // ==================== الوظائف ====================
  
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
  
  Future<void> _tellQiblaInfo() async {
    await _speak("اتجاه القبلة من سوريا نحو الجنوب الشرقي تقريباً، استدر بحوالي خمسة وستين درجة شرق الجنوب");
  }
  
  Future<void> _greetWithTime() async {
    final hour = DateTime.now().hour;
    String greeting;
    
    if (hour >= 5 && hour < 12) {
      greeting = "صباح الخير يا مجد الدين، نهارك سعيد";
    } else if (hour >= 12 && hour < 17) {
      greeting = "نهارك مبارك يا مجد الدين";
    } else if (hour >= 17 && hour < 21) {
      greeting = "مساء الخير يا مجد الدين";
    } else {
      greeting = "مساء النور يا مجد الدين";
    }
    
    await _speak(greeting);
  }
  
  Future<void> _tellSeason() async {
    final month = DateTime.now().month;
    String season;
    
    if (month >= 3 && month <= 5) {
      season = "نحن الآن في فصل الربيع";
    } else if (month >= 6 && month <= 8) {
      season = "نحن الآن في فصل الصيف";
    } else if (month >= 9 && month <= 11) {
      season = "نحن الآن في فصل الخريف";
    } else {
      season = "نحن الآن في فصل الشتاء";
    }
    
    await _speak(season);
  }
  
  Future<void> _tellMonth() async {
    final months = ["كانون الثاني يناير", "شباط فبراير", "آذار مارس", 
                    "نيسان أبريل", "أيار مايو", "حزيران يونيو",
                    "تموز يوليو", "آب أغسطس", "أيلول سبتمبر", 
                    "تشرين الأول أكتوبر", "تشرين الثاني نوفمبر", "كانون الأول ديسمبر"];
    final now = DateTime.now();
    await _speak("نحن في شهر ${months[now.month - 1]}");
  }
  
  Future<void> _tellHelp() async {
    await _speak("يمكنك أن تقول: كم الساعة، شو التاريخ، اتجاه القبلة، شو الفصل، شو الشهر، أو اطلب جمع أو طرح أرقام");
  }
  
  Future<void> _tellDaysUntilEvent(String cmd) async {
    final now = DateTime.now();
    DateTime? eventDate;
    String eventName = "";
    
    if (cmd.contains("رمضان")) {
      eventDate = DateTime(now.year, 3, 1);
      if (eventDate.isBefore(now)) eventDate = DateTime(now.year + 1, 3, 1);
      eventName = "شهر رمضان";
    } else if (cmd.contains("عيد") && cmd.contains("فطر")) {
      eventDate = DateTime(now.year, 4, 1);
      if (eventDate.isBefore(now)) eventDate = DateTime(now.year + 1, 4, 1);
      eventName = "عيد الفطر";
    } else if (cmd.contains("سنة جديدة") || cmd.contains("راس السنة")) {
      eventDate = DateTime(now.year + 1, 1, 1);
      eventName = "رأس السنة";
    } else if (cmd.contains("نهاية الاسبوع")) {
      final daysUntilFriday = (DateTime.friday - now.weekday + 7) % 7;
      eventDate = now.add(Duration(days: daysUntilFriday));
      eventName = "نهاية الأسبوع";
    }
    
    if (eventDate != null) {
      final days = eventDate.difference(now).inDays;
      await _speak("باقي $days يوم على $eventName");
    } else {
      await _speak("لم أفهم المناسبة، حاول قول كم باقي على رمضان أو على العيد");
    }
  }
  
  bool _hasNumbers(String text) {
    return RegExp(r'\d').hasMatch(text) || 
           text.contains("واحد") || text.contains("اثنين") || text.contains("ثلاثة") ||
           text.contains("اربعة") || text.contains("خمسة") || text.contains("ستة") ||
           text.contains("سبعة") || text.contains("ثمانية") || text.contains("تسعة") ||
           text.contains("عشرة");
  }
  
  int _extractNumber(String text) {
    final match = RegExp(r'\d+').firstMatch(text);
    if (match != null) return int.parse(match.group(0)!);
    
    if (text.contains("واحد")) return 1;
    if (text.contains("اثنين") || text.contains("اثنان")) return 2;
    if (text.contains("ثلاثة") || text.contains("ثلاث")) return 3;
    if (text.contains("اربعة") || text.contains("اربع")) return 4;
    if (text.contains("خمسة") || text.contains("خمس")) return 5;
    if (text.contains("ستة") || text.contains("ست")) return 6;
    if (text.contains("سبعة") || text.contains("سبع")) return 7;
    if (text.contains("ثمانية") || text.contains("ثمان")) return 8;
    if (text.contains("تسعة") || text.contains("تسع")) return 9;
    if (text.contains("عشرة") || text.contains("عشر")) return 10;
    
    return 0;
  }
  
  Future<void> _calculateAdd(String cmd) async {
    final numbers = RegExp(r'\d+').allMatches(cmd).map((m) => int.parse(m.group(0)!)).toList();
    if (numbers.length >= 2) {
      final result = numbers.reduce((a, b) => a + b);
      await _speak("${numbers.join(' زائد ')} يساوي $result");
    } else {
      await _speak("قل مثلاً جمع خمسة زائد ثلاثة");
    }
  }
  
  Future<void> _calculateSubtract(String cmd) async {
    final numbers = RegExp(r'\d+').allMatches(cmd).map((m) => int.parse(m.group(0)!)).toList();
    if (numbers.length >= 2) {
      final result = numbers[0] - numbers[1];
      await _speak("${numbers[0]} ناقص ${numbers[1]} يساوي $result");
    } else {
      await _speak("قل مثلاً عشرة ناقص ثلاثة");
    }
  }
  
  Future<void> _calculateMultiply(String cmd) async {
    final numbers = RegExp(r'\d+').allMatches(cmd).map((m) => int.parse(m.group(0)!)).toList();
    if (numbers.length >= 2) {
      final result = numbers[0] * numbers[1];
      await _speak("${numbers[0]} ضرب ${numbers[1]} يساوي $result");
    } else {
      await _speak("قل مثلاً خمسة ضرب اثنين");
    }
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
                child: Icon(centerIcon, color: Colors.white, size: 120),
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
                    style: const TextStyle(color: Colors.white, fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              const Spacer(),
              
              const Text(
                "تكلم بأي وقت، أنا أستمع",
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              
              const SizedBox(height: 10),
              
              const Text(
                "AYN v1.3 — Smart Edition",
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
