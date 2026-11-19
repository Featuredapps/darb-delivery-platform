import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/api.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'localizations.dart';
import 'notifications.dart';
import 'design_system.dart';

const ink = DarbColors.forest;
const green = DarbColors.forestSoft;
const paper = DarbColors.canvas;
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
      theme: DarbTheme.light,
      home: Api.instance.accessToken == null ? const LoginScreen() : const AppShell(),
    ),
  );
}

