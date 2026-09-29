import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../models/absensi_model.dart';
import 'app_data.dart';

class ApiService {
  static final ValueNotifier<int> transactionRevision = ValueNotifier(0);

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bhafnanmoguwmrbtwrmv.supabase.co',
  );
  static const String supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_BMSidByjJPOx2fwW-3VLHQ_G0lSzh6H',
    ),
  );

  static bool get isSupabaseConfigured {
    if (const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY').isEmpty &&
        const String.fromEnvironment('SUPABASE_ANON_KEY').isEmpty) {
      try {
        final binding = WidgetsBinding.instance.runtimeType.toString();
        if (binding.contains('TestBinding') ||
            binding.contains('AutomatedTestWidgetsFlutterBinding')) {
          return false;
        }
      } catch (_) {}
    }
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        (supabaseKey.startsWith('sb_publishable_') ||
            supabaseKey.startsWith('eyJ'));
  }

  static Map<String, String> get _restHeaders => {
    'apikey': supabaseKey,
    'Content-Type': 'application/json',
    if (!supabaseKey.startsWith('sb_publishable_'))
      'Authorization': 'Bearer $supabaseKey',
  };

  static Uri _tableEndpoint(
    String table, [
    Map<String, String>? queryParameters,
  ]) => Uri.parse(
    '${supabaseUrl.replaceFirst(RegExp(r'/+$'), '')}/rest/v1/$table',
  ).replace(queryParameters: queryParameters);

  static Uri _rpcEndpoint(String function) => Uri.parse(
    '${supabaseUrl.replaceFirst(RegExp(r'/+$'), '')}/rest/v1/rpc/$function',
  );

  static Future<List<MenuItem>> loadProducts() async {
    if (!isSupabaseConfigured) return menuItems;

    final response = await http.get(
      _tableEndpoint('products', {
        'select': 'id,name,category,price,stock,variants,image_url',
        'active': 'eq.true',
        'order': 'name.asc',
      }),
      headers: _restHeaders,
    );
    _throwIfFailed(response);
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows.map((row) {
      final product = row as Map<String, dynamic>;
      return MenuItem(
        id: product['id'] as String? ?? '',
        name: product['name'] as String? ?? 'Produk',
        category: product['category'] as String? ?? 'Lainnya',
        price: _asInt(product['price']),
        stock: _asInt(product['stock']),
        variants: (product['variants'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(),
        imageUrl: product['image_url'] as String?,
      );
    }).toList();
  }

  static Future<bool> kirimAbsensi({
    required String karyawanId,
    required String tipeAbsen,
    required double latitude,
    required double longitude,
    required String fotoBase64,
  }) async {
    if (!isSupabaseConfigured) {
      throw const ApiException(
        'Supabase belum dikonfigurasi. Isi SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY.',
      );
    }

    try {
      final response = await http.post(
        _tableEndpoint('attendance'),
        headers: {..._restHeaders, 'Prefer': 'return=minimal'},
        body: jsonEncode({
          'karyawan_id': karyawanId,
          'tipe_absen': tipeAbsen,
          'latitude': latitude,
          'longitude': longitude,
          'foto': fotoBase64,
          'waktu': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) return true;

      throw ApiException.fromResponse(response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('Error koneksi database: $e');
      throw ApiException('Tidak dapat terhubung ke API absensi: $e');
    }
  }

  static Future<List<AbsensiRecord>> riwayatAbsensi({
    required String karyawanId,
  }) async {
    if (!isSupabaseConfigured) return const [];

    try {
      final response = await http.get(
        _tableEndpoint('attendance', {
          'select': 'tipe_absen,waktu',
          'karyawan_id': 'eq.$karyawanId',
          'order': 'waktu.desc',
          'limit': '3',
        }),
        headers: _restHeaders,
      );

      _throwIfFailed(response);

      final rows = jsonDecode(response.body) as List<dynamic>;
      return rows
          .map((row) => AbsensiRecord.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      if (error is ApiException) rethrow;
      debugPrint('Error mengambil riwayat absensi: $error');
      throw ApiException('Tidak dapat memuat riwayat absensi: $error');
    }
  }

  static Future<List<TransactionRecord>> loadTransactions() async {
    if (!isSupabaseConfigured) {
      return completedTransactions.reversed.toList();
    }

    final response = await http.get(
      _tableEndpoint('orders', {
        'select': '*,order_items(product_id,product_name,variant,quantity,unit_price,total)',
        'order': 'created_at.desc',
        'limit': '100',
      }),
      headers: _restHeaders,
    );
    _throwIfFailed(response);
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows.map((row) {
      final order = row as Map<String, dynamic>;
      final items = order['order_items'] as List<dynamic>? ?? const [];
      final lines = items.map((value) {
        final item = value as Map<String, dynamic>;
        return TransactionLineRecord(
          productId: item['product_id'] as String? ?? '',
          productName: item['product_name'] as String? ?? 'Produk',
          variant: item['variant'] as String? ?? '',
          quantity: _asInt(item['quantity']),
          unitPrice: _asInt(item['unit_price']),
          total: _asInt(item['total']),
        );
      }).toList();
      final itemCount = lines.fold<int>(0, (sum, item) => sum + item.quantity);
      return TransactionRecord(
        id: order['id'] as String? ?? '',
        total: _asInt(order['total']),
        payment: order['payment_method'] as String? ?? 'Tunai',
        createdAt:
            DateTime.tryParse(order['created_at']?.toString() ?? '') ??
            DateTime.now(),
        cashier: order['cashier_name'] as String? ?? 'Kasir',
        terminal: order['terminal_id'] as String? ?? 'POS-01',
        itemCount: itemCount,
        orderType: order['order_type'] as String? ?? 'Dine-in',
        status: order['status'] as String? ?? 'Sukses',
        cashierId: order['cashier_id'] as String? ?? '',
        subtotal: _asInt(order['subtotal']),
        tax: _asInt(order['tax']),
        discount: _asInt(order['discount']),
        synced: true,
        lines: lines,
      );
    }).toList();
  }

  static Future<void> createTransaction({
    required TransactionRecord transaction,
    required String cashierId,
    required List<Map<String, dynamic>> items,
    required int subtotal,
    required int tax,
    required int discount,
  }) async {
    if (!isSupabaseConfigured) {
      completedTransactions.add(transaction);
      transactionRevision.value++;
      return;
    }

    final response = await http.post(
      _rpcEndpoint('pos_create_order'),
      headers: _restHeaders,
      body: jsonEncode({
        'p_order': {
          'id': transaction.id,
          'cashier_id': cashierId,
          'cashier_name': transaction.cashier,
          'terminal_id': transaction.terminal,
          'order_type': transaction.orderType,
          'payment_method': transaction.payment,
          'subtotal': subtotal,
          'tax': tax,
          'discount': discount,
          'total': transaction.total,
          'status': transaction.status,
          'created_at': transaction.createdAt.toIso8601String(),
        },
        'p_items': items,
      }),
    );
    _throwIfFailed(response);
    transactionRevision.value++;
  }

  static Future<void> voidTransaction(String transactionId) async {
    if (!isSupabaseConfigured) {
      final index = completedTransactions.indexWhere(
        (transaction) => transaction.id == transactionId,
      );
      if (index >= 0) {
        completedTransactions[index] = completedTransactions[index].copyWith(
          status: 'Void',
        );
      }
      transactionRevision.value++;
      return;
    }

    final response = await http.patch(
      _tableEndpoint('orders', {'id': 'eq.$transactionId'}),
      headers: {..._restHeaders, 'Prefer': 'return=minimal'},
      body: jsonEncode({'status': 'Void'}),
    );
    _throwIfFailed(response);
    transactionRevision.value++;
  }

  static Future<List<ShiftRecord>> loadShifts() async {
    if (!isSupabaseConfigured) return const [];

    final response = await http.get(
      _tableEndpoint('shifts', {
        'select': '*',
        'order': 'opened_at.desc',
        'limit': '30',
      }),
      headers: _restHeaders,
    );
    _throwIfFailed(response);
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows.map(_shiftFromJson).toList();
  }

  static Future<ShiftRecord?> loadActiveShift(String cashierId) async {
    if (!isSupabaseConfigured) return null;

    final response = await http.get(
      _tableEndpoint('shifts', {
        'select': '*',
        'cashier_id': 'eq.$cashierId',
        'status': 'eq.open',
        'order': 'opened_at.desc',
        'limit': '1',
      }),
      headers: _restHeaders,
    );
    _throwIfFailed(response);
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows.isEmpty ? null : _shiftFromJson(rows.first);
  }

  static Future<ShiftRecord> openShift({
    required String cashierId,
    required String cashier,
    required int openingFloat,
  }) async {
    final now = DateTime.now();
    if (!isSupabaseConfigured) {
      return ShiftRecord(
        id: 'SFT-${now.millisecondsSinceEpoch}',
        cashierId: cashierId,
        cashier: cashier,
        openingFloat: openingFloat,
        openedAt: now,
      );
    }

    final response = await http.post(
      _tableEndpoint('shifts'),
      headers: {..._restHeaders, 'Prefer': 'return=representation'},
      body: jsonEncode({
        'id': 'SFT-${now.millisecondsSinceEpoch}',
        'cashier_id': cashierId,
        'cashier_name': cashier,
        'terminal_id': 'POS-01',
        'opening_float': openingFloat,
        'status': 'open',
      }),
    );
    _throwIfFailed(response);
    final row = (jsonDecode(response.body) as List<dynamic>).first;
    return _shiftFromJson(row);
  }

  static Future<void> closeShift({
    required String shiftId,
    required int actualCash,
    required String note,
  }) async {
    if (!isSupabaseConfigured) return;

    final response = await http.patch(
      _tableEndpoint('shifts', {'id': 'eq.$shiftId'}),
      headers: {..._restHeaders, 'Prefer': 'return=minimal'},
      body: jsonEncode({
        'actual_cash': actualCash,
        'closing_note': note,
        'status': 'closed',
        'closed_at': DateTime.now().toIso8601String(),
      }),
    );
    _throwIfFailed(response);
  }

  static ShiftRecord _shiftFromJson(dynamic value) {
    final row = value as Map<String, dynamic>;
    return ShiftRecord(
      id: row['id'] as String? ?? '',
      cashierId: row['cashier_id'] as String? ?? '',
      cashier: row['cashier_name'] as String? ?? 'Kasir',
      openingFloat: _asInt(row['opening_float']),
      openedAt:
          DateTime.tryParse(row['opened_at']?.toString() ?? '') ??
          DateTime.now(),
      status: row['status'] as String? ?? 'open',
    );
  }

  static int _asInt(dynamic value) =>
      value is num ? value.round() : int.tryParse(value?.toString() ?? '') ?? 0;

  static void _throwIfFailed(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  factory ApiException.fromResponse(int statusCode, String body) {
    try {
      final response = jsonDecode(body) as Map<String, dynamic>;
      if (response['code'] == 'PGRST205') {
        final message = response['message']?.toString() ?? '';
        final table = message.contains('products')
            ? 'products'
            : message.contains('orders')
            ? 'orders'
            : message.contains('shifts')
            ? 'shifts'
            : 'attendance';
        final migration = table == 'attendance'
            ? '20260927000000_create_attendance.sql'
            : '20260929000000_create_pos.sql';
        return ApiException(
          'Tabel public.$table belum dibuat. Jalankan '
          'supabase/migrations/$migration di Supabase SQL Editor.',
        );
      }
    } on FormatException {
      // Keep the original response for non-JSON errors.
    } on TypeError {
      // Keep the original response if Supabase returns a non-object JSON value.
    }

    return ApiException('API absensi menolak data ($statusCode): $body');
  }

  final String message;

  @override
  String toString() => message;
}
