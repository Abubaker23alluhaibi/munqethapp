import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'services/storage_service.dart';
import 'services/local_notification_service.dart';
import 'services/socket_service.dart';
import 'providers/app_providers.dart';
import 'providers/auth_provider.dart';
import 'core/utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Storage (سريع)
  await StorageService.init();
  
  // تشغيل التطبيق فوراً
  runApp(const MyApp());
  
  // تهيئة Local Notifications (بدون Firebase)
  LocalNotificationService().initialize().then((_) {
    AppLogger.i('✅ LocalNotificationService initialized');
  }).catchError((error) {
    AppLogger.e('❌ Error initializing LocalNotificationService', error);
  });
  
  // الاتصال بـ Socket.IO
  SocketService().connect().then((_) {
    AppLogger.i('✅ SocketService connected');
  }).catchError((error) {
    AppLogger.e('❌ Error connecting SocketService', error);
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
      // عندما يعود التطبيق إلى المقدمة
      AppLogger.d('📱 App resumed');
      _ensureFcmTokens();
    }
  }

  void _ensureFcmTokens() async {
    // لا حاجة لـ FCM tokens - نستخدم Socket.IO الآن
    AppLogger.d('App resumed - Socket.IO will handle notifications');
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.providers,
      child: Builder(
        builder: (context) {
          // حفظ context للاستخدام في lifecycle callbacks
          _appContext = context;
          
          // Socket.IO سيتم تهيئته في main() - لا حاجة لـ FCM tokens
          AppLogger.d('App started - Socket.IO will handle notifications');
          
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
