import 'environment.dart';

class ApiConfig {
  static String get baseUrl => Env.apiBaseUrl;
  static String get mlBaseUrl => Env.mlServiceUrl;

  // Auth
  static String get register => '$baseUrl/auth/register';
  static String get login => '$baseUrl/auth/login';
  static String get verifyOtp => '$baseUrl/auth/verify-otp';

  // Riders
  static String get riders => '$baseUrl/riders';
  static String riderDashboard(String id) => '$baseUrl/riders/$id/dashboard';

  // Policies
  static String get policies => '$baseUrl/policies';
  static String get plans => '$baseUrl/policies/plans';

  // Claims
  static String get claims => '$baseUrl/claims';
  static String riderClaims(String id) => '$baseUrl/claims/rider/$id';

  // Alerts
  static String get alerts => '$baseUrl/alerts';

  // Weather
  static String get weather => '$baseUrl/weather/current';

  // ML
  static String get premiumPredict => '$mlBaseUrl/predict/premium';
  static String get riskAssess => '$mlBaseUrl/predict/risk';
  static String get fraudDetect => '$mlBaseUrl/predict/fraud';
}
