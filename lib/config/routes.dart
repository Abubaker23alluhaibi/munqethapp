import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/welcome_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/phone_check_screen.dart';
import '../screens/main_screen.dart';
import '../screens/shopping/shopping_screen.dart';
import '../screens/shopping/order_screen.dart';
import '../screens/services/services_screen.dart';
import '../screens/services/service_request_screen.dart';
import '../screens/taxi/taxi_screen.dart';
import '../screens/taxi/taxi_order_screen.dart';
import '../screens/supermarket/dashboard_screen.dart';
import '../screens/supermarket/products_screen.dart';
import '../screens/supermarket/orders_screen.dart';
import '../screens/supermarket/settings_screen.dart' as supermarket;
import '../screens/supermarket/add_edit_product_screen.dart';
import '../screens/driver/dashboard_screen.dart';
import '../screens/driver/orders_screen.dart';
import '../screens/driver/my_orders_screen.dart';
import '../screens/driver/order_details_screen.dart';
import '../screens/admin/dashboard_screen.dart';
import '../screens/admin/create_account_screen.dart';
import '../screens/admin/users_management_screen.dart';
import '../screens/admin/user_details_screen.dart';
import '../screens/admin/edit_user_screen.dart';
import '../screens/admin/advertisements_screen.dart';
import '../screens/admin/add_edit_advertisement_screen.dart';
import '../screens/admin/cards_screen.dart';
import '../screens/admin/manage_supermarket_locations_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/addresses_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../screens/profile/help_screen.dart';
import '../screens/profile/redeem_card_screen.dart';
import '../screens/orders/order_history_screen.dart';
import '../screens/orders/order_tracking_screen.dart';
import '../models/product.dart';
import '../models/driver.dart';
import '../models/supermarket.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/welcome',
    routes: [
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/phone-check',
        name: 'phone_check',
        builder: (context, state) => const PhoneCheckScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? '';
          return LoginScreen(initialId: id);
        },
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return SignupScreen(phone: phone);
        },
      ),
      GoRoute(
        path: '/main',
        name: 'main',
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        name: 'edit_profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/addresses',
        name: 'addresses',
        builder: (context, state) => const AddressesScreen(),
      ),
      GoRoute(
        path: '/profile/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile/help',
        name: 'help',
        builder: (context, state) => const HelpScreen(),
      ),
      GoRoute(
        path: '/orders/history',
        name: 'order_history',
        builder: (context, state) => const OrderHistoryScreen(),
      ),
      GoRoute(
        path: '/orders/tracking/:id',
        name: 'order_tracking',
        builder: (context, state) {
          final orderId = state.pathParameters['id'] ?? '';
          return OrderTrackingScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/shopping',
        name: 'shopping',
        builder: (context, state) => const ShoppingScreen(),
        routes: [
          GoRoute(
            path: 'order',
            name: 'shopping_order',
            builder: (context, state) => const ShoppingOrderScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/services',
        name: 'services',
        builder: (context, state) => const ServicesScreen(),
        routes: [
          GoRoute(
            path: 'service-request',
            name: 'service_request',
            builder: (context, state) {
              final serviceType = state.uri.queryParameters['type'] ?? 'maintenance';
              return ServiceRequestScreen(serviceType: serviceType);
            },
          ),
          GoRoute(
            path: 'car-repair-request',
            name: 'car_repair_request',
            builder: (context, state) => const ServiceRequestScreen(serviceType: 'maintenance'),
          ),
        ],
      ),
      GoRoute(
        path: '/taxi',
        name: 'taxi',
        builder: (context, state) => const TaxiScreen(),
        routes: [
          GoRoute(
            path: 'order',
            name: 'taxi_order',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final serviceType = state.uri.queryParameters['serviceType'] ?? 'taxi';
              return TaxiOrderScreen(
                driverId: extra?['driverId'] as String?,
                serviceType: serviceType,
              );
            },
          ),
        ],
      ),
      // Supermarket Routes
      GoRoute(
        path: '/supermarket/dashboard',
        name: 'supermarket_dashboard',
        builder: (context, state) => const SupermarketDashboardScreen(),
      ),
      GoRoute(
        path: '/supermarket/products',
        name: 'supermarket_products',
        builder: (context, state) => const ProductsScreen(),
        routes: [
          GoRoute(
            path: 'add',
            name: 'supermarket_products_add',
            builder: (context, state) => const AddEditProductScreen(),
          ),
          GoRoute(
            path: 'edit',
            name: 'supermarket_products_edit',
            builder: (context, state) {
              final product = state.extra as Product?;
              return AddEditProductScreen(product: product);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/supermarket/orders',
        name: 'supermarket_orders',
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: '/supermarket/settings',
        name: 'supermarket_settings',
        builder: (context, state) => const supermarket.SettingsScreen(),
      ),
      // Driver Routes (Unified)
      GoRoute(
        path: '/driver/dashboard',
        name: 'driver_dashboard',
        builder: (context, state) => const DriverDashboardScreen(),
      ),
      GoRoute(
        path: '/driver/orders',
        name: 'driver_orders',
        builder: (context, state) => const DriverOrdersScreen(),
      ),
      GoRoute(
        path: '/driver/my-orders',
        name: 'driver_my_orders',
        builder: (context, state) => const DriverMyOrdersScreen(),
      ),
      GoRoute(
        path: '/driver/order-details',
        name: 'driver_order_details',
        builder: (context, state) {
          final orderId = state.extra as String? ?? '';
          return DriverOrderDetailsScreen(orderId: orderId);
        },
      ),
      // Admin Routes
      GoRoute(
        path: '/admin/dashboard',
        name: 'admin_dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/create-account',
        name: 'admin_create_account',
        builder: (context, state) => const CreateAccountScreen(),
      ),
      GoRoute(
        path: '/admin/users-management',
        name: 'admin_users_management',
        builder: (context, state) => const UsersManagementScreen(),
      ),
      GoRoute(
        path: '/admin/user-details/:id',
        name: 'admin_user_details',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return UserDetailsScreen(userId: id);
        },
      ),
      GoRoute(
        path: '/admin/edit-user',
        name: 'admin_edit_user',
        builder: (context, state) {
          final driver = state.extra as Driver;
          return EditUserScreen(driver: driver);
        },
      ),
      GoRoute(
        path: '/admin/advertisements',
        name: 'admin_advertisements',
        builder: (context, state) => const AdvertisementsScreen(),
        routes: [
          GoRoute(
            path: 'add',
            name: 'admin_advertisements_add',
            builder: (context, state) => const AddEditAdvertisementScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            name: 'admin_advertisements_edit',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return AddEditAdvertisementScreen(advertisementId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/admin/cards',
        name: 'admin_cards',
        builder: (context, state) => const CardsScreen(),
      ),
      GoRoute(
        path: '/admin/manage-supermarket-locations',
        name: 'admin_manage_supermarket_locations',
        builder: (context, state) {
          final supermarket = state.extra as Supermarket;
          return ManageSupermarketLocationsScreen(supermarket: supermarket);
        },
      ),
      GoRoute(
        path: '/profile/redeem-card',
        name: 'redeem_card',
        builder: (context, state) => const RedeemCardScreen(),
      ),
    ],
  );
}


