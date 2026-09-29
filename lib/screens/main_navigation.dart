import 'package:flutter/material.dart';

import '../theme/stitch_theme.dart';
import '../services/app_session.dart';
import 'absensi_home_screen.dart';
import 'jadwal_screen.dart';
import 'overview_screen.dart';
import 'pos_screen.dart';
import 'profil_screen.dart';
import 'shift_management_screen.dart';
import 'transaction_history_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  late Set<int> _visitedIndexes;

  @override
  void initState() {
    super.initState();
    _currentIndex = AppSession.instance.user?.isCashier == true ? 1 : 0;
    _visitedIndexes = {_currentIndex};
  }

  Future<void> _selectTab(
    int index, {
    required bool isCashier,
    required _NavigationItem item,
  }) async {
    if (isCashier && item.keyName == 'pos') {
      final accessGranted = await showDialog<bool>(
        context: context,
        builder: (_) =>
            _PosPinDialog(verifyPin: AppSession.instance.verifyPosPin),
      );
      if (accessGranted != true) return;
    }

    if (mounted) {
      setState(() {
        _currentIndex = index;
        _visitedIndexes.add(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AppSession.instance.user;
    final isCashier = user?.isCashier == true;
    final isOwner = user?.isOwner == true;
    final items = isOwner
        ? const [
            _NavigationItem(
              'overview',
              'Overview',
              Icons.dashboard_outlined,
              OverviewScreen(),
            ),
            _NavigationItem(
              'history',
              'Riwayat',
              Icons.receipt_long_outlined,
              TransactionHistoryScreen(),
            ),
            _NavigationItem(
              'shift',
              'Shift',
              Icons.swap_horiz_rounded,
              ShiftManagementScreen(),
            ),
            _NavigationItem(
              'attendance',
              'Absensi',
              Icons.how_to_reg_outlined,
              AbsensiHomeScreen(),
            ),
            _NavigationItem(
              'profile',
              'Profil',
              Icons.person_outline_rounded,
              ProfilScreen(),
            ),
          ]
        : isCashier
        ? const [
            _NavigationItem(
              'pos',
              'POS',
              Icons.point_of_sale_outlined,
              PosScreen(),
            ),
            _NavigationItem(
              'history',
              'Riwayat',
              Icons.receipt_long_outlined,
              TransactionHistoryScreen(),
            ),
            _NavigationItem(
              'shift',
              'Shift',
              Icons.swap_horiz_rounded,
              ShiftManagementScreen(),
            ),
            _NavigationItem(
              'attendance',
              'Absensi',
              Icons.how_to_reg_outlined,
              AbsensiHomeScreen(),
            ),
            _NavigationItem(
              'profile',
              'Profil',
              Icons.person_outline_rounded,
              ProfilScreen(),
            ),
          ]
        : const [
            _NavigationItem(
              'attendance',
              'Absensi',
              Icons.how_to_reg_outlined,
              AbsensiHomeScreen(),
            ),
          ];
    final selectedIndex = _currentIndex.clamp(0, items.length - 1);
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: Row(
        children: [
          if (isWide)
            _SidebarNavigation(
              items: items,
              selectedIndex: selectedIndex,
              onSelect: (index) =>
                  _selectTab(index, isCashier: isCashier, item: items[index]),
            ),
          Expanded(
            child: IndexedStack(
              index: selectedIndex,
              children: [
                for (var index = 0; index < items.length; index++)
                  _visitedIndexes.contains(index)
                      ? items[index].screen
                      : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide || items.length == 1
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  _selectTab(index, isCashier: isCashier, item: items[index]),
              destinations: items
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(item.icon),
                      label: item.label,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _NavigationItem {
  const _NavigationItem(this.keyName, this.label, this.icon, this.screen);

  final String keyName;
  final String label;
  final IconData icon;
  final Widget screen;
}

class _SidebarNavigation extends StatelessWidget {
  const _SidebarNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_NavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final user = AppSession.instance.user;
    return Container(
      width: 218,
      color: StitchTheme.sidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 22),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF151B1D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.point_of_sale_rounded,
                      color: StitchTheme.primaryGreen,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'POSHub',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'ENTERPRISE',
                        style: TextStyle(
                          color: StitchTheme.primaryGreen,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF183D35),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: Color(0xFF7CE0C5),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        user?.isOwner == true
                            ? 'Owner & Manager Portal'
                            : user?.role ?? 'Portal Karyawan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Text(
                      'PRO',
                      style: TextStyle(
                        color: Color(0xFF7CE0C5),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 12, 7),
              child: Text(
                'OPERASIONAL',
                style: TextStyle(
                  color: Color(0xFF9BA7A8),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = index == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                        selected: selected,
                        selectedTileColor: StitchTheme.primaryGreen,
                        selectedColor: Colors.white,
                        iconColor: selected
                            ? Colors.white
                            : const Color(0xFFD2D8D9),
                        textColor: selected
                            ? Colors.white
                            : const Color(0xFFD2D8D9),
                        leading: Icon(item.icon, size: 18),
                        title: Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () => onSelect(index),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Color(0xFF414849), height: 1),
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 15,
                backgroundColor: StitchTheme.primaryGreen,
                child: Text(
                  (user?.name.isNotEmpty == true ? user!.name[0] : 'U')
                      .toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              title: Text(
                user?.name ?? 'Pengguna',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                user?.role ?? '',
                style: const TextStyle(color: Color(0xFFB2BCBD), fontSize: 9),
              ),
              trailing: IconButton(
                tooltip: 'Keluar',
                onPressed: AppSession.instance.logout,
                icon: const Icon(
                  Icons.logout_rounded,
                  size: 17,
                  color: Color(0xFFCFD6D6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosPinDialog extends StatefulWidget {
  const _PosPinDialog({required this.verifyPin});

  final bool Function(String) verifyPin;

  @override
  State<_PosPinDialog> createState() => _PosPinDialogState();
}

class _PosPinDialogState extends State<_PosPinDialog> {
  final _pinController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.verifyPin(_pinController.text)) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'PIN kasir tidak valid.');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Verifikasi PIN POS'),
    content: TextField(
      key: const ValueKey('pos-pin-input'),
      controller: _pinController,
      keyboardType: TextInputType.number,
      maxLength: 6,
      obscureText: true,
      autofocus: true,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: 'PIN kasir',
        prefixIcon: const Icon(Icons.lock_outline),
        errorText: _error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Batal'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Buka POS')),
    ],
  );
}
