import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/google_logo.dart';
import '../../../services/providers.dart';
import '../../../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String _view = 'main'; // 'main', 'email'
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _switchView(String view) {
    setState(() {
      _view = view;
      _errorMessage = null;
    });
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authProvider.notifier)
          .signIn(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
      // Success triggers AuthNotifier listener, which auto-redirects to home
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.client.auth.signInWithOAuth(
        sb.OAuthProvider.google,
        redirectTo: 'com.mdalfaaz.bunkmitra://login',
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Google authentication failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Hero Brand Badge with Ambient Glow (Apple / Arc style)
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E2433).withValues(alpha: 0.85)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : const Color(0xFF4F46E5).withValues(alpha: 0.15),
                      width: 1.2,
                    ),
                    boxShadow: [
                      // Ambient purple/magenta multi-layer glow
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(
                          alpha: isDark ? 0.35 : 0.2,
                        ),
                        blurRadius: 36,
                        spreadRadius: 2,
                        offset: const Offset(-4, 8),
                      ),
                      BoxShadow(
                        color: const Color(0xFFB4136D).withValues(
                          alpha: isDark ? 0.25 : 0.15,
                        ),
                        blurRadius: 32,
                        spreadRadius: 1,
                        offset: const Offset(6, -4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFFB4136D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
                .animate()
                .fade(duration: 400.ms)
                .scale(
                  begin: const Offset(0.88, 0.88),
                  curve: Curves.easeOutBack,
                ),
                const SizedBox(height: 24),

                // 2. Headings
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFFB4136D)],
                  ).createShader(bounds),
                  child: Text(
                    'Bunk Mitra',
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ).animate().fade(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: 4),
                Text(
                  'Your attendance, simplified',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMutedLight,
                  ),
                ).animate().fade(delay: 200.ms, duration: 400.ms),
                const SizedBox(height: 32),

                // 3. Auth Form View Toggle
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 0.05),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: _view == 'email'
                      ? _buildEmailForm()
                      : _buildMainButtons(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainButtons() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      key: const ValueKey('main_view'),
      children: [
        // 1. Sleek Frosted Dark Glass Google Sign-In Card
        CustomButton(
          color: isDark
              ? const Color(0xFF1E2433).withValues(alpha: 0.85)
              : Colors.white,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : AppColors.outlineVariantLight.withValues(alpha: 0.4),
            width: 1,
          ),
          borderRadius: 14.0,
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
          onTap: _isLoading ? null : _handleGoogleLogin,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GoogleLogo(size: 20),
              const SizedBox(width: 12),
              Text(
                'Continue with Google',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 2. OR Divider
        Row(
          children: [
            Expanded(
              child: Divider(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.12),
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Text(
                'OR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMutedLight,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.12),
                thickness: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // 3. Sleek Frosted Dark Glass Continue with Email Button
        CustomButton(
          color: isDark
              ? const Color(0xFF1E2433).withValues(alpha: 0.85)
              : Colors.white,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : AppColors.outlineVariantLight.withValues(alpha: 0.4),
            width: 1,
          ),
          borderRadius: 14.0,
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
          onTap: () => _switchView('email'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mail_outline_rounded,
                size: 20,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
              const SizedBox(width: 12),
              Text(
                'Continue with Email',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Signup Redirect Link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account?",
              style: TextStyle(
                color: isDark
                    ? AppColors.textMutedDark
                    : AppColors.textMutedLight,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => context.push('/signup'),
              child: const Text(
                'Sign up',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmailForm() {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('email_view'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextField(
            controller: _emailController,
            hintText: 'Email address',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email, size: 20),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Email is required';
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(val.trim())) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _passwordController,
            hintText: 'Password',
            isPassword: true,
            prefixIcon: const Icon(Icons.lock, size: 20),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Password is required';
              if (val.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.redBg, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],

          CustomButton(
            color: const Color(0xFF4F46E5),
            borderRadius: 14.0,
            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
            onTap: _isLoading ? null : _handleEmailLogin,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'LOG IN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      fontSize: 13,
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _switchView('main'),
                child: Text(
                  '← Back',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/forgot-password'),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
