import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../core/utils/platform_support.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ─── Auth State ──────────────────────────────────────────────────
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isLoggedIn => user != null;
  bool get isAdmin => user?.isAdmin ?? false;
  bool get isPainter => user?.isPainter ?? false;

  AuthState copyWith({UserModel? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Auth Notifier ───────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final DataService _dataService;
  final AuthService _authService;

  AuthNotifier(this._dataService, this._authService)
    : super(const AuthState(isLoading: true));

  bool _isAutologging = false;

  Future<void> checkSavedLogin() async {
    if (_isAutologging) return;
    _isAutologging = true;

    debugPrint('AuthNotifier: checkSavedLogin started');
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Wait for DataService to load initial data from Supabase
      int retryCount = 0;
      while (!_dataService.isLoaded && retryCount < 200) {
        await Future.delayed(const Duration(milliseconds: 100));
        retryCount++;
      }
      debugPrint(
        'AuthNotifier: DataService isLoaded=${_dataService.isLoaded} after ${retryCount * 100}ms',
      );

      if (!_dataService.isLoaded) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone');
      final pin = prefs.getString('user_pin');
      debugPrint('AuthNotifier: SharedPrefs phone=$phone');

      if (phone != null && pin != null) {
        final success = await login(phone, pin, remember: false);
        debugPrint('AuthNotifier: Auto-login success=$success');
      }
    } catch (e) {
      debugPrint('AuthNotifier: Error in checkSavedLogin: $e');
    } finally {
      _isAutologging = false;
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> login(String phone, String pin, {bool remember = true}) async {
    state = state.copyWith(isLoading: true, error: null);

    // Enforce synchronization before validation
    int retry = 0;
    while (!_dataService.isLoaded && retry < 30) {
      await Future.delayed(const Duration(milliseconds: 200));
      retry++;
    }

    final user = _dataService.login(phone, pin);
    if (user == null) {
      final errorMsg = !_dataService.isLoaded
          ? 'Connecting to server... please try again in a moment'
          : 'Invalid phone number or PIN';
      state = AuthState(error: errorMsg);
      return false;
    }

    if (user.isInactive) {
      state = AuthState(user: user, error: 'pending_approval');
      return false;
    }

    if (user.isSuspended) {
      state = const AuthState(
        error: 'Your account has been suspended. Contact admin.',
      );
      return false;
    }

    if (remember) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_phone', phone);
      await prefs.setString('user_pin', pin);
    }

    state = AuthState(user: user);
    _updateVersion(user.id);
    return true;
  }

  Future<void> _updateVersion(String userId) async {
    try {
      final info = await PackageInfo.fromPlatform();
      await _dataService.updateUserAppVersion(userId, info.version);
    } catch (_) {}
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);

    if (!PlatformSupport.supportsGoogleSignIn) {
      state = const AuthState(
        error:
            'Google Sign-In is not available on Windows yet. Please use phone and PIN.',
      );
      return false;
    }

    final response = await _authService.signInWithGoogle();

    if (response == null || response.user == null) {
      state = state.copyWith(isLoading: false);
      return false;
    }

    final email = response.user!.email;
    if (email == null) {
      state = AuthState(error: 'Could not retrieve email from Google account');
      return false;
    }

    // Check if user exists in Supabase by email
    final user = _dataService.getUserByEmail(email);

    if (user == null) {
      state = AuthState(
        error: 'No account found for this email. Please register first.',
      );
      return false;
    }

    if (user.isInactive) {
      state = AuthState(user: user, error: 'pending_approval');
      return false;
    }

    if (user.isSuspended) {
      state = const AuthState(
        error: 'Your account has been suspended. Contact admin.',
      );
      return false;
    }

    state = AuthState(user: user);
    _updateVersion(user.id);
    return true;
  }

  Future<String?> register({
    required String name,
    required String phone,
    required String email,
    required String pin,
    required String businessName,
    required String businessAddress,
    String? referralCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final user = await _dataService.register(
        name: name,
        phone: phone,
        email: email,
        pin: pin,
        businessName: businessName,
        businessAddress: businessAddress,
        referralCode: referralCode,
      );
      // Save credentials immediately so they stay logged in (even if pending)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_phone', phone);
      await prefs.setString('user_pin', pin);

      state = AuthState(user: user, error: 'pending_approval');
      return null; // success
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('unique_violation')) {
        errorMessage = 'user with this mobile no. is already registerd';
      }
      state = AuthState(error: errorMessage);
      return errorMessage;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_phone');
    await prefs.remove('user_pin');
    await _authService.signOut();
    state = const AuthState();
  }

  void refreshUser() {
    if (state.user != null) {
      final updated = _dataService.getUserById(state.user!.id);
      if (updated != null) {
        state = AuthState(user: updated);
      }
    }
  }
}

// ─── Providers ───────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final dataService = ref.read(dataServiceProvider);
  final authService = ref.read(authServiceProvider);
  return AuthNotifier(dataService, authService);
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});
