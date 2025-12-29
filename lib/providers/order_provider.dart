import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../services/order_service.dart';

/// Provider لإدارة الطلبات
class OrderProvider with ChangeNotifier {
  final OrderService _orderService = OrderService();

  List<Order> _orders = [];
  Order? _currentOrder;
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastCustomerPhone; // حفظ آخر customerPhone مستخدم

  // Getters
  List<Order> get orders => List.unmodifiable(_orders);
  Order? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// الحصول على الطلبات حسب الحالة
  List<Order> getOrdersByStatus(OrderStatus status) {
    return _orders.where((order) => order.status == status).toList();
  }

  /// الحصول على الطلبات الجديدة
  List<Order> get newOrders => getOrdersByStatus(OrderStatus.pending);

  /// الحصول على الطلبات النشطة
  List<Order> get activeOrders {
    return _orders.where((order) => 
      order.status != OrderStatus.completed && 
      order.status != OrderStatus.cancelled
    ).toList();
  }

  /// تحميل جميع الطلبات
  Future<void> loadOrders({String? supermarketId, String? driverId, String? customerPhone}) async {
    _setLoading(true);
    _clearError();

    try {
      List<Order> loadedOrders;

      if (supermarketId != null) {
        loadedOrders = await _orderService.getAllOrders(supermarketId);
        _lastCustomerPhone = null; // إعادة تعيين عند استخدام supermarketId
      } else if (driverId != null) {
        loadedOrders = await _orderService.getOrdersByDriver(driverId);
        _lastCustomerPhone = null; // إعادة تعيين عند استخدام driverId
      } else if (customerPhone != null) {
        loadedOrders = await _orderService.getOrdersByCustomerPhone(customerPhone);
        _lastCustomerPhone = customerPhone; // حفظ customerPhone
      } else if (_lastCustomerPhone != null) {
        // إذا لم يتم تمرير customerPhone ولكن يوجد آخر واحد محفوظ، استخدمه
        loadedOrders = await _orderService.getOrdersByCustomerPhone(_lastCustomerPhone!);
      } else {
        loadedOrders = await _orderService.getAllOrdersForDriver();
        _lastCustomerPhone = null; // إعادة تعيين
      }

      _orders = loadedOrders;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('حدث خطأ أثناء تحميل الطلبات: $e');
      _setLoading(false);
    }
  }

  /// تحميل طلب محدد
  Future<void> loadOrder(String orderId, {String? supermarketId}) async {
    _setLoading(true);
    _clearError();

    try {
      Order? order;
      
      if (supermarketId != null) {
        order = await _orderService.getOrderById(orderId, supermarketId);
      } else {
        final allOrders = await _orderService.getAllOrdersForDriver();
        try {
          order = allOrders.firstWhere((o) => o.id == orderId);
        } catch (e) {
          order = null;
        }
      }

      _currentOrder = order;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('حدث خطأ أثناء تحميل الطلب: $e');
      _setLoading(false);
    }
  }

  /// إنشاء طلب جديد
  Future<bool> createOrder(Order order) async {
    _setLoading(true);
    _clearError();

    try {
      final createdOrder = await _orderService.createOrder(order);
      if (createdOrder != null) {
        _orders.insert(0, createdOrder);
        _currentOrder = createdOrder;
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('فشل إنشاء الطلب');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('حدث خطأ أثناء إنشاء الطلب: $e');
      _setLoading(false);
      return false;
    }
  }

  /// تحديث حالة الطلب
  Future<bool> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    String? supermarketId,
    String? driverId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      bool success;

      if (supermarketId != null) {
        success = await _orderService.updateOrderStatus(orderId, status, supermarketId);
      } else if (driverId != null) {
        success = await _orderService.updateOrderStatusByDriver(orderId, status, driverId);
      } else {
        success = false;
      }

      try {
        if (success) {
          // تحديث الطلب في القائمة
          final index = _orders.indexWhere((o) => o.id == orderId);
          if (index != -1) {
            _orders[index] = _orders[index].copyWith(
              status: status,
              updatedAt: DateTime.now(),
            );
          }

          // تحديث الطلب الحالي إذا كان هو نفسه
          if (_currentOrder?.id == orderId) {
            _currentOrder = _currentOrder!.copyWith(
              status: status,
              updatedAt: DateTime.now(),
            );
          }

          _setLoading(false);
          notifyListeners();
          return true;
        } else {
          _setError('فشل تحديث حالة الطلب');
          _setLoading(false);
          return false;
        }
      } catch (e) {
        // التعامل مع الأخطاء من السيرفر
        String errorMessage = 'فشل تحديث حالة الطلب';
        if (e is Exception) {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        }
        _setError(errorMessage);
        _setLoading(false);
        return false;
      }
    } catch (e) {
      // التعامل مع الأخطاء من orderService
      String errorMessage = 'حدث خطأ أثناء تحديث حالة الطلب';
      if (e is Exception) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      _setError(errorMessage);
      _setLoading(false);
      return false;
    }
  }

  /// قبول طلب من قبل سائق
  Future<bool> acceptOrder(String orderId, String driverId, String serviceType) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _orderService.acceptOrderByDriver(orderId, driverId, serviceType);
      
      if (success) {
        // إعادة تحميل الطلبات
        await loadOrders(driverId: driverId);
        _setLoading(false);
        notifyListeners();
      } else {
        _setError('فشل قبول الطلب');
        _setLoading(false);
      }

      return success;
    } catch (e) {
      _setError('حدث خطأ أثناء قبول الطلب: $e');
      _setLoading(false);
      return false;
    }
  }

  /// إلغاء طلب (للزبون أو السائق)
  /// يمكن الإلغاء فقط قبل قبول السائق للطلب (قبل حالة accepted)
  Future<bool> cancelOrder(String orderId, {String? driverId, String? cancellationReason}) async {
    _setLoading(true);
    _clearError();

    try {
      // التحقق من حالة الطلب أولاً - استخدام orderService مباشرة
      Order? order;
      
      // محاولة الحصول على الطلب من القائمة المحلية أولاً
      try {
        order = _currentOrder?.id == orderId ? _currentOrder : 
                _orders.firstWhere((o) => o.id == orderId);
      } catch (e) {
        // إذا لم يُوجد في القائمة المحلية، سيتم الحصول عليه من orderService
        // Order not found in local list, will fetch from service
      }
      
      // إذا لم يُوجد محلياً، سيتم الحصول عليه من orderService.cancelOrder
      // الذي سيتحقق من الطلب قبل الإلغاء

      // التحقق من حالة الطلب إذا كان موجوداً محلياً
      if (order != null) {
        // إذا كان السائق يلغي طلب قبل، يمكنه الإلغاء حتى بعد الوصول مع سبب
        if (driverId != null && order.driverId == driverId) {
          // السائق يمكنه الإلغاء حتى بعد الوصول (arrived, inProgress) إذا كان هناك سبب
          // لا يمكن الإلغاء فقط بعد التسليم أو الإكمال
          if (order.status == OrderStatus.delivered ||
              order.status == OrderStatus.completed) {
            _setError('لا يمكن إلغاء الطلب بعد التسليم');
            _setLoading(false);
            return false;
          }
          // إذا كان السائق يلغي بعد الوصول (arrived أو inProgress)، يجب أن يكون هناك سبب
          if ((order.status == OrderStatus.arrived || 
               order.status == OrderStatus.inProgress) && 
              (cancellationReason == null || cancellationReason.trim().isEmpty)) {
            _setError('يرجى كتابة سبب الإلغاء');
            _setLoading(false);
            return false;
          }
          // إذا كانت الحالة accepted أو قبلها، يمكن الإلغاء بدون سبب (أو مع سبب)
        } else {
          // للزبون: يمكن الإلغاء حتى بعد قبول السائق، لكن فقط قبل وصول السائق للموقع
          // أي يمكن الإلغاء في حالات: pending, preparing, ready, accepted
          // لا يمكن الإلغاء بعد: arrived, inProgress, delivered, completed
          if (order.status == OrderStatus.arrived ||
              order.status == OrderStatus.inProgress ||
              order.status == OrderStatus.delivered ||
              order.status == OrderStatus.completed) {
            _setError('لا يمكن إلغاء الطلب بعد وصول السائق للموقع');
            _setLoading(false);
            return false;
          }
        }
      }
      // إذا لم يكن الطلب موجوداً محلياً، سيتم التحقق منه في orderService.cancelOrder

      try {
        final success = await _orderService.cancelOrder(orderId, driverId: driverId, cancellationReason: cancellationReason);
        
        if (success) {
          // إعادة تحميل الطلبات للتأكد من الحصول على أحدث البيانات
          if (_lastCustomerPhone != null) {
            await loadOrders(customerPhone: _lastCustomerPhone);
          } else {
            // تحديث الطلب في القائمة محلياً
            final index = _orders.indexWhere((o) => o.id == orderId);
            if (index != -1) {
              _orders[index] = _orders[index].copyWith(
                status: OrderStatus.cancelled,
                updatedAt: DateTime.now(),
              );
            }

            // تحديث الطلب الحالي إذا كان هو نفسه
            if (_currentOrder?.id == orderId) {
              _currentOrder = _currentOrder!.copyWith(
                status: OrderStatus.cancelled,
                updatedAt: DateTime.now(),
              );
            }
          }

          _setLoading(false);
          notifyListeners();
          return true;
        } else {
          _setError('فشل إلغاء الطلب');
          _setLoading(false);
          return false;
        }
      } catch (e) {
        // التعامل مع الأخطاء من السيرفر
        String errorMessage = 'فشل إلغاء الطلب';
        if (e is Exception) {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        }
        _setError(errorMessage);
        _setLoading(false);
        return false;
      }
    } catch (e) {
      // التعامل مع الأخطاء العامة
      String errorMessage = 'حدث خطأ أثناء إلغاء الطلب';
      if (e is Exception) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      } else {
        errorMessage = 'حدث خطأ أثناء إلغاء الطلب: $e';
      }
      _setError(errorMessage);
      _setLoading(false);
      return false;
    }
  }

  /// تحديث الطلبات (للـ refresh)
  Future<void> refreshOrders({String? supermarketId, String? driverId, String? customerPhone}) async {
    await loadOrders(
      supermarketId: supermarketId,
      driverId: driverId,
      customerPhone: customerPhone ?? _lastCustomerPhone,
    );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}





