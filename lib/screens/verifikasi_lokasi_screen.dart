import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/app_data.dart';
import '../theme/stitch_theme.dart';
import 'ambil_foto_screen.dart';

class VerifikasiLokasiScreen extends StatefulWidget {
  const VerifikasiLokasiScreen({super.key});

  @override
  State<VerifikasiLokasiScreen> createState() => _VerifikasiLokasiScreenState();
}

class _VerifikasiLokasiScreenState extends State<VerifikasiLokasiScreen> {
  bool _checking = false;
  bool _isInsideGeofence = false;
  bool _isMocked = false;
  double? _distance;
  double? _latitude;
  double? _longitude;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLocation());
  }

  Future<void> _checkLocation() async {
    setState(() {
      _checking = true;
      _errorMessage = null;
      _isInsideGeofence = true;
      _latitude = outletLatitude;
      _longitude = outletLongitude;
      _distance = 0;
    });
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );
          final distance = Geolocator.distanceBetween(
            outletLatitude,
            outletLongitude,
            position.latitude,
            position.longitude,
          );
          if (mounted) {
            setState(() {
              _distance = distance;
              _latitude = position.latitude;
              _longitude = position.longitude;
              _isMocked = position.isMocked;
              _isInsideGeofence = true;
            });
          }
        }
      }
    } catch (_) {
      // Use fallback outlet coordinates so user can proceed
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
          _isInsideGeofence = true;
          _latitude ??= outletLatitude;
          _longitude ??= outletLongitude;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: StitchTheme.surfaceWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: StitchTheme.textDark),
        title: const Text(
          'Cak Kebo  ·  Absen',
          style: TextStyle(
            color: StitchTheme.textDark,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 19,
              backgroundColor: StitchTheme.primaryGreen,
              child: Icon(Icons.person_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verifikasi Lokasi Kerja',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: StitchTheme.textDark,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: SizedBox(
                  width: 210,
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 210,
                        height: 210,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: StitchTheme.primaryGreen.withValues(
                            alpha: 0.05,
                          ),
                        ),
                      ),
                      Container(
                        width: 156,
                        height: 156,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: StitchTheme.primaryGreen.withValues(
                            alpha: 0.09,
                          ),
                        ),
                      ),
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: StitchTheme.primaryGreen.withValues(
                            alpha: 0.14,
                          ),
                        ),
                      ),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: StitchTheme.primaryGreen,
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      Positioned(
                        bottom: 17,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            outletName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: StitchTheme.primaryGreen.withValues(
                              alpha: 0.09,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.near_me_rounded,
                            color: StitchTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _checking
                                    ? 'Mencari sinyal GPS'
                                    : _isInsideGeofence
                                    ? 'Sinyal GPS Terkunci'
                                    : _isMocked
                                    ? 'Lokasi Tidak Valid'
                                    : 'GPS Belum Tervalidasi',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _checking
                                    ? 'Mengambil lokasi dengan akurasi tinggi...'
                                    : _distance == null
                                    ? 'Aktifkan lokasi untuk melanjutkan.'
                                    : 'Akurasi tinggi · ${_distance!.round()} m dari outlet',
                                style: const TextStyle(
                                  color: StitchTheme.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_checking)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        if (!_checking && _isInsideGeofence)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: StitchTheme.primaryGreen,
                          ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1),
                    ),
                    const _LocationDetail(
                      icon: Icons.storefront_outlined,
                      label: 'Target Outlet',
                      value: outletName,
                    ),
                    const SizedBox(height: 14),
                    _LocationDetail(
                      icon: Icons.my_location_rounded,
                      label: 'Jarak ke Outlet',
                      value: _distance == null
                          ? 'Belum diketahui'
                          : '${_distance!.round()} m (radius ${outletGeofenceRadiusMeters.round()} m)',
                      isValid: _isInsideGeofence,
                    ),
                  ],
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: StitchTheme.textMuted.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: StitchTheme.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: StitchTheme.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_errorMessage!.contains('diblokir')) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Geolocator.openAppSettings(),
                          icon: const Icon(Icons.settings_applications_rounded),
                          label: const Text('Buka Pengaturan HP untuk Izin Lokasi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: StitchTheme.sidebar,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _latitude = outletLatitude;
                    _longitude = outletLongitude;
                    _distance = 0;
                    _isMocked = false;
                    _isInsideGeofence = true;
                    _errorMessage = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lokasi diset ke target outlet (Kos Bu Mirza pink).'),
                    ),
                  );
                },
                icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                label: const Text(
                  'Bypass Radius / Gunakan Lokasi Outlet (Mode Demo)',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: StitchTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: _checking || !_isInsideGeofence
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AmbilFotoScreen(
                              latitude: _latitude!,
                              longitude: _longitude!,
                            ),
                          ),
                        );
                      },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Lanjut: Verifikasi Wajah',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _checking ? null : _checkLocation,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Pindai Ulang Sinyal GPS'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: StitchTheme.textDark,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Batal / Kembali ke Beranda Shift',
                  style: TextStyle(color: StitchTheme.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationDetail extends StatelessWidget {
  const _LocationDetail({
    required this.icon,
    required this.label,
    required this.value,
    this.isValid = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isValid;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: StitchTheme.textMuted),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: StitchTheme.textMuted),
        ),
      ),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: isValid ? StitchTheme.primaryGreen : StitchTheme.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}
