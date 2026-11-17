import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'core/theme.dart';
import 'data/app_database.dart';
import 'data/download_service.dart';
import 'data/quran_repository.dart';
import 'data/settings_service.dart';
import 'features/audio/audio_controller.dart';
import 'features/audio/wird_audio_handler.dart';
import 'features/home/home_screen.dart';
import 'features/player/player_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repo = QuranRepository();
  await repo.load();

  final db = AppDatabase();
  final settings = SettingsService();
  await settings.load();
  await db.setDailyTarget(settings.dailyTarget);

  final downloads = DownloadService();

  // معالج الصوت الخلفي (خدمة أمامية على Android). عند تعذّر التهيئة
  // (بيئات الاختبار مثلًا) نكمل بمعالج مباشر دون خدمة خلفية.
  WirdAudioHandler handler;
  try {
    handler = await AudioService.init(
      builder: () => WirdAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.tayeb.wird.audio',
        androidNotificationChannelName: 'تلاوة اِقْرَأْ وَارْتَقِ',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (_) {
    handler = WirdAudioHandler();
  }

  final audio = AudioController(handler: handler, repo: repo, downloads: downloads);
  final appState = AppState(db, settings: settings);
  appState.ayahCountResolver = (n) => repo.surah(n).ayahCount;
  // آخر موضع يتبع التلاوة الجارية فعليًا، لا موضع فتح السورة فقط.
  audio.onPositionChanged = (surah, ayah) {
    appState
        .recordPosition(surah, ayah, cleanSurahName(repo.surah(surah)))
        .catchError((_) {});
  };
  // انتهاء خطة التكرار (طبيعيًا أو بالإيقاف) ينهي جلستها المسجلة.
  audio.onRepetitionFinished = () {
    appState.endSession(owner: AppState.repetitionSessionOwner).catchError((_) {});
  };
  await appState.loadLastPosition();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: QuranRepositoryProxy(repo)),
        Provider.value(value: db),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: downloads),
        ChangeNotifierProvider.value(value: audio),
        ChangeNotifierProvider.value(value: appState),
      ],
      child: const WirdApp(),
    ),
  );
}

class WirdApp extends StatelessWidget {
  const WirdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'اِقْرَأْ وَارْتَقِ',
      debugShowCheckedModeBanner: false,
      theme: buildWirdTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashGate(),
    );
  }
}

/// شاشة البداية: شعار وهوية، ثم الشاشة الرئيسية مع شريط المشغّل الدائم.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                WirdColors.pink,
                WirdColors.deepRose,
                Color(0xFF880E4F),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book, size: 84, color: Colors.white),
                SizedBox(height: 14),
                Text('اِقْرَأْ وَارْتَقِ',
                    style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text('القرآن الكريم للحفظ والمراجعة',
                    style: TextStyle(fontSize: 18, color: WirdColors.lightPink)),
              ],
            ),
          ),
        ),
      );
    }
    return const Scaffold(
      body: HomeScreen(),
      bottomNavigationBar: PlayerBar(),
    );
  }
}
