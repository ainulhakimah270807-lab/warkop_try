// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:warkop_try/main.dart';
import 'package:warkop_try/services/app_data.dart';
import 'package:warkop_try/services/api_service.dart';
import 'package:warkop_try/services/app_session.dart';

void main() {
  setUp(() {
    AppSession.instance.logout();
    completedTransactions.clear();
    ApiService.transactionRevision.value = 0;
  });

  testWidgets('Aplikasi membuka halaman login', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('POSHub'), findsOneWidget);
    expect(find.text('Email / ID Karyawan'), findsOneWidget);
    expect(find.text('Kata Sandi'), findsOneWidget);
    expect(find.text('Masuk ke Terminal'), findsOneWidget);
  });

  test('PGRST205 memberi petunjuk menjalankan migrasi attendance', () {
    final error = ApiException.fromResponse(
      404,
      '{"code":"PGRST205","message":"Could not find table"}',
    );

    expect(error.toString(), contains('public.attendance belum dibuat'));
    expect(error.toString(), contains('20260927000000_create_attendance.sql'));
  });

  testWidgets('Username menentukan sesi karyawan atau kasir', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.enterText(
      find.byKey(const ValueKey('login-username')),
      'raka',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      '123456',
    );
    await tester.tap(find.text('Masuk ke Terminal'));
    await tester.pumpAndSettle();

    expect(AppSession.instance.user?.isCashier, isTrue);
  });

  testWidgets('Tab POS hanya muncul untuk karyawan kasir', (
    WidgetTester tester,
  ) async {
    AppSession.instance.login('alisa', '123456');
    await tester.pumpWidget(const MyApp());

    expect(find.text('POS'), findsNothing);
    expect(find.text('Jadwal'), findsNothing);
    expect(find.text('Profil'), findsNothing);
    expect(find.text('Cak Kebo'), findsOneWidget);
  });

  test('PIN POS berbeda untuk setiap kasir', () {
    expect(AppSession.instance.login('raka', '123456'), isTrue);
    expect(AppSession.instance.verifyPosPin('123456'), isTrue);
    expect(AppSession.instance.verifyPosPin('654321'), isFalse);

    expect(AppSession.instance.login('dimas', '123456'), isTrue);
    expect(AppSession.instance.verifyPosPin('654321'), isTrue);
    expect(AppSession.instance.verifyPosPin('123456'), isFalse);
  });

  test('Akun owner mendapatkan akses pemilik', () {
    expect(AppSession.instance.login('owner', '123456'), isTrue);
    expect(AppSession.instance.user?.isOwner, isTrue);
  });

  testWidgets('Owner membuka portal manajemen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppSession.instance.login('owner', '123456');
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Portal Manajemen'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Riwayat transaksi menampilkan tabel desktop', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppSession.instance.login('owner', '123456');
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();

    expect(find.text('Riwayat Transaksi & Penjualan'), findsOneWidget);
    expect(find.text('DETAIL ITEMS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PIN wajib benar sebelum POS dibuka', (
    WidgetTester tester,
  ) async {
    AppSession.instance.login('raka', '123456');
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Riwayat Transaksi & Penjualan'), findsOneWidget);
    expect(find.text('POS Kasir'), findsNothing);

    await tester.tap(find.text('POS'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pos-pin-input')),
      '111111',
    );
    await tester.tap(find.text('Buka POS'));
    await tester.pumpAndSettle();
    expect(find.text('PIN kasir tidak valid.'), findsOneWidget);
    expect(find.text('POS Kasir'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('pos-pin-input')),
      '123456',
    );
    await tester.tap(find.text('Buka POS'));
    await tester.pumpAndSettle();
    expect(find.text('POS Kasir'), findsOneWidget);
  });

  testWidgets('POS menyesuaikan layar ponsel', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppSession.instance.login('raka', '123456');
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('POS'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pos-pin-input')),
      '123456',
    );
    await tester.tap(find.text('Buka POS'));
    await tester.pumpAndSettle();

    expect(find.text('POS Kasir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Item pesanan bisa dikurangi dan dibatalkan', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppSession.instance.login('raka', '123456');
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('POS'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pos-pin-input')),
      '123456',
    );
    await tester.tap(find.text('Buka POS'));
    await tester.pumpAndSettle();
    expect(find.text('POS Kasir'), findsOneWidget);
    expect(find.text('Riwayat Transaksi & Penjualan'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('product-ESP-001')));
    await tester.pumpAndSettle();
    expect(find.text('Pesanan Aktif'), findsOneWidget);
    final plusFinder = find.byKey(const ValueKey('increase-ESP-001'));
    await tester.ensureVisible(plusFinder);
    await tester.tap(plusFinder);
    await tester.pumpAndSettle();

    final quantityFinder = find.byKey(const ValueKey('quantity-ESP-001'));
    expect(tester.widget<Text>(quantityFinder).data, '2');
    final minusFinder = find.byKey(const ValueKey('decrease-ESP-001'));
    await tester.ensureVisible(minusFinder);
    await tester.tap(minusFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(quantityFinder).data, '1');

    final removeFinder = find.byKey(const ValueKey('remove-ESP-001'));
    await tester.ensureVisible(removeFinder);
    await tester.tap(removeFinder);
    await tester.pumpAndSettle();
    expect(find.text('Tambahkan produk dari menu di atas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PIN Dimas berbeda dari PIN Raka', (WidgetTester tester) async {
    AppSession.instance.login('dimas', '123456');
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('POS'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pos-pin-input')),
      '123456',
    );
    await tester.tap(find.text('Buka POS'));
    await tester.pumpAndSettle();
    expect(find.text('PIN kasir tidak valid.'), findsOneWidget);
    expect(find.text('POS Kasir'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('pos-pin-input')),
      '654321',
    );
    await tester.tap(find.text('Buka POS'));
    await tester.pumpAndSettle();
    expect(find.text('POS Kasir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Checkout lokal tersimpan ke riwayat', (
    WidgetTester tester,
  ) async {
    AppSession.instance.login('raka', '123456');
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('POS'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pos-pin-input')),
      '123456',
    );
    await tester.tap(find.text('Buka POS'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tambah Espresso Double Shot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selesaikan Pesanan'));
    await tester.pumpAndSettle();

    final transactions = await ApiService.loadTransactions();
    expect(transactions, hasLength(1));
    expect(transactions.single.total, greaterThan(0));
    expect(find.textContaining('Tersimpan di sesi lokal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
