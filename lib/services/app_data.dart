class ShiftItem {
  const ShiftItem({
    required this.name,
    required this.role,
    required this.day,
    required this.time,
    required this.status,
  });

  final String name;
  final String role;
  final String day;
  final String time;
  final String status;
}

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.total,
    required this.payment,
    required this.createdAt,
    this.cashier = 'Kasir',
    this.terminal = 'POS-01',
    this.itemCount = 0,
    this.orderType = 'Dine-in',
    this.status = 'Sukses',
    this.cashierId = '',
    this.subtotal = 0,
    this.tax = 0,
    this.discount = 0,
    this.synced = false,
    this.lines = const [],
  });

  final String id;
  final int total;
  final String payment;
  final DateTime createdAt;
  final String cashier;
  final String terminal;
  final int itemCount;
  final String orderType;
  final String status;
  final String cashierId;
  final int subtotal;
  final int tax;
  final int discount;
  final bool synced;
  final List<TransactionLineRecord> lines;

  TransactionRecord copyWith({String? status, bool? synced}) =>
      TransactionRecord(
        id: id,
        total: total,
        payment: payment,
        createdAt: createdAt,
        cashier: cashier,
        terminal: terminal,
        itemCount: itemCount,
        orderType: orderType,
        status: status ?? this.status,
        cashierId: cashierId,
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        synced: synced ?? this.synced,
        lines: lines,
      );
}

class TransactionLineRecord {
  const TransactionLineRecord({
    required this.productId,
    required this.productName,
    required this.variant,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  final String productId;
  final String productName;
  final String variant;
  final int quantity;
  final int unitPrice;
  final int total;
}

class ShiftRecord {
  const ShiftRecord({
    required this.id,
    required this.cashierId,
    required this.cashier,
    required this.openingFloat,
    required this.openedAt,
    this.status = 'open',
  });

  final String id;
  final String cashierId;
  final String cashier;
  final int openingFloat;
  final DateTime openedAt;
  final String status;
}

const outletName = 'Kos Bu Mirza pink';
const outletLatitude = -8.1565529;
const outletLongitude = 113.7189992;
const outletGeofenceRadiusMeters = 150.0;

class MenuItem {
  const MenuItem({
    this.id = '',
    required this.name,
    required this.category,
    required this.price,
    required this.variants,
    this.stock = 20,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String category;
  final int price;
  final List<String> variants;
  final int stock;
  final String? imageUrl;
}

const shifts = [
  ShiftItem(
    name: 'Alisa Yasmin',
    role: 'Barista',
    day: 'Senin, 25 Sep',
    time: '08:00 - 16:00',
    status: 'Aktif',
  ),
  ShiftItem(
    name: 'Raka Pratama',
    role: 'Kasir',
    day: 'Senin, 25 Sep',
    time: '16:00 - 00:00',
    status: 'Terjadwal',
  ),
  ShiftItem(
    name: 'Dimas Saputra',
    role: 'Kasir',
    day: 'Selasa, 26 Sep',
    time: '08:00 - 16:00',
    status: 'Terjadwal',
  ),
  ShiftItem(
    name: 'Nadia Putri',
    role: 'Barista',
    day: 'Selasa, 26 Sep',
    time: '16:00 - 00:00',
    status: 'Terjadwal',
  ),
];

final List<TransactionRecord> completedTransactions = [];

const menuItems = [
  MenuItem(
    id: 'ESP-001',
    name: 'Espresso Double Shot',
    category: 'Kopi & Minuman',
    price: 24000,
    variants: ['Hot', 'Extra Shot'],
    stock: 35,
    imageUrl: 'https://images.unsplash.com/photo-1510707577719-ae7c14805e3a?auto=format&fit=crop&w=640&q=85',
  ),
  MenuItem(
    id: 'MAC-001',
    name: 'Caramel Macchiato',
    category: 'Kopi & Minuman',
    price: 38000,
    variants: ['Less Sugar', 'Extra Ice', 'Hot'],
    stock: 18,
    imageUrl: 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=640&q=85',
  ),
  MenuItem(
    id: 'MAT-001',
    name: 'Matcha Latte',
    category: 'Kopi & Minuman',
    price: 36000,
    variants: ['Oat Milk', 'Less Sugar', 'Extra Ice'],
    stock: 22,
    imageUrl: 'https://images.unsplash.com/photo-1515823064-d6e0c04616a7?auto=format&fit=crop&w=640&q=85',
  ),
  MenuItem(
    id: 'CRS-001',
    name: 'Croissant Butter Almond',
    category: 'Makanan Utama',
    price: 32000,
    variants: ['Hangatkan'],
    stock: 9,
    imageUrl: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?auto=format&fit=crop&w=640&q=85',
  ),
  MenuItem(
    id: 'FRY-001',
    name: 'French Fries',
    category: 'Snack & Pastry',
    price: 35000,
    variants: ['Saus Terpisah', 'Extra Saus'],
    stock: 14,
    imageUrl: 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?auto=format&fit=crop&w=640&q=85',
  ),
  MenuItem(
    id: 'BUR-001',
    name: 'Classic Cheeseburger',
    category: 'Makanan Utama',
    price: 48000,
    variants: ['No Onion', 'Extra Cheese'],
    stock: 12,
    imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=640&q=85',
  ),
  MenuItem(
    id: 'TEA-001',
    name: 'Iced Peach Lemon Tea',
    category: 'Kopi & Minuman',
    price: 28000,
    variants: ['Less Sugar', 'No Ice'],
    stock: 40,
    imageUrl: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=640&q=85',
  ),
];

String formatCurrency(int value) =>
    'Rp ${value.toString().replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (match) => '.')}';
