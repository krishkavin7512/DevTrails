import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? riderId;
  final String? error;

  const AuthState({
    required this.status,
    this.riderId,
    this.error,
  });

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final _authService = AuthService();
  final _storage = StorageService();

  AuthNotifier() : super(const AuthState(status: AuthStatus.loading)) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await _authService.isLoggedIn();
    if (loggedIn) {
      final riderId = await _storage.getRiderId();
      state = AuthState(status: AuthStatus.authenticated, riderId: riderId);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<AuthResult> signInWithGoogle() async {
    final result = await _authService.signInWithGoogle();
    if (result.success && !result.isNewUser && result.riderId != null) {
      state = AuthState(
          status: AuthStatus.authenticated, riderId: result.riderId);
    }
    return result;
  }

  Future<AuthResult> sendOTP(String phone) => _authService.sendOTP(phone);

  Future<AuthResult> verifyOTP(String otp) async {
    final result = await _authService.verifyOTP(otp);
    if (result.success && !result.isNewUser && result.riderId != null) {
      state = AuthState(
          status: AuthStatus.authenticated, riderId: result.riderId);
    }
    return result;
  }

  Future<AuthResult> registerRider(Map<String, dynamic> data) async {
    final result = await _authService.registerRider(data);
    if (result.success && result.riderId != null) {
      state =
          AuthState(status: AuthStatus.authenticated, riderId: result.riderId);
    }
    return result;
  }

  Future<void> logout() async {
    await _authService.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

// Convenience provider — watched by rider_provider and claim_provider
final riderIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).riderId;
});
