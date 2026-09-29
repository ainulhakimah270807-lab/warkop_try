import 'package:flutter/foundation.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.branch,
  });

  final String id;
  final String name;
  final String role;
  final String branch;

  bool get isCashier => role == 'Kasir';
  bool get isOwner => role == 'Owner';
}

class ActiveShift {
  const ActiveShift({
    required this.id,
    required this.label,
    required this.startedAt,
  });

  final String id;
  final String label;
  final DateTime startedAt;
}

class AppSession extends ChangeNotifier {
  AppSession._();

  static final AppSession instance = AppSession._();
  AppUser? _user;
  ActiveShift? _activeShift;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  ActiveShift? get activeShift => _activeShift;

  bool login(String username, String password) {
    final normalizedUsername = username.trim().toLowerCase();
    if (normalizedUsername == 'alisa' && password == '123456') {
      _user = const AppUser(
        id: 'EMP-042',
        name: 'Alisa Yasmin',
        role: 'Karyawan',
        branch: 'Cabang Senopati',
      );
      _activeShift = null;
      notifyListeners();
      return true;
    }
    if (normalizedUsername == 'raka' && password == '123456') {
      _user = const AppUser(
        id: 'KSR-001',
        name: 'Raka Pratama',
        role: 'Kasir',
        branch: 'Cabang Senopati',
      );
      _activeShift = ActiveShift(
        id: 'SHIFT-20260925-001',
        label: 'Shift sore • 16:00 - 00:00',
        startedAt: DateTime.now(),
      );
      notifyListeners();
      return true;
    }
    if (normalizedUsername == 'dimas' && password == '123456') {
      _user = const AppUser(
        id: 'KSR-002',
        name: 'Dimas Prasetyo',
        role: 'Kasir',
        branch: 'Cabang Senopati',
      );
      _activeShift = ActiveShift(
        id: 'SHIFT-20260929-002',
        label: 'Shift pagi • 08:00 - 16:00',
        startedAt: DateTime.now(),
      );
      notifyListeners();
      return true;
    }
    if (normalizedUsername == 'owner' && password == '123456') {
      _user = const AppUser(
        id: 'OWN-001',
        name: 'Faris Ramadhan',
        role: 'Owner',
        branch: 'Cabang Senopati',
      );
      _activeShift = null;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool verifyPosPin(String pin) {
    const pinsByCashierId = {'KSR-001': '123456', 'KSR-002': '654321'};
    return _user?.isCashier == true &&
        RegExp(r'^\d{6}$').hasMatch(pin) &&
        pin == pinsByCashierId[_user?.id];
  }

  void logout() {
    _user = null;
    _activeShift = null;
    notifyListeners();
  }
}
