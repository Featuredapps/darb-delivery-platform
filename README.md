# دَرْب | DARB

منصة توصيل متعددة الأدوار: عميل، بائع، سائق، وإدارة.

المصدر الكامل للمشروع موجود ضمن مجلدي `backend/` و`mobile/` داخل الأرشيف `DARB-source.zip`. التعديلات التشغيلية الحالية وملفات Prisma migrations محفوظة كملفات مستقلة في المستودع.

## حالة التحقق

- Backend CI: تثبيت الحزم، توليد Prisma Client، تطبيق Migration على PostgreSQL 16 مع PostGIS، بناء NestJS، وتشغيل الاختبارات.
- أضيفت اختبارات لوحدة فحص صحة الخادم وتغطي حالات النجاح وتعطل قاعدة البيانات أو Redis.
- تم تطبيق Migration الأولية بنجاح على قاعدة بيانات PostGIS مؤقتة في GitHub Actions.
- تطبيق Android الذي بُني سابقاً كان APK من نوع Debug، وليس إصدار Release موقعاً للنشر.
- لا يوجد حتى الآن نشر فعلي لخدمات Backend على Render أو عنوان API إنتاجي.

## آخر تحديث تقني

- أضيفت مسارات فحص صحة Backend: `/api/v1/healthz` و`/api/v1/readyz`.
- فحص الجاهزية يتحقق من اتصال Redis ووجود جدول المستخدمين في PostgreSQL.
- أضيفت Migration أولية معتمدة في `backend/prisma/migrations/20261116162000_initial/`.
- Migration تنشئ الجداول والعلاقات والفهارس، وتفعّل PostGIS، وتضيف فهارس مكانية وقيود رقم الهاتف السوري.
- Backend CI يختبر تطبيق Migration على PostgreSQL/PostGIS نظيف قبل البناء والاختبارات.
- إعداد Render ينسخ ملفات Migration ويشغّل `prisma migrate deploy` قبل تشغيل API.
- إعداد Render Blueprint لا ينشئ الاستضافة تلقائياً؛ يتطلب حساب Render وموافقة مالك الحساب على إنشاء الموارد.

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

- إنشاء حسابات وربط خدمات SMS وFirebase والخرائط واختبارها فعلياً.
- نشر Backend على خطة استضافة مناسبة مع قاعدة بيانات دائمة وRedis دائم.
- اختبار تدفق الطلب كاملاً بين العميل والبائع والسائق والإدارة.
- اختبار صلاحيات الأدوار وعزل البيانات والأمان.
- إعداد HTTPS وإيقاف cleartext traffic.
- حفظ أسرار الخدمات ومفاتيح توقيع Android خارج المستودع.
- بناء APK Release موقع واختباره على أجهزة Android فعلية.

## إعدادات الأمان

لا تضع أسرار الإنتاج في المستودع. استخدم ملفات البيئة المحلية أو GitHub Actions Secrets، وراجع إعدادات HTTPS وسياسات الوصول قبل النشر.
