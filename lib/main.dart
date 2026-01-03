import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'services/storage_service.dart';
import 'services/local_notification_service.dart';
import 'services/firebase_messaging_service.dart';
import 'services/socket_service.dart';
import 'providers/app_providers.dart';
import 'core/utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Firebase (يجب أن تكون أولاً قبل أي استخدام لـ Firebase)
  try {
    await Firebase.initializeApp();
    AppLogger.i('✅ Firebase initialized');
  } catch (e, stackTrace) {
    AppLogger.e('❌ Error initializing Firebase', e, stackTrace);
    // يمكن المتابعة بدون Firebase إذا لم يكن متوفراً
  }
  
  // تهيئة Storage (سريع)
  await StorageService.init();
  
  // تشغيل التطبيق فوراً
  runApp(const MyApp());
  
  // تهيئة Firebase Messaging (للإشعارات الخارجية - عندما يكون التطبيق مغلق)
  FirebaseMessagingService().initialize().then((_) {
    AppLogger.i('✅ FirebaseMessagingService initialized');
  }).catchError((error, stackTrace) {
    AppLogger.e('❌ Error initializing FirebaseMessagingService', error, stackTrace);
  });
  
  // تهيئة Local Notifications (للإشعارات المحلية - عندما يكون التطبيق مفتوح)
  LocalNotificationService().initialize().then((_) {
    AppLogger.i('✅ LocalNotificationService initialized');
  }).catchError((error) {
    AppLogger.e('❌ Error initializing LocalNotificationService', error);
  });
  
  // الاتصال بـ Socket.IO (للتحديثات الفورية)
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
    
    final socketService = SocketService();
    
    switch (state) {
      case AppLifecycleState.resumed:
        // عندما يعود التطبيق إلى المقدمة
        AppLogger.d('📱 App resumed - checking Socket.IO connection...');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!socketService.isConnected) {
            AppLogger.d('📱 Socket not connected, reconnecting...');
            socketService.reconnect();
          } else {
            // حتى لو كان متصل، نتحقق من أن الاتصال نشط
            AppLogger.d('📱 Socket connected, verifying connection...');
            // إعادة إعداد listeners للتأكد من أنها تعمل
            // نستخدم reconnect() لكن فقط إذا كان الاتصال غير نشط
            final socket = socketService.socket;
            if (socket == null || !socket.connected) {
              AppLogger.d('📱 Socket object is null or not connected, reconnecting...');
              socketService.reconnect();
            } else {
              AppLogger.d('📱 Socket is connected and active');
            }
          }
        });
        break;
      case AppLifecycleState.paused:
        // عندما يذهب التطبيق إلى الخلفية
        AppLogger.d('📱 App paused - keeping Socket.IO connection alive');
        // لا نقطع الاتصال - نبقيه نشطاً
        break;
      case AppLifecycleState.inactive:
        AppLogger.d('📱 App inactive');
        break;
      case AppLifecycleState.detached:
        AppLogger.d('📱 App detached');
        break;
      case AppLifecycleState.hidden:
        AppLogger.d('📱 App hidden');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.providers,
      child: Builder(
        builder: (context) {
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
