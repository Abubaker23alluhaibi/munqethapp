class AdminPermissions {
  final bool dashboard;
  final bool usersManagement;
  final bool createAccount;
  final bool advertisements;
  final bool cards;
  final bool settings;
  final bool manageLocations;
  final bool changePassword;
  final bool addAdmins;

  const AdminPermissions({
    this.dashboard = true,
    this.usersManagement = true,
    this.createAccount = true,
    this.advertisements = true,
    this.cards = true,
    this.settings = true,
    this.manageLocations = true,
    this.changePassword = true,
    this.addAdmins = false,
  });

  factory AdminPermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AdminPermissions();
    return AdminPermissions(
      dashboard: json['dashboard'] as bool? ?? true,
      usersManagement: json['usersManagement'] as bool? ?? true,
      createAccount: json['createAccount'] as bool? ?? true,
      advertisements: json['advertisements'] as bool? ?? true,
      cards: json['cards'] as bool? ?? true,
      settings: json['settings'] as bool? ?? true,
      manageLocations: json['manageLocations'] as bool? ?? true,
      changePassword: json['changePassword'] as bool? ?? true,
      addAdmins: json['addAdmins'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'dashboard': dashboard,
        'usersManagement': usersManagement,
        'createAccount': createAccount,
        'advertisements': advertisements,
        'cards': cards,
        'settings': settings,
        'manageLocations': manageLocations,
        'changePassword': changePassword,
        'addAdmins': addAdmins,
      };

  bool get canAccessDashboard => dashboard;
  bool get canManageUsers => usersManagement;
  bool get canCreateAccount => createAccount;
  bool get canManageAdvertisements => advertisements;
  bool get canManageCards => cards;
  bool get canAccessSettings => settings;
  bool get canManageLocations => manageLocations;
  bool get canChangePassword => changePassword;
  bool get canAddAdmins => addAdmins;
}

class Admin {
  final String id;
  final String code;
  final String name;
  final String? email;
  final String? phone;
  final bool isSuperAdmin;
  final AdminPermissions permissions;

  Admin({
    required this.id,
    required this.code,
    required this.name,
    this.email,
    this.phone,
    this.isSuperAdmin = false,
    AdminPermissions? permissions,
  }) : permissions = permissions ?? const AdminPermissions();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'email': email,
      'phone': phone,
      'isSuperAdmin': isSuperAdmin,
      'permissions': permissions.toJson(),
    };
  }

  factory Admin.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    return Admin(
      id: id,
      code: json['code'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      isSuperAdmin: json['isSuperAdmin'] as bool? ?? false,
      permissions: AdminPermissions.fromJson(
        json['permissions'] as Map<String, dynamic>?,
      ),
    );
  }

  Admin copyWith({
    String? id,
    String? code,
    String? name,
    String? email,
    String? phone,
    bool? isSuperAdmin,
    AdminPermissions? permissions,
  }) {
    return Admin(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      permissions: permissions ?? this.permissions,
    );
  }
}






