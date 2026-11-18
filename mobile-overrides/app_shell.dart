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

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});
  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  final search = TextEditingController();
  bool loading = true;
  String? error;
  List<dynamic> cities = [], vendors = [];
  String? cityId;

  @override
  void initState() {
    super.initState();
    search.addListener(() { if (mounted) setState(() {}); });
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      cities = await Api.instance.get('/cities') as List;
      if (cities.isNotEmpty) {
        cityId ??= cities.first['id'].toString();
        vendors = await Api.instance.get('/vendors?cityId=$cityId&locale=ar') as List;
      } else {
        vendors = [];
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _cityName(dynamic city) {
    final names = city['names'] as List? ?? [];
    for (final item in names) {
      if (item is Map && item['locale'] == 'ar') return item['name'].toString();
    }
    return names.isEmpty ? city['code'].toString() : names.first['name'].toString();
  }

  String _vendorName(dynamic vendor) {
    final translations = vendor['translations'] as List? ?? [];
    for (final item in translations) {
      if (item is Map && item['locale'] == 'ar') return item['name'].toString();
    }
    return translations.isEmpty ? 'متجر' : translations.first['name']?.toString() ?? 'متجر';
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final visibleVendors = vendors.where((v) => _vendorName(v).toLowerCase().contains(query)).toList();
    return RefreshIndicator(
      onRefresh: _load,
      color: green,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: green, size: 19),
              const SizedBox(width: 6),
              const Text('التوصيل إلى', style: TextStyle(color: Colors.black54, fontSize: 12)),
              const Spacer(),
              if (cities.isNotEmpty)
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: cityId,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: green),
                    style: const TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w800),
                    items: [for (final c in cities) DropdownMenuItem(value: c['id'].toString(), child: Text(_cityName(c)))],
                    onChanged: (value) async {
                      if (value == null || value == cityId) return;
                      setState(() => cityId = value);
                      await _load();
                    },
                  ),
                )
              else
                const Text('حدد المدينة', style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF244D40), Color(0xFF102B26), Color(0xFF0B211D)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              children: [
                Positioned(left: -38, top: -52, child: Container(
                  width: 190, height: 190,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.045)),
                )),
                Positioned(left: 32, bottom: -72, child: Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(.08), width: 24)),
                )),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(30)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.bolt_rounded, color: Color(0xFFC8F169), size: 15),
                          SizedBox(width: 5),
                          Text('كل مشاويرك في مكان واحد', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      const Text('من وين بدك\nنوصّل لك؟',
                        style: TextStyle(color: Colors.white, fontSize: 29, height: 1.22, fontWeight: FontWeight.w900, letterSpacing: -.4)),
                      const SizedBox(height: 9),
                      const Text('اطلب من متجرك المفضل أو أرسل غرضك لأي مكان.',
                        style: TextStyle(color: Color(0xFFD0DED7), fontSize: 13, height: 1.55)),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFC8F169),
                                foregroundColor: ink,
                                minimumSize: const Size(0, 52),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              onPressed: cityId == null ? null : () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => PeerDeliveryScreen(cityId: cityId!))),
                              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.near_me_rounded, size: 18),
                                SizedBox(width: 7),
                                Text('أرسل غرضاً', style: TextStyle(fontWeight: FontWeight.w900)),
                              ]),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(15)),
                            child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 23),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('اكتشف المتاجر', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: ink)),
          const SizedBox(height: 5),
          const Text('خيارات قريبة منك، وطلبك يوصل لبابك', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 15),
          TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'ابحث عن متجر...',
              prefixIcon: const Icon(Icons.search_rounded, color: green),
              suffixIcon: search.text.isEmpty ? null : IconButton(
                onPressed: search.clear, icon: const Icon(Icons.close_rounded)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFFE7ECE7))),
            ),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 34), child: Center(child: CircularProgressIndicator()))
          else if (error != null)
            _ErrorPanel(message: error!, retry: _load)
          else if (visibleVendors.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE7ECE7))),
              child: Column(children: [
                Container(width: 58, height: 58,
                  decoration: BoxDecoration(color: const Color(0xFFEAF2EC), borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.storefront_rounded, color: green, size: 28)),
                const SizedBox(height: 13),
                Text(query.isEmpty ? 'لا توجد متاجر متاحة حالياً' : 'لم نعثر على متجر بهذا الاسم',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
                const SizedBox(height: 5),
                const Text('يمكنك تحديث القائمة أو استخدام خدمة التوصيل المستقل.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.5)),
                const SizedBox(height: 14),
                OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('تحديث المتاجر')),
              ]),
            )
          else
            ...visibleVendors.map((v) {
              final name = _vendorName(v);
              final count = v['_count']?['products'] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(21),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(21),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => VendorCatalog(vendorId: v['id'].toString(), name: name, cityId: cityId ?? ''))),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(21),
                        border: Border.all(color: const Color(0xFFE7ECE7))),
                      child: Row(children: [
                        Container(width: 58, height: 58,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFE6F1E9), Color(0xFFF4F7E9)]),
                            borderRadius: BorderRadius.circular(17)),
                          child: const Icon(Icons.storefront_rounded, color: green, size: 27)),
                        const SizedBox(width: 13),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 5),
                          Text('$count منتج متاح', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        ])),
                        Container(width: 34, height: 34,
                          decoration: BoxDecoration(color: const Color(0xFFF4F6F2), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.arrow_forward_ios_rounded, textDirection: TextDirection.ltr, color: green, size: 14)),
                      ]),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class PeerDeliveryScreen extends StatefulWidget {
  final String cityId;
  const PeerDeliveryScreen({super.key, required this.cityId});
  @override
  State<PeerDeliveryScreen> createState() => _PeerDeliveryScreenState();
}

class _PeerDeliveryScreenState extends State<PeerDeliveryScreen> {
  final pickup = TextEditingController(), notes = TextEditingController();
  List<Map<String, dynamic>> addresses = [];
  String? addressId, error;
  bool loading = true, sending = false, locating = false, savingAddress = false;
  Position? pickupPosition;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { pickup.dispose(); notes.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final result = await Api.instance.get('/addresses') as List;
      addresses = result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (addressId == null || !addresses.any((a) => a['id'].toString() == addressId)) {
        addressId = addresses.isEmpty ? null : addresses.first['id'].toString();
      }
    } catch (e) { error = e.toString(); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<Position> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw Exception('فعّل خدمة الموقع على الهاتف');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('يلزم السماح بالوصول إلى الموقع');
    }
    return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20),
    ));
  }

  Future<void> _locatePickup() async {
    setState(() { locating = true; error = null; });
    try { pickupPosition = await _currentPosition(); }
    catch (e) { error = e.toString(); }
    finally { if (mounted) setState(() => locating = false); }
  }

  Future<void> _addAddress() async {
    final label = TextEditingController(), details = TextEditingController();
    Position? position;
    String? dialogError;
    bool locatingAddress = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('عنوان تسليم جديد'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: label, decoration: const InputDecoration(labelText: 'اسم العنوان (اختياري)')),
            const SizedBox(height: 10),
            TextField(controller: details, maxLines: 3, decoration: const InputDecoration(labelText: 'العنوان بالتفصيل')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: locatingAddress ? null : () async {
                setDialogState(() { locatingAddress = true; dialogError = null; });
                try { position = await _currentPosition(); }
                catch (e) { dialogError = e.toString(); }
                finally { setDialogState(() => locatingAddress = false); }
              },
              icon: Icon(position == null ? Icons.my_location : Icons.check_circle),
              label: Text(locatingAddress ? 'جارٍ تحديد الموقع...' : position == null ? 'تحديد موقع عنوان التسليم' : 'تم تحديد موقع العنوان'),
            ),
            if (position != null)
              Text(position!.latitude.toStringAsFixed(5) + ', ' + position!.longitude.toStringAsFixed(5),
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
            if (dialogError != null) Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            const SizedBox(height: 6),
            const Text('حدد الموقع وأنت موجود في مكان التسليم نفسه. لا تستخدم موقعك الحالي إذا كان العنوان في مكان آخر.',
              style: TextStyle(fontSize: 11, color: Colors.black54)),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: position == null ? null : () => Navigator.pop(dialogContext, true),
              child: const Text('حفظ العنوان'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && details.text.trim().length < 3) {
      if (mounted) setState(() => error = 'اكتب تفاصيل عنوان التسليم بشكل أوضح');
    }
    if (saved == true && details.text.trim().length >= 3) {
      setState(() { savingAddress = true; error = null; });
      try {
        final created = await Api.instance.post('/addresses', {
          'label': label.text.trim(), 'details': details.text.trim(),
          'latitude': position!.latitude, 'longitude': position!.longitude,
        });
        final address = Map<String, dynamic>.from(created as Map);
        address['hasLocation'] = true;
        if (mounted) setState(() { addresses.insert(0, address); addressId = address['id'].toString(); });
      } catch (e) { if (mounted) setState(() => error = e.toString()); }
      finally { if (mounted) setState(() => savingAddress = false); }
    }
    label.dispose(); details.dispose();
  }

  Future<void> _submit() async {
    if (pickup.text.trim().length < 5) { setState(() => error = 'اكتب عنوان الاستلام بالتفصيل'); return; }
    if (pickupPosition == null) { setState(() => error = 'حدد موقع الاستلام أولاً'); return; }
    Map<String, dynamic>? selected;
    for (final address in addresses) {
      if (address['id'].toString() == addressId) selected = address;
    }
    if (selected == null) { setState(() => error = 'أضف عنوان التسليم أولاً'); return; }
    if (selected['hasLocation'] != true) {
      setState(() => error = 'عنوان التسليم لا يحتوي على موقع جغرافي. أضف عنواناً جديداً وحدد موقعه.');
      return;
    }
    setState(() { sending = true; error = null; });
    try {
      final order = await Api.instance.post('/orders/peer-delivery', {
        'cityId': widget.cityId, 'addressId': addressId,
        'pickupAddress': pickup.text.trim(),
        'pickupLatitude': pickupPosition!.latitude,
        'pickupLongitude': pickupPosition!.longitude,
        'notes': notes.text.trim(),
      });
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('تم إرسال طلب التوصيل'),
        content: Text('رقم الطلب: ' + (order['orderNumber'] ?? order['id']).toString() +
          '\nتم احتساب الرسوم حسب إعدادات المدينة وموقع التسليم.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => sending = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('توصيل مستقل')),
    body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
      padding: const EdgeInsets.all(18), children: [
        const Text('أرسل غرضاً من موقع إلى موقع', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('حدد موقع الاستلام واختر عنوان تسليم محفوظاً مع موقع جغرافي.', style: TextStyle(color: Colors.black54)),
        if (error != null && addresses.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _ErrorPanel(message: error!, retry: _load),
          ),
        const SizedBox(height: 22),
        TextField(controller: pickup, maxLines: 3,
          decoration: const InputDecoration(labelText: 'وصف مكان الاستلام', hintText: 'اسم المكان، الشارع، أقرب نقطة دالة')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: locating ? null : _locatePickup,
          icon: Icon(pickupPosition == null ? Icons.my_location : Icons.check_circle_outline),
          label: Text(locating ? 'جارٍ تحديد الموقع...' : pickupPosition == null ? 'تحديد موقعي الحالي للاستلام' : 'تم تحديد موقع الاستلام'),
        ),
        if (pickupPosition != null)
          Text(pickupPosition!.latitude.toStringAsFixed(5) + ', ' + pickupPosition!.longitude.toStringAsFixed(5),
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 18),
        Row(children: [
          const Expanded(child: Text('عنوان التسليم', style: TextStyle(fontWeight: FontWeight.w900))),
          TextButton.icon(onPressed: savingAddress ? null : _addAddress,
            icon: const Icon(Icons.add_location_alt_outlined), label: const Text('إضافة عنوان')),
        ]),
        if (addresses.isEmpty) const _EmptyPanel(text: 'لا يوجد عنوان محفوظ. أضف عنواناً وحدد موقعه الجغرافي.'),
        if (addresses.isNotEmpty) DropdownButtonFormField<String>(
          value: addressId, isExpanded: true,
          items: [for (final a in addresses) DropdownMenuItem(
            value: a['id'].toString(),
            child: Row(children: [
              Expanded(child: Text((a['label'] ?? 'عنوان').toString() + ' — ' + (a['details'] ?? '').toString(),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              Icon(a['hasLocation'] == true ? Icons.location_on : Icons.location_off,
                size: 16, color: a['hasLocation'] == true ? green : Colors.red),
            ]),
          )],
          onChanged: (v) => setState(() => addressId = v),
        ),
        if (addresses.any((a) => a['id'].toString() == addressId && a['hasLocation'] != true))
          const Padding(padding: EdgeInsets.only(top: 7),
            child: Text('هذا العنوان لا يحتوي على إحداثيات. أضف عنواناً جديداً بموقع محدد لإكمال الطلب.',
              style: TextStyle(color: Colors.red, fontSize: 12))),
        const SizedBox(height: 16),
        TextField(controller: notes, maxLines: 3,
          decoration: const InputDecoration(labelText: 'تفاصيل الغرض أو تعليمات للسائق (اختياري)')),
        if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 18),
        FilledButton(onPressed: sending || savingAddress || addresses.isEmpty ? null : _submit,
          child: sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('إرسال طلب التوصيل')),
      ],
    ),
  );
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
Widget _orderCard(dynamic row){final id=row['id']?.toString()??'';final status=row['status']?.toString()??'';final actions=<Widget>[];if(widget.path=='/orders/vendor'){if(status=='PENDING')actions.add(_action(id,'قبول','ACCEPTED'));if(status=='ACCEPTED')actions.add(_action(id,'بدء التحضير','PREPARING'));if(status=='PREPARING')actions.add(_action(id,'جاهز للاستلام','READY'));}if(widget.path=='/orders/driver/available')actions.add(TextButton(onPressed:()=>_claim(id),child:const Text('استلام الطلب')));if(widget.path=='/orders/mine'&&(status=='ASSIGNED'||status=='PICKED_UP'))actions.add(TextButton.icon(onPressed:()=>_track(id),icon:const Icon(Icons.location_on_outlined),label:const Text('موقع السائق')));if(widget.path=='/orders/driver/mine'){if(status=='ASSIGNED')actions.add(_action(id,'تم الاستلام','PICKED_UP'));if(status=='PICKED_UP')actions.add(_action(id,'تم التسليم','DELIVERED'));}final peer=row['type']=='PEER_DELIVERY';
final pickup=row['pickupAddress']?.toString();
final destination=(row['address'] is Map)?row['address']['details']?.toString():null;
return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
ListTile(contentPadding:EdgeInsets.zero,title:Text(peer?'طلب توصيل مستقل':'طلب ${row['orderNumber']??id}'),subtitle:Text('رقم الطلب: ${row['orderNumber']??id} • الحالة: $status'),trailing:Text('${row['total']??''} ${row['currency']??''}')),
if(peer&&pickup!=null)ListTile(dense:true,leading:const Icon(Icons.store_mall_directory_outlined),title:const Text('الاستلام'),subtitle:Text(pickup)),
if(peer&&destination!=null)ListTile(dense:true,leading:const Icon(Icons.flag_outlined),title:const Text('التسليم'),subtitle:Text(destination)),
if(actions.isNotEmpty)Wrap(spacing:8,children:actions)
])));}
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
