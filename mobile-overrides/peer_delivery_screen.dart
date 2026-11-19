part of 'app_shell.dart';

class PeerDeliveryScreen extends StatefulWidget {
  final String cityId;
  const PeerDeliveryScreen({super.key, required this.cityId});

  @override
  State<PeerDeliveryScreen> createState() => _PeerDeliveryScreenState();
}

class _PeerDeliveryScreenState extends State<PeerDeliveryScreen> {
  final pickup = TextEditingController();
  final itemType = TextEditingController();
  final itemDescription = TextEditingController();
  final driverInstructions = TextEditingController();

  List<Map<String, dynamic>> addresses = [];
  String? addressId;
  String? error;
  int step = 0;
  bool loading = true;
  bool sending = false;
  bool locating = false;
  bool savingAddress = false;
  Position? pickupPosition;

  static const _stepTitles = ['المواقع', 'تفاصيل الغرض', 'مراجعة الطلب'];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    pickup.dispose();
    itemType.dispose();
    itemDescription.dispose();
    driverInstructions.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final result = await Api.instance.get('/addresses') as List;
      addresses = result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (addressId == null || !addresses.any((a) => a['id'].toString() == addressId)) {
        final located = addresses.where((a) => a['hasLocation'] == true).toList();
        addressId = located.isNotEmpty ? located.first['id'].toString() : null;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<Position> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('فعّل خدمة الموقع على الهاتف');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('يلزم السماح بالوصول إلى الموقع');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Future<void> _locatePickup() async {
    setState(() { locating = true; error = null; });
    try {
      pickupPosition = await _currentPosition();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> _addAddress() async {
    final label = TextEditingController();
    final details = TextEditingController();
    Position? position;
    String? dialogError;
    bool locatingAddress = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('إضافة عنوان تسليم'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: label,
                  decoration: const InputDecoration(labelText: 'اسم العنوان'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: details,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'العنوان بالتفصيل',
                    hintText: 'الحي، الشارع، البناء، أقرب نقطة دالة',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: locatingAddress ? null : () async {
                    setDialogState(() { locatingAddress = true; dialogError = null; });
                    try {
                      position = await _currentPosition();
                    } catch (e) {
                      dialogError = e.toString();
                    } finally {
                      setDialogState(() => locatingAddress = false);
                    }
                  },
                  icon: Icon(position == null ? Icons.my_location : Icons.check_circle),
                  label: Text(
                    locatingAddress
                        ? 'جارٍ تحديد الموقع...'
                        : position == null ? 'تحديد موقع العنوان' : 'تم تحديد الموقع',
                  ),
                ),
                if (position != null)
                  const Text(
                    'تم حفظ الإحداثيات لهذا العنوان',
                    style: TextStyle(color: DarbColors.forest, fontSize: 12),
                  ),
                if (dialogError != null)
                  Text(dialogError!, style: const TextStyle(color: DarbColors.danger)),
                const SizedBox(height: 6),
                const Text(
                  'يجب تحديد الموقع وأنت موجود في مكان التسليم نفسه.',
                  style: TextStyle(color: DarbColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: position == null ? null : () => Navigator.pop(dialogContext, true),
              child: const Text('حفظ العنوان'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      if (details.text.trim().length < 3 || position == null) {
        if (mounted) setState(() => error = 'أكمل العنوان وحدد موقعه الجغرافي');
      } else {
        setState(() { savingAddress = true; error = null; });
        try {
          final created = await Api.instance.post('/addresses', {
            'label': label.text.trim(),
            'details': details.text.trim(),
            'latitude': position!.latitude,
            'longitude': position!.longitude,
          });
          final address = Map<String, dynamic>.from(created as Map);
          address['hasLocation'] = true;
          if (mounted) {
            setState(() {
              addresses.insert(0, address);
              addressId = address['id'].toString();
            });
          }
        } catch (e) {
          if (mounted) setState(() => error = e.toString());
        } finally {
          if (mounted) setState(() => savingAddress = false);
        }
      }
    }
    label.dispose();
    details.dispose();
  }

  Map<String, dynamic>? get _selectedAddress {
    for (final address in addresses) {
      if (address['id'].toString() == addressId) return address;
    }
    return null;
  }

  String _addressLabel(Map<String, dynamic>? address) {
    if (address == null) return 'لم يتم اختيار عنوان';
    final label = (address['label'] ?? 'عنوان التسليم').toString();
    final details = (address['details'] ?? '').toString();
    return details.isEmpty ? label : '$label — $details';
  }

  bool _validateCurrentStep() {
    setState(() => error = null);
    if (step == 0) {
      if (pickup.text.trim().length < 5) {
        setState(() => error = 'اكتب وصفاً واضحاً لمكان الاستلام');
        return false;
      }
      if (pickupPosition == null) {
        setState(() => error = 'حدد موقع الاستلام أولاً');
        return false;
      }
      final destination = _selectedAddress;
      if (destination == null || destination['hasLocation'] != true) {
        setState(() => error = 'اختر عنوان تسليم محفوظاً مع موقع جغرافي أو أضف عنواناً جديداً');
        return false;
      }
    } else if (step == 1) {
      if (itemType.text.trim().length < 2) {
        setState(() => error = 'اكتب نوع الغرض الذي تريد إرساله');
        return false;
      }
      if (itemDescription.text.trim().length < 3) {
        setState(() => error = 'أضف وصفاً مختصراً للغرض');
        return false;
      }
    }
    return true;
  }

  void _next() {
    if (!_validateCurrentStep()) return;
    setState(() => step += 1);
  }

  void _back() {
    if (sending) return;
    if (step == 0) {
      Navigator.pop(context);
    } else {
      setState(() { step--; error = null; });
    }
  }

  Future<void> _submit() async {
    if (!_validateCurrentStep()) return;
    final destination = _selectedAddress;
    if (destination == null || pickupPosition == null) return;

    final noteParts = <String>[
      'نوع الغرض: ${itemType.text.trim()}',
      'وصف الغرض: ${itemDescription.text.trim()}',
      if (driverInstructions.text.trim().isNotEmpty)
        'تعليمات للسائق: ${driverInstructions.text.trim()}',
    ];

    setState(() { sending = true; error = null; });
    try {
      final order = await Api.instance.post('/orders/peer-delivery', {
        'cityId': widget.cityId,
        'addressId': addressId,
        'pickupAddress': pickup.text.trim(),
        'pickupLatitude': pickupPosition!.latitude,
        'pickupLongitude': pickupPosition!.longitude,
        'notes': noteParts.join('\n'),
      });
      if (!mounted) return;
      final fee = order['deliveryFee'];
      final currency = (order['currency'] ?? '').toString();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: DarbColors.forest, size: 42),
          title: const Text('تم إرسال طلبك'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('رقم الطلب: ${order['orderNumber'] ?? order['id']}'),
              if (fee != null) ...[
                const SizedBox(height: 8),
                Text('رسوم التوصيل: $fee $currency'),
              ],
              const SizedBox(height: 8),
              const Text('سيظهر طلبك للسائقين المتاحين في مدينتك.'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Widget _progressHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'الخطوة ${step + 1} من 3',
              style: const TextStyle(color: DarbColors.muted, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              _stepTitles[step],
              style: const TextStyle(color: DarbColors.forest, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(3, (index) => Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              height: 5,
              margin: EdgeInsetsDirectional.only(end: index == 2 ? 0 : 6),
              decoration: BoxDecoration(
                color: index <= step ? DarbColors.forest : DarbColors.line,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )),
        ),
      ],
    );
  }

  Widget _stepOne() {
    final selected = _selectedAddress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('من أين نستلم؟', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: DarbColors.ink)),
        const SizedBox(height: 6),
        const Text('حدد مكان وجود الغرض حتى يصل السائق إليك.', style: TextStyle(color: DarbColors.muted)),
        const SizedBox(height: 18),
        TextField(
          controller: pickup,
          maxLines: 2,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'وصف مكان الاستلام',
            hintText: 'مثلاً: أمام صيدلية الشفاء، شارع ...',
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: locating ? null : _locatePickup,
          icon: locating
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(pickupPosition == null ? Icons.my_location : Icons.check_circle),
          label: Text(
            locating ? 'جارٍ تحديد الموقع...' : pickupPosition == null ? 'استخدام موقعي الحالي' : 'تم تحديد موقع الاستلام',
          ),
        ),
        if (pickupPosition != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'تم تحديد الموقع بدقة: ${pickupPosition!.latitude.toStringAsFixed(4)}, ${pickupPosition!.longitude.toStringAsFixed(4)}',
              style: const TextStyle(color: DarbColors.muted, fontSize: 11),
            ),
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: Text('إلى أين نوصّل؟', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            TextButton.icon(
              onPressed: savingAddress ? null : _addAddress,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('إضافة عنوان'),
            ),
          ],
        ),
        if (addresses.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DarbColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: DarbColors.line),
            ),
            child: const Text('لا يوجد عنوان تسليم محفوظ. أضف عنواناً وحدد موقعه للمتابعة.', style: TextStyle(color: DarbColors.muted)),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: addressId,
            isExpanded: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on_outlined)),
            items: [
              for (final address in addresses)
                DropdownMenuItem(
                  value: address['id'].toString(),
                  child: Text(
                    _addressLabel(address),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => addressId = value),
          ),
        if (selected != null && selected['hasLocation'] != true)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('هذا العنوان لا يحتوي على موقع. أضف عنواناً جديداً وحدد موقعه.', style: TextStyle(color: DarbColors.danger, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _stepTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ماذا تريد إرسال؟', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: DarbColors.ink)),
        const SizedBox(height: 6),
        const Text('أخبر السائق بنوع الغرض وحجمه بشكل واضح.', style: TextStyle(color: DarbColors.muted)),
        const SizedBox(height: 20),
        TextField(
          controller: itemType,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'نوع الغرض',
            hintText: 'مثلاً: مستندات، حقيبة، قطعة غيار',
            prefixIcon: Icon(Icons.category_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: itemDescription,
          minLines: 3,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'وصف الغرض',
            hintText: 'اذكر الحجم أو أي تفاصيل تساعد السائق',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: driverInstructions,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'تعليمات إضافية للسائق (اختياري)',
            hintText: 'وقت مناسب، شخص للتواصل عند الوصول...',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: DarbColors.forest, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: DarbColors.muted, fontSize: 12)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(color: DarbColors.ink, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepThree() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('راجع طلبك', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: DarbColors.ink)),
        const SizedBox(height: 6),
        const Text('تأكد من التفاصيل قبل إرسال الطلب للسائقين.', style: TextStyle(color: DarbColors.muted)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: DarbColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DarbColors.line),
          ),
          child: Column(
            children: [
              _summaryRow(Icons.trip_origin, 'موقع الاستلام', pickup.text.trim()),
              const Divider(height: 1),
              _summaryRow(Icons.location_on_outlined, 'عنوان التسليم', _addressLabel(_selectedAddress)),
              const Divider(height: 1),
              _summaryRow(Icons.inventory_2_outlined, 'نوع الغرض', itemType.text.trim()),
              const Divider(height: 1),
              _summaryRow(Icons.description_outlined, 'الوصف', itemDescription.text.trim()),
              if (driverInstructions.text.trim().isNotEmpty) ...[
                const Divider(height: 1),
                _summaryRow(Icons.notes_rounded, 'تعليمات السائق', driverInstructions.text.trim()),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: DarbColors.mint.withValues(alpha: .35),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.payments_outlined, color: DarbColors.forest),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ستظهر رسوم التوصيل بعد احتساب المسافة وإعدادات المدينة عند إرسال الطلب.',
                  style: TextStyle(color: DarbColors.forest, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('توصيل مستقل'),
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: _back,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                      children: [
                        _progressHeader(),
                        const SizedBox(height: 28),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: KeyedSubtree(
                            key: ValueKey(step),
                            child: step == 0 ? _stepOne() : step == 1 ? _stepTwo() : _stepThree(),
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: DarbColors.danger.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline, color: DarbColors.danger, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(error!, style: const TextStyle(color: DarbColors.danger, fontSize: 12))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    decoration: const BoxDecoration(
                      color: DarbColors.surface,
                      border: Border(top: BorderSide(color: DarbColors.line)),
                    ),
                    child: Row(
                      children: [
                        if (step > 0) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: sending ? null : _back,
                              child: const Text('السابق'),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          flex: step == 0 ? 1 : 2,
                          child: FilledButton(
                            onPressed: sending || savingAddress
                                ? null
                                : step == 2 ? _submit : _next,
                            child: sending
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(step == 2 ? 'تأكيد وإرسال الطلب' : 'متابعة'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
