import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../config/environment.dart';
import '../models/alert.dart';
import '../models/api_response.dart';
import '../models/claim.dart';
import '../models/policy.dart';
import '../models/rider.dart';
import '../models/weather_data.dart';
import 'cache_service.dart';
import 'storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late Dio _dio;
  late Dio _mlDio;
  final StorageService _storage = StorageService();

  void initialize() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _mlDio = Dio(BaseOptions(
      baseUrl: Env.mlServiceUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _storage.clearToken();
          await _storage.clearRiderId();
        }
        return handler.next(error);
      },
    ));
  }

  // ── Generic helpers ───────────────────────────────────────────────────────

  Future<ApiResponse<T>> _get<T>(
    String endpoint,
    T Function(dynamic) fromJson, {
    Map<String, dynamic>? params,
    bool useML = false,
  }) async {
    try {
      final client = useML ? _mlDio : _dio;
      final response =
          await client.get(endpoint, queryParameters: params);
      return ApiResponse.fromJson(
          response.data as Map<String, dynamic>, fromJson);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: _parseError(e),
      );
    }
  }

  Future<ApiResponse<T>> _post<T>(
    String endpoint,
    Map<String, dynamic> data,
    T Function(dynamic) fromJson, {
    bool useML = false,
  }) async {
    try {
      final client = useML ? _mlDio : _dio;
      final response = await client.post(endpoint, data: data);
      return ApiResponse.fromJson(
          response.data as Map<String, dynamic>, fromJson);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: _parseError(e),
      );
    }
  }

  Future<ApiResponse<T>> _put<T>(
    String endpoint,
    Map<String, dynamic> data,
    T Function(dynamic) fromJson,
  ) async {
    try {
      final response = await _dio.put(endpoint, data: data);
      return ApiResponse.fromJson(
          response.data as Map<String, dynamic>, fromJson);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: _parseError(e),
      );
    }
  }

  String _parseError(DioException e) {
    final serverMsg = e.response?.data;
    if (serverMsg is Map) {
      return serverMsg['error'] ?? serverMsg['message'] ?? e.message ?? 'Network error';
    }
    return e.message ?? 'Network error';
  }

  /// GET with transparent cache fallback.
  /// On success the response is written to cache under [cacheKey].
  /// On network failure the cached value (if any) is returned as a success.
  Future<ApiResponse<T>> _getCached<T>(
    String endpoint,
    T Function(dynamic) fromJson,
    String cacheKey, {
    Map<String, dynamic>? params,
    Duration? ttl,
  }) async {
    final result = await _get<T>(endpoint, fromJson, params: params);
    if (result.success && result.data != null) {
      // Persist raw JSON-compatible representation for cache
      try {
        await CacheService().set(cacheKey, result.data);
      } catch (_) {}
      return result;
    }
    // Network failed — try cache
    final cached = await CacheService().get<dynamic>(cacheKey, ttl: ttl);
    if (cached != null) {
      try {
        return ApiResponse(success: true, data: fromJson(cached), message: 'cached');
      } catch (_) {}
    }
    return result;
  }

  /// Retry a call up to [attempts] times with [delay] between tries.
  Future<ApiResponse<T>> _withRetry<T>(
    Future<ApiResponse<T>> Function() call, {
    int attempts = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (int i = 0; i < attempts; i++) {
      final res = await call();
      if (res.success) return res;
      if (i < attempts - 1) await Future.delayed(delay);
    }
    return call();
  }

  // ── Riders ────────────────────────────────────────────────────────────────

  Future<ApiResponse<Rider>> createRider(
          Map<String, dynamic> data) =>
      _post('/riders', data, (j) => Rider.fromJson(j));

  Future<ApiResponse<Rider>> updateRider(
          String id, Map<String, dynamic> data) =>
      _put('/riders/$id', data, (j) => Rider.fromJson(j));

  Future<ApiResponse<Rider>> getRiderById(String id) =>
      _get('/riders/$id', (j) => Rider.fromJson(j));

  Future<ApiResponse<Map<String, dynamic>>> getRiderDashboard(
          String id) =>
      _getCached(
        '/riders/$id/dashboard',
        (j) => j as Map<String, dynamic>,
        CacheService.dashboardKey(id),
      );

  // ── Policies ──────────────────────────────────────────────────────────────

  Future<ApiResponse<Policy>> createPolicy(
          Map<String, dynamic> data) =>
      _post('/policies', data, (j) => Policy.fromJson(j));

  Future<ApiResponse<List<Policy>>> getRiderPolicies(String riderId) =>
      _getCached(
        '/policies/rider/$riderId',
        (j) => (j as List)
            .map((p) => Policy.fromJson(p as Map<String, dynamic>))
            .toList(),
        CacheService.policiesKey(riderId),
      );

  Future<ApiResponse<List<Map<String, dynamic>>>> getPlans() =>
      _get('/policies/plans',
          (j) => (j as List).cast<Map<String, dynamic>>());

  // ── Claims ────────────────────────────────────────────────────────────────

  Future<ApiResponse<List<Claim>>> getRiderClaims(
    String riderId, {
    int page = 1,
    int limit = 10,
    String? status,
  }) =>
      _getCached(
        '/claims/rider/$riderId',
        (j) => (j as List)
            .map((c) => Claim.fromJson(c as Map<String, dynamic>))
            .toList(),
        CacheService.claimsKey(riderId),
        params: {
          'page': page,
          'limit': limit,
          if (status != null) 'status': status,
        },
      );

  Future<ApiResponse<Claim>> getClaimById(String id) =>
      _get('/claims/$id', (j) => Claim.fromJson(j));

  Future<ApiResponse<Claim>> initiateClaim(
          Map<String, dynamic> data) =>
      _withRetry(() => _post('/claims/initiate', data, (j) => Claim.fromJson(j)));

  // ── Alerts ────────────────────────────────────────────────────────────────

  Future<ApiResponse<Alert>> submitAlert(
          Map<String, dynamic> data) =>
      _post('/alerts', data, (j) => Alert.fromJson(j));

  Future<ApiResponse<List<Alert>>> getNearbyAlerts(
    double lat,
    double lng, {
    double radius = 5.0,
  }) =>
      _get(
        '/alerts/nearby',
        (j) => (j as List)
            .map((a) => Alert.fromJson(a as Map<String, dynamic>))
            .toList(),
        params: {'lat': lat, 'lng': lng, 'radius': radius},
      );

  Future<ApiResponse<Alert>> confirmAlert(String alertId) =>
      _post('/alerts/$alertId/confirm', {}, (j) => Alert.fromJson(j));

  Future<ApiResponse<Map<String, dynamic>>> getRiderTrustProfile(
          String riderId) =>
      _get('/riders/$riderId/trust',
          (j) => Map<String, dynamic>.from(j as Map));

  // ── Emergency ─────────────────────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> triggerEmergency(
          Map<String, dynamic> data) =>
      _post('/emergency/trigger', data,
          (j) => Map<String, dynamic>.from(j as Map));

  Future<ApiResponse<Map<String, dynamic>>> updateEmergencyLocation(
          String id, Map<String, dynamic> location) =>
      _put('/emergency/$id/location', location,
          (j) => Map<String, dynamic>.from(j as Map));

  Future<ApiResponse<Map<String, dynamic>>> cancelEmergency(
          String id, Map<String, dynamic> data) =>
      _post('/emergency/$id/cancel', data,
          (j) => Map<String, dynamic>.from(j as Map));

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> updateFcmToken(
          String riderId, String token) =>
      _put('/riders/$riderId/fcm-token', {'fcmToken': token},
          (j) => Map<String, dynamic>.from(j as Map));

  Future<ApiResponse<Map<String, dynamic>>> updateNotificationPrefs(
          String riderId, Map<String, dynamic> prefs) =>
      _put('/riders/$riderId/notification-prefs', prefs,
          (j) => Map<String, dynamic>.from(j as Map));

  // ── Payments ──────────────────────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> verifyPayment(
          Map<String, dynamic> data) =>
      _post('/payments/verify', data,
          (j) => Map<String, dynamic>.from(j as Map));

  Future<ApiResponse<Map<String, dynamic>>> createSubscription(
          Map<String, dynamic> data) =>
      _post('/payments/subscription/create', data,
          (j) => Map<String, dynamic>.from(j as Map));

  Future<ApiResponse<Map<String, dynamic>>> pauseSubscription(
          String subscriptionId) =>
      _post('/payments/subscription/$subscriptionId/pause', {},
          (j) => Map<String, dynamic>.from(j as Map));

  Future<ApiResponse<Map<String, dynamic>>> resumeSubscription(
          String subscriptionId) =>
      _post('/payments/subscription/$subscriptionId/resume', {},
          (j) => Map<String, dynamic>.from(j as Map));

  Future<ApiResponse<Map<String, dynamic>>> cancelSubscription(
          String subscriptionId) =>
      _post('/payments/subscription/$subscriptionId/cancel', {},
          (j) => Map<String, dynamic>.from(j as Map));

  Future<ApiResponse<List<Map<String, dynamic>>>> getPaymentHistory(
          String riderId) =>
      _get('/payments/history/$riderId',
          (j) => (j as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList());

  Future<ApiResponse<Map<String, dynamic>>> initiatePayout(
          Map<String, dynamic> data) =>
      _post('/payments/payout', data,
          (j) => Map<String, dynamic>.from(j as Map));

  Future<ApiResponse<Map<String, dynamic>>> getSubscriptionStatus(
          String riderId) =>
      _get('/payments/subscription/status/$riderId',
          (j) => Map<String, dynamic>.from(j as Map));

  // ── Weather ───────────────────────────────────────────────────────────────

  Future<ApiResponse<WeatherData>> getWeatherForCity(String city) =>
      _getCached(
        '/weather/$city',
        (j) => WeatherData.fromJson(j),
        CacheService.weatherKey(city),
        ttl: const Duration(minutes: 10),
      );

  Future<ApiResponse<WeatherData>> getWeatherByLocation(
    double lat,
    double lng,
  ) =>
      _get(
        '/weather/current',
        (j) => WeatherData.fromJson(j),
        params: {'lat': lat, 'lng': lng},
      );

  // ── ML service ────────────────────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> getPremiumPrediction(
          Map<String, dynamic> features) =>
      _post(
        '/predict/premium',
        features,
        (j) => j as Map<String, dynamic>,
        useML: true,
      );

  Future<ApiResponse<Map<String, dynamic>>> getRiskAssessment(
          Map<String, dynamic> features) =>
      _post(
        '/predict/risk',
        features,
        (j) => j as Map<String, dynamic>,
        useML: true,
      );

  Future<ApiResponse<Map<String, dynamic>>> detectFraud(
          Map<String, dynamic> claimData) =>
      _post(
        '/predict/fraud',
        claimData,
        (j) => j as Map<String, dynamic>,
        useML: true,
      );

  // ── Fraud detection ───────────────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> checkDevice(
          Map<String, dynamic> data) =>
      _post('/fraud/check-device', data,
          (j) => Map<String, dynamic>.from(j as Map));

  Future<ApiResponse<Map<String, dynamic>>> checkRing(
          Map<String, dynamic> data) =>
      _post('/fraud/check-ring', data,
          (j) => Map<String, dynamic>.from(j as Map));

  Future<ApiResponse<List<Map<String, dynamic>>>> getReviewQueue() =>
      _get('/fraud/review-queue',
          (j) => (j as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList());

  Future<ApiResponse<Map<String, dynamic>>> reviewClaim(
          String claimId, Map<String, dynamic> data) =>
      _put('/fraud/review/$claimId', data,
          (j) => Map<String, dynamic>.from(j as Map));

  Future<ApiResponse<Map<String, dynamic>>> appealClaim(
          String claimId, String reason) =>
      _put('/claims/$claimId/appeal', {'reason': reason},
          (j) => Map<String, dynamic>.from(j as Map));

  Future<ApiResponse<Map<String, dynamic>>> submitEarningsProof(
          String claimId, Map<String, dynamic> data) =>
      _put('/claims/$claimId/submit-proof', data,
          (j) => Map<String, dynamic>.from(j as Map));
}
