import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../main.dart';
import '../notifications.dart';
import 'login_screen.dart';

class AppShell extends StatefulWidget { const AppShell({super.key}); @override State<AppShell> createState() => _AppShellState(); }
class _AppShellState extends State<AppShell> {
  int tab = 0; bool loading = true; String role = 'CUSTOMER'; String? error; Map<String,dynamic>? me;
  @override void initState() { super.initState(); _load(); DarbNotifications.register(); }
  Future<void> _load() async { try { final data = await Api.instance.get('/auth/me'); me = Map<String,dynamic>.from(data); role = me?['role']?.toString() ?? 'CUSTOMER'; } catch(e) { error = e.toString(); } finally { if(mounted) setState(()=>loading=false); } }
  Future<void> _logout() async { await DarbNotifications.unregister(); await Api.instance.clear(); if(mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const LoginScreen()),(_)=>false); }
  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child:CircularProgressIndicator()));
    if (error != null) return Scaffold(body: Center(child: Padding(padding:const EdgeInsets.all(24), child:Column(mainAxisSize:MainAxisSize.min, children:[Text(error!,textAlign:TextAlign.center),const SizedBox(height:12),FilledButton(onPressed:_logout,child:const Text('تسجيل الدخول مجدداً'))]))));
    final isCustomer = role == 'CUSTOMER';
    final isAdmin = role == 'ADMIN';
    final titles = isAdmin ? ['طلبات المتاجر','طلبات السائقين','رسوم التوصيل','حسابي'] : isCustomer ? ['الرئيسية','طلباتي','حسابي'] : role == 'VENDOR' ? ['طلبات المتجر','المنتجات','حسابي'] : ['الطلبات المتاحة','توصيلاتي','حسابي'];
    final pages = isAdmin ? [const AdminQueue(kind:'vendors'),const AdminQueue(kind:'drivers'),const AdminDeliveryZones(),AccountPage(me:me,onLogout:_logout)] : isCustomer ? [const CustomerHome(),const CustomerOrders(),AccountPage(me:me,onLogout:_logout)] : role == 'VENDOR' ? [const VendorOrders(),const VendorProducts(),AccountPage(me:me,onLogout:_logout)] : [const DriverAvailable(),const DriverOrders(),AccountPage(me:me,onLogout:_logout)];
    return Scaffold(appBar:AppBar(title:Row(children:[Container(width:34,height:34,alignment:Alignment.center,decoration:BoxDecoration(color:ink,borderRadius:BorderRadius.circular(11)),child:const Text('د',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:22))),const SizedBox(width:10),const Text('دَرْب',style:TextStyle(fontWeight:FontWeight.w900))]), actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),body:pages[tab],bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:[for(var i=0;i<titles.length;i++) NavigationDestination(icon:Icon(isAdmin?(i==0?Icons.storefront_outlined:i==1?Icons.delivery_dining:i==2?Icons.payments_outlined:Icons.person_outline):(i==0?Icons.home_outlined:i==1?Icons.receipt_long_outlined:Icons.person_outline)),label:titles[i]) ]));
  }
}

class AdminQueue extends StatefulWidget {
  final String kind;
  const AdminQueue({super.key, required this.kind});
  @override State<AdminQueue> createState() => _AdminQueueState();
}

class _AdminQueueState extends State<AdminQueue> {
  bool loading = true, working = false;
  String? error;
  List rows = [];
  String get endpoint => widget.kind == 'vendors' ? '/admin/vendors/pending' : '/admin/drivers/pending';
  String get heading => widget.kind == 'vendors' ? 'طلبات انضمام المتاجر' : 'طلبات انضمام السائقين';
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try { rows = await Api.instance.get(endpoint) as List; }
    catch (e) { error = e.toString(); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> _setStatus(String id, String status) async {
    setState(() => working = true);
    try {
      await Api.instance.patch('/admin/${widget.kind}/$id/status', {'status': status});
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally { if (mounted) setState(() => working = false); }
  }
  @override Widget build(BuildContext context) => RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(18), children: [
    Text(heading, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
    const SizedBox(height: 14),
    if (loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
    if (error != null) _ErrorPanel(message: error!, retry: _load),
    if (!loading && error == null && rows.isEmpty) const _EmptyPanel(text: 'لا توجد طلبات معلّقة حالياً'),
    for (final row in rows) _requestCard(row),
  ]));
  Widget _requestCard(dynamic row) {
    final user = row['user'] as Map? ?? {};
    final translations = row['translations'] as List? ?? [];
    final title = widget.kind == 'vendors'
      ? (translations.isEmpty ? 'متجر جديد' : translations.first['name']?.toString() ?? 'متجر جديد')
      : user['name']?.toString() ?? 'سائق جديد';
    final cityData = row['city'];
    final city = widget.kind == 'drivers' && cityData is Map ? cityData['code']?.toString() ?? '' : '';
    final detail = widget.kind == 'vendors' ? row['type']?.toString() ?? '' : row['vehicleType']?.toString() ?? '';
    final id = row['id'].toString();
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      const SizedBox(height: 5), Text(user['phone']?.toString() ?? ''),
      if (detail.isNotEmpty) Text(detail), if (city.isNotEmpty) Text('رمز المدينة: $city'),
      const SizedBox(height: 10), Wrap(spacing: 8, children: [
        FilledButton(onPressed: working ? null : () => _setStatus(id, 'APPROVED'), child: const Text('اعتماد')),
        OutlinedButton(onPressed: working ? null : () => _setStatus(id, widget.kind == 'vendors' ? 'REJECTED' : 'SUSPENDED'), child: Text(widget.kind == 'vendors' ? 'رفض' : 'تعليق')),
      ]),
    ])));
  }
}

class CustomerHome extends StatefulWidget { const CustomerHome({super.key}); @override State<CustomerHome> createState()=>_CustomerHomeState(); }
class _CustomerHomeState extends State<CustomerHome> {
  bool loading=true; String? error; List<dynamic> cities=[], vendors=[]; String? cityId;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {setState(()=>loading=true);try{cities=await Api.instance.get('/cities') as List; if(cities.isNotEmpty){cityId ??= cities.first['id'].toString(); vendors=await Api.instance.get('/vendors?cityId=$cityId&locale=ar') as List;}}catch(e){error=e.toString();}finally{if(mounted)setState(()=>loading=false);}}
  @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(18),children:[Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:ink,borderRadius:BorderRadius.circular(24)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('أهلاً بك في دَرْب',style:TextStyle(color:Colors.white70)),SizedBox(height:8),Text('طلبك يبدأ من هنا',style:TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900)),SizedBox(height:6),Text('متاجر قريبة، طلبات واضحة وتوصيل حتى بابك',style:TextStyle(color:Colors.white70))])),const SizedBox(height:22),const Text('اختر مدينتك',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),const SizedBox(height:10),if(cities.isNotEmpty) DropdownButtonFormField<String>(value:cityId,decoration:const InputDecoration(),items:[for(final c in cities) DropdownMenuItem(value:c['id'].toString(),child:Text(_cityName(c)))],onChanged:(v)async{if(v==null)return;setState(()=>cityId=v);await _load();}),const SizedBox(height:22),const Text('المتاجر المتاحة',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),const SizedBox(height:12),if(loading)const Center(child:Padding(padding:EdgeInsets.all(28),child:CircularProgressIndicator())),if(error!=null) _ErrorPanel(message:error!,retry:_load),if(!loading&&error==null&&vendors.isEmpty)const _EmptyPanel(text:'لا توجد متاجر متاحة في هذه المدينة حالياً'),for(final v in vendors) _VendorTile(vendor:Map<String,dynamic>.from(v),cityId:cityId ?? ''),const SizedBox(height:24),const Text('الخرائط والتتبع المباشر سيظهران بعد ضبط مفتاح مزود الخرائط ونشر خدمة الموقع.',style:TextStyle(color:Colors.black45,fontSize:12))]));
  String _cityName(dynamic c){final names=(c['names'] as List? ?? []);return names.isEmpty?c['code'].toString():names.first['name'].toString();}
}
class _VendorTile extends StatelessWidget {final Map<String,dynamic> vendor;final String cityId;const _VendorTile({required this.vendor,required this.cityId});@override Widget build(BuildContext context){final t=(vendor['translations'] as List? ?? []);final name=t.isEmpty?'متجر':t.first['name']?.toString()??'متجر';return Card(child:ListTile(contentPadding:const EdgeInsets.all(12),leading:Container(width:54,height:54,decoration:BoxDecoration(color:const Color(0xFFE7F1EC),borderRadius:BorderRadius.circular(16)),child:const Icon(Icons.storefront,color:green,size:28)),title:Text(name,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${vendor['_count']?['products']??0} منتج متاح'),trailing:const Icon(Icons.chevron_left),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>VendorCatalog(vendorId:vendor['id'].toString(),name:name,cityId:cityId)))));}}
class VendorCatalog extends StatefulWidget {final String vendorId,name,cityId;const VendorCatalog({super.key,required this.vendorId,required this.name,required this.cityId});@override State<VendorCatalog> createState()=>_VendorCatalogState();}
String _productName(dynamic p){final translations=p['translations'] as List? ?? [];return translations.isEmpty?'منتج':translations.first['name']?.toString()??'منتج';}
class _VendorCatalogState extends State<VendorCatalog>{bool loading=true;String? error;List products=[];final Map<String,Map<String,dynamic>> cart={};@override void initState(){super.initState();_load();}Future<void> _load()async{try{products=await Api.instance.get('/vendors/${widget.vendorId}/products?locale=ar') as List;}catch(e){error=e.toString();}finally{if(mounted)setState(()=>loading=false);}}void _add(dynamic p){final id=p['id'].toString();setState((){final old=cart[id];cart[id]={'productId':id,'name':_productName(p),'price':p['basePrice'],'currency':p['currency'],'quantity':(old?['quantity']??0)+1};});ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('أضيف ${_productName(p)} إلى السلة'),duration:const Duration(milliseconds:900)));} @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.name),actions:[TextButton.icon(onPressed:cart.isEmpty?null:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CheckoutScreen(vendorId:widget.vendorId,cityId:widget.cityId,items:cart.values.toList()))),icon:const Icon(Icons.shopping_bag_outlined),label:Text('السلة (${cart.values.fold<int>(0,(n,x)=>n+(x['quantity'] as int))})'))]),body:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:Text(error!)):products.isEmpty?const _EmptyPanel(text:'لا توجد منتجات متاحة'):ListView(children:[for(final p in products)ListTile(title:Text(_productName(p)),subtitle:Text('${p['basePrice']} ${p['currency']}'),leading:const Icon(Icons.fastfood),trailing:IconButton(onPressed:()=>_add(p),icon:const Icon(Icons.add_circle,color:green,size:30))) ]));}

class CheckoutScreen extends StatefulWidget {final String vendorId,cityId;final List<Map<String,dynamic>> items;const CheckoutScreen({super.key,required this.vendorId,required this.cityId,required this.items});@override State<CheckoutScreen> createState()=>_CheckoutScreenState();}
class _CheckoutScreenState extends State<CheckoutScreen>{bool loading=true,sending=false;String? error,addressId;List addresses=[];final notes=TextEditingController();@override void initState(){super.initState();_load();}@override void dispose(){notes.dispose();super.dispose();}Future<void> _load()async{try{addresses=await Api.instance.get('/addresses') as List;if(addresses.isNotEmpty)addressId=addresses.first['id'].toString();}catch(e){error=e.toString();}finally{if(mounted)setState(()=>loading=false);}}Future<void> _newAddress()async{final label=TextEditingController();final details=TextEditingController();double? latitude,longitude;final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('عنوان جديد'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:label,decoration:const InputDecoration(labelText:'اسم العنوان (اختياري)')),const SizedBox(height:10),TextField(controller:details,maxLines:3,decoration:const InputDecoration(labelText:'العنوان بالتفصيل')),TextButton.icon(onPressed:()async{try{if(!await Geolocator.isLocationServiceEnabled())throw Exception('فعّل خدمة الموقع أولاً');var permission=await Geolocator.checkPermission();if(permission==LocationPermission.denied)permission=await Geolocator.requestPermission();if(permission==LocationPermission.denied||permission==LocationPermission.deniedForever)throw Exception('لم يتم منح إذن الموقع');final point=await Geolocator.getCurrentPosition();latitude=point.latitude;longitude=point.longitude;if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تحديد إحداثيات موقعك')));}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}},icon:const Icon(Icons.my_location),label:const Text('استخدام موقعي الحالي'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))]));if(ok==true&&details.text.trim().isNotEmpty){try{final a=await Api.instance.post('/addresses',{'label':label.text.trim(),'details':details.text.trim(),if(latitude!=null&&longitude!=null)'latitude':latitude,if(latitude!=null&&longitude!=null)'longitude':longitude});setState((){addresses.insert(0,a);addressId=a['id'].toString();error=null;});}catch(e){setState(()=>error=e.toString());}}label.dispose();details.dispose();}Future<void> _submit()async{if(addressId==null){setState(()=>error='أضف عنوان توصيل أولاً');return;}setState(()=>sending=true);try{await Api.instance.post('/orders',{'cityId':widget.cityId,'addressId':addressId,'vendorId':widget.vendorId,'items':widget.items.map((x)=>{'productId':x['productId'],'quantity':x['quantity']}).toList(),'notes':notes.text.trim()});if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم إرسال طلبك بنجاح')));Navigator.of(context).popUntil((r)=>r.isFirst);}catch(e){if(mounted)setState(()=>error=e.toString());}finally{if(mounted)setState(()=>sending=false);}}@override Widget build(BuildContext context){final subtotal=widget.items.fold<double>(0,(s,x)=>s+((double.tryParse(x['price'].toString())??0)*(x['quantity'] as int)));return Scaffold(appBar:AppBar(title:const Text('تأكيد الطلب')),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(18),children:[const Text('ملخص السلة',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),for(final x in widget.items)ListTile(title:Text(x['name'].toString()),subtitle:Text('الكمية: ${x['quantity']}'),trailing:Text('${x['price']} ${x['currency']}')),const Divider(),Text('المجموع الفرعي: ${subtotal.toStringAsFixed(2)}'),const SizedBox(height:22),const Text('عنوان التوصيل',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),if(addresses.isEmpty)const _EmptyPanel(text:'لا يوجد عنوان محفوظ'),if(addresses.isNotEmpty)DropdownButtonFormField<String>(value:addressId,items:[for(final a in addresses)DropdownMenuItem(value:a['id'].toString(),child:Text('${a['label']??'عنوان'} — ${a['details']??''}',maxLines:1,overflow:TextOverflow.ellipsis))],onChanged:(v)=>setState(()=>addressId=v)),TextButton.icon(onPressed:_newAddress,icon:const Icon(Icons.add_location_alt_outlined),label:const Text('إضافة عنوان')),const SizedBox(height:12),TextField(controller:notes,maxLines:2,decoration:const InputDecoration(labelText:'ملاحظات للمتجر (اختياري)')),if(error!=null)Padding(padding:const EdgeInsets.all(12),child:Text(error!,style:const TextStyle(color:Colors.red))),const SizedBox(height:18),FilledButton(onPressed:sending?null:_submit,child:sending?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):const Text('إرسال الطلب — الدفع عند الاستلام'))]));}}

class CustomerOrders extends StatelessWidget {const CustomerOrders({super.key});@override Widget build(BuildContext context)=>const _DataList(path:'/orders/mine',title:'طلباتك',empty:'لا توجد طلبات حتى الآن');}
class VendorOrders extends StatelessWidget {const VendorOrders({super.key});@override Widget build(BuildContext context)=>const _DataList(path:'/orders/vendor',title:'طلبات المتجر',empty:'لا توجد طلبات واردة');}
class DriverAvailable extends StatefulWidget {const DriverAvailable({super.key});@override State<DriverAvailable> createState()=>_DriverAvailableState();}
class _DriverAvailableState extends State<DriverAvailable>{bool loading=true,working=false;Map<String,dynamic>? driver;String? error;Timer? _locationTimer;@override void initState(){super.initState();_load();}@override void dispose(){_locationTimer?.cancel();super.dispose();}Future<void> _load()async{try{driver=Map<String,dynamic>.from(await Api.instance.get('/drivers/me'));error=null;if(driver?['isOnline']==true&&driver?['status']=='APPROVED')_startLocationUpdates();}catch(e){error=e.toString();}finally{if(mounted)setState(()=>loading=false);}}Future<void> _toggle(bool value)async{setState(()=>working=true);try{driver=Map<String,dynamic>.from(await Api.instance.patch('/drivers/online',{'isOnline':value}));error=null;if(value&&driver?['status']=='APPROVED'){_startLocationUpdates();}else{_locationTimer?.cancel();_locationTimer=null;}}catch(e){error=e.toString();}finally{if(mounted)setState(()=>working=false);}}void _startLocationUpdates(){_locationTimer?.cancel();_sendLocation();_locationTimer=Timer.periodic(const Duration(seconds:30),(_)=>_sendLocation());}Future<void> _sendLocation()async{try{if(!await Geolocator.isLocationServiceEnabled())return;var permission=await Geolocator.checkPermission();if(permission==LocationPermission.denied)permission=await Geolocator.requestPermission();if(permission==LocationPermission.denied||permission==LocationPermission.deniedForever)return;final position=await Geolocator.getCurrentPosition(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,timeLimit:Duration(seconds:15)));await Api.instance.patch('/drivers/location',{'latitude':position.latitude,'longitude':position.longitude});}catch(_){}}@override Widget build(BuildContext context){if(loading)return const Center(child:CircularProgressIndicator());if(error!=null)return Center(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[Text(error!),TextButton(onPressed:(){setState(()=>loading=true);_load();},child:const Text('إعادة المحاولة'))])));final approved=driver?['status']=='APPROVED';return Column(children:[Padding(padding:const EdgeInsets.all(14),child:Card(child:SwitchListTile(value:driver?['isOnline']==true&&approved,onChanged:!approved||working?null:_toggle,title:const Text('متصل لاستلام الطلبات'),subtitle:Text(approved?'فعّل الحالة لتظهر لك الطلبات الجاهزة':'حساب السائق بانتظار اعتماد الإدارة')))),if(approved&&driver?['isOnline']==true)const Expanded(child:_DataList(path:'/orders/driver/available',title:'طلبات جاهزة للاستلام',empty:'لا توجد طلبات متاحة حالياً'))else const Expanded(child:Center(child:Text('اتصل لاستقبال الطلبات بعد اعتماد حسابك')))]);}}
class DriverOrders extends StatelessWidget {const DriverOrders({super.key});@override Widget build(BuildContext context)=>const _DataList(path:'/orders/driver/mine',title:'توصيلاتي',empty:'لا توجد توصيلات حالياً');}
class _DataList extends StatefulWidget {final String path,title,empty;const _DataList({super.key,required this.path,required this.title,required this.empty});@override State<_DataList> createState()=>_DataListState();}
class _DataListState extends State<_DataList>{bool loading=true;String? error;List rows=[];@override void initState(){super.initState();_load();}Future<void> _load()async{setState(()=>loading=true);try{rows=await Api.instance.get(widget.path) as List;error=null;}catch(e){error=e.toString();}finally{if(mounted)setState(()=>loading=false);}}@override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(18),children:[Text(widget.title,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:14),if(loading)const Center(child:CircularProgressIndicator()),if(error!=null)_ErrorPanel(message:error!,retry:_load),if(!loading&&error==null&&rows.isEmpty)_EmptyPanel(text:widget.empty),for(final row in rows)_orderCard(row)]));
Widget _orderCard(dynamic row){final id=row['id']?.toString()??'';final status=row['status']?.toString()??'';final actions=<Widget>[];if(widget.path=='/orders/vendor'){if(status=='PENDING')actions.add(_action(id,'قبول','ACCEPTED'));if(status=='ACCEPTED')actions.add(_action(id,'بدء التحضير','PREPARING'));if(status=='PREPARING')actions.add(_action(id,'جاهز للاستلام','READY'));}if(widget.path=='/orders/driver/available')actions.add(TextButton(onPressed:()=>_claim(id),child:const Text('استلام الطلب')));if(widget.path=='/orders/mine'&&(status=='ASSIGNED'||status=='PICKED_UP'))actions.add(TextButton.icon(onPressed:()=>_track(id),icon:const Icon(Icons.location_on_outlined),label:const Text('موقع السائق')));if(widget.path=='/orders/driver/mine'){if(status=='ASSIGNED')actions.add(_action(id,'تم الاستلام','PICKED_UP'));if(status=='PICKED_UP')actions.add(_action(id,'تم التسليم','DELIVERED'));}return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[ListTile(contentPadding:EdgeInsets.zero,title:Text('طلب ${row['orderNumber']??id}'),subtitle:Text('الحالة: $status'),trailing:Text('${row['total']??''} ${row['currency']??''}')),if(actions.isNotEmpty)Wrap(spacing:8,children:actions)])));}
Widget _action(String id,String label,String status)=>TextButton(onPressed:()=>_changeStatus(id,status),child:Text(label));
Future<void> _track(String id)async{try{final location=await Api.instance.get('/orders/$id/driver-location');if(location is! Map||location['available']!=true){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('لم يشارك السائق موقعه بعد')));return;}final lat=location['latitude'];final lng=location['longitude'];final uri=Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');if(!await launchUrl(uri,mode:LaunchMode.externalApplication))throw Exception('تعذر فتح الخرائط');}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}Future<void> _changeStatus(String id,String status)async{try{await Api.instance.patch('/orders/$id/status',{'status':status});await _load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}
Future<void> _claim(String id)async{try{await Api.instance.post('/orders/$id/claim',{});await _load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}
}

class AdminDeliveryZones extends StatefulWidget {
  const AdminDeliveryZones({super.key});
  @override State<AdminDeliveryZones> createState() => _AdminDeliveryZonesState();
}
class _AdminDeliveryZonesState extends State<AdminDeliveryZones> {
  bool loading=true,working=false;
  String? error;
  List zones=[],cities=[];
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    setState(()=>loading=true);
    try{final values=await Future.wait([Api.instance.get('/admin/delivery-zones'),Api.instance.get('/cities')]);zones=values[0] as List;cities=values[1] as List;error=null;}
    catch(e){error=e.toString();}
    finally{if(mounted)setState(()=>loading=false);}
  }
  String _cityName(Map city){
    final names=city['names'] as List? ?? [];
    for(final item in names){if(item is Map&&item['locale']=='ar')return item['name'].toString();}
    return names.isNotEmpty?names.first['name'].toString():city['code'].toString();
  }
  Future<void> _edit([Map? zone])async{
    final selectableCities=zone==null?cities.where((c)=>!zones.any((z)=>z['cityId']==c['id'])).toList():cities;
    if(selectableCities.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('لا توجد مدن أخرى تحتاج إلى إعداد رسوم')));return;}
    final name=TextEditingController(text:zone?['name']?.toString()??'');
    final base=TextEditingController(text:zone?['feeBase']?.toString()??'');
    final perKm=TextEditingController(text:zone?['feePerKm']?.toString()??'');
    String cityId=zone?['cityId']?.toString()??selectableCities.first['id'].toString();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
      title:Text(zone==null?'إضافة منطقة توصيل':'تعديل رسوم التوصيل'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        if(zone==null)DropdownButtonFormField<String>(value:cityId,decoration:const InputDecoration(labelText:'المدينة'),items:[for(final c in selectableCities)DropdownMenuItem(value:c['id'].toString(),child:Text(_cityName(c)))],onChanged:(v){if(v!=null)setDialog(()=>cityId=v);}),
        TextField(controller:name,decoration:const InputDecoration(labelText:'وصف إعداد الرسوم')),
        TextField(controller:base,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'الرسم الأساسي (ل.س)')),
        TextField(controller:perKm,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'الرسم لكل كيلومتر (ل.س)')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))],
    )));
    if(ok==true){
      final feeBase=double.tryParse(base.text),feePerKm=double.tryParse(perKm.text);
      if(name.text.trim().isEmpty||feeBase==null||feePerKm==null||feeBase<0||feePerKm<0){
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('أدخل اسمًا ورسومًا رقمية غير سالبة')));
      }else{
        setState(()=>working=true);
        try{
          final body={'name':name.text.trim(),'feeBase':feeBase,'feePerKm':feePerKm,if(zone==null)'cityId':cityId};
          if(zone==null){await Api.instance.post('/admin/delivery-zones',body);}else{await Api.instance.patch('/admin/delivery-zones/${zone['id']}',body);}
          await _load();
        }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
        finally{if(mounted)setState(()=>working=false);}
      }
    }
    name.dispose();base.dispose();perKm.dispose();
  }
  @override Widget build(BuildContext context)=>Scaffold(
    floatingActionButton:FloatingActionButton.extended(onPressed:working?null:()=>_edit(),icon:const Icon(Icons.add),label:const Text('إضافة رسوم لمدينة')),
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:TextButton(onPressed:_load,child:Text('تعذر تحميل المناطق: $error'))):zones.isEmpty?const Center(child:_EmptyPanel(text:'لم تُضف رسوم توصيل بعد')):RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('إعداد رسوم التوصيل',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
      const SizedBox(height:8),const Text('يُضبط رسم واحد لكل مدينة. احتساب رسم الكيلومتر يتطلب تحديد موقع المتجر وموقع عنوان العميل.',style:TextStyle(color:Colors.black54)),
      for(final zone in zones)Card(child:ListTile(
        leading:const Icon(Icons.payments_outlined,color:green),
        title:Text(zone['name']?.toString()??'منطقة'),
        subtitle:Text('${_cityName(zone['city'] as Map)} • أساسي: ${zone['feeBase']} ل.س • لكل كم: ${zone['feePerKm']} ل.س'),
        trailing:IconButton(onPressed:working?null:()=>_edit(zone as Map),icon:const Icon(Icons.edit_outlined)),
      )),
    ])),
  );
}

class VendorProducts extends StatefulWidget {const VendorProducts({super.key});@override State<VendorProducts> createState()=>_VendorProductsState();}
class _VendorProductsState extends State<VendorProducts>{bool loading=true,saving=false;String? error,vendorStatus;List products=[];@override void initState(){super.initState();_load();}Future<void> _load()async{try{final mine=await Api.instance.get('/vendors/mine');vendorStatus=mine['status']?.toString();if(vendorStatus!='APPROVED'){products=[];error=null;}else{final id=mine['id'].toString();products=await Api.instance.get('/vendors/$id/products?locale=ar') as List;error=null;}}catch(e){error=e.toString();}finally{if(mounted)setState(()=>loading=false);}}Future<void> _add()async{final name=TextEditingController(),price=TextEditingController(),description=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('منتج جديد'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'اسم المنتج')),TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'السعر')),TextField(controller:description,maxLines:2,decoration:const InputDecoration(labelText:'الوصف'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('إضافة'))]));if(ok==true&&name.text.trim().isNotEmpty&&(double.tryParse(price.text)??0)>0){setState(()=>saving=true);try{await Api.instance.post('/vendor/products',{'name':name.text.trim(),'price':double.parse(price.text),'description':description.text.trim(),'currency':'SYP'});await _load();}catch(e){setState(()=>error=e.toString());}finally{if(mounted)setState(()=>saving=false);}}name.dispose();price.dispose();description.dispose();}@override Widget build(BuildContext context)=>Scaffold(body:loading?const Center(child:CircularProgressIndicator()):vendorStatus!=null&&vendorStatus!='APPROVED'?Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(vendorStatus=='PENDING'?'طلب متجرك قيد المراجعة. ستتمكن من إدارة المنتجات بعد اعتماد الإدارة.':'حالة المتجر: $vendorStatus',textAlign:TextAlign.center))):error!=null?ListView(padding:const EdgeInsets.all(18),children:[Text(error!),TextButton(onPressed:(){setState(()=>loading=true);_load();},child:const Text('إعادة المحاولة'))]):products.isEmpty?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const _EmptyPanel(text:'لم تضف أي منتجات بعد'),FilledButton.icon(onPressed:saving?null:_add,icon:const Icon(Icons.add),label:const Text('إضافة منتج'))])):ListView(padding:const EdgeInsets.all(16),children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('منتجات متجرك',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),FilledButton.icon(onPressed:saving?null:_add,icon:const Icon(Icons.add),label:const Text('إضافة'))]),for(final p in products)Card(child:ListTile(title:Text(_productName(p)),subtitle:Text('${p['basePrice']} ${p['currency']}'),leading:const Icon(Icons.inventory_2_outlined))) ]));}
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
