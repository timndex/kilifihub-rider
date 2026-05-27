import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';

/// Profile Screen - rider info, settings, and logout
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout? You will stop receiving orders and '
          'location tracking will be disabled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConfig.ERROR_COLOR),
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoggingOut = true);

    // Stop location tracking
    await LocationService.instance.stopTracking();

    // Logout from auth service
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.logout();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConfig.BACKGROUND_COLOR),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(AppConfig.TEXT_PRIMARY),
        elevation: 0.5,
      ),
      body: Consumer<AuthService>(
        builder: (context, auth, _) {
          final rider = auth.rider;
          if (rider == null) {
            return const Center(child: Text('No profile data'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Card
                _buildProfileCard(rider),

                const SizedBox(height: 20),

                // Stats
                _buildStatsRow(rider),

                const SizedBox(height: 20),

                // Menu Items
                _buildMenuSection([
                  _MenuItem(
                    icon: Icons.person_outline,
                    title: 'Personal Information',
                    subtitle: 'Name, phone, email',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.motorcycle_outlined,
                    title: 'Vehicle Details',
                    subtitle: '${rider.vehicleType} · ${rider.vehiclePlate}',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.star_outline,
                    title: 'Ratings & Reviews',
                    subtitle: '${rider.rating.toStringAsFixed(1)} average rating',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notification Settings',
                    subtitle: 'Manage alerts and sounds',
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 12),

                _buildMenuSection([
                  _MenuItem(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    subtitle: 'Contact support, FAQ',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.info_outline,
                    title: 'About KilifiHub Rider',
                    subtitle: 'Version ${AppConfig.APP_VERSION}',
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 24),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isLoggingOut ? null : _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(AppConfig.ERROR_COLOR),
                      side: const BorderSide(color: Color(AppConfig.ERROR_COLOR)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoggingOut
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(AppConfig.ERROR_COLOR),
                            ),
                          )
                        : const Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(dynamic rider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(AppConfig.PRIMARY_COLOR).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person,
              size: 32,
              color: Color(AppConfig.PRIMARY_COLOR),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rider.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(AppConfig.TEXT_PRIMARY),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rider.phone.isNotEmpty ? '+254 ${rider.phone}' : 'Rider',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(AppConfig.TEXT_SECONDARY),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: rider.registrationStatus == 'approved'
                        ? const Color(AppConfig.SUCCESS_COLOR).withOpacity(0.1)
                        : const Color(AppConfig.ACCENT_COLOR).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    rider.registrationStatus == 'approved'
                        ? 'Verified Rider'
                        : 'Pending Verification',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: rider.registrationStatus == 'approved'
                          ? const Color(AppConfig.SUCCESS_COLOR)
                          : const Color(AppConfig.ACCENT_COLOR),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(dynamic rider) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.delivery_dining,
            value: '${rider.totalDeliveries}',
            label: 'Deliveries',
            color: const Color(AppConfig.PRIMARY_COLOR),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.star,
            value: rider.rating.toStringAsFixed(1),
            label: 'Rating',
            color: const Color(AppConfig.ACCENT_COLOR),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: items
            .asMap()
            .entries
            .map((entry) => Column(
                  children: [
                    _buildMenuItem(entry.value),
                    if (entry.key < items.length - 1)
                      const Padding(
                        padding: EdgeInsets.only(left: 56),
                        child: Divider(height: 1, color: Color(AppConfig.DIVIDER_COLOR)),
                      ),
                  ],
                ))
            .toList(),
      ),
    );
  }

  Widget _buildMenuItem(_MenuItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(AppConfig.BACKGROUND_COLOR),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 18, color: const Color(AppConfig.TEXT_SECONDARY)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(AppConfig.TEXT_PRIMARY),
                    ),
                  ),
                  if (item.subtitle.isNotEmpty)
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(AppConfig.TEXT_HINT),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(AppConfig.TEXT_HINT),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle = '',
    required this.onTap,
  });
}
