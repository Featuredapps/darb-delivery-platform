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
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
  const CircleAvatar(radius:36,backgroundColor:Color(0xFFE2EEE8),child:Icon(Icons.person,color:green,size:34)),
  const SizedBox(height:14),Text(profile?['name']?.toString()??'مستخدم دَرْب',textAlign:TextAlign.center,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
  Text(profile?['phone']?.toString()??profile?['email']?.toString()??'',textAlign:TextAlign.center,style:const TextStyle(color:Colors.black54)),
  const SizedBox(height:16),OutlinedButton.icon(onPressed:saving?null:_edit,icon:const Icon(Icons.edit_outlined),label:Text(saving?'جارٍ الحفظ...':'تعديل الملف الشخصي')),
  ListTile(leading:const Icon(Icons.verified_user_outlined),title:const Text('نوع الحساب'),subtitle:Text(profile?['role']?.toString()??'CUSTOMER')),
  if(profile?['role']=='CUSTOMER')... [
   const SizedBox(height:12),
   if(profile?['vendorApplication']==null)FilledButton.tonalIcon(onPressed:()=>_apply(context,true),icon:const Icon(Icons.storefront_outlined),label:const Text('قدّم طلب انضمام كبائع')) else ListTile(leading:const Icon(Icons.storefront_outlined),title:const Text('طلب المتجر'),subtitle:Text(profile?['vendorApplication'].toString()??'')),
   if(profile?['driverApplication']==null)FilledButton.tonalIcon(onPressed:()=>_apply(context,false),icon:const Icon(Icons.delivery_dining),label:const Text('قدّم طلب انضمام كسائق')) else ListTile(leading:const Icon(Icons.delivery_dining),title:const Text('طلب السائق'),subtitle:Text(profile?['driverApplication'].toString()??'')),
 ],
  const SizedBox(height:16),OutlinedButton.icon(onPressed:widget.onLogout,icon:const Icon(Icons.logout),label:const Text('تسجيل الخروج'))
 ]);
}
class _EmptyPanel extends StatelessWidget {final String text;const _EmptyPanel({required this.text});@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:Text(text,textAlign:TextAlign.center,style:const TextStyle(color:Colors.black54)));}
class _ErrorPanel extends StatelessWidget {final String message;final Future<void> Function() retry;const _ErrorPanel({required this.message,required this.retry});@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFFFFEEEE),borderRadius:BorderRadius.circular(16)),child:Column(children:[Text(message,style:const TextStyle(color:Colors.red)),TextButton(onPressed:retry,child:const Text('إعادة المحاولة'))]));}
