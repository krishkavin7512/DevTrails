import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5001/api';
  static String get mlServiceUrl =>
      dotenv.env['ML_SERVICE_URL'] ?? 'http://10.0.2.2:8000/api';
  static String get mapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  static String get razorpayKeyId => dotenv.env['RAZORPAY_KEY_ID'] ?? '';
  static String get razorpayKeySecret =>
      dotenv.env['RAZORPAY_KEY_SECRET'] ?? '';
  static String get openWeatherApiKey =>
      dotenv.env['OPENWEATHERMAP_API_KEY'] ?? '';
  static String get twilioAccountSid =>
      dotenv.env['TWILIO_ACCOUNT_SID'] ?? '';
  static String get twilioAuthToken => dotenv.env['TWILIO_AUTH_TOKEN'] ?? '';
  static String get twilioWhatsApp =>
      dotenv.env['TWILIO_WHATSAPP_NUMBER'] ?? '+14155238886';
}
