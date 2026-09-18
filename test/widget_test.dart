import 'package:flutter_test/flutter_test.dart';

import 'package:barber/models/user_role.dart';

void main() {
  test('UserRoleX.fromValue parses known roles', () {
    expect(UserRoleX.fromValue('admin'), UserRole.admin);
    expect(UserRoleX.fromValue('owner'), UserRole.owner);
    expect(UserRoleX.fromValue('barber'), UserRole.barber);
    expect(UserRoleX.fromValue('client'), UserRole.client);
  });

  test('UserRoleX.fromValue falls back to client for unknown values', () {
    expect(UserRoleX.fromValue('unknown'), UserRole.client);
  });
}
