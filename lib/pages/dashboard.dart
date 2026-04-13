import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/sipora_api_service.dart';
import 'dokumen_semua_page.dart';
import 'notifikasi.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  double _w(double p) => MediaQuery.of(context).size.width * p;
  double _f(double s) =>
      s * (MediaQuery.of(context).size.width / 400).clamp(0.65, 1.1);

  final SiporaApiService _apiService = SiporaApiService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = true;
  final String _profileName = 'Saiful Rizal';
  final String _profileRole = 'Mahasiswa';
  final String _profileEmail = 'saiful.rizal@polije.ac.id';
  final String _profileNim = 'E41231234';
  Uint8List? _profilePhotoBytes;

  List<Map<String, dynamic>> _stats = [
    {
      'title': 'Total Dokumen',
      'value': '2.890',
      'change': '+12%',
      'isPositive': true,
      'icon': Icons.description_outlined,
      'color': const Color(0xFF4F46E5),
    },
    {
      'title': 'Pengguna Aktif',
      'value': '1.231',
      'change': '-0.9%',
      'isPositive': false,
      'icon': Icons.people_outline,
      'color': const Color(0xFFF59E0B),
    },
    {
      'title': 'Upload Baru',
      'value': '108',
      'change': '+12%',
      'isPositive': true,
      'icon': Icons.upload_outlined,
      'color': const Color(0xFFEF4444),
    },
    {
      'title': 'Kutipan',
      'value': '534',
      'change': '+8%',
      'isPositive': true,
      'icon': Icons.format_quote_outlined,
      'color': const Color(0xFF10B981),
    },
  ];

  List<Map<String, dynamic>> _documents = [
    {
      'title': 'Implementasi Machine Learning untuk Prediksi Hasil Belajar',
      'author': 'Dr. Budi Santoso',
      'downloads': '233',
      'date': '24 Sept 2025',
      'category': 'Teknologi',
      'color': const Color(0xFF4F46E5),
      'file_path': '',
    },
    {
      'title': 'Analisis Kinerja Struktur Beton dengan Metode Finite Element',
      'author': 'Ani Wijaya, M.T.',
      'downloads': '189',
      'date': '19 Sept 2025',
      'category': 'Teknik Sipil',
      'color': const Color(0xFF10B981),
      'file_path': '',
    },
    {
      'title': 'Optimasi Sistem Kontrol Motor Listrik untuk Kendaraan Hybrid',
      'author': 'Prof. Darmawan',
      'downloads': '312',
      'date': '13 Sept 2025',
      'category': 'Teknik Elektro',
      'color': const Color(0xFFF59E0B),
      'file_path': '',
    },
    {
      'title': 'Rancang Bangun Sistem Keamanan Jaringan Berbasis IoT',
      'author': 'Rina Kusuma',
      'downloads': '145',
      'date': '10 Sept 2025',
      'category': 'Informatika',
      'color': const Color(0xFFEF4444),
      'file_path': '',
    },
    {
      'title': 'Studi Komparatif Bauran Pemasaran UMKM di Era Digital',
      'author': 'Ahmad Fadillah',
      'downloads': '98',
      'date': '05 Sept 2025',
      'category': 'Bisnis',
      'color': const Color(0xFF8B5CF6),
      'file_path': '',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final response = await _apiService.fetchDashboard();
      final stats = Map<String, dynamic>.from(
        (response['stats'] as Map?) ?? const {},
      );
      final recent = (response['recent_documents'] as List?) ?? const [];

      final mappedStats = [
        {
          'title': 'Total Dokumen',
          'value': '${stats['total_dokumen'] ?? 0}',
          'change': 'DB',
          'isPositive': true,
          'icon': Icons.description_outlined,
          'color': const Color(0xFF4F46E5),
        },
        {
          'title': 'Pengguna Aktif',
          'value': '${stats['pengguna_aktif'] ?? 0}',
          'change': 'DB',
          'isPositive': true,
          'icon': Icons.people_outline,
          'color': const Color(0xFFF59E0B),
        },
        {
          'title': 'Upload Hari Ini',
          'value': '${stats['upload_baru'] ?? 0}',
          'change': 'DB',
          'isPositive': true,
          'icon': Icons.upload_outlined,
          'color': const Color(0xFFEF4444),
        },
        {
          'title': 'Total Penulis',
          'value': '${stats['total_penulis'] ?? 0}',
          'change': 'DB',
          'isPositive': true,
          'icon': Icons.format_quote_outlined,
          'color': const Color(0xFF10B981),
        },
      ];

      final mappedDocs = recent.map((item) {
        final doc = Map<String, dynamic>.from(item as Map);
        return {
          'title': (doc['title'] ?? '-').toString(),
          'author': (doc['author'] ?? '-').toString(),
          'downloads': (doc['downloads'] ?? 0).toString(),
          'date': (doc['date'] ?? '-').toString(),
          'category': (doc['category'] ?? 'Dokumen').toString(),
          'color': const Color(0xFF4F46E5),
          'file_path': (doc['file_path'] ?? '').toString(),
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _stats = mappedStats;
        _documents = mappedDocs.isEmpty ? _documents : mappedDocs;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Uri? _resolveDocumentUri(Map<String, dynamic> doc) {
    final filePath = doc['file_path']?.toString() ?? '';
    if (filePath.trim().isEmpty) return null;
    return _apiService.resolveFileUri(filePath);
  }

  Future<void> _downloadDocument(Map<String, dynamic> doc) async {
    final uri = _resolveDocumentUri(doc);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File dokumen belum tersedia')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka file dokumen')),
      );
    }
  }

  Future<void> _requestProfilePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );

      if (photo == null) return;
      final bytes = await photo.readAsBytes();

      if (!mounted) return;
      setState(() => _profilePhotoBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamera tidak dapat dibuka')),
      );
    }
  }

  void _openDocumentDetail(Map<String, dynamic> doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DetailDokumenPage(document: doc, apiService: _apiService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ GUNAKAN COLUMN: HEADER DI LUAR, SCROLLVIEW DI DALAM
    return Column(
      children: [
        // 1. HEADER STATIC (Tidak ikut scroll)
        _buildMainHeader(),

        // 2. CONTENT YANG BISA DISCROLL
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                bottom: 90.0,
              ), // Padding bawah agar tidak ketutupan navbar
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  _w(0.04),
                  _w(0.01),
                  _w(0.04),
                  _w(0.04),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: _w(0.004)),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildStatsGrid(),
                    SizedBox(height: _w(0.04)),
                    _buildRecentDocuments(),
                    SizedBox(height: _w(0.04)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showProfilePopup() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Profile Dialog',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        final uploadHariIni = _stats.length > 2
            ? _stats[2]['value'].toString()
            : '0';
        final totalDokumen = _stats.isNotEmpty
            ? _stats[0]['value'].toString()
            : '0';

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: _w(0.9),
              constraints: BoxConstraints(maxWidth: 420, maxHeight: _w(1.9)),
              margin: EdgeInsets.symmetric(horizontal: _w(0.05)),
              padding: EdgeInsets.fromLTRB(
                _w(0.06),
                _w(0.05),
                _w(0.06),
                _w(0.06),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildProfileAvatar(
                          size: _w(0.16),
                          onTap: _requestProfilePhoto,
                          showCameraBadge: true,
                        ),
                        SizedBox(width: _w(0.03)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _profileName,
                                style: TextStyle(
                                  fontSize: _f(18),
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E3A5F),
                                ),
                              ),
                              SizedBox(height: _w(0.005)),
                              Text(
                                _profileRole,
                                style: TextStyle(
                                  fontSize: _f(12),
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: _w(0.05)),
                    _buildProfileInfoRow(
                      Icons.badge_outlined,
                      'NIM',
                      _profileNim,
                    ),
                    _buildProfileInfoRow(
                      Icons.email_outlined,
                      'Email',
                      _profileEmail,
                    ),
                    _buildProfileInfoRow(
                      Icons.school_outlined,
                      'Status',
                      'Aktif',
                    ),
                    SizedBox(height: _w(0.04)),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(_w(0.035)),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFD),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE6ECF5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  totalDokumen,
                                  style: TextStyle(
                                    fontSize: _f(16),
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E3A5F),
                                  ),
                                ),
                                Text(
                                  'Total Dokumen',
                                  style: TextStyle(
                                    fontSize: _f(11),
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: const Color(0xFFE6ECF5),
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: _w(0.04)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    uploadHariIni,
                                    style: TextStyle(
                                      fontSize: _f(16),
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E3A5F),
                                    ),
                                  ),
                                  Text(
                                    'Upload Hari Ini',
                                    style: TextStyle(
                                      fontSize: _f(11),
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: _w(0.05)),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Tutup'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: _w(0.02)),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: _f(16), color: const Color(0xFF1E3A5F)),
          ),
          SizedBox(width: _w(0.025)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: _f(10),
                    color: Colors.grey.shade500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: _f(12),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HEADER (TIDAK BERUBAH SAMA SEKALI)
  // ==========================================
  Widget _buildMainHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_w(0.08)),
          bottomRight: Radius.circular(_w(0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(_w(0.05), _w(0.04), _w(0.05), _w(0.06)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SIPORA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _f(22),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Portal Repository Akademik',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: _f(11),
                        ),
                      ),
                    ],
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationPage(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: EdgeInsets.all(_w(0.02)),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: _f(22),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: _w(0.05)),
              Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showProfilePopup,
                      borderRadius: BorderRadius.circular(999),
                      child: _buildProfileAvatar(size: _w(0.13)),
                    ),
                  ),
                  SizedBox(width: _w(0.03)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selamat Datang',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: _f(12),
                        ),
                      ),
                      Text(
                        _profileName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _f(18),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: _w(0.05)),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_w(0.03)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari dokumen, penulis, atau kata kunci...',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: _f(13),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: const Color(0xFF1E3A5F).withOpacity(0.5),
                      size: _f(22),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: _w(0.035)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar({
    required double size,
    VoidCallback? onTap,
    bool showCameraBadge = false,
  }) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: _profilePhotoBytes != null
            ? Image.memory(
                _profilePhotoBytes!,
                fit: BoxFit.cover,
                width: size,
                height: size,
              )
            : Container(
                color: const Color(0xFF1E3A5F).withOpacity(0.08),
                child: Icon(
                  Icons.person,
                  color: const Color(0xFF1E3A5F),
                  size: size * 0.55,
                ),
              ),
      ),
    );

    final content = showCameraBadge
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A5F),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_camera_rounded,
                    size: size * 0.18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          )
        : avatar;

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: content,
      ),
    );
  }

  // ==========================================
  // STATS GRID
  // ==========================================
  Widget _buildStatsGrid() {
    final sw = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Statistik',
              style: TextStyle(
                fontSize: _f(16),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E3A5F),
              ),
            ),
          ],
        ),
        SizedBox(height: _w(0.002)),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: _w(0.025),
            mainAxisSpacing: _w(0.025),
            childAspectRatio: sw > 400 ? 1.5 : 1.3,
          ),
          itemCount: _stats.length,
          itemBuilder: (_, i) => _buildStatCard(_stats[i]),
        ),
      ],
    );
  }

  Widget _buildStatCard(Map<String, dynamic> s) {
    return Container(
      padding: EdgeInsets.all(_w(0.03)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_w(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(_w(0.015)),
                decoration: BoxDecoration(
                  color: (s['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(_w(0.02)),
                ),
                child: Icon(
                  s['icon'] as IconData,
                  color: s['color'] as Color,
                  size: _f(18),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _w(0.015),
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: (s['isPositive'] as bool)
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s['change'] as String,
                  style: TextStyle(
                    color: (s['isPositive'] as bool)
                        ? Colors.green
                        : Colors.red,
                    fontSize: _f(9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: _w(0.01)),
          Text(
            s['value'] as String,
            style: TextStyle(
              fontSize: _f(20),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E3A5F),
            ),
          ),
          Text(
            s['title'] as String,
            style: TextStyle(fontSize: _f(10), color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // RECENT DOCUMENTS
  // ==========================================
  Widget _buildRecentDocuments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Dokumen Terbaru',
              style: TextStyle(
                fontSize: _f(16),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E3A5F),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'Lihat Semua',
                style: TextStyle(
                  color: const Color(0xFF4F46E5),
                  fontSize: _f(11),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: _w(0.002)),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _documents.length,
          itemBuilder: (_, i) => _buildDocumentCard(_documents[i]),
        ),
      ],
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc) {
    final color = doc['color'] as Color;

    return Container(
      margin: EdgeInsets.only(bottom: _w(0.04)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_w(0.04)),
          onTap: () => _openDocumentDetail(doc),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_w(0.04)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(_w(0.04)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: _w(0.11),
                        height: _w(0.12),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(_w(0.03)),
                        ),
                        child: Icon(
                          Icons.description_rounded,
                          color: color,
                          size: _f(26),
                        ),
                      ),
                      SizedBox(width: _w(0.035)),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: _w(0.02),
                                    vertical: _w(0.008),
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(
                                      _w(0.015),
                                    ),
                                  ),
                                  child: Text(
                                    doc['category'] as String,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: _f(9.5),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.event,
                                      size: _f(11),
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      doc['date'] as String,
                                      style: TextStyle(
                                        fontSize: _f(10),
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: _w(0.015)),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                doc['title'] as String,
                                style: TextStyle(
                                  fontSize: _f(13.5),
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E3A5F),
                                  height: 1.35,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(height: _w(0.02)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_pin,
                                        size: _f(12),
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          doc['author'] as String,
                                          style: TextStyle(
                                            fontSize: _f(10.5),
                                            color: Colors.grey[700],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.download_done_rounded,
                                      size: _f(13),
                                      color: Colors.green[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${doc['downloads']}',
                                      style: TextStyle(
                                        fontSize: _f(10.5),
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFBFC),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(_w(0.04)),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    _w(0.04),
                    _w(0.025),
                    _w(0.04),
                    _w(0.03),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openDocumentDetail(doc),
                          icon: Icon(Icons.visibility_outlined, size: _f(16)),
                          label: Text(
                            "Lihat",
                            style: TextStyle(
                              fontSize: _f(11),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A5F),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_w(0.02)),
                            ),
                            padding: EdgeInsets.symmetric(vertical: _w(0.025)),
                          ),
                        ),
                      ),
                      SizedBox(width: _w(0.03)),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _downloadDocument(doc),
                          icon: Icon(Icons.download_rounded, size: _f(16)),
                          label: Text(
                            "Unduh",
                            style: TextStyle(
                              fontSize: _f(11),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_w(0.02)),
                            ),
                            padding: EdgeInsets.symmetric(vertical: _w(0.025)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
