import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart' as notification_service;
import 'providers/app_providers.dart';
import 'providers/auth_provider.dart';
import 'core/utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Storage (سريع)
  await StorageService.init();
  
  // تسجيل background message handler (يجب أن يكون قبل runApp)
  FirebaseMessaging.onBackgroundMessage(notification_service.firebaseMessagingBackgroundHandler);
  
  // تشغيل التطبيق فوراً بدون انتظار تهيئة Firebase/Notifications
  // سيتم تهيئة Firebase/Notifications في الخلفية بعد تشغيل التطبيق
  runApp(const MyApp());
  
  // تهيئة Notifications مع Firebase في الخلفية (غير متزامن)
  // هذا لن يبطئ بدء التطبيق
  notification_service.NotificationService().initialize().catchError((error) {
    AppLogger.e('Error initializing notifications in background', error);
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  BuildContext? _appContext;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // عندما يعود التطبيق إلى المقدمة، تأكد من تسجيل FCM tokens
      AppLogger.d('📱 App resumed - ensuring FCM tokens are registered...');
      _ensureFcmTokens();
    }
  }

  void _ensureFcmTokens() {
    if (_appContext != null && _appContext!.mounted) {
      try {
        final authProvider = Provider.of<AuthProvider>(_appContext!, listen: false);
        authProvider.ensureFcmTokenRegistered();
      } catch (e) {
        AppLogger.e('❌ Error ensuring FCM tokens on app resume', e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.providers,
      child: Builder(
        builder: (context) {
          // حفظ context للاستخدام في lifecycle callbacks
          _appContext = context;
          
          // تأكد من تسجيل FCM tokens عند فتح التطبيق لأول مرة
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              try {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                authProvider.ensureFcmTokenRegistered();
              } catch (e) {
                AppLogger.e('❌ Error ensuring FCM tokens on app start', e);
              }
            }
          });
          
          return Directionality(
            textDirection: TextDirection.rtl,
            child: MaterialApp.router(
              title: 'تطبيق المنقذ',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              routerConfig: AppRouter.router,
            ),
          );
        },
      ),
    );
  }
}
