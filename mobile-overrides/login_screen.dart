import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import 'app_shell.dart';

const _ink = Color(0xFF12302A);
const _green = Color(0xFF167A5A);
const _canvas = Color(0xFFF6F7F4);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final phone = TextEditingController();
  final code = TextEditingController();
  final name = TextEditingController();
  bool sent = false, busy = false;
  String? error;
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))..forward();

  @override
  void dispose() {
    phone.dispose(); code.dispose(); name.dispose(); _intro.dispose();
    super.dispose();
  }

  String get normalizedPhone => phone.text.replaceAll(RegExp(r'[^0-9]'), '');
  bool get validPhone => RegExp(r'^09[3-9][0-9]{7}$').hasMatch(normalizedPhone);

  Future<void> requestCode() async {
    if (!validPhone) {
      setState(() => error = 'أدخل رقم هاتف سوري صحيحاً يبدأ بـ 09 ويتكون من 10 أرقام');
      HapticFeedback.mediumImpact();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() { busy = true; error = null; });
    try {
      await Api.instance.post('/auth/otp/request', {'phone': normalizedPhone});
      if (mounted) setState(() => sent = true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verify() async {
    if (code.text.trim().length != 6) {
      setState(() => error = 'أدخل رمز التحقق المكوّن من 6 أرقام');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() { busy = true; error = null; });
    try {
      final result = await Api.instance.post('/auth/otp/verify', {
        'phone': normalizedPhone,
        'code': code.text.trim(),
        'name': name.text.trim().isEmpty ? null : name.text.trim(),
        'locale': 'ar',
      });
      await Api.instance.saveTokens(Map<String, dynamic>.from(result['tokens'] as Map));
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint, Widget? prefix, Widget? suffix}) => InputDecoration(
    labelText: label, hintText: hint, prefixIcon: prefix, suffixIcon: suffix,
    filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFFDCE4DF))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFFDCE4DF))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: _green, width: 1.7)),
  );

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 42),
          child: FadeTransition(opacity: CurvedAnimation(parent: _intro, curve: Curves.easeOut),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Align(alignment: AlignmentDirectional.centerStart, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFFE3E9E5))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shield_outlined, size: 16, color: _green), SizedBox(width: 6),
                  Text('دخول آمن برقم الهاتف', style: TextStyle(fontSize: 12, color: _ink, fontWeight: FontWeight.w600)),
                ]),
              )),
              const SizedBox(height: 46),
              Center(child: Container(
                width: 112, height: 112,
                decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: _ink.withOpacity(.17), blurRadius: 25, offset: const Offset(0, 12))]),
                child: const Center(child: Text('دَرْب', style: TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900, letterSpacing: -1))),
              )),
              const SizedBox(height: 27),
              const Text('أهلاً بك في دَرْب', textAlign: TextAlign.center, style: TextStyle(color: _ink, fontSize: 27, fontWeight: FontWeight.w900)),
              const SizedBox(height: 9),
              const Text('طريقك الأسهل لاكتشاف المتاجر وطلب ما تحتاجه', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF718079), fontSize: 14, height: 1.6)),
              const SizedBox(height: 42),
              Text(sent ? 'تحقق من رقمك' : 'سجّل الدخول للمتابعة', style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(sent ? 'أدخل الرمز الذي وصلك برسالة نصية' : 'سنرسل إليك رمز تحقق لمرة واحدة', style: const TextStyle(color: Color(0xFF78857F), fontSize: 13)),
              const SizedBox(height: 20),
              if (!sent) TextField(
                controller: phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                decoration: _decoration('رقم الهاتف السوري', hint: '09XXXXXXXX', prefix: const Padding(padding: EdgeInsets.symmetric(horizontal: 13), child: Center(widthFactor: 1, child: Text('+963', style: TextStyle(color: _ink, fontWeight: FontWeight.bold))))),
                onChanged: (_) { if (error != null) setState(() => error = null); },
              ) else ...[
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFEAF2ED), borderRadius: BorderRadius.circular(15)), child: Row(children: [
                  const Icon(Icons.phone_iphone, color: _green), const SizedBox(width: 10),
                  Expanded(child: Text('+963 $normalizedPhone', textDirection: TextDirection.ltr, style: const TextStyle(color: _ink, fontWeight: FontWeight.bold))),
                  TextButton(onPressed: busy ? null : () => setState(() { sent = false; code.clear(); error = null; }), child: const Text('تغيير')),
                ])),
                const SizedBox(height: 13),
                TextField(controller: code, keyboardType: TextInputType.number, textAlign: TextAlign.center, textDirection: TextDirection.ltr, maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  style: const TextStyle(fontSize: 23, letterSpacing: 9, fontWeight: FontWeight.w800, color: _ink),
                  decoration: _decoration('رمز التحقق', hint: '••••••')),
                const SizedBox(height: 8),
                TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: _decoration('الاسم (اختياري)', hint: 'كيف نناديك؟')),
              ],
              if (error != null) ...[
                const SizedBox(height: 13),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(13)), child: Row(children: [
                  const Icon(Icons.error_outline, color: Color(0xFFD64545), size: 19), const SizedBox(width: 8),
                  Expanded(child: Text(error!, style: const TextStyle(color: Color(0xFFB83232), fontSize: 12, height: 1.4))),
                ])),
              ],
              const SizedBox(height: 20),
              SizedBox(height: 57, child: FilledButton(
                onPressed: busy ? null : (sent ? verify : requestCode),
                style: FilledButton.styleFrom(backgroundColor: _green, disabledBackgroundColor: const Color(0xFF9AB8AA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)), elevation: 0),
                child: busy ? const SizedBox(width: 23, height: 23, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(sent ? 'تأكيد الدخول' : 'إرسال رمز التحقق', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 9), const Icon(Icons.arrow_back_rounded, size: 19),
                  ]),
              )),
              const SizedBox(height: 24),
              const SizedBox(height: 34),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_outline, size: 14, color: Color(0xFF8A9690)), SizedBox(width: 6),
                Text('بياناتك محمية ولا نشارك رقمك مع المتاجر', style: TextStyle(fontSize: 11, color: Color(0xFF8A9690))),
              ]),
              const SizedBox(height: 10),
              const Text('بمتابعتك، أنت توافق على شروط الاستخدام وسياسة الخصوصية', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Color(0xFFA0AAA4))),
            ]),
          ),
        ),
      ))),
    ),
  );
}
