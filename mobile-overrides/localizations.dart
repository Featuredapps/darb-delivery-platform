import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);
  static const supportedLocales = [Locale('ar'), Locale('en'), Locale('tr')];
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  static const LocalizationsDelegate<AppLocalizations> delegate = _DarbLocalizationsDelegate();

  String t(String key) => (_values[locale.languageCode] ?? _values['ar']!)[key] ?? key;
  static const Map<String, Map<String, String>> _values = {
    'ar': {
      'welcomeTitle':'أهلاً بك في دَرْب','welcomeSubtitle':'طريقك الأسهل لاكتشاف المتاجر وطلب ما تحتاجه',
      'featureStores':'متاجر','featureDelivery':'توصيل','featureNearby':'على دربك',
      'phoneTitle':'سجّل الدخول برقم هاتفك','phoneSubtitle':'سنرسل إليك رمز تحقق لمرة واحدة',
      'phoneLabel':'رقم الهاتف السوري','sendOtp':'إرسال رمز التحقق','or':'أو المتابعة عبر',
      'google':'المتابعة باستخدام Google','secure':'بياناتك محمية ونستخدم رقمك لتأكيد هويتك',
      'invalidPhone':'أدخل رقمًا سوريًا صحيحًا يبدأ بـ 09 ويتكون من 10 أرقام',
      'networkError':'تعذر إتمام الطلب. تحقق من اتصالك وحاول مجددًا.',
      'googleUnavailable':'تسجيل Google غير مفعّل على الخادم حاليًا. استخدم رقم الهاتف.',
      'googleFailed':'تعذر تسجيل الدخول باستخدام Google. حاول مجددًا.',
      'otpTitle':'تحقق من رقمك','otpSubtitle':'أدخل رمز التحقق الذي وصلك برسالة نصية',
      'otpLabel':'رمز التحقق','nameLabel':'الاسم (اختياري)','verify':'تأكيد الدخول',
      'changePhone':'تغيير رقم الهاتف','invalidOtp':'أدخل رمز التحقق المكوّن من 6 أرقام',
    },
    'en': {
      'welcomeTitle':'Welcome to DARB','welcomeSubtitle':'Your easier way to discover stores and order what you need',
      'featureStores':'Stores','featureDelivery':'Delivery','featureNearby':'Nearby',
      'phoneTitle':'Sign in with your phone','phoneSubtitle':'We will send you a one-time verification code',
      'phoneLabel':'Syrian phone number','sendOtp':'Send verification code','or':'Or continue with',
      'google':'Continue with Google','secure':'Your information is protected and your number verifies your identity',
      'invalidPhone':'Enter a valid Syrian number starting with 09 and containing 10 digits',
      'networkError':'Could not complete the request. Check your connection and try again.',
      'googleUnavailable':'Google sign-in is not enabled on the server yet. Use your phone number.',
      'googleFailed':'Google sign-in failed. Please try again.',
      'otpTitle':'Verify your number','otpSubtitle':'Enter the verification code sent by SMS',
      'otpLabel':'Verification code','nameLabel':'Name (optional)','verify':'Verify and continue',
      'changePhone':'Change phone number','invalidOtp':'Enter the 6-digit verification code',
    },
    'tr': {
      'welcomeTitle':"DARB'a hoş geldiniz",'welcomeSubtitle':'İhtiyacınız olanı keşfetmenin ve sipariş etmenin kolay yolu',
      'featureStores':'Mağazalar','featureDelivery':'Teslimat','featureNearby':'Yakınında',
      'phoneTitle':'Telefon numaranızla giriş yapın','phoneSubtitle':'Size tek kullanımlık doğrulama kodu göndereceğiz',
      'phoneLabel':'Suriye telefon numarası','sendOtp':'Doğrulama kodu gönder','or':'Veya şununla devam et',
      'google':"Google ile devam et",'secure':'Bilgileriniz korunur; numaranız kimliğinizi doğrulamak için kullanılır',
      'invalidPhone':'09 ile başlayan ve 10 rakam içeren geçerli bir Suriye numarası girin',
      'networkError':'İşlem tamamlanamadı. Bağlantınızı kontrol edip tekrar deneyin.',
      'googleUnavailable':'Google ile giriş henüz sunucuda etkin değil. Telefon numaranızı kullanın.',
      'googleFailed':'Google ile giriş başarısız. Lütfen tekrar deneyin.',
      'otpTitle':'Numaranızı doğrulayın','otpSubtitle':'SMS ile gönderilen doğrulama kodunu girin',
      'otpLabel':'Doğrulama kodu','nameLabel':'Ad (isteğe bağlı)','verify':'Doğrula ve devam et',
      'changePhone':'Telefon numarasını değiştir','invalidOtp':'6 haneli doğrulama kodunu girin',
    },
  };
}

class _DarbLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _DarbLocalizationsDelegate();
  @override bool isSupported(Locale locale) => ['ar','en','tr'].contains(locale.languageCode);
  @override Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);
  @override bool shouldReload(_DarbLocalizationsDelegate old) => false;
}

