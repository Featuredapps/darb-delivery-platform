part of 'app_shell.dart';

class DriverLocationReporter {
  static Timer? _timer;
  static bool _sending = false;

  static Future<void> start() async {
    if (_timer != null) return;
    await refresh();
  }

  static Future<void> refresh() async {
    _timer?.cancel();
    _timer = null;
    try {
      final driver = Map<String, dynamic>.from(await Api.instance.get('/drivers/me'));
      if (driver['status'] != 'APPROVED' || driver['isOnline'] != true) return;
      await _sendLocation();
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => _sendLocation());
    } catch (_) {
      _timer?.cancel();
      _timer = null;
    }
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _sendLocation() async {
    if (_sending) return;
    _sending = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        ),
      );
      await Api.instance.patch('/drivers/location', {
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
    } catch (_) {
      // Location failures must not interrupt the driver's order workflow.
    } finally {
      _sending = false;
    }
  }
}

class DriverAvailable extends StatefulWidget {const DriverAvailable({super.key});@override State<DriverAvailable> createState()=>_DriverAvailableState();}
class _DriverAvailableState extends State<DriverAvailable>{bool loading=true,working=false;Map<String,dynamic>? driver;String? error;@override void initState(){super.initState();_load();}Future<void> _load()async{try{driver=Map<String,dynamic>.from(await Api.instance.get('/drivers/me'));error=null;await DriverLocationReporter.start();}catch(e){error=e.toString();}finally{if(mounted)setState(()=>loading=false);}}Future<void> _toggle(bool value)async{setState(()=>working=true);try{driver=Map<String,dynamic>.from(await Api.instance.patch('/drivers/online',{'isOnline':value}));error=null;await DriverLocationReporter.refresh();}catch(e){error=e.toString();}finally{if(mounted)setState(()=>working=false);}}@override Widget build(BuildContext context){if(loading)return Center(child:CircularProgressIndicator());if(error!=null)return Center(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[Text(error!),TextButton(onPressed:(){setState(()=>loading=true);_load();},child:Text(dt('إعادة المحاولة')))])));final approved=driver?['status']=='APPROVED';return Column(children:[Padding(padding:const EdgeInsets.all(14),child:Card(child:SwitchListTile(value:driver?['isOnline']==true&&approved,onChanged:!approved||working?null:_toggle,title:Text(dt('متصل لاستلام الطلبات')),subtitle:Text(approved?'فعّل الحالة لتظهر لك الطلبات الجاهزة':'حساب السائق بانتظار اعتماد الإدارة')))),if(approved&&driver?['isOnline']==true)Expanded(child:_DataList(path:'/orders/driver/available',title: dt('طلبات جاهزة للاستلام'),empty: dt('لا توجد طلبات متاحة حالياً')))else Expanded(child:Center(child:Text(dt('اتصل لاستقبال الطلبات بعد اعتماد حسابك'))))]);}}
class DriverOrders extends StatelessWidget {const DriverOrders({super.key});@override Widget build(BuildContext context)=>_DataList(path:'/orders/driver/mine',title: dt('توصيلاتي'),empty: dt('لا توجد توصيلات حالياً'));}
class _DataList extends StatefulWidget {final String path,title,empty;const _DataList({super.key,required this.path,required this.title,required this.empty});@override State<_DataList> createState()=>_DataListState();}
class _DataListState extends State<_DataList>{bool loading=true;String? error;List rows=[];@override void initState(){super.initState();_load();}Future<void> _load()async{setState(()=>loading=true);try{rows=await Api.instance.get(widget.path) as List;error=null;}catch(e){error=e.toString();}finally{if(mounted)setState(()=>loading=false);}}@override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(18),children:[Text(widget.title,style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),SizedBox(height:14),if(loading)Center(child:CircularProgressIndicator()),if(error!=null)_ErrorPanel(message:error!,retry:_load),if(!loading&&error==null&&rows.isEmpty)_EmptyPanel(text:widget.empty),for(final row in rows)_orderCard(row)]));
String _statusLabel(String status, {required bool peer}) {
  switch (status) {
    case 'PENDING':
      return peer ? dt('بانتظار عروض السائقين') : dt('بانتظار التأكيد');
    case 'ACCEPTED':
      return dt('تم قبول الطلب');
    case 'PREPARING':
      return dt('قيد التحضير');
    case 'READY':
      return dt('جاهز للاستلام');
    case 'ASSIGNED':
      return dt('تم تعيين سائق');
    case 'PICKED_UP':
      return dt('تم استلام الطلب');
    case 'DELIVERED':
      return dt('تم التسليم');
    case 'CANCELLED':
      return dt('ملغي');
    default:
      return status;
  }
}
Widget _orderCard(dynamic row){
  final id=row['id']?.toString()??'';
  final status=row['status']?.toString()??'';
  final peer=row['type']=='PEER_DELIVERY';
  final pickup=row['pickupAddress']?.toString();
  final destination=(row['address'] is Map)?row['address']['details']?.toString():null;
  final actions=<Widget>[];
  if(widget.path=='/orders/vendor'){
    if(status=='PENDING')actions.add(_action(id,dt('قبول'),'ACCEPTED'));
    if(status=='ACCEPTED')actions.add(_action(id,dt('بدء التحضير'),'PREPARING'));
    if(status=='PREPARING')actions.add(_action(id,dt('جاهز للاستلام'),'READY'));
  }
  if(widget.path=='/orders/driver/available'&&!peer)actions.add(TextButton(onPressed:()=>_claim(id),child:Text(dt('استلام الطلب'))));
  if(widget.path=='/orders/driver/available'&&peer)actions.add(_DriverOfferAction(orderId:id,onSent:_load));
  if(widget.path=='/orders/mine'&&(status=='ASSIGNED'||status=='PICKED_UP'))actions.add(TextButton.icon(onPressed:()=>_track(id),icon:Icon(Icons.location_on_outlined),label:Text(dt('موقع السائق'))));
  if(widget.path=='/orders/driver/mine'){
    if(status=='ASSIGNED')actions.add(_action(id,dt('تم الاستلام'),'PICKED_UP'));
    if(status=='PICKED_UP')actions.add(_action(id,dt('تم التسليم'),'DELIVERED'));
  }
  return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    ListTile(contentPadding:EdgeInsets.zero,title:Text(peer?dt('طلب توصيل مستقل'):'${dt('طلب')} ${row['orderNumber']??id}'),subtitle:Text('${dt('رقم الطلب')}: ${row['orderNumber']??id} • ${dt('الحالة')}: ${_statusLabel(status, peer: peer)}'),trailing:peer&&row['deliveryFee']==0?Text(dt('بانتظار العروض')):Text('${row['total']??''} ${row['currency']??''}')),
    if(peer&&row['distanceKm']!=null)Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Text(dt('مسافة التوصيل: ${(row['distanceKm'] as num).toStringAsFixed(1)} كم'),style:TextStyle(fontWeight:FontWeight.w800))),
    if(peer&&pickup!=null)ListTile(dense:true,leading:Icon(Icons.trip_origin),title:Text(dt('الاستلام')),subtitle:Text(pickup)),
    if(peer&&destination!=null)ListTile(dense:true,leading:Icon(Icons.flag_outlined),title:Text(dt('التسليم')),subtitle:Text(destination)),
    if(peer&&widget.path=='/orders/mine'&&status=='PENDING')_CustomerDeliveryOffers(orderId:id,onSelected:_load),
    if(actions.isNotEmpty)Wrap(spacing:8,children:actions)
  ])));
}
Widget _action(String id,String label,String status)=>TextButton(onPressed:()=>_changeStatus(id,status),child:Text(label));
Future<void> _track(String id)async{try{final location=await Api.instance.get('/orders/$id/driver-location');if(location is! Map||location['available']!=true){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(dt('لم يشارك السائق موقعه بعد'))));return;}final lat=location['latitude'];final lng=location['longitude'];final uri=Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');if(!await launchUrl(uri,mode:LaunchMode.externalApplication))throw Exception('تعذر فتح الخرائط');}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}Future<void> _changeStatus(String id,String status)async{try{await Api.instance.patch('/orders/$id/status',{'status':status});await _load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}
Future<void> _claim(String id)async{try{await Api.instance.post('/orders/$id/claim',{});await _load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}
}


class _DriverOfferAction extends StatelessWidget {
  final String orderId;
  final Future<void> Function() onSent;
  const _DriverOfferAction({required this.orderId,required this.onSent});
  Future<void> _offer(BuildContext context) async {
    final price=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(dt('تقديم أجرة التوصيل')),
      content:TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText: dt('الأجرة بالليرة السورية الجديدة'),hintText: dt('أدخل المبلغ'))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(dt('إلغاء'))),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(dt('إرسال العرض')))],
    ));
    final amount=double.tryParse(price.text.trim());
    price.dispose();
    if(ok!=true||amount==null||amount<=0)return;
    try{
      await Api.instance.post('/orders/$orderId/offers',{'amount':amount});
      if(context.mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(dt('تم إرسال عرضك للعميل'))));await onSent();}
    }catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
  }
  @override Widget build(BuildContext context)=>FilledButton.icon(onPressed:()=>_offer(context),icon:Icon(Icons.local_offer_outlined),label:Text(dt('تحديد الأجرة')));
}

class _CustomerDeliveryOffers extends StatefulWidget {
  final String orderId;
  final Future<void> Function() onSelected;
  const _CustomerDeliveryOffers({required this.orderId,required this.onSelected});
  @override State<_CustomerDeliveryOffers> createState()=>_CustomerDeliveryOffersState();
}
class _CustomerDeliveryOffersState extends State<_CustomerDeliveryOffers>{
  bool loading=true,selecting=false;
  String? error;
  List offers=[];
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{offers=await Api.instance.get('/orders/${widget.orderId}/offers') as List;error=null;}
    catch(e){error=e.toString();}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> _select(dynamic offer)async{
    setState(()=>selecting=true);
    try{
      await Api.instance.post('/orders/${widget.orderId}/offers/${offer['id']}/select',{});
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(dt('تم اختيار السائق وتأكيد الأجرة'))));await widget.onSelected();}
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
    finally{if(mounted)setState(()=>selecting=false);}
  }
  @override Widget build(BuildContext context){
    if(loading)return Padding(padding:EdgeInsets.all(12),child:Center(child:CircularProgressIndicator()));
    if(error!=null)return TextButton(onPressed:(){setState(()=>loading=true);_load();},child:Text(dt('تعذر تحميل العروض: $error')));
    if(offers.isEmpty)return Padding(padding:const EdgeInsets.all(12),child:Row(children:[
      Expanded(child:Text(dt('بانتظار عروض السائقين.'))),
      TextButton.icon(onPressed:(){setState(()=>loading=true);_load();},icon:Icon(Icons.refresh),label:Text(dt('تحديث'))),
    ]));
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),child:Row(children:[
        Expanded(child:Text(dt('عروض السائقين'),style:TextStyle(fontWeight:FontWeight.w900))),
        IconButton(onPressed:selecting?null:(){setState(()=>loading=true);_load();},tooltip: dt('تحديث العروض'),icon:Icon(Icons.refresh)),
      ])),
      for(final offer in offers)ListTile(
        leading:CircleAvatar(child:Icon(Icons.delivery_dining)),
        title:Text(offer['driver']?['user']?['name']?.toString()??dt('سائق')),
        subtitle:Text(offer['driver']?['vehicleType']?.toString()??dt('سائق معتمد')),
        trailing:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.end,children:[
          Text('${offer['amount']} ${offer['currency']}',style:TextStyle(fontWeight:FontWeight.w900)),
          TextButton(onPressed:selecting?null:()=>_select(offer),child:Text(dt('اختيار'))),
        ]),
      ),
    ]);
  }
}
