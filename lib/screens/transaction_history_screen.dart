import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/app_data.dart';
import '../theme/stitch_theme.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final _searchController = TextEditingController();
  List<TransactionRecord> _orders = const [];
  TransactionRecord? _selected;
  String _query = '';
  String _payment = 'Semua';
  bool _loading = true;
  String? _error;

  List<TransactionRecord> get _filtered => _orders.where((order) {
    final query = _query.trim().toLowerCase();
    final matchesQuery =
        query.isEmpty ||
        order.id.toLowerCase().contains(query) ||
        order.cashier.toLowerCase().contains(query);
    return matchesQuery && (_payment == 'Semua' || order.payment == _payment);
  }).toList();

  @override
  void initState() {
    super.initState();
    ApiService.transactionRevision.addListener(_reloadAfterCheckout);
    _load();
  }

  @override
  void dispose() {
    ApiService.transactionRevision.removeListener(_reloadAfterCheckout);
    _searchController.dispose();
    super.dispose();
  }

  void _reloadAfterCheckout() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await ApiService.loadTransactions();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _selected =
            orders.where((order) => order.id == _selected?.id).firstOrNull ??
            (orders.isEmpty ? null : orders.first);
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

  Future<void> _exportCsv() async {
    final rows = [
      'ID,Waktu,Kasir,Terminal,Metode,Item,Total,Status',
      ..._filtered.map(
        (order) =>
            '${order.id},${order.createdAt.toIso8601String()},${order.cashier},${order.terminal},${order.payment},${order.itemCount},${order.total},${order.status}',
      ),
    ];
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV transaksi disalin ke clipboard.')),
    );
  }

  Future<void> _copyReceipt(TransactionRecord order) async {
    final rows = [
      'POSHub · ${order.terminal}',
      order.id,
      _dateTimeLabel(order.createdAt),
      'Kasir: ${order.cashier}',
      ...order.lines.map(
        (line) =>
            '${line.quantity}x ${line.productName} · ${formatCurrency(line.total)}',
      ),
      'Subtotal: ${formatCurrency(order.subtotal)}',
      'Pajak: ${formatCurrency(order.tax)}',
      'Diskon: -${formatCurrency(order.discount)}',
      'TOTAL: ${formatCurrency(order.total)}',
      'Pembayaran: ${order.payment}',
    ];
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ringkasan struk disalin ke clipboard.')),
    );
  }

  Future<void> _voidOrder(TransactionRecord order) async {
    if (order.status.toLowerCase() == 'void') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan transaksi?'),
        content: Text('Transaksi ${order.id} akan ditandai void.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Void transaksi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.voidTransaction(order.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaksi belum dapat di-void: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _filtered.fold<int>(0, (sum, order) => sum + order.total);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi & Penjualan'),
        actions: [
          if (MediaQuery.sizeOf(context).width >= 900)
            TextButton.icon(
              onPressed: _exportCsv,
              icon: const Icon(Icons.file_download_outlined, size: 17),
              label: const Text('Ekspor Data (CSV)'),
            ),
          IconButton(
            tooltip: 'Ekspor CSV',
            onPressed: _exportCsv,
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: 'Muat ulang riwayat',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _wideList(total)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 320,
                    child: SingleChildScrollView(child: _detailPanel()),
                  ),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _metrics(total),
                const SizedBox(height: 12),
                _filters(),
                const SizedBox(height: 10),
                _table(expand: false),
                if (_selected != null) ...[
                  const SizedBox(height: 12),
                  _detailPanel(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _wideList(int total) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _metrics(total),
      const SizedBox(height: 12),
      _filters(),
      const SizedBox(height: 10),
      Expanded(child: _table(expand: true)),
    ],
  );

  Widget _metrics(int total) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / 180).floor().clamp(1, 4);
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.8,
        children: [
          _MetricTile(
            label: 'TOTAL OMZET TERFILTER',
            value: formatCurrency(total),
            icon: Icons.payments_outlined,
            tint: const Color(0xFFE5F8F1),
          ),
          _MetricTile(
            label: 'TRANSAKSI',
            value: '${_filtered.length}',
            icon: Icons.receipt_long_outlined,
            tint: const Color(0xFFEAF0FF),
          ),
          _MetricTile(
            label: 'TERSINKRON CLOUD',
            value: ApiService.isSupabaseConfigured ? 'Aktif' : 'Lokal',
            icon: Icons.cloud_done_outlined,
            tint: const Color(0xFFE5F8F1),
          ),
          const _MetricTile(
            label: 'MENUNGGU SINKRON',
            value: '0',
            icon: Icons.cloud_upload_outlined,
            tint: Color(0xFFFFECEA),
          ),
        ],
      );
    },
  );

  Widget _filters() => Column(
    children: [
      TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        decoration: InputDecoration(
          hintText: 'Cari ID transaksi, nama kasir, atau catatan...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Hapus pencarian',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      const SizedBox(height: 6),
      LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 480;
          void resetFilters() {
            _searchController.clear();
            setState(() {
              _query = '';
              _payment = 'Semua';
            });
          }

          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 2,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.payments_outlined, size: 14),
                  const SizedBox(width: 4),
                  const Text('Metode:', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 4),
                  DropdownButton<String>(
                    value: _payment,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'Semua',
                        child: Text('Semua metode'),
                      ),
                      DropdownMenuItem(value: 'Tunai', child: Text('Tunai')),
                      DropdownMenuItem(value: 'QRIS', child: Text('QRIS')),
                      DropdownMenuItem(value: 'EDC', child: Text('EDC')),
                    ],
                    onChanged: (value) =>
                        setState(() => _payment = value ?? 'Semua'),
                  ),
                ],
              ),
              if (compact)
                IconButton(
                  tooltip: 'Reset Filter',
                  visualDensity: VisualDensity.compact,
                  onPressed: resetFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                )
              else
                TextButton(
                  onPressed: resetFilters,
                  child: const Text('Reset Filter'),
                ),
            ],
          );
        },
      ),
    ],
  );

  Widget _table({required bool expand}) => Card(
    clipBehavior: Clip.antiAlias,
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              ),
            ),
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 700,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    color: const Color(0xFFF0F3F4),
                    child: const Row(
                      children: [
                        _TableCell(
                          width: 105,
                          label: 'ID & WAKTU',
                          header: true,
                        ),
                        _TableCell(
                          width: 105,
                          label: 'KASIR & TIPE',
                          header: true,
                        ),
                        _TableCell(
                          width: 160,
                          label: 'DETAIL ITEMS',
                          header: true,
                        ),
                        _TableCell(width: 62, label: 'METODE', header: true),
                        _TableCell(
                          width: 100,
                          label: 'TOTAL',
                          header: true,
                          align: TextAlign.right,
                        ),
                        _TableCell(
                          width: 100,
                          label: 'SYNC',
                          header: true,
                          align: TextAlign.center,
                        ),
                        _TableCell(width: 30, label: 'AKSI', header: true),
                      ],
                    ),
                  ),
                  if (expand)
                    Expanded(child: _tableRows())
                  else
                    SizedBox(height: 420, child: _tableRows()),
                  if (!_loading && _filtered.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Menampilkan ${_filtered.length} dari ${_orders.length} transaksi.',
                          style: const TextStyle(
                            fontSize: 9,
                            color: StitchTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
  );

  Widget _tableRows() => _filtered.isEmpty
      ? Center(
          child: Text(
            _orders.isEmpty
                ? 'Transaksi akan tampil setelah kasir menyelesaikan pesanan.'
                : 'Tidak ada transaksi yang cocok.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: StitchTheme.textMuted, fontSize: 11),
          ),
        )
      : ListView.separated(
          itemCount: _filtered.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, indent: 12, endIndent: 12),
          itemBuilder: (context, index) => _transactionRow(_filtered[index]),
        );

  Widget _transactionRow(TransactionRecord order) => Material(
    color: _selected?.id == order.id ? const Color(0xFFEAF7F3) : Colors.white,
    child: InkWell(
      onTap: () => setState(() => _selected = order),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 105,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: StitchTheme.primaryGreen,
                    ),
                  ),
                  Text(
                    _dateTimeLabel(order.createdAt),
                    style: const TextStyle(
                      fontSize: 8,
                      color: StitchTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 105,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.cashier,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9),
                  ),
                  Text(
                    order.orderType,
                    style: const TextStyle(
                      fontSize: 8,
                      color: StitchTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 160,
              child: Text(
                order.lines.isEmpty
                    ? '${order.itemCount} item'
                    : '${order.lines.first.quantity}x ${order.lines.first.productName}'
                          '${order.lines.length > 1 ? ', +${order.lines.length - 1} lainnya' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9),
              ),
            ),
            SizedBox(
              width: 62,
              child: Text(order.payment, style: const TextStyle(fontSize: 9)),
            ),
            SizedBox(
              width: 100,
              child: Text(
                formatCurrency(order.total),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              width: 100,
              child: Center(
                child: _SyncBadge(synced: order.synced, status: order.status),
              ),
            ),
            SizedBox(
              width: 30,
              child: IconButton(
                tooltip: 'Lihat transaksi',
                onPressed: () => setState(() => _selected = order),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.visibility_outlined, size: 16),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _detailPanel() {
    final order = _selected;
    if (order == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'Pilih transaksi untuk melihat detail.',
            style: TextStyle(color: StitchTheme.textMuted),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'PEMERIKSAAN TRANSAKSI',
                    style: TextStyle(
                      fontSize: 9,
                      color: StitchTheme.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _SyncBadge(synced: order.synced, status: order.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              order.id,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const Divider(height: 18),
            _DetailRow(label: 'Tipe pesanan', value: order.orderType),
            _DetailRow(
              label: 'Kasir & terminal',
              value: '${order.cashier} · ${order.terminal}',
            ),
            _DetailRow(
              label: 'Waktu transaksi',
              value: _dateTimeLabel(order.createdAt),
            ),
            _DetailRow(label: 'Metode bayar', value: order.payment),
            const SizedBox(height: 12),
            const Text(
              'Detail Order Items',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            if (order.lines.isEmpty)
              Text(
                '${order.itemCount} item',
                style: const TextStyle(
                  fontSize: 10,
                  color: StitchTheme.textMuted,
                ),
              )
            else
              for (final line in order.lines)
                Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F3F4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${line.quantity}x ${line.productName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (line.variant.isNotEmpty)
                              Text(
                                line.variant,
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: StitchTheme.textMuted,
                                ),
                              ),
                            Text(
                              '@ ${formatCurrency(line.unitPrice)}',
                              style: const TextStyle(
                                fontSize: 8,
                                color: StitchTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatCurrency(line.total),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 6),
            _DetailRow(
              label: 'Subtotal pesanan',
              value: formatCurrency(order.subtotal),
            ),
            _DetailRow(
              label: 'Pajak restoran (10%)',
              value: formatCurrency(order.tax),
            ),
            _DetailRow(
              label: 'Diskon',
              value: '-${formatCurrency(order.discount)}',
            ),
            const Divider(height: 15),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total pembayaran',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  formatCurrency(order.total),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: StitchTheme.primaryGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SyncNotice(synced: order.synced),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Muat Ulang dari Cloud'),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyReceipt(order),
                    icon: const Icon(Icons.receipt_long_outlined, size: 15),
                    label: const Text('Salin Struk'),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: order.status.toLowerCase() == 'void'
                        ? null
                        : () => _voidOrder(order),
                    icon: const Icon(Icons.block_rounded, size: 15),
                    label: const Text('Void'),
                  ),
                ),
              ],
            ),
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
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: StitchTheme.textMuted,
                  ),
                ),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Container(
            width: 29,
            height: 29,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16, color: StitchTheme.primaryGreen),
          ),
        ],
      ),
    ),
  );
}

class _TableCell extends StatelessWidget {
  const _TableCell({
    required this.width,
    required this.label,
    this.header = false,
    this.align = TextAlign.left,
  });

  final double width;
  final String label;
  final bool header;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Text(
      label,
      textAlign: align,
      style: TextStyle(
        fontSize: header ? 8 : 9,
        color: header ? StitchTheme.textMuted : StitchTheme.textDark,
        fontWeight: header ? FontWeight.w800 : FontWeight.normal,
      ),
    ),
  );
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.synced, required this.status});

  final bool synced;
  final String status;

  @override
  Widget build(BuildContext context) {
    final isVoid = status.toLowerCase() == 'void';
    final color = isVoid
        ? const Color(0xFFFFECEA)
        : synced
        ? const Color(0xFFE5F8F1)
        : const Color(0xFFFFECEA);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isVoid
            ? 'Void'
            : synced
            ? 'Tersinkron'
            : 'Offline Stored',
        maxLines: 1,
        style: TextStyle(
          fontSize: 8,
          color: isVoid
              ? Colors.red.shade700
              : synced
              ? const Color(0xFF087B5C)
              : Colors.red.shade700,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SyncNotice extends StatelessWidget {
  const _SyncNotice({required this.synced});

  final bool synced;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: synced ? const Color(0xFFEAF7F3) : const Color(0xFFF0F3F4),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: [
        Icon(
          synced ? Icons.cloud_done_outlined : Icons.info_outline,
          size: 16,
          color: StitchTheme.primaryGreen,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            synced ? 'Transaksi tersimpan di cloud.' : 'Transaksi tersimpan lokal. Konfigurasikan Supabase untuk sinkronisasi cloud.',
            style: const TextStyle(fontSize: 9),
          ),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 9, color: StitchTheme.textMuted),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

String _dateTimeLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} WIB';

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
