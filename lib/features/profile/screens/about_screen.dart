import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _copyToClipboard(BuildContext context, String text, String label) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $label to clipboard! 📋'),
        backgroundColor: AppColors.primaryLight,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $urlString');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'About Bunk Guru',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          children: [
            // APP HERO CARD
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF242729) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.indigo.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.indigo.withValues(alpha: 0.05),
                ),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // App Logo box
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF9333EA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.school,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF9333EA)],
                    ).createShader(bounds),
                    child: Text(
                      'Bunk Guru',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your attendance, simplified',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.indigo.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified,
                          size: 14,
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'v1.0.7',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.primaryDark
                                : AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // MISSION STATEMENT CARD
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF242729) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.indigo.withValues(alpha: 0.05),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lightbulb,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Why This App Exists',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Every student knows the struggle —',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '"Kitne classes bunk kar sakte hain?"\n"75% ke neeche toh nahi jaunga na?"',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFC3C0FF)
                                : const Color(0xFF4F46E5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'I faced the same problem again and again. Sometimes I\'d think I\'m safe… and then suddenly — boom 💥 — attendance dropped below 75%. That\'s when I thought, why not build a gorgeous native tool that does all this instantly?',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // FEATURES GRID LIST
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF242729) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.indigo.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 20, top: 16, bottom: 8),
                    child: Text(
                      'PREMIUM FEATURES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  _buildFeatureItem(
                    icon: Icons.analytics,
                    title: 'Smart Attendance Tracking',
                    desc: 'Real-time percentage calculations with 75% alerts',
                    iconBg: Colors.blue.withValues(alpha: 0.1),
                    iconColor: Colors.blue,
                  ),
                  const Divider(height: 1),
                  _buildFeatureItem(
                    icon: Icons.calendar_month,
                    title: 'Weekly Schedule Planner',
                    desc: 'Organize your entire week with slot management',
                    iconBg: Colors.purple.withValues(alpha: 0.1),
                    iconColor: Colors.purple,
                  ),
                  const Divider(height: 1),
                  _buildFeatureItem(
                    icon: Icons.notifications_active,
                    title: 'Interactive Attendance Prompts',
                    desc: 'Quick prompts scheduled right after your lectures',
                    iconBg: Colors.deepOrange.withValues(alpha: 0.1),
                    iconColor: Colors.deepOrange,
                  ),
                  const Divider(height: 1),
                  _buildFeatureItem(
                    icon: Icons.cloud_sync,
                    title: 'Secure Cloud Sync',
                    desc: 'Sync stats instantly to online Supabase databases',
                    iconBg: Colors.green.withValues(alpha: 0.1),
                    iconColor: Colors.green,
                  ),
                  const Divider(height: 1),
                  _buildFeatureItem(
                    icon: Icons.calculate,
                    title: 'Bunk Calculator',
                    desc: 'Plan your bunks with precision and maintain 75%',
                    iconBg: Colors.teal.withValues(alpha: 0.1),
                    iconColor: Colors.teal,
                  ),
                  const Divider(height: 1),
                  _buildFeatureItem(
                    icon: Icons.share,
                    title: 'Import & Share Schedule',
                    desc: 'Easily import schedules or share yours with friends',
                    iconBg: Colors.pink.withValues(alpha: 0.1),
                    iconColor: Colors.pink,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // MEET THE TEAM
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'THE BUNK GURU TEAM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // MD ALFAAZ CARD
            _buildDevCard(
              context: context,
              imagePath: 'assets/devs/alfaaz.png',
              name: 'Md Alfaaz',
              role: 'Lead Developer',
              details: 'Galgotias University · 1st Year',
              description:
                  'Hey! 👋 Just a developer trying to solve the age-old student dilemma: "Can I skip this lecture?" Bunk Guru is my solution to help you stay on track without losing your freedom.',
              instagram: 'https://instagram.com/mdalfaaz',
              github: 'https://github.com/imscaryclown',
              linkedin: 'https://www.linkedin.com/in/md-alfaaz-4b13b314b',
            ),

            const SizedBox(height: 16),

            // UTKARSH SINGH CARD
            _buildDevCard(
              context: context,
              imagePath: 'assets/devs/utkarsh.png',
              name: 'Utkarsh Singh',
              role: 'Collaborator & Designer',
              details: 'Galgotias University · 1st Year',
              description:
                  'Co-developer and problem solver. Working alongside Alfaaz to make attendance management stress-free for students everywhere.',
              instagram: 'https://instagram.com/utkarshsingh.47',
              linkedin: 'https://www.linkedin.com/in/utkarsh-singh-2b0279387',
            ),

            const SizedBox(height: 16),

            // AMIT YADAV CARD
            _buildDevCard(
              context: context,
              imagePath: 'assets/devs/amit.png',
              name: 'Amit Yadav',
              role: 'Quality Assurance / Tester',
              details: 'Galgotias University · 1st Year',
              description:
                  'Dedicated tester ensuring every feature works perfectly. Amit helps identify and squash bugs before they reach you.',
            ),

            const SizedBox(height: 32),

            // FOOTER SECTION
            Text(
              'Bunk Guru v1.0.0',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white30 : Colors.black38,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Made with ',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const Icon(Icons.favorite, color: Colors.red, size: 12),
                const Text(
                  ' for students everywhere',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String desc,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevCard({
    required BuildContext context,
    required String imagePath,
    required String name,
    required String role,
    required String details,
    required String description,
    String? instagram,
    String? github,
    String? linkedin,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242729) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.indigo.withValues(alpha: 0.05),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: AssetImage(imagePath),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      details,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.4,
            ),
          ),
          if (instagram != null || github != null || linkedin != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (instagram != null)
                  _buildSocialButton(
                    context: context,
                    icon: Icons.camera_alt,
                    label: 'Instagram',
                    color: Colors.pink,
                    onTap: () => _launchUrl(context, instagram),
                  ),
                if (github != null) ...[
                  const SizedBox(width: 8),
                  _buildSocialButton(
                    context: context,
                    icon: Icons.code,
                    label: 'GitHub',
                    color: isDark ? Colors.white : Colors.black,
                    onTap: () => _launchUrl(context, github),
                  ),
                ],
                if (linkedin != null) ...[
                  const SizedBox(width: 8),
                  _buildSocialButton(
                    context: context,
                    icon: Icons.link,
                    label: 'LinkedIn',
                    color: Colors.blue,
                    onTap: () => _launchUrl(context, linkedin),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
