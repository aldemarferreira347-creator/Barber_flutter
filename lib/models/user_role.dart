enum UserRole { admin, owner, barber, client }

extension UserRoleX on UserRole {
  String get value => name;

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.client,
    );
  }
}
