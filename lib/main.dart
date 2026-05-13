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
      _statusMessage = _speechAvailable 
          ? "اضغط الميكروفون للتحدث" 
          : "استخدم الأزرار أدناه";
    });
    
    await _speak("أهلاً يا مجد الدين، أنا عَيْن، مساعدك الذكي");
    await Future.delayed(const Duration(seconds: 1));
    
    if (_speechAvailable) {
      await _speak("اضغط الميكروفون الكبير وتحدث، أو استخدم الأزرار في الأسفل");
    } else {
      await _speak("استخدم الأزرار الكبيرة في الشاشة، اضغط على أي زر للأمر");
    }
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
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          print("Speech error: ${error.errorMsg}");
        },
        onStatus: (status) {
          print("Speech status: $status");
        },
      );
    } catch (e) {
      _speechAvailable = false;
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
  
  Future<void> _startListening() async {
    if (!_speechAvailable) {
      await _speak("الاستماع غير متاح، استخدم الأزرار من فضلك");
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
      onResult: (result) {
        if (result.finalResult) {
          setState(() {
            _lastWords = result.recognizedWords;
            _isListening = false;
            _statusMessage = "جاهز";
          });
          _processCommand(result.recognizedWords);
        }
      },
      localeId: "ar-SA",
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );
  }
  
  Future<void> _processCommand(String command) async {
    final cmd = command.toLowerCase().trim();
    
    await _vibrate(duration: 100);
    
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
      await _speak("لم أفهم، استخدم الأزرار من فضلك");
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
  
  Future<void> _greetCommand() async {
    await _vibrate(duration: 100);
    await _speak("أهلاً وسهلاً يا مجد الدين، كيف حالك");
  }
  
  Future<void> _introCommand() async {
    await _vibrate(duration: 100);
    await _speak("أنا عَيْن، مساعد ذكي للأشخاص ذوي الإعاقة البصرية");
  }
  
  Future<void> _countCommand() async {
    await _vibrate(duration: 100);
    await _speak("واحد، اثنان، ثلاثة، أربعة، خمسة");
  }
  
  Future<void> _thanksCommand() async {
    await _vibrate(duration: 100);
    await _speak("على الرحب والسعة، أنا هنا لمساعدتك");
  }
  
  Future<void> _stopCommand() async {
    await _vibrate(duration: 50);
    await _tts.stop();
  }
  
  @override
  void dispose() {
    _tts.stop();
    _speech.stop();
    super.dispose();
  }
  
  Widget _buildCommandButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 36),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              
              const Text(
                "عَيْن",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 70,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 10),
              
              // الميكروفون - يعمل لمن لديه إعدادات صوت جاهزة
              GestureDetector(
                onTap: _startListening,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening 
                        ? Colors.red.shade700 
                        : (_speechAvailable ? Colors.blue.shade700 : Colors.grey.shade800),
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                    size: 70,
                  ),
                ),
              ),
              
              const SizedBox(height: 10),
              
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              
              const SizedBox(height: 20),
              
              const Text(
                "أو اضغط على الأمر مباشرة:",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              
              const SizedBox(height: 12),
              
              // شبكة الأزرار
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    _buildCommandButton(
                      label: "كم الساعة",
                      icon: Icons.access_time,
                      color: Colors.blue.shade700,
                      onTap: _tellTime,
                    ),
                    _buildCommandButton(
                      label: "مرحبا",
                      icon: Icons.waving_hand,
                      color: Colors.green.shade700,
                      onTap: _greetCommand,
                    ),
                    _buildCommandButton(
                      label: "من أنت",
                      icon: Icons.info,
                      color: Colors.purple.shade700,
                      onTap: _introCommand,
                    ),
                    _buildCommandButton(
                      label: "عد لي",
                      icon: Icons.format_list_numbered,
                      color: Colors.orange.shade700,
                      onTap: _countCommand,
                    ),
                    _buildCommandButton(
                      label: "شكرا",
                      icon: Icons.favorite,
                      color: Colors.pink.shade700,
                      onTap: _thanksCommand,
                    ),
                    _buildCommandButton(
                      label: "اسكت",
                      icon: Icons.volume_off,
                      color: Colors.red.shade700,
                      onTap: _stopCommand,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 10),
              
              const Text(
                "AYN v1.1 — Majd Aldin",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
