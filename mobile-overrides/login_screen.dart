import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/api.dart';
import '../main.dart';
import '../localizations.dart';
import 'app_shell.dart';

const _ink = Color(0xFF12302A);
const _green = Color(0xFF167A5A);
const _red = Color(0xFFD64545);
const _muted = Color(0xFF687A75);
const _border = Color(0xFFD0D7D4);
const _success = Color(0xFF2E7D32);
const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final phone = TextEditingController();
  final code = TextEditingController();
  final name = TextEditingController();
  bool sent = false, busy = false, googleLoading = false;
  String? error;
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _shakeX = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: -9), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -9, end: 9), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 9, end: -6), weight: 2),
    TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
  ]).animate(CurvedAnimation(parent: _shake, curve: Curves.easeOut));
  bool get validPhone => RegExp(r'^09[3-9][0-9]{7}$').hasMatch(phone.text.replaceAll(RegExp(r'\D'), ''));
  String get digits => phone.text.replaceAll(RegExp(r'\D'), '');
  bool get authenticating => busy || googleLoading;

  @override void dispose() {
    phone.dispose(); code.dispose(); name.dispose(); _shake.dispose(); super.dispose();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => error = message);
    _shake.forward(from: 0);
    HapticFeedback.mediumImpact();
  }

  Future<void> requestCode() async {
    final l = AppLocalizations.of(context);
    if (!validPhone) { _fail(l.t('invalidPhone')); return; }
    FocusScope.of(context).unfocus();
    setState(() { busy = true; error = null; });
    try {
      await Api.instance.post('/auth/otp/request', {'phone': '+963${digits.substring(1)}'});
      if (mounted) setState(() => sent = true);
    } on ApiException catch (e) {
      _fail(e.message);
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail(l.t('networkError'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verify() async {
    final l = AppLocalizations.of(context);
    if (code.text.trim().length != 6) { _fail(l.t('invalidOtp')); return; }
    FocusScope.of(context).unfocus();
    setState(() { busy = true; error = null; });
    try {
      final result = await Api.instance.post('/auth/otp/verify', {
        'phone': '+963${digits.substring(1)}', 'code': code.text.trim(),
        'name': name.text.trim().isEmpty ? null : name.text.trim(),
        'locale': darbLocale.value.languageCode,
      });
      await Api.instance.saveTokens(Map<String, dynamic>.from(result['tokens'] as Map));
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    } catch (_) {
      _fail(l.t('networkError'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final l = AppLocalizations.of(context);
    if (authenticating) return;
    var stage = 'GOOGLE_ACCOUNT_PICKER';
    setState(() { googleLoading = true; error = null; });
    try {
      if (_googleServerClientId.isEmpty) {
        throw StateError('GOOGLE_SERVER_CLIENT_ID is missing from this release build');
      }
      final google = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: _googleServerClientId,
      );
      final account = await google.signIn();
      if (account == null) return;
      stage = 'GOOGLE_ID_TOKEN';
      final authentication = await account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google returned no ID token. Check Android OAuth package name and release SHA-1.');
      }
      stage = 'BACKEND_AUTH_GOOGLE';
      final result = await Api.instance.post('/auth/google', {'idToken': idToken, 'locale': darbLocale.value.languageCode});
      stage = 'SAVE_SESSION';
      await Api.instance.saveTokens(Map<String, dynamic>.from(result['tokens'] as Map));
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    } catch (e) {
      final detail = e.toString().replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
      final safeDetail = detail.length > 220 ? detail.substring(0, 220) : detail;
      _fail('فشل تسجيل Google عند المرحلة $stage\n$safeDetail');
    } finally {
      if (mounted) setState(() => googleLoading = false);
    }
  }

  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isArabic = darbLocale.value.languageCode == 'ar';
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F3),
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) =>
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AnimatedBuilder(animation: _shake, builder: (context, child) =>
              Transform.translate(offset: Offset(_shakeX.value, 0), child: child),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  _languageChip('AR', const Locale('ar')),
                  const SizedBox(width: 7),
                  _languageChip('EN', const Locale('en')),
                  const SizedBox(width: 7),
                  _languageChip('TR', const Locale('tr')),
                ]),
                const SizedBox(height: 27),
                Center(child: Container(
                  width: 104, height: 104,
                  decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: _ink.withOpacity(.18), blurRadius: 22, offset: const Offset(0, 10))]),
                  alignment: Alignment.center,
                  child: Text(isArabic ? 'دَرْب' : 'DARB', style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
                )),
                const SizedBox(height: 25),
                Text(l.t('welcomeTitle'), textAlign: TextAlign.center,
                  style: const TextStyle(color: _ink, fontSize: 27, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(l.t('welcomeSubtitle'), textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 14, height: 1.6)),
                const SizedBox(height: 34),
                Text(sent ? l.t('otpTitle') : l.t('phoneTitle'),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                Text(sent ? l.t('otpSubtitle') : l.t('phoneSubtitle'),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(color: _muted, fontSize: 13)),
                const SizedBox(height: 17),
                if (!sent) ...[
                  Text(l.t('phoneLabel'), style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _phoneField(l),
                ] else ...[
                  TextField(controller: code, keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr, textAlign: TextAlign.center, maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    style: const TextStyle(fontSize: 23, letterSpacing: 9, fontWeight: FontWeight.w800, color: _ink),
                    decoration: _decoration(l.t('otpLabel'))),
                  const SizedBox(height: 12),
                  TextField(controller: name, decoration: _decoration(l.t('nameLabel'))),
                  Align(alignment: AlignmentDirectional.centerStart,
                    child: TextButton(onPressed: authenticating ? null : () => setState(() { sent = false; code.clear(); error = null; }),
                      child: Text(l.t('changePhone')))),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Container(padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(13)),
                    child: Row(children: [const Icon(Icons.error_outline, color: _red, size: 19),
                      const SizedBox(width: 8), Expanded(child: Text(error!, style: const TextStyle(color: _red, fontSize: 12, height: 1.4)))])),
                ],
                const SizedBox(height: 18),
                SizedBox(height: 56, child: FilledButton(
                  onPressed: authenticating || (!sent && !validPhone) ? null : (sent ? verify : requestCode),
                  style: FilledButton.styleFrom(backgroundColor: _green, disabledBackgroundColor: const Color(0xFFB7C9C1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                    : Text(sent ? l.t('verify') : l.t('sendOtp'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                )),
                if (!sent) ...[
                  const SizedBox(height: 22),
                  Row(children: [const Expanded(child: Divider(color: _border)), Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    child: Text(l.t('or'), style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
                    const Expanded(child: Divider(color: _border))]),
                  const SizedBox(height: 17),
                  SizedBox(height: 56, child: OutlinedButton(
                    onPressed: authenticating ? null : _handleGoogleSignIn,
                    style: OutlinedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _ink,
                      side: const BorderSide(color: _border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: googleLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _green))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          _googleMark(), const SizedBox(width: 11),
                          Text(l.t('google'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        ]),
                  )),
                ],
                const SizedBox(height: 27),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.lock_outline, size: 14, color: _muted), const SizedBox(width: 7),
                  Flexible(child: Text(l.t('secure'), textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 11))),
                ]),
              ]),
            ),
          )),
        ),
      )),
    );
  }

  Widget _languageChip(String label, Locale locale) {
    final selected = darbLocale.value.languageCode == locale.languageCode;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: authenticating ? null : () => darbLocale.value = locale,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(color: selected ? _ink : Colors.white, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _ink : _border)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
          color: selected ? Colors.white : _muted))),
    );
  }

  Widget _phoneField(AppLocalizations l) => Directionality(
    textDirection: TextDirection.ltr,
    child: Container(
      height: 62, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: validPhone ? _success : _border, width: validPhone ? 1.6 : 1)),
      child: Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 13), height: double.infinity,
          decoration: const BoxDecoration(border: Border(right: BorderSide(color: _border))),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Text('🇸🇾', style: TextStyle(fontSize: 20)), SizedBox(width: 7),
            Text('+963', style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
          ])),
        Expanded(child: TextField(
          controller: phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr,
          textAlign: TextAlign.left, enabled: !authenticating,
          inputFormatters: [SyrianPhoneFormatter()],
          style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: .4),
          decoration: InputDecoration(hintText: '09X XXX XXXX', hintStyle: const TextStyle(color: Color(0xFF9AA7A2)),
            border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14)),
          onChanged: (_) => setState(() { error = null; }),
        )),
        if (validPhone) const Padding(padding: EdgeInsetsDirectional.only(end: 13),
          child: Icon(Icons.check_circle_rounded, color: _success, size: 21)),
      ]),
    ),
  );

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label, filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _green, width: 1.6)),
  );

  Widget _googleMark() => Container(width: 25, height: 25, alignment: Alignment.center,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE8ECEA))),
    child: const Text('G', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))));
}

class SyrianPhoneFormatter extends TextInputFormatter {
  @override TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll(RegExp(r'\D'), '');
    final digits = raw.length > 10 ? raw.substring(0, 10) : raw;
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) out.write(' ');
      out.write(digits[i]);
    }
    final text = out.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
