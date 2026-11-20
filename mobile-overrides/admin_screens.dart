part of 'app_shell.dart';

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
    if (!loading && error == null && rows.isEmpty) _EmptyPanel(text: dt('لا توجد طلبات معلّقة حالياً')),
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
      if (detail.isNotEmpty) Text(detail), if (city.isNotEmpty) Text(dt('رمز المدينة: $city')),
      const SizedBox(height: 10), Wrap(spacing: 8, children: [
        FilledButton(onPressed: working ? null : () => _setStatus(id, 'APPROVED'), child: Text(dt('اعتماد'))),
        OutlinedButton(onPressed: working ? null : () => _setStatus(id, widget.kind == 'vendors' ? 'REJECTED' : 'SUSPENDED'), child: Text(widget.kind == 'vendors' ? 'رفض' : 'تعليق')),
      ]),
    ])));
  }
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
    if(selectableCities.isEmpty){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(dt('لا توجد مدن أخرى تحتاج إلى إعداد رسوم'))));return;}
    final name=TextEditingController(text:zone?['name']?.toString()??'');
    final base=TextEditingController(text:zone?['feeBase']?.toString()??'');
    final perKm=TextEditingController(text:zone?['feePerKm']?.toString()??'');
    String cityId=zone?['cityId']?.toString()??selectableCities.first['id'].toString();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
      title:Text(zone==null?'إضافة منطقة توصيل':'تعديل رسوم التوصيل'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        if(zone==null)DropdownButtonFormField<String>(value:cityId,decoration:InputDecoration(labelText: dt('المدينة')),items:[for(final c in selectableCities)DropdownMenuItem(value:c['id'].toString(),child:Text(_cityName(c)))],onChanged:(v){if(v!=null)setDialog(()=>cityId=v);}),
        TextField(controller:name,decoration:InputDecoration(labelText: dt('وصف إعداد الرسوم'))),
        TextField(controller:base,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText: dt('الرسم الأساسي (ل.س)'))),
        TextField(controller:perKm,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText: dt('الرسم لكل كيلومتر (ل.س)'))),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(dt('إلغاء'))),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(dt('حفظ')))],
    )));
    if(ok==true){
      final feeBase=double.tryParse(base.text),feePerKm=double.tryParse(perKm.text);
      if(name.text.trim().isEmpty||feeBase==null||feePerKm==null||feeBase<0||feePerKm<0){
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(dt('أدخل اسمًا ورسومًا رقمية غير سالبة'))));
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
    floatingActionButton:FloatingActionButton.extended(onPressed:working?null:()=>_edit(),icon:const Icon(Icons.add),label:Text(dt('إضافة رسوم لمدينة'))),
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:TextButton(onPressed:_load,child:Text(dt('تعذر تحميل المناطق: $error')))):zones.isEmpty?const Center(child:_EmptyPanel(text: dt('لم تُضف رسوم توصيل بعد'))):RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
      Text(dt('إعداد رسوم التوصيل'),style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
      const SizedBox(height:8),Text(dt('يُضبط رسم واحد لكل مدينة. احتساب رسم الكيلومتر يتطلب تحديد موقع المتجر وموقع عنوان العميل.'),style:TextStyle(color:Colors.black54)),
      for(final zone in zones)Card(child:ListTile(
        leading:const Icon(Icons.payments_outlined,color:green),
        title:Text(zone['name']?.toString()??'منطقة'),
        subtitle:Text('${_cityName(zone['city'] as Map)} • أساسي: ${zone['feeBase']} ل.س • لكل كم: ${zone['feePerKm']} ل.س'),
        trailing:IconButton(onPressed:working?null:()=>_edit(zone as Map),icon:const Icon(Icons.edit_outlined)),
      )),
    ])),
  );
}

