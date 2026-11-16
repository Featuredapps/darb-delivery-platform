# دَرْب | DARB

منصة توصيل متعددة الأدوار: عميل، بائع، سائق، وإدارة.

المصدر الكامل للمشروع موجود ضمن مجلدي `backend/` و`mobile/` داخل الأرشيف `DARB-source.zip`.

## حالة التحقق

تم التحقق سابقاً من بناء Backend packages وبناء تطبيق Flutter Android بنجاح في GitHub Actions بتاريخ 2026-11-16.

- Workflow run: [43817595520](https://github.com/Featuredapps/darb-delivery-platform/actions/runs/43817595520)
- النتيجة: نجاح جميع خطوات البناء.
- ناتج Android: APK من نوع Debug، وليس إصدار Release موقعاً للنشر.
- تم إصلاح Android platform scaffold الناقص أثناء CI وإنتاج أرشيف مصدر مصحح كـ artifact منفصل.
- لم يتم استبدال `DARB-source.zip` الأصلي في المستودع بهذا التشغيل.

## آخر تحديث تقني

- أضيفت مسارات فحص صحة Backend: `/api/v1/healthz` و`/api/v1/readyz`.
- فحص الجاهزية يتحقق من اتصال Redis ووجود جدول المستخدمين في PostgreSQL، ولا يعطي نجاحاً زائفاً إذا لم تُهيأ قاعدة البيانات.
- أضيف GitHub Actions workflow مستقل لبناء Backend وتشغيل اختباراته عند تعديل ملفات Backend أو إعدادات النشر.
- إعداد Render يستخدم فحص liveness، لكن إنشاء موارد الاستضافة لم يتم بعد.
- لا توجد حتى الآن Prisma migration أولية معتمدة؛ لذلك لا تعتبر قاعدة البيانات جاهزة لتشغيل الطلبات الفعلية.

## تنزيل المخرجات

تتوفر مخرجات البناء السابقة من صفحة [GitHub Actions run](https://github.com/Featuredapps/darb-delivery-platform/actions/runs/43817595520):

- `darb-debug-apk`: تطبيق Android Debug للاختبار.
- `darb-source-fixed`: أرشيف المصدر بعد إصلاح Android scaffold وتحديث اعتماد Flutter في بيئة البناء.

Artifacts مؤقتة وتنتهي صلاحيتها وفق مدة الاحتفاظ المضبوطة في GitHub Actions.

## Backend

NestJS + Prisma + PostgreSQL/PostGIS + Redis.

تفاصيل النشر والقيود الحالية: [backend/DEPLOYMENT.md](backend/DEPLOYMENT.md).

## Mobile

Flutter، واجهة عربية RTL.

## تكاملات لم يثبت تفعيلها إنتاجياً بعد

- مزود SMS فعلي يدعم إرسال الرسائل إلى سوريا وربط OTP.
- Firebase Cloud Messaging وإشعارات الأجهزة الحقيقية.
- الخرائط وGeocoding وتتبع السائق الحي.

لا تعتبر هذه الخدمات متصلة حتى يتم اختبارها بمفاتيح وخدمات فعلية في بيئة آمنة.

## متطلبات ما قبل الإنتاج

- إنشاء Prisma migration أولية ومراجعتها واختبارها.
- اختبار تدفق الطلب كاملاً بين العميل والبائع والسائق والإدارة.
- اختبار صلاحيات الأدوار وعزل البيانات والأمان.
- إعداد HTTPS وإيقاف cleartext traffic.
- حفظ أسرار الخدمات ومفاتيح توقيع Android خارج المستودع.
- بناء APK Release موقع واختباره على أجهزة Android فعلية.

## إعدادات الأمان

لا تضع أسرار الإنتاج في المستودع. استخدم ملفات البيئة المحلية أو GitHub Actions Secrets، وراجع إعدادات HTTPS وسياسات الوصول قبل النشر.
