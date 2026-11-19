import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../design_system.dart';
import '../main.dart';
import '../notifications.dart';
import 'login_screen.dart';

part 'admin_screens.dart';
part 'customer_screens.dart';
part 'peer_delivery_screen.dart';
part 'vendor_screens.dart';
part 'driver_screens.dart';
part 'account_screens.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int tab = 0;
  bool loading = true;
  String role = 'CUSTOMER';
  String? error;
  Map<String, dynamic>? me;

  @override
  void initState() {
    super.initState();
    _load();
    DarbNotifications.register();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/auth/me');
      me = Map<String, dynamic>.from(data);
      role = me?['role']?.toString() ?? 'CUSTOMER';
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _logout() async {
    await DarbNotifications.unregister();
    await Api.instance.clear();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 42, color: DarbColors.muted),
                const SizedBox(height: 14),
                const Text('تعذر تحميل حسابك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: DarbColors.muted)),
                const SizedBox(height: 18),
                FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                TextButton(onPressed: _logout, child: const Text('تسجيل الخروج')),
              ],
            ),
          ),
        ),
      );
    }

    final isAdmin = role == 'ADMIN';
    final isCustomer = role == 'CUSTOMER';
    final isVendor = role == 'VENDOR';
    final titles = isAdmin
        ? ['طلبات المتاجر', 'طلبات السائقين', 'رسوم التوصيل', 'حسابي']
        : isCustomer
            ? ['الرئيسية', 'طلباتي', 'حسابي']
            : isVendor
                ? ['طلبات المتجر', 'المنتجات', 'حسابي']
                : ['الطلبات المتاحة', 'توصيلاتي', 'حسابي'];
    final pages = isAdmin
        ? [const AdminQueue(kind: 'vendors'), const AdminQueue(kind: 'drivers'), const AdminDeliveryZones(), AccountPage(me: me, onLogout: _logout)]
        : isCustomer
            ? [const CustomerHome(), const CustomerOrders(), AccountPage(me: me, onLogout: _logout)]
            : isVendor
                ? [const VendorOrders(), const VendorProducts(), AccountPage(me: me, onLogout: _logout)]
                : [const DriverAvailable(), const DriverOrders(), AccountPage(me: me, onLogout: _logout)];
    final icons = isAdmin
        ? [Icons.storefront_outlined, Icons.delivery_dining_rounded, Icons.payments_outlined, Icons.person_outline_rounded]
        : isCustomer
            ? [Icons.explore_outlined, Icons.receipt_long_outlined, Icons.person_outline_rounded]
            : isVendor
                ? [Icons.receipt_long_outlined, Icons.inventory_2_outlined, Icons.person_outline_rounded]
                : [Icons.radar_rounded, Icons.route_outlined, Icons.person_outline_rounded];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [DarbColors.forestSoft, DarbColors.forest]),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Text('د', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 23)),
            ),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('دَرْب', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, height: 1.1)),
                Text(titles[tab], style: const TextStyle(color: DarbColors.muted, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () { setState(() => loading = true); _load(); },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, .025), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: [
          for (var i = 0; i < titles.length; i++)
            NavigationDestination(icon: Icon(icons[i]), selectedIcon: Icon(icons[i]), label: titles[i]),
        ],
      ),
    );
  }
}
