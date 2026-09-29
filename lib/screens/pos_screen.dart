import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/app_data.dart';
import '../services/app_session.dart';
import '../theme/stitch_theme.dart';

class CartLine {
  CartLine(this.item, this.variant);

  final MenuItem item;
  final String variant;
  int quantity = 1;
  int get total => item.price * quantity;
}

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchController = TextEditingController();
  final List<CartLine> _cart = [];
  List<MenuItem> _products = menuItems;
  String _category = 'Semua Menu';
  String _search = '';
  String _payment = 'Tunai';
  String _orderType = 'Dine-in';
  int _discount = 0;
  bool _loadingProducts = false;
  bool _submitting = false;
  bool _apiOnline = false;
  bool _showCartOnMobile = false;

  int get _itemCount => _cart.fold(0, (sum, line) => sum + line.quantity);
  int get _subtotal => _cart.fold(0, (sum, line) => sum + line.total);
  int get _tax => (_subtotal * .1).round();
  int get _total => _subtotal + _tax - _discount;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (!ApiService.isSupabaseConfigured) return;
    setState(() => _loadingProducts = true);
    try {
      final products = await ApiService.loadProducts();
      if (!mounted) return;
      setState(() {
        if (products.isNotEmpty) _products = products;
        _apiOnline = true;
        _loadingProducts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _apiOnline = false;
        _loadingProducts = false;
      });
    }
  }

  void _addItem(MenuItem item) {
    if (item.stock <= 0) return;
    setState(() {
      CartLine? existing;
      for (final line in _cart) {
        if (line.item.id == item.id) {
          existing = line;
          break;
        }
      }
      if (existing != null) {
        if (existing.quantity < item.stock) existing.quantity++;
      } else {
        _cart.add(
          CartLine(item, item.variants.isEmpty ? '' : item.variants.first),
        );
      }
    });
  }

  void _changeQuantity(CartLine line, int change) {
    if (change < 0 && line.quantity <= 1) {
      _removeLine(line);
      return;
    }
    if (change > 0 && line.quantity >= line.item.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah sudah mencapai batas stok.')),
      );
      return;
    }
    setState(() {
      line.quantity += change;
      if (_discount > _subtotal) _discount = 0;
    });
  }

  void _removeLine(CartLine line) {
    final index = _cart.indexOf(line);
    if (index < 0) return;
    setState(() {
      _cart.removeAt(index);
      if (_discount > _subtotal) _discount = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${line.item.name} dibatalkan dari pesanan.'),
        action: SnackBarAction(
          label: 'Urungkan',
          onPressed: () => setState(() {
            _cart.insert(index.clamp(0, _cart.length), line);
          }),
        ),
      ),
    );
  }

  Future<void> _finishTransaction() async {
    if (_cart.isEmpty || _submitting) return;
    final now = DateTime.now();
    final user = AppSession.instance.user;
    final transaction = TransactionRecord(
      id:
          'ORD-${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}-'
          '${now.millisecondsSinceEpoch}',
      total: _total,
      payment: _payment,
      createdAt: now,
      cashier: user?.name ?? 'Kasir',
      cashierId: user?.id ?? 'KSR-001',
      itemCount: _itemCount,
      orderType: _orderType,
      subtotal: _subtotal,
      tax: _tax,
      discount: _discount,
      synced: ApiService.isSupabaseConfigured,
      lines: _cart
          .map(
            (line) => TransactionLineRecord(
              productId: line.item.id,
              productName: line.item.name,
              variant: line.variant,
              quantity: line.quantity,
              unitPrice: line.item.price,
              total: line.total,
            ),
          )
          .toList(),
    );

    setState(() => _submitting = true);
    try {
      await ApiService.createTransaction(
        transaction: transaction,
        cashierId: user?.id ?? 'KSR-001',
        subtotal: _subtotal,
        tax: _tax,
        discount: _discount,
        items: _cart
            .map(
              (line) => {
                'product_id': line.item.id,
                'product_name': line.item.name,
                'variant': line.variant,
                'quantity': line.quantity,
                'unit_price': line.item.price,
                'total': line.total,
              },
            )
            .toList(),
      );
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _discount = 0;
        _submitting = false;
      });
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline_rounded,
            color: StitchTheme.primaryGreen,
            size: 42,
          ),
          title: const Text('Pesanan selesai'),
          content: Text(
            '${transaction.id}\n${formatCurrency(transaction.total)} · ${transaction.payment}\n'
            '${ApiService.isSupabaseConfigured ? 'Tersimpan ke cloud' : 'Tersimpan di sesi lokal'}',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Selesai'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pesanan belum tersimpan: $error')),
      );
    }
  }

  List<MenuItem> get _visibleProducts {
    return _products.where((item) {
      final matchesCategory =
          _category == 'Semua Menu' || item.category == _category;
      final query = _search.trim().toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.id.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  List<String> get _categories => [
    'Semua Menu',
    ..._products.map((item) => item.category).toSet(),
  ];

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 450;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(
          children: [
            const Icon(
              Icons.point_of_sale_rounded,
              color: StitchTheme.primaryGreen,
            ),
            const SizedBox(width: 9),
            const Text('POS Kasir'),
            if (!narrow) ...[
              const SizedBox(width: 14),
              _StatusPill(
                active: _apiOnline,
                label: _apiOnline ? 'Online · Cloud Sync' : 'Mode Offline',
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan katalog',
            onPressed: _loadingProducts ? null : _loadProducts,
            icon: _loadingProducts
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
          if (!narrow)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 16),
              child: Center(
                child: Text(
                  AppSession.instance.user?.name ?? 'Kasir',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          if (wide) {
            return Row(
              children: [
                Expanded(flex: 6, child: _buildProductsPanel()),
                const VerticalDivider(width: 1),
                Expanded(flex: 4, child: _buildCartPanel(compact: false)),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProductsPanel(inline: true),
                const Divider(height: 1),
                _buildCartPanel(compact: true, inline: true),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductsPanel({bool inline = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _apiOnline
                  ? const Color(0xFFE6F8F2)
                  : const Color(0xFFFFF2DF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  _apiOnline
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  size: 16,
                  color: _apiOnline
                      ? StitchTheme.primaryGreen
                      : StitchTheme.accentWarning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _apiOnline
                        ? 'Sinkronisasi cloud aktif · Katalog terbaru'
                        : 'Offline · Pesanan demo tersimpan di sesi ini',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              hintText: 'Cari nama produk, barcode, SKU...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Hapus pencarian',
                onPressed: () {
                  _searchController.clear();
                  setState(() => _search = '');
                },
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF0F3F4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final selected = category == _category;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = category),
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                  backgroundColor: const Color(0xFFF0F3F4),
                  selectedColor: StitchTheme.sidebar,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : StitchTheme.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                  side: BorderSide.none,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (inline)
            _buildProductGrid(inline: true)
          else
            Expanded(child: _buildProductGrid(inline: false)),
        ],
      ),
    );
  }

  Widget _buildProductGrid({required bool inline}) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / 185).floor().clamp(2, 4);
      if (_visibleProducts.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Produk tidak ditemukan.')),
        );
      }
      return GridView.builder(
        itemCount: _visibleProducts.length,
        shrinkWrap: inline,
        physics: inline ? const NeverScrollableScrollPhysics() : null,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: 1.02,
          crossAxisSpacing: 9,
          mainAxisSpacing: 9,
        ),
        itemBuilder: (context, index) => _productCard(_visibleProducts[index]),
      );
    },
  );

  Widget _productCard(MenuItem item) {
    final available = item.stock > 0;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _cart.any((line) => line.item.id == item.id)
              ? StitchTheme.primaryGreen.withValues(alpha: .65)
              : StitchTheme.borderSubtle,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('product-${item.id}'),
        onTap: available ? () => _addItem(item) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.imageUrl != null)
                    Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _productPlaceholder(item),
                    )
                  else
                    _productPlaceholder(item),
                  Positioned(
                    left: 7,
                    top: 7,
                    child: _StockBadge(stock: item.stock),
                  ),
                  if (!available)
                    ColoredBox(
                      color: Colors.white.withValues(alpha: .68),
                      child: const Center(
                        child: Text(
                          'STOK HABIS',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 5, 7, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: StitchTheme.textMuted,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatCurrency(item.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        SizedBox.square(
                          dimension: 28,
                          child: IconButton.filled(
                            key: ValueKey('add-${item.id}'),
                            tooltip: 'Tambah ${item.name}',
                            padding: EdgeInsets.zero,
                            onPressed: available ? () => _addItem(item) : null,
                            icon: const Icon(Icons.add_rounded, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productPlaceholder(MenuItem item) {
    final icon = switch (item.category) {
      'Makanan Utama' => Icons.lunch_dining_rounded,
      'Snack & Pastry' => Icons.bakery_dining_rounded,
      _ => Icons.local_cafe_rounded,
    };
    return ColoredBox(
      color: const Color(0xFFE7EFEC),
      child: Center(
        child: Icon(icon, size: 38, color: StitchTheme.primaryGreen),
      ),
    );
  }

  Widget _buildCartPanel({required bool compact, bool inline = false}) {
    final horizontal = compact ? 12.0 : 18.0;
    final cartContent = _cart.isEmpty
        ? Center(
            child: Text(
              compact
                  ? 'Tambahkan produk dari menu di atas'
                  : 'Pilih produk untuk memulai pesanan',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: StitchTheme.textMuted,
                fontSize: 10,
              ),
            ),
          )
        : ListView.separated(
            shrinkWrap: inline,
            physics: inline ? const NeverScrollableScrollPhysics() : null,
            itemCount: _cart.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _cartLine(_cart[index]),
          );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        compact ? 8 : 14,
        horizontal,
        compact ? 6 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                color: StitchTheme.primaryGreen,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Pesanan Aktif',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '#ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: StitchTheme.textMuted,
                ),
              ),
              IconButton(
                tooltip: 'Kosongkan pesanan',
                onPressed: _cart.isEmpty
                    ? null
                    : () => setState(() {
                        _cart.clear();
                        _discount = 0;
                      }),
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
              ),
            ],
          ),
          SizedBox(height: compact ? 3 : 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'Dine-in',
                label: Text('Dine-in'),
                icon: Icon(Icons.table_restaurant_outlined),
              ),
              ButtonSegment(
                value: 'Takeaway',
                label: Text('Takeaway'),
                icon: Icon(Icons.takeout_dining_outlined),
              ),
            ],
            selected: {_orderType},
            onSelectionChanged: (selection) =>
                setState(() => _orderType = selection.first),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
            ),
          ),
          SizedBox(height: compact ? 2 : 6),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 15),
              const SizedBox(width: 5),
              Text(
                AppSession.instance.user?.name ?? 'Kasir',
                style: const TextStyle(
                  fontSize: 11,
                  color: StitchTheme.textMuted,
                ),
              ),
              const Spacer(),
              const Text('POS-01', style: TextStyle(fontSize: 10)),
            ],
          ),
          Divider(height: compact ? 10 : 15),
          if (inline) cartContent else Expanded(child: cartContent),
          const Divider(height: 14),
          _AmountRow(
            label: 'Subtotal ($_itemCount item)',
            value: formatCurrency(_subtotal),
          ),
          const SizedBox(height: 4),
          _AmountRow(
            label: 'Pajak restoran (10%)',
            value: formatCurrency(_tax),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Diskon',
                  style: TextStyle(
                    fontSize: 11,
                    color: StitchTheme.primaryGreen,
                  ),
                ),
              ),
              DropdownButton<int>(
                value: _discount,
                underline: const SizedBox.shrink(),
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Tidak ada')),
                  DropdownMenuItem(value: 10000, child: Text('- Rp 10.000')),
                ],
                onChanged: _subtotal < 10000
                    ? null
                    : (value) => setState(() => _discount = value ?? 0),
              ),
            ],
          ),
          const Divider(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total Akhir',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                formatCurrency(_total),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              for (final method in ['Tunai', 'QRIS', 'EDC'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _payment = method),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _payment == method
                            ? StitchTheme.sidebar
                            : Colors.white,
                        foregroundColor: _payment == method
                            ? Colors.white
                            : StitchTheme.textDark,
                        side: BorderSide(
                          color: _payment == method
                              ? StitchTheme.sidebar
                              : StitchTheme.borderSubtle,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                      ),
                      icon: Icon(
                        method == 'Tunai'
                            ? Icons.payments_outlined
                            : method == 'QRIS'
                            ? Icons.qr_code_2_rounded
                            : Icons.credit_card_outlined,
                        size: 15,
                      ),
                      label: Text(method, style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: _cart.isEmpty || _submitting
                  ? null
                  : _finishTransaction,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(_submitting ? 'Menyimpan...' : 'Selesaikan Pesanan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartLine(CartLine line) => Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F5F4),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Column(
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                width: 34,
                height: 34,
                child: line.item.imageUrl == null
                    ? _productPlaceholder(line.item)
                    : Image.network(
                        line.item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _productPlaceholder(line.item),
                      ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    line.variant.isEmpty ? line.item.id : line.variant,
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
            IconButton(
              key: ValueKey('remove-${line.item.id}'),
              tooltip: 'Hapus ${line.item.name}',
              onPressed: () => _removeLine(line),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 17,
                color: Color(0xFFB9382D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '@ ${formatCurrency(line.item.price)}',
              style: const TextStyle(fontSize: 9, color: StitchTheme.textMuted),
            ),
            const Spacer(),
            _QuantityControl(
              itemId: line.item.id,
              value: line.quantity,
              onDecrease: () => _changeQuantity(line, -1),
              onIncrease: () => _changeQuantity(line, 1),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              child: Text(
                formatCurrency(line.total),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: active ? const Color(0xFFE6F8F2) : const Color(0xFFFFF2DF),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          size: 6,
          color: active ? StitchTheme.primaryGreen : StitchTheme.accentWarning,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    final low = stock <= 10;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .93),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          stock == 0 ? 'Habis' : 'Stok: $stock',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: low ? Colors.redAccent : StitchTheme.primaryGreen,
          ),
        ),
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.itemId,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String itemId;
  final int value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF0F3F4),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuantityStepButton(
          controlKey: ValueKey('decrease-$itemId'),
          tooltip: 'Kurangi jumlah',
          icon: Icons.remove_rounded,
          onTap: onDecrease,
        ),
        Text(
          '$value',
          key: ValueKey('quantity-$itemId'),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        _QuantityStepButton(
          controlKey: ValueKey('increase-$itemId'),
          tooltip: 'Tambah jumlah',
          icon: Icons.add_rounded,
          onTap: onIncrease,
        ),
      ],
    ),
  );
}

class _QuantityStepButton extends StatelessWidget {
  const _QuantityStepButton({
    required this.controlKey,
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final Key controlKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: controlKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(width: 28, height: 30, child: Icon(icon, size: 15)),
        ),
      ),
    ),
  );
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: StitchTheme.textMuted),
        ),
      ),
      Text(value, style: const TextStyle(fontSize: 11)),
    ],
  );
}
