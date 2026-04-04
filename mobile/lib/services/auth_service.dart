import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';
import 'cache_service.dart';
import 'storage_service.dart';

/// Auth flow reality check:
///   - Firebase handles identity (Google Sign-In / Phone OTP)
///   - Backend has no JWT endpoint — rider ID is stored locally after
///     POST /api/riders/register returns the created rider's _id
///   - isLoggedIn = riderId saved in storage + Firebase currentUser present

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Google Sign-In ────────────────────────────────────────────────────────

  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.cancelled();
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return AuthResult.error('Firebase sign-in failed');

      // Check if this phone/email already has a rider in backend
      final savedId = await _storage.getRiderId();
      if (savedId != null) {
        return AuthResult.success(riderId: savedId, isNewUser: false);
      }

      // New user — needs onboarding
      return AuthResult.success(
        riderId: null,
        isNewUser: true,
        firebaseUid: user.uid,
        email: user.email,
        displayName: user.displayName,
      );
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }

  // ── Phone OTP ─────────────────────────────────────────────────────────────

  String? _verificationId;

  Future<AuthResult> sendOTP(String phoneNumber) async {
    try {
      // Firebase expects E.164 format: +91XXXXXXXXXX
      final formatted = phoneNumber.startsWith('+')
          ? phoneNumber
          : '+91$phoneNumber';

      final completer = _OTPCompleter();

      await _auth.verifyPhoneNumber(
        phoneNumber: formatted,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential cred) async {
          // Auto-verified on Android — sign in immediately
          await _auth.signInWithCredential(cred);
          completer.complete(AuthResult.success(riderId: null, isNewUser: true));
        },
        verificationFailed: (FirebaseAuthException e) {
          completer.complete(AuthResult.error(e.message ?? 'OTP send failed'));
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          completer.complete(AuthResult.otpSent());
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );

      return completer.result ?? AuthResult.otpSent();
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }

  Future<AuthResult> verifyOTP(String otp) async {
    try {
      if (_verificationId == null) {
        return AuthResult.error('No verification in progress — resend OTP');
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return AuthResult.error('OTP verification failed');

      // Check if rider already registered
      final savedId = await _storage.getRiderId();
      if (savedId != null) {
        return AuthResult.success(riderId: savedId, isNewUser: false);
      }

      return AuthResult.success(
        riderId: null,
        isNewUser: true,
        firebaseUid: user.uid,
        phone: user.phoneNumber,
      );
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }

  // ── Register rider with backend ───────────────────────────────────────────

  Future<AuthResult> registerRider(Map<String, dynamic> riderData) async {
    try {
      final res = await _api.createRider(riderData);
      if (!res.success || res.data == null) {
        return AuthResult.error(res.error ?? 'Registration failed');
      }

      final riderId = res.data!.id;
      await _storage.saveRiderId(riderId);
      await _storage.setOnboardingDone();

      return AuthResult.success(riderId: riderId, isNewUser: false);
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }

  // ── Auto-login check ──────────────────────────────────────────────────────

  Future<bool> isLoggedIn() async {
    // Both conditions must be true: local rider ID saved AND Firebase session active
    final savedId = await _storage.getRiderId();
    if (savedId == null) return false;
    return _auth.currentUser != null;
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
      CacheService().clearAll(),
      _storage.clearAll(),
    ]);
  }
}

// ── Result type ───────────────────────────────────────────────────────────────

class AuthResult {
  final bool success;
  final bool cancelled;
  final bool otpSent;
  final String? riderId;
  final bool isNewUser;
  final String? error;
  final String? firebaseUid;
  final String? email;
  final String? displayName;
  final String? phone;

  const AuthResult._({
    required this.success,
    this.cancelled = false,
    this.otpSent = false,
    this.riderId,
    this.isNewUser = false,
    this.error,
    this.firebaseUid,
    this.email,
    this.displayName,
    this.phone,
  });

  factory AuthResult.success({
    required String? riderId,
    required bool isNewUser,
    String? firebaseUid,
    String? email,
    String? displayName,
    String? phone,
  }) =>
      AuthResult._(
        success: true,
        riderId: riderId,
        isNewUser: isNewUser,
        firebaseUid: firebaseUid,
        email: email,
        displayName: displayName,
        phone: phone,
      );

  factory AuthResult.cancelled() =>
      const AuthResult._(success: false, cancelled: true);

  factory AuthResult.otpSent() =>
      const AuthResult._(success: true, otpSent: true);

  factory AuthResult.error(String message) =>
      AuthResult._(success: false, error: message);
}

// Simple completer for the callback-based verifyPhoneNumber API
class _OTPCompleter {
  AuthResult? result;
  void complete(AuthResult r) => result ??= r;
}
