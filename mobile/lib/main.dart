import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await StorageService().initialize();
  ApiService().initialize();

  try {
    await Firebase.initializeApp();
    await NotificationService().initialize();
  } catch (_) {
    // Firebase/FCM unavailable (missing google-services.json) — safe to continue
  }

  runApp(const ProviderScope(child: RainCheckApp()));
}
