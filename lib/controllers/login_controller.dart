import 'package:get/get.dart';

import '../services/app_session_service.dart';
import '../services/google_auth_service.dart';
import '../services/push_notification_service.dart';
import '../services/sipora_api_service.dart';

class LoginController extends GetxController {
  LoginController({
    SiporaApiService? apiService,
    GoogleAuthService? googleAuthService,
  }) : _apiService = apiService ?? SiporaApiService(),
       _googleAuthService = googleAuthService ?? GoogleAuthService();

  final SiporaApiService _apiService;
  final GoogleAuthService _googleAuthService;

  final RxBool isLoading = false.obs;
  final RxBool isGoogleLoading = false.obs;

  Future<bool> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    isLoading.value = true;
    try {
      final response = await _apiService.login(
        email: email.trim(),
        password: password,
      );

      final user = response['user'];
      if (user is Map) {
        AppSessionService.setCurrentUser(Map<String, dynamic>.from(user));
        await PushNotificationService.registerCurrentDeviceToken();
      }

      return true;
    } catch (_) {
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithGoogle() async {
    isGoogleLoading.value = true;
    try {
      final credential = await _googleAuthService.signInWithGoogle();
      final user = credential.user;
      if (user != null) {
        AppSessionService.setCurrentUser({
          'id_user': user.uid,
          'nama_lengkap': user.displayName ?? user.email ?? 'Pengguna',
          'email': user.email ?? '',
          'username': user.email?.split('@').first ?? user.uid,
          'role': 'user',
          'status': 'active',
        });
        await PushNotificationService.registerCurrentDeviceToken();
      }
    } finally {
      isGoogleLoading.value = false;
    }
  }
}
