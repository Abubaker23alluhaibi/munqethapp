import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart' as notification_service;
import 'providers/app_providers.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Storage
  await StorageService.init();
  
  // تهيئة Notifications مع Firebase
  await notification_service.NotificationService().initialize();
  
  // تسجيل background message handler
  FirebaseMessaging.onBackgroundMessage(notification_service.firebaseMessagingBackgroundHandler);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.providers,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp.router(
          title: 'تطبيق المنقذ',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: AppRouter.router,
        ),
      ),
    );
  }
}
