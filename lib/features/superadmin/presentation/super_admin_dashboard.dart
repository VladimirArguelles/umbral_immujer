import 'package:flutter/widgets.dart';
import 'package:umbral_immujer/features/coordinator/presentation/coordinator_dashboard_page.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

class SuperAdminDashboardPage extends StatelessWidget {
  const SuperAdminDashboardPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return CoordinatorDashboardPage(profile: profile);
  }
}
