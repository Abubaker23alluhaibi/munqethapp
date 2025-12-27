import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('المساعدة والدعم'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHelpItem(
              context,
              icon: Icons.phone,
              title: 'اتصل بنا',
              subtitle: '07700000000',
              onTap: () async {
                final uri = Uri.parse('tel:07700000000');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              context,
              icon: Icons.email,
              title: 'البريد الإلكتروني',
              subtitle: 'support@munqeth.com',
              onTap: () async {
                final uri = Uri.parse('mailto:support@munqeth.com');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              context,
              icon: Icons.info_outline,
              title: 'عن التطبيق',
              subtitle: 'تطبيق المنقذ - الإصدار 1.0.0',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'تطبيق المنقذ',
                  applicationVersion: '1.0.0',
                  applicationIcon: Image.asset(
                    'assets/icons/logo.png',
                    width: 64,
                    height: 64,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}









