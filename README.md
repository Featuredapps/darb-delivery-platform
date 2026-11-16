# دَرْب | DARB

منصة توصيل متعددة الأدوار: عميل، بائع، سائق، وإدارة.

المصدر الكامل للمشروع موجود ضمن مجلدي `backend/` و`mobile/` داخل الأرشيف `DARB-source.zip`.

## حالة التحقق

تم التحقق من بناء Backend packages وبناء تطبيق Flutter Android بنجاح في GitHub Actions بتاريخ 2026-11-16.

- Workflow run: [43817595520](https://github.com/Featuredapps/darb-delivery-platform/actions/runs/43817595520)
- النتيجة: نجاح جميع خطوات البناء.
- ناتج Android: APK من نوع Debug، وليس إصدار Release موقعاً للنشر.
- تم إصلاح Android platform scaffold الناقص أثناء CI وإنتاج أرشيف مصدر مصحح كـ artifact منفصل.
- لم يتم استبدال `DARB-source.zip` الأصلي في المستودع بهذا التشغيل.

## تنزيل المخرجات

تتوفر مخرجات البناء من صفحة [GitHub Actions run](https://github.com/Featuredapps/darb-delivery-platform/actions/runs/43817595520):

- `darb-debug-apk`: تطبيق Android Debug للاختبار.
- `darb-source-fixed`: أرشيف المصدر بعد إصلاح Android scaffold وتحديث اعتماد Flutter في بيئة البناء.

Artifacts مؤقتة وتنتهي صلاحيتها وفق مدة الاحتفاظ المضبوطة في GitHub Actions.

## Backend

NestJS + Prisma + PostgreSQL/PostGIS + Redis.

## Mobile

Flutter، واجهة عربية RTL.

## تكاملات لم يثبت تفعيلها إنتاجياً بعد

- مزود SMS فعلي يدعم إرسال الرسائل إلى سوريا وربط OTP.
- Firebase Cloud Messaging وإشعارات الأجهزة الحقيقية.
- الخرائط وGeocoding وتتبع السائق الحي.

لا تعتبر هذه الخدمات متصلة حتى يتم اختبارها بمفاتيح وخدمات فعلية في بيئة آمنة.

## متطلبات ما قبل الإنتاج

- اختبار تدفق الطلب كاملاً بين العميل والبائع والسائق والإدارة.
- اختبار صلاحيات الأدوار وعزل البيانات والأمان.
- إعداد HTTPS وإيقاف cleartext traffic.
- حفظ أسرار الخدمات ومفاتيح توقيع Android خارج المستودع.
- بناء APK Release موقع واختباره على أجهزة Android فعلية.

## إعدادات الأمان

لا تضع أسرار الإنتاج في المستودع. استخدم ملفات البيئة المحلية أو GitHub Actions Secrets، وراجع إعدادات HTTPS وسياسات الوصول قبل النشر.


## تحديث التقوية

أُضيف دليل إعداد ونشر Backend الآمن في [`backend/DEPLOYMENT.md`](backend/DEPLOYMENT.md). يتضمن إعداد الأسرار، عزل منافذ PostgreSQL وRedis، ترحيل Prisma كخطوة مستقلة، فحص الصحة، ومتطلبات بناء Android مع `API_BASE_URL` عبر HTTPS. هذا الدليل لا يعني أن خادماً عاماً أو مزود SMS قد تم تفعيله.
