import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/api.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'localizations.dart';
import 'notifications.dart';

const ink = Color(0xFF12302A);
const green = Color(0xFF167A5A);
const paper = Color(0xFFF6F6F3);
final ValueNotifier<Locale> darbLocale = ValueNotifier(const Locale('ar'));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DarbNotifications.initialize();
  await Api.instance.restore();
  runApp(const DarbApp());
}

class DarbApp extends StatelessWidget {
  const DarbApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: darbLocale,
    builder: (context, locale, _) => MaterialApp(
      title: 'دَرْب', debugShowCheckedModeBanner: false, locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true, scaffoldBackgroundColor: paper,
        colorScheme: ColorScheme.fromSeed(seedColor: green, primary: green, surface: Colors.white),
        fontFamily: 'Arial',
        appBarTheme: const AppBarTheme(backgroundColor: paper, foregroundColor: ink, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFD0D7D4))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      home: Api.instance.accessToken == null ? const LoginScreen() : const AppShell(),
    ),
  );
}

