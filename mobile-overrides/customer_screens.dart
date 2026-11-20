part of 'app_shell.dart';

class CustomerHome extends StatefulWidget {
  CustomerHome({super.key});
  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  final search = TextEditingController();
  final storesKey = GlobalKey();
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
      final loadedCities = await Api.instance.get('/cities') as List;
      cities = loadedCities;
      if (cities.isNotEmpty) {
        cityId ??= cities.first['id'].toString();
        vendors = await Api.instance.get('/vendors?cityId=$cityId&locale=ar') as List;
      } else {
        cityId = null;
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
    return translations.isEmpty ? dt('متجر') : translations.first['name']?.toString() ?? dt('متجر');
  }

  void _openPeerDelivery() {
    if (cityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dt('لا توجد مدينة مفعّلة لخدمة التوصيل حالياً'))),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PeerDeliveryScreen(cityId: cityId!),
    ));
  }

  void _openStores() {
    Scrollable.ensureVisible(
      storesKey.currentContext!,
      duration: Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      alignment: .04,
    );
  }

  Widget _sectionTitle(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink)),
      SizedBox(height: 4),
      Text(subtitle, style: TextStyle(fontSize: 12, color: DarbColors.muted, height: 1.45)),
    ],
  );

  Widget _serviceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final foreground = primary ? Colors.white : ink;
    return Material(
      color: primary ? DarbColors.forestSoft : Colors.white,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: primary ? Colors.transparent : DarbColors.line),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: primary ? Colors.white.withValues(alpha: .12) : Color(0xFFEAF2EC),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: primary ? Color(0xFFC8F169) : green, size: 23),
            ),
            SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: foreground, fontSize: 14, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text(subtitle, style: TextStyle(
                  color: primary ? Colors.white.withValues(alpha: .72) : DarbColors.muted,
                  fontSize: 11, height: 1.4,
                )),
              ],
            )),
            Icon(Icons.arrow_forward_ios_rounded, size: 15,
              color: primary ? Colors.white70 : DarbColors.muted),
          ]),
        ),
      ),
    );
  }

  Widget _storeTile(dynamic vendor) {
    final name = _vendorName(vendor);
    final count = vendor['_count']?['products'] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => VendorCatalog(
              vendorId: vendor['id'].toString(),
              name: name,
              cityId: cityId ?? '',
            ),
          )),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: DarbColors.line),
            ),
            child: Row(children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE6F1E9), Color(0xFFF4F7E9)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.storefront_rounded, color: green, size: 25),
              ),
              SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  Text('$count منتج متاح',
                    style: TextStyle(color: DarbColors.muted, fontSize: 11)),
                ],
              )),
              Icon(Icons.chevron_left_rounded, color: green, size: 23),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final visibleVendors = vendors.where(
      (v) => _vendorName(v).toLowerCase().contains(query),
    ).toList();

    return RefreshIndicator(
      onRefresh: _load,
      color: green,
      child: ListView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Color(0xFFE8F0EA),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.location_on_rounded, color: green, size: 20),
            ),
            SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dt('موقع التوصيل'), style: TextStyle(color: DarbColors.muted, fontSize: 10)),
                SizedBox(height: 2),
                if (cities.isNotEmpty)
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isDense: true,
                      value: cityId,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: green),
                      style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w900),
                      items: [for (final c in cities)
                        DropdownMenuItem(value: c['id'].toString(), child: Text(_cityName(c)))],
                      onChanged: (value) async {
                        if (value == null || value == cityId) return;
                        setState(() => cityId = value);
                        await _load();
                      },
                    ),
                  )
                else
                  Text(dt('المدينة غير متاحة'), style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w800)),
              ],
            )),
            IconButton(
              tooltip: dt('تحديث'),
              onPressed: _load,
              icon: Icon(Icons.refresh_rounded, color: DarbColors.muted),
            ),
          ]),
          SizedBox(height: 17),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF285647), Color(0xFF102B26), Color(0xFF091D19)],
              ),
              borderRadius: BorderRadius.circular(27),
              boxShadow: const [
                BoxShadow(color: Color(0x1D102B26), blurRadius: 22, offset: Offset(0, 10)),
              ],
            ),
            child: Stack(children: [
              Positioned(left: -48, top: -64, child: Container(
                width: 190, height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: .07), width: 27),
                ),
              )),
              Positioned(left: 28, bottom: -95, child: Container(
                width: 175, height: 175,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .035),
                ),
              )),
              Padding(
                padding: const EdgeInsets.fromLTRB(21, 22, 21, 21),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.route_rounded, color: Color(0xFFC8F169), size: 14),
                      SizedBox(width: 6),
                      Text(dt('توصيل من الباب إلى الباب'),
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  SizedBox(height: 17),
                  Text(dt('غرضك بأي مكان…\\nودَرْب يوصّله.'),
                    style: TextStyle(
                      color: Colors.white, fontSize: 27, height: 1.22,
                      fontWeight: FontWeight.w900, letterSpacing: -.35,
                    )),
                  SizedBox(height: 8),
                  Text(dt('اطلب سائقاً ليستلم غرضك من موقعك ويوصله إلى العنوان الذي تختاره.'),
                    style: TextStyle(color: Color(0xFFD0DED7), fontSize: 12, height: 1.55)),
                  SizedBox(height: 19),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: cityId == null ? null : _openPeerDelivery,
                      style: FilledButton.styleFrom(
                        backgroundColor: Color(0xFFC8F169),
                        foregroundColor: ink,
                        minimumSize: Size(0, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.near_me_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(dt('اطلب توصيلاً الآن'), style: TextStyle(fontWeight: FontWeight.w900)),
                      ]),
                    ),
                  ),
                  SizedBox(height: 11),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.verified_user_outlined, color: Color(0xFFB9D4C5), size: 13),
                    SizedBox(width: 5),
                    Text(dt('تتابع حالة طلبك من داخل التطبيق'),
                      style: TextStyle(color: Color(0xFFB9D4C5), fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),
            ]),
          ),
          SizedBox(height: 22),
          _sectionTitle('اختر الخدمة', 'مساران واضحان لكل احتياجات التوصيل'),
          SizedBox(height: 12),
          _serviceCard(
            icon: Icons.inventory_2_outlined,
            title: dt('إرسال غرض مستقل'),
            subtitle: dt('أرسل طرداً أو غرضاً من أي عنوان إلى آخر'),
            onTap: _openPeerDelivery,
            primary: true,
          ),
          SizedBox(height: 9),
          _serviceCard(
            icon: Icons.storefront_outlined,
            title: dt('الطلب من المتاجر'),
            subtitle: dt('تصفح المتاجر والمنتجات واطلب إلى بابك'),
            onTap: _openStores,
          ),
          SizedBox(height: 25),
          Container(key: storesKey),
          _sectionTitle('المتاجر المتاحة', 'متاجر مدينتك التي يمكنك الطلب منها'),
          SizedBox(height: 12),
          TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: dt('ابحث عن متجر أو نشاط...'),
              prefixIcon: Icon(Icons.search_rounded, color: green),
              suffixIcon: search.text.isEmpty ? null : IconButton(
                onPressed: search.clear,
                icon: Icon(Icons.close_rounded),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: DarbColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: DarbColors.forest, width: 1.4),
              ),
            ),
          ),
          SizedBox(height: 13),
          if (loading)
            ...List.generate(3, (index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: DarbColors.line),
                ),
                child: Center(child: LinearProgressIndicator(minHeight: 2)),
              ),
            ))
          else if (error != null)
            _ErrorPanel(message: error!, retry: _load)
          else if (visibleVendors.isEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: DarbColors.line),
              ),
              child: Column(children: [
                Container(
                  width: 55, height: 55,
                  decoration: BoxDecoration(
                    color: Color(0xFFEAF2EC),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(Icons.storefront_outlined, color: green, size: 27),
                ),
                SizedBox(height: 12),
                Text(
                  query.isEmpty ? 'لا توجد متاجر متاحة في هذه المدينة' : 'لم نعثر على نتائج مطابقة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 14),
                ),
                SizedBox(height: 6),
                Text(dt('هذا لا يمنعك من استخدام دَرْب لإرسال غرضك بشكل مستقل.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DarbColors.muted, fontSize: 11, height: 1.5),
                ),
                SizedBox(height: 13),
                OutlinedButton.icon(
                  onPressed: _openPeerDelivery,
                  icon: Icon(Icons.near_me_rounded, size: 17),
                  label: Text(dt('إرسال غرض بدلاً من ذلك')),
                ),
              ]),
            )
          else
            ...visibleVendors.map(_storeTile),
        ],
      ),
    );
  }
}
