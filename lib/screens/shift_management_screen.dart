import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/app_data.dart';
import '../services/app_session.dart';
import '../theme/stitch_theme.dart';

class ShiftManagementScreen extends StatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  State<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends State<ShiftManagementScreen> {
  ShiftRecord? _active;
  List<ShiftRecord> _history = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isCashier => AppSession.instance.user?.isCashier == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final history = await ApiService.loadShifts();
      final user = AppSession.instance.user;
      ShiftRecord? active;
      if (user?.isCashier == true) {
        active = await ApiService.loadActiveShift(user!.id);
        final sessionShift = AppSession.instance.activeShift;
        if (active == null &&
            !ApiService.isSupabaseConfigured &&
            sessionShift != null) {
          active = ShiftRecord(
            id: sessionShift.id,
            cashierId: user.id,
            cashier: user.name,
            openingFloat: 500000,
            openedAt: sessionShift.startedAt,
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _active = active;
        _history = history;
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

  Future<void> _openShift() async {
    final openingFloat = await showDialog<int>(
      context: context,
      builder: (context) => const _OpenShiftDialog(),
    );
    if (openingFloat == null) return;
    final user = AppSession.instance.user;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final shift = await ApiService.openShift(
        cashierId: user.id,
        cashier: user.name,
        openingFloat: openingFloat,
      );
      if (!mounted) return;
      setState(() {
        _active = shift;
        _history = [shift, ..._history];
        _saving = false;
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _closeShift() async {
    final shift = _active;
    if (shift == null) return;
    final closeData = await showDialog<({int cash, String note})>(
      context: context,
      builder: (context) => _CloseShiftDialog(expectedCash: shift.openingFloat),
    );
    if (closeData == null) return;
    setState(() => _saving = true);
    try {
      await ApiService.closeShift(
        shiftId: shift.id,
        actualCash: closeData.cash,
        note: closeData.note,
      );
      if (!mounted) return;
      final closed = ShiftRecord(
        id: shift.id,
        cashierId: shift.cashierId,
        cashier: shift.cashier,
        openingFloat: shift.openingFloat,
        openedAt: shift.openedAt,
        status: 'closed',
      );
      setState(() {
        _active = null;
        _history = _history
            .map((item) => item.id == closed.id ? closed : item)
            .toList();
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift ditutup dan direkonsiliasi.')),
      );
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Shift belum tersimpan: $error')));
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buka & Tutup Shift Kasir'),
        actions: [
          IconButton(
            tooltip: 'Segarkan shift',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            const Text(
              'Operasional Shift',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kelola modal, rekonsiliasi kas, dan penutupan transaksi harian.',
              style: TextStyle(fontSize: 12, color: StitchTheme.textMuted),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ShiftNotice(message: _error!, isError: true),
            ],
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (active != null)
              _activeShiftPanel(active)
            else if (_isCashier)
              _openShiftPanel()
            else
              const _ShiftNotice(
                message: 'Belum ada shift aktif di cabang ini.',
                isError: false,
              ),
            const SizedBox(height: 18),
            _historyPanel(),
          ],
        ),
      ),
    );
  }

  Widget _openShiftPanel() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_open_rounded,
            color: StitchTheme.primaryGreen,
            size: 26,
          ),
          const SizedBox(height: 10),
          const Text(
            'Belum ada shift aktif',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'Catat modal awal sebelum mulai menerima pesanan.',
            style: TextStyle(fontSize: 11, color: StitchTheme.textMuted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: _saving ? null : _openShift,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: const Text('Buka Shift'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _activeShiftPanel(ShiftRecord shift) => Column(
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.circle,
                    color: StitchTheme.primaryGreen,
                    size: 9,
                  ),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      'Shift Aktif',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    shift.id,
                    style: const TextStyle(
                      fontSize: 10,
                      color: StitchTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 28,
                runSpacing: 14,
                children: [
                  _ShiftValue(label: 'KASIR BERTUGAS', value: shift.cashier),
                  _ShiftValue(
                    label: 'SESI & TERMINAL',
                    value: 'POS-01 · Cabang Senopati',
                  ),
                  _ShiftValue(
                    label: 'WAKTU BUKA',
                    value: _dateTimeLabel(shift.openedAt),
                  ),
                  _ShiftValue(
                    label: 'MODAL AWAL',
                    value: formatCurrency(shift.openingFloat),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = (constraints.maxWidth / 210).floor().clamp(1, 3);
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: 2.2,
            children: [
              _ShiftMetric(
                label: 'TOTAL PENJUALAN',
                value: 'Tersinkron',
                icon: Icons.payments_outlined,
              ),
              _ShiftMetric(
                label: 'TRANSAKSI SELESAI',
                value: 'Cloud aktif',
                icon: Icons.receipt_long_outlined,
              ),
              _ShiftMetric(
                label: 'MODAL KAS',
                value: formatCurrency(shift.openingFloat),
                icon: Icons.point_of_sale_outlined,
              ),
            ],
          );
        },
      ),
      if (_isCashier) ...[
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Checklist Sebelum Tutup Shift',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const _CheckRow(label: 'Semua pesanan berstatus paid'),
                const _CheckRow(label: 'Sinkronisasi data transaksi aman'),
                const _CheckRow(label: 'Struk transaksi tersimpan di cloud'),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFBB2E2A),
                    ),
                    onPressed: _saving ? null : _closeShift,
                    icon: const Icon(Icons.lock_outline_rounded),
                    label: Text(
                      _saving ? 'Menyimpan...' : 'Tutup Shift & Rekonsiliasi',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );

  Widget _historyPanel() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Riwayat Shift Terakhir',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${_history.length} catatan',
                style: const TextStyle(
                  fontSize: 10,
                  color: StitchTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_history.isEmpty)
            const Text(
              'Riwayat shift akan tampil setelah shift pertama ditutup.',
              style: TextStyle(fontSize: 11, color: StitchTheme.textMuted),
            )
          else
            for (final shift in _history)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: StitchTheme.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${shift.cashier} · ${shift.id}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _dateTimeLabel(shift.openedAt),
                            style: const TextStyle(
                              fontSize: 9,
                              color: StitchTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatCurrency(shift.openingFloat),
                      style: const TextStyle(fontSize: 10),
                    ),
                    const SizedBox(width: 10),
                    _ShiftStatus(status: shift.status),
                  ],
                ),
              ),
        ],
      ),
    ),
  );
}

class _OpenShiftDialog extends StatefulWidget {
  const _OpenShiftDialog();

  @override
  State<_OpenShiftDialog> createState() => _OpenShiftDialogState();
}

class _OpenShiftDialogState extends State<_OpenShiftDialog> {
  final _controller = TextEditingController(text: '500000');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Buka shift kasir'),
    content: TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Modal awal (Rp)'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          final amount = int.tryParse(_controller.text.replaceAll('.', ''));
          if (amount != null && amount >= 0) Navigator.pop(context, amount);
        },
        child: const Text('Konfirmasi'),
      ),
    ],
  );
}

class _CloseShiftDialog extends StatefulWidget {
  const _CloseShiftDialog({required this.expectedCash});

  final int expectedCash;

  @override
  State<_CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends State<_CloseShiftDialog> {
  late final _cashController = TextEditingController(
    text: '${widget.expectedCash}',
  );
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _cashController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tutup & rekonsiliasi shift'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _cashController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Kas fisik terhitung (Rp)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Catatan penutupan (opsional)',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFBB2E2A)),
        onPressed: () {
          final amount = int.tryParse(_cashController.text.replaceAll('.', ''));
          if (amount != null && amount >= 0) {
            Navigator.pop(context, (cash: amount, note: _noteController.text));
          }
        },
        child: const Text('Tutup Shift'),
      ),
    ],
  );
}

class _ShiftValue extends StatelessWidget {
  const _ShiftValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 175,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            color: StitchTheme.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ShiftMetric extends StatelessWidget {
  const _ShiftMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 8,
                    color: StitchTheme.textMuted,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: StitchTheme.primaryGreen, size: 17),
        ],
      ),
    ),
  );
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        const Icon(
          Icons.check_box_rounded,
          size: 15,
          color: StitchTheme.primaryGreen,
        ),
        const SizedBox(width: 7),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 10))),
      ],
    ),
  );
}

class _ShiftStatus extends StatelessWidget {
  const _ShiftStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final open = status == 'open';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: open ? const Color(0xFFE5F8F1) : const Color(0xFFEFF1F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        open ? 'Aktif' : 'Ditutup',
        style: TextStyle(
          fontSize: 9,
          color: open ? StitchTheme.primaryGreen : StitchTheme.textMuted,
        ),
      ),
    );
  }
}

class _ShiftNotice extends StatelessWidget {
  const _ShiftNotice({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isError ? const Color(0xFFFFECEA) : const Color(0xFFEAF7F3),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(message, style: const TextStyle(fontSize: 11)),
  );
}

String _dateTimeLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
