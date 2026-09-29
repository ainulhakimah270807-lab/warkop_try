import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/app_data.dart';
import '../theme/stitch_theme.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  List<TransactionRecord> _orders = const [];
  List<ShiftRecord> _shifts = const [];
  List<MenuItem> _products = menuItems;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    ApiService.transactionRevision.addListener(_refreshAfterTransaction);
    _load();
  }

  @override
  void dispose() {
    ApiService.transactionRevision.removeListener(_refreshAfterTransaction);
    super.dispose();
  }

  void _refreshAfterTransaction() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.loadTransactions(),
        ApiService.loadShifts(),
        ApiService.loadProducts(),
      ]);
      if (!mounted) return;
      setState(() {
        _orders = results[0] as List<TransactionRecord>;
        _shifts = results[1] as List<ShiftRecord>;
        _products = results[2] as List<MenuItem>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final todayOrders = _orders
        .where((order) => DateUtils.isSameDay(order.createdAt, today))
        .toList();
    final revenue = todayOrders.fold<int>(0, (sum, order) => sum + order.total);
    final activeCashiers = _shifts
        .where((shift) => shift.status == 'open')
        .length;
    final lowStock = _products.where((item) => item.stock <= 10).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portal Manajemen'),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.sync_rounded, size: 17),
            label: const Text('Sinkronkan'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Dashboard Overview & Analitik Operasional',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                ),
                _Pill(
                  icon: _error == null
                      ? Icons.circle
                      : Icons.cloud_off_outlined,
                  label: _error == null
                      ? ApiService.isSupabaseConfigured
                            ? 'Cloud API Terhubung'
                            : 'Mode Lokal · API belum diatur'
                      : 'Sinkronisasi bermasalah',
                  color: _error == null
                      ? const Color(0xFFE5F8F1)
                      : const Color(0xFFFFEDEB),
                  foreground: _error == null
                      ? const Color(0xFF087B5C)
                      : const Color(0xFFB9382D),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Cabang Senopati  ·  ${_dateLabel(DateTime.now())}',
              style: const TextStyle(
                color: StitchTheme.textMuted,
                fontSize: 12,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: _error!, onRetry: _load),
            ],
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth / 225).floor().clamp(
                  1,
                  4,
                );
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.65,
                  children: [
                    _MetricTile(
                      label: 'TOTAL OMZET HARI INI',
                      value: _loading ? 'Memuat...' : formatCurrency(revenue),
                      detail: '${todayOrders.length} transaksi tersimpan',
                      icon: Icons.account_balance_wallet_outlined,
                      color: const Color(0xFFE5F8F1),
                    ),
                    _MetricTile(
                      label: 'TRANSAKSI SELESAI',
                      value: _loading ? '...' : '${todayOrders.length}',
                      detail: 'Data hari ini',
                      icon: Icons.receipt_long_outlined,
                      color: const Color(0xFFEAF0FF),
                    ),
                    _MetricTile(
                      label: 'SHIFT KASIR AKTIF',
                      value: _loading ? '...' : '$activeCashiers',
                      detail: 'Sedang bertugas',
                      icon: Icons.badge_outlined,
                      color: const Color(0xFFEAF0FF),
                    ),
                    _MetricTile(
                      label: 'STOK KRITIS',
                      value: _loading ? '...' : '$lowStock item',
                      detail: 'Stok 10 atau kurang',
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFFFECEA),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 850;
                final sales = _SalesPanel(orders: todayOrders);
                final shifts = _ShiftPanel(shifts: _shifts);
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: sales),
                      const SizedBox(width: 12),
                      Expanded(flex: 4, child: shifts),
                    ],
                  );
                }
                return Column(
                  children: [sales, const SizedBox(height: 12), shifts],
                );
              },
            ),
            const SizedBox(height: 18),
            _RecentOrders(orders: _orders.take(5).toList()),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: StitchTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: StitchTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: StitchTheme.textDark),
          ),
        ],
      ),
    ),
  );
}

class _SalesPanel extends StatelessWidget {
  const _SalesPanel({required this.orders});

  final List<TransactionRecord> orders;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aktivitas Penjualan',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          const Text(
            'Transaksi yang tersimpan hari ini',
            style: TextStyle(fontSize: 11, color: StitchTheme.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 92,
            child: orders.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada transaksi hari ini',
                      style: TextStyle(
                        color: StitchTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  )
                : _SalesBars(orders: orders),
          ),
          const Divider(height: 22),
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 16,
                color: StitchTheme.primaryGreen,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${orders.where((order) => order.payment == 'Tunai').length} transaksi tunai',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              Text(
                '${orders.where((order) => order.payment != 'Tunai').length} non-tunai',
                style: const TextStyle(
                  fontSize: 11,
                  color: StitchTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SalesBars extends StatelessWidget {
  const _SalesBars({required this.orders});

  final List<TransactionRecord> orders;

  @override
  Widget build(BuildContext context) {
    final maxTotal = orders.fold<int>(
      1,
      (maximum, order) => order.total > maximum ? order.total : maximum,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final order in orders.take(12).toList().reversed)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Tooltip(
                message: '${order.id} · ${formatCurrency(order.total)}',
                child: Container(
                  height: (order.total / maxTotal * 78).clamp(8, 78),
                  decoration: BoxDecoration(
                    color: const Color(0xFF75D6BB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ShiftPanel extends StatelessWidget {
  const _ShiftPanel({required this.shifts});

  final List<ShiftRecord> shifts;

  @override
  Widget build(BuildContext context) {
    final active = shifts.where((shift) => shift.status == 'open').toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Status Shift & Kasir',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                _Pill(
                  icon: Icons.circle,
                  label: '${active.length} aktif',
                  color: const Color(0xFFE5F8F1),
                  foreground: const Color(0xFF087B5C),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (active.isEmpty)
              const Text(
                'Belum ada shift aktif. Kasir dapat membuka shift dari menu Shift.',
                style: TextStyle(color: StitchTheme.textMuted, fontSize: 11),
              )
            else
              for (final shift in active.take(4))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 15,
                        backgroundColor: Color(0xFFE7EFEC),
                        child: Icon(
                          Icons.person_outline,
                          size: 17,
                          color: StitchTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shift.cashier,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '${shift.id} · POS-01',
                              style: const TextStyle(
                                fontSize: 9,
                                color: StitchTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _timeLabel(shift.openedAt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: StitchTheme.textMuted,
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

class _RecentOrders extends StatelessWidget {
  const _RecentOrders({required this.orders});

  final List<TransactionRecord> orders;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Aktivitas Transaksi & Audit Kasir Terbaru',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${orders.length} terakhir',
                style: const TextStyle(
                  fontSize: 10,
                  color: StitchTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Transaksi baru akan muncul setelah checkout.',
                  style: TextStyle(color: StitchTheme.textMuted, fontSize: 11),
                ),
              ),
            )
          else
            for (final order in orders)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 105,
                      child: Text(
                        order.id,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: StitchTheme.primaryGreen,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 54,
                      child: Text(
                        _timeLabel(order.createdAt),
                        style: const TextStyle(
                          fontSize: 9,
                          color: StitchTheme.textMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        order.cashier,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Text(order.payment, style: const TextStyle(fontSize: 10)),
                    const SizedBox(width: 12),
                    Text(
                      formatCurrency(order.total),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
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

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 8, color: foreground),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFECEA),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, size: 17, color: Colors.redAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10),
          ),
        ),
        IconButton(
          tooltip: 'Coba lagi',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
        ),
      ],
    ),
  );
}

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} ${date.year}';

String _timeLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];
