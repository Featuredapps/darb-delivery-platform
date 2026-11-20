part of 'app_shell.dart';

class AccountPage extends StatefulWidget {
 final Map<String,dynamic>? me; final VoidCallback onLogout;
 const AccountPage({super.key,required this.me,required this.onLogout});
 @override State<AccountPage> createState()=>_AccountPageState();
}
class _AccountPageState extends State<AccountPage>{
 late Map<String,dynamic>? profile=widget.me; bool saving=false;
 Future<void> _edit()async{
  final name=TextEditingController(text:profile?['name']?.toString()??'');
  String locale=profile?['locale']?.toString()??'ar';
  final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
   title:const Text('تعديل الملف الشخصي'),
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:name,maxLength:120,decoration:const InputDecoration(labelText:'الاسم')),
    DropdownButtonFormField<String>(value:locale,decoration:const InputDecoration(labelText:'اللغة'),items:const [
     DropdownMenuItem(value:'ar',child:Text('العربية')),DropdownMenuItem(value:'en',child:Text('English')),DropdownMenuItem(value:'tr',child:Text('Türkçe'))],
     onChanged:(v){if(v!=null)setDialog(()=>locale=v);}),
   ]),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))])));
  if(ok==true){setState(()=>saving=true);try{final updated=await Api.instance.patch('/auth/me',{'name':name.text.trim(),'locale':locale});if(mounted){setState(()=>profile=Map<String,dynamic>.from(updated));darbLocale.value=Locale(locale);}}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}finally{if(mounted)setState(()=>saving=false);}}
  name.dispose();
 }
 Future<void> _apply(BuildContext context,bool vendor)async{List cities;try{cities=await Api.instance.get('/cities') as List;}catch(e){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));return;}if(cities.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('لا توجد مدن مفعّلة حالياً')));return;}String cityId=cities.first['id'].toString();final name=TextEditingController(),type=TextEditingController(),extra=TextEditingController();double? vendorLatitude,vendorLongitude;bool vendorLocationSet=false;final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(title:Text(vendor?'طلب انضمام متجر':'طلب انضمام سائق'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[if(vendor)...[TextField(controller:name,decoration:const InputDecoration(labelText:'اسم المتجر')),TextField(controller:type,decoration:const InputDecoration(labelText:'نوع النشاط'))]else TextField(controller:type,decoration:const InputDecoration(labelText:'نوع المركبة (اختياري)')),DropdownButtonFormField<String>(value:cityId,decoration:const InputDecoration(labelText:'المدينة'),items:[for(final c in cities)DropdownMenuItem(value:c['id'].toString(),child:Text((c['names'] as List? ?? []).isEmpty?c['code'].toString():(c['names'] as List).first['name'].toString()))],onChanged:(v){if(v!=null)setDialog(()=>cityId=v);}),if(vendor)...[
TextField(controller:extra,decoration:const InputDecoration(labelText:'العنوان (اختياري)')),
TextButton.icon(onPressed:()async{try{if(!await Geolocator.isLocationServiceEnabled())throw Exception('فعّل خدمة الموقع أولاً');var permission=await Geolocator.checkPermission();if(permission==LocationPermission.denied)permission=await Geolocator.requestPermission();if(permission==LocationPermission.denied||permission==LocationPermission.deniedForever)throw Exception('لم يتم منح إذن الموقع');final point=await Geolocator.getCurrentPosition();vendorLatitude=point.latitude;vendorLongitude=point.longitude;setDialog(()=>vendorLocationSet=true);}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}},icon:Icon(vendorLocationSet?Icons.check_circle:Icons.my_location),label:Text(vendorLocationSet?'تم تحديد موقع المتجر':'تحديد موقع المتجر على الخريطة')),
]])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('إرسال الطلب'))])));if(ok==true){try{await Api.instance.post(vendor?'/vendors/apply':'/drivers/apply',vendor?{'name':name.text.trim(),'type':type.text.trim(),'cityId':cityId,'address':extra.text.trim(),if(vendorLatitude!=null&&vendorLongitude!=null)...{'latitude':vendorLatitude,'longitude':vendorLongitude}}:{'cityId':cityId,'vehicleType':type.text.trim()});final fresh=await Api.instance.get('/auth/me');if(context.mounted){setState(()=>profile=Map<String,dynamic>.from(fresh));ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم إرسال الطلب. ستبقى صلاحيات حسابك كما هي حتى اعتماد الإدارة.')));}}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}name.dispose();type.dispose();extra.dispose();}
 String _statusLabel(dynamic value) {
  switch (value?.toString()) {
    case 'PENDING': return 'قيد مراجعة الإدارة';
    case 'APPROVED': return 'تمت الموافقة';
    case 'REJECTED': return 'لم تتم الموافقة';
    case 'SUSPENDED': return 'معلّق من الإدارة';
    default: return 'لم يُرسل طلب بعد';
  }
 }
 Color _statusColor(dynamic value) {
  switch (value?.toString()) {
    case 'APPROVED': return const Color(0xFF247A55);
    case 'REJECTED':
    case 'SUSPENDED': return DarbColors.danger;
    case 'PENDING': return const Color(0xFFB7791F);
    default: return DarbColors.muted;
  }
 }
 Widget _applicationCard({required String title, required String description, required IconData icon, required dynamic status, required VoidCallback? onApply}) {
  final sent = status != null;
  final color = _statusColor(status);
  return Container(
   padding: const EdgeInsets.all(17),
   decoration: BoxDecoration(color: DarbColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: DarbColors.line)),
   child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
     Container(width: 46,height: 46,decoration: BoxDecoration(color: DarbColors.mint.withValues(alpha:.42),borderRadius: BorderRadius.circular(15)),child: Icon(icon,color:DarbColors.forest)),
     const SizedBox(width:12), Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w900,color:DarbColors.ink)),
      const SizedBox(height:3), Text(description,style:const TextStyle(fontSize:12,color:DarbColors.muted)),
     ])),
     if(sent) Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:color.withValues(alpha:.12),borderRadius:BorderRadius.circular(30)),child:Text(_statusLabel(status),style:TextStyle(color:color,fontSize:10,fontWeight:FontWeight.w800))),
    ]),
    if(!sent) ...[
     const SizedBox(height:14),
     SizedBox(width:double.infinity,child:FilledButton.tonalIcon(onPressed:onApply,icon:const Icon(Icons.arrow_forward_rounded,size:18),label:const Text('ابدأ طلب الانضمام'))),
    ] else ...[
     const SizedBox(height:12),
     Row(children:[
      Icon(status=='APPROVED'?Icons.check_circle_outline:status=='PENDING'?Icons.hourglass_top_rounded:Icons.info_outline_rounded,size:17,color:color),
      const SizedBox(width:7), Expanded(child:Text(status=='PENDING'?'استلمنا طلبك. ستراجع الإدارة بياناتك قبل تفعيل الصلاحيات.':status=='APPROVED'?'تم اعتماد طلبك. حدّث الصفحة لتظهر صلاحيات حسابك الجديدة.':'يمكنك التواصل مع الدعم لمعرفة تفاصيل القرار.',style:const TextStyle(fontSize:12,color:DarbColors.muted,height:1.45))),
     ]),
    ],
   ]),
  );
 }
 @override Widget build(BuildContext context) {
  final name = profile?['name']?.toString().trim() ?? '';
  final email = profile?['email']?.toString() ?? '';
  final phone = profile?['phone']?.toString() ?? '';
  final role = profile?['role']?.toString() ?? 'CUSTOMER';
  final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : 'د';
  final roleLabel = role == 'ADMIN'
      ? 'إدارة دَرْب'
      : role == 'DRIVER'
          ? 'حساب سائق'
          : role == 'VENDOR'
              ? 'حساب تاجر'
              : 'حساب عميل';

  return ListView(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
    children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: .94, end: 1),
        duration: DarbMotion.expressive,
        curve: DarbMotion.enter,
        builder: (context, value, child) => Transform.scale(
          scale: value,
          alignment: Alignment.topCenter,
          child: child,
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [DarbColors.forest, DarbColors.forestSoft],
            ),
            borderRadius: BorderRadius.circular(DarbRadius.hero),
            boxShadow: DarbElevation.floating,
          ),
          child: Stack(
            children: [
              Positioned(
                top: -58,
                left: -38,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: .07), width: 24),
                  ),
                ),
              ),
              Positioned(
                bottom: -88,
                right: -45,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DarbColors.lime.withValues(alpha: .07),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 25, 22, 22),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'ملفي الشخصي',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(DarbRadius.pill),
                            border: Border.all(color: Colors.white.withValues(alpha: .12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_user_outlined, color: DarbColors.lime, size: 13),
                              const SizedBox(width: 6),
                              Text(roleLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: 86,
                      height: 86,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .12),
                        border: Border.all(color: Colors.white.withValues(alpha: .28), width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 22, offset: const Offset(0, 9))],
                      ),
                      child: Text(initial, style: const TextStyle(color: DarbColors.lime, fontSize: 34, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name.isEmpty ? 'مرحباً بك في دَرْب' : name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      phone.isNotEmpty ? phone : (email.isNotEmpty ? email : 'أضف بيانات التواصل إلى حسابك'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: .72), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : _edit,
                        icon: saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.edit_outlined, size: 17),
                        label: Text(saving ? 'جارٍ حفظ التعديلات' : 'تعديل الملف الشخصي'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: .28)),
                          backgroundColor: Colors.white.withValues(alpha: .07),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 27),
      _sectionHeading('بيانات الحساب', 'المعلومات المرتبطة بحسابك'),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: DarbColors.surface,
          borderRadius: BorderRadius.circular(DarbRadius.lg),
          border: Border.all(color: DarbColors.line),
          boxShadow: DarbElevation.card,
        ),
        child: Column(
          children: [
            _accountInfoTile(icon: Icons.person_outline_rounded, label: 'الاسم', value: name.isEmpty ? 'غير محدد' : name),
            _accountDivider(),
            _accountInfoTile(icon: Icons.alternate_email_rounded, label: 'البريد الإلكتروني', value: email.isEmpty ? 'غير مرتبط' : email),
            if (phone.isNotEmpty) ...[
              _accountDivider(),
              _accountInfoTile(icon: Icons.phone_iphone_rounded, label: 'رقم الهاتف', value: phone),
            ],
          ],
        ),
      ),
      if (role == 'CUSTOMER') ...[
        const SizedBox(height: 28),
        _sectionHeading('انضم إلى شبكة دَرْب', 'اختر كيف تريد أن تشارك في خدماتنا'),
        const SizedBox(height: 12),
        _applicationCard(
          title: 'كن سائقاً في دَرْب',
          description: 'استقبل طلبات التوصيل وقدّم أجرتك للعملاء',
          icon: Icons.delivery_dining_rounded,
          status: profile?['driverApplication'],
          onApply: () => _apply(context, false),
        ),
        const SizedBox(height: 12),
        _applicationCard(
          title: 'انضم بمتجرك',
          description: 'اعرض منتجات متجرك واستقبل طلبات العملاء',
          icon: Icons.storefront_rounded,
          status: profile?['vendorApplication'],
          onApply: () => _apply(context, true),
        ),
      ],
      const SizedBox(height: 28),
      _sectionHeading('التفضيلات والدعم', 'إعدادات تجربتك في دَرْب'),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: DarbColors.surface,
          borderRadius: BorderRadius.circular(DarbRadius.lg),
          border: Border.all(color: DarbColors.line),
          boxShadow: DarbElevation.card,
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
              leading: _settingsIcon(Icons.language_rounded),
              title: const Text('اللغة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              subtitle: Text(profile?['locale']?.toString() ?? 'ar', style: const TextStyle(color: DarbColors.muted, fontSize: 12)),
              trailing: const Icon(Icons.chevron_left_rounded, color: DarbColors.muted),
            ),
            _accountDivider(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
              leading: _settingsIcon(Icons.support_agent_rounded),
              title: const Text('المساعدة والدعم', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              subtitle: const Text('تواصل معنا عند الحاجة', style: TextStyle(color: DarbColors.muted, fontSize: 12)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      OutlinedButton.icon(
        onPressed: widget.onLogout,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('تسجيل الخروج'),
        style: OutlinedButton.styleFrom(
          foregroundColor: DarbColors.danger,
          side: BorderSide(color: DarbColors.danger.withValues(alpha: .28)),
          backgroundColor: DarbColors.danger.withValues(alpha: .035),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      const SizedBox(height: 10),
      const Center(
        child: Text('دَرْب • كل طريق يبدأ بخطوة', style: TextStyle(color: DarbColors.muted, fontSize: 10, fontWeight: FontWeight.w600)),
      ),
    ],
  );
 }

 Widget _sectionHeading(String title, String subtitle) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
   Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: DarbColors.ink)),
   const SizedBox(height: 3),
   Text(subtitle, style: const TextStyle(fontSize: 11, color: DarbColors.muted)),
  ],
 );

 Widget _accountInfoTile({required IconData icon, required String label, required String value}) => ListTile(
  contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
  leading: _settingsIcon(icon),
  title: Text(label, style: const TextStyle(fontSize: 11, color: DarbColors.muted, fontWeight: FontWeight.w600)),
  subtitle: Text(value, style: const TextStyle(fontSize: 13, color: DarbColors.ink, fontWeight: FontWeight.w800)),
 );

 Widget _settingsIcon(IconData icon) => Container(
  width: 42,
  height: 42,
  alignment: Alignment.center,
  decoration: BoxDecoration(color: DarbColors.mint.withValues(alpha: .35), borderRadius: BorderRadius.circular(14)),
  child: Icon(icon, color: DarbColors.forest, size: 20),
 );

 Widget _accountDivider() => const Divider(height: 1, indent: 17, endIndent: 17);
 }
class _EmptyPanel extends StatelessWidget {final String text;const _EmptyPanel({required this.text});@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:Text(text,textAlign:TextAlign.center,style:const TextStyle(color:Colors.black54)));}
class _ErrorPanel extends StatelessWidget {final String message;final Future<void> Function() retry;const _ErrorPanel({required this.message,required this.retry});@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFFFFEEEE),borderRadius:BorderRadius.circular(16)),child:Column(children:[Text(message,style:const TextStyle(color:Colors.red)),TextButton(onPressed:retry,child:const Text('إعادة المحاولة'))]));}
