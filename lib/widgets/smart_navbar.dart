import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// Pastikan import ini sesuai dengan struktur folder proyek Anda
import '../pages/dashboard.dart';
import '../pages/upload.dart';
import '../pages/jelajahi.dart';
import '../pages/pencarian.dart'; // ✅ TAMBAHKAN IMPORT SEARCH PAGE DI SINI
import 'chat_panel.dart';
import 'floating_chatbot.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static final GlobalKey<MainShellState> globalKey =
      GlobalKey<MainShellState>();

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _showChatOverlay = false;
  late AnimationController _chatOverlayController;

  late Animation<Offset> _chatSlideAnim;
  late Animation<double> _chatFadeAnim;

  // ✅ 1. TAMBAHKAN SearchPage ke daftar halaman
  final List<Widget> _pages = [
    const DashboardPage(), // Index 0
    const UploadPage(), // Index 1
    const SearchPage(), // Index 2 (Baru ditambahkan)
    const JelajahiPage(), // Index 3
  ];

  @override
  void initState() {
    super.initState();
    _chatOverlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _chatSlideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _chatOverlayController,
            curve: Curves.easeOutCubic,
          ),
        );

    _chatFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _chatOverlayController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _chatOverlayController.dispose();
    super.dispose();
  }

  void openChat() {
    setState(() => _showChatOverlay = true);
    _chatOverlayController.forward();
  }

  void _closeChat() {
    _chatOverlayController.reverse().then((_) {
      if (mounted) setState(() => _showChatOverlay = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );

    return Stack(
      children: [
        Scaffold(
          extendBody: true,
          body: _pages[_currentIndex],
          bottomNavigationBar: _buildNavBar(),
          floatingActionButton: _buildFab(),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
        ),
        if (_showChatOverlay) _buildChatOverlay(),
      ],
    );
  }

  Widget _buildFab() {
    return FloatingChatbotButton(onTap: openChat);
  }

  Widget _buildNavBar() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const contentHeight = 52.0;

    return SizedBox(
      height: contentHeight + bottomInset,
      child: CustomPaint(
        painter: _NotchPainter(bottomPadding: bottomInset),
        child: Column(
          children: [
            SizedBox(
              height: contentHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(
                    Icons.home_outlined,
                    Icons.home_rounded,
                    "Beranda",
                    0,
                  ),
                  _navItem(
                    Icons.cloud_upload_outlined,
                    Icons.cloud_upload_rounded,
                    "Upload",
                    1,
                  ),
                  const SizedBox(width: 62),
                  // ✅ 2. UBAH INDEX DARI -1 JADI 2
                  _navItem(
                    Icons.search_outlined,
                    Icons.search_rounded,
                    "Pencarian",
                    2,
                  ),
                  // ✅ 3. UBAH INDEX JELAJAHI DARI 2 JADI 3
                  _navItem(
                    Icons.explore_outlined,
                    Icons.explore_rounded,
                    "Jelajahi",
                    3,
                  ),
                ],
              ),
            ),
            SizedBox(height: bottomInset),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, IconData activeIcon, String label, int index) {
    final isActive = _currentIndex == index;

    return Semantics(
      button: true,
      label: label,
      selected: isActive,
      child: GestureDetector(
        onTap: () {
          // ✅ 4. HAPUS LOGIKA SNACKBAR, LANGSUNG GANTI HALAMAN
          setState(() => _currentIndex = index);
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 58,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 26,
                color: isActive ? Colors.white : Colors.white.withOpacity(0.45),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  height: 1,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatOverlay() {
    return Positioned.fill(
      child: SlideTransition(
        position: _chatSlideAnim,
        child: FadeTransition(
          opacity: _chatFadeAnim,
          child: ChatPanel(onClose: _closeChat),
        ),
      ),
    );
  }
}

// Custom Painter untuk Notch bawah
class _NotchPainter extends CustomPainter {
  final double bottomPadding;
  const _NotchPainter({this.bottomPadding = 0});

  @override
  void paint(Canvas canvas, Size size) {
    const cornerR = 12.0;
    const fabR = 27.0;
    const gap = 6.0;
    const notchHalfW = fabR + gap;
    const notchD = 32.0;
    const cpOffset = 18.0;

    final cx = size.width / 2;
    final curveStartX = cx - notchHalfW - cpOffset;
    final curveEndX = cx + notchHalfW + cpOffset;

    final path = Path()
      ..moveTo(0, cornerR)
      ..quadraticBezierTo(0, 0, cornerR, 0)
      ..lineTo(curveStartX, 0)
      ..cubicTo(curveStartX + cpOffset, 0, cx - cpOffset, notchD, cx, notchD)
      ..cubicTo(cx + cpOffset, notchD, curveEndX - cpOffset, 0, curveEndX, 0)
      ..lineTo(size.width - cornerR, 0)
      ..quadraticBezierTo(size.width, 0, size.width, cornerR)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawShadow(
      path,
      const Color(0xFF1565C0).withOpacity(0.15),
      8,
      false,
    );

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF1565C0), Color(0xFF1E88E5), Color(0xFF42A5F5)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NotchPainter old) =>
      old.bottomPadding != bottomPadding;
}
