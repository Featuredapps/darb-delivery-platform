part of 'app_shell.dart';

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

