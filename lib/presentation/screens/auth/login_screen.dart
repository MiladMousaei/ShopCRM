import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../services/biometric_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _rememberMe = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
    _checkBiometric();
  }

  Future<void> _loadRememberedCredentials() async {
    final credentials =
        await ref.read(authProvider.notifier).loadRememberedCredentials();
    if (!mounted || credentials == null) return;
    setState(() {
      _usernameController.text = credentials.username;
      _passwordController.text = credentials.password;
      _rememberMe = true;
    });
  }

  void _setRememberMe(bool value) {
    setState(() => _rememberMe = value);
    if (!value) {
      ref.read(authProvider.notifier).clearRememberedCredentials();
    }
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
      // اگر اثر انگشت فعال است، به‌صورت خودکار پنجره بیومتریک را نمایش بده
      if (available && enabled) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) _loginWithBiometric();
      }
    }
  }

  Future<void> _loginWithBiometric() async {
    final ok = await BiometricService.authenticate();
    if (ok && mounted) {
      // اثر انگشت تأیید شد — ورود مستقیم
      final authNotifier = ref.read(authProvider.notifier);
      final success = await authNotifier.loginWithBiometric();
      if (success && mounted) context.go('/dashboard');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authProvider.notifier).login(
          _usernameController.text.trim(),
          _passwordController.text,
          remember: _rememberMe,
        );
    if (success && mounted) context.go('/dashboard');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: LoadingOverlay(
          isLoading: authState.isLoading,
          message: 'در حال ورود...',
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // لوگو
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.store_rounded,
                          size: 52, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'سیستم مدیریت فروشگاه',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // فرم ورود
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                AppStrings.login,
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),

                              // نام کاربری
                              TextFormField(
                                controller: _usernameController,
                                textDirection: TextDirection.ltr,
                                decoration: const InputDecoration(
                                  labelText: AppStrings.username,
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: Validators.username,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 16),

                              // رمز عبور
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_passwordVisible,
                                textDirection: TextDirection.ltr,
                                decoration: InputDecoration(
                                  labelText: AppStrings.password,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_passwordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                    onPressed: () => setState(() =>
                                        _passwordVisible = !_passwordVisible),
                                  ),
                                ),
                                validator: Validators.password,
                                onFieldSubmitted: (_) => _login(),
                              ),
                              const SizedBox(height: 8),

                              // به خاطر بسپار
                              Row(
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    onChanged: (v) =>
                                        _setRememberMe(v ?? false),
                                    activeColor: AppColors.primary,
                                  ),
                                  const Text(AppStrings.rememberMe,
                                      style: TextStyle(
                                        fontFamily: 'Vazirmatn',
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      )),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // پیام خطا
                              if (authState.error != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorLight,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.error
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: AppColors.error, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(authState.error!,
                                            style: const TextStyle(
                                              fontFamily: 'Vazirmatn',
                                              fontSize: 13,
                                              color: AppColors.error,
                                            )),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 16),

                              // دکمه ورود
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed:
                                      authState.isLoading ? null : _login,
                                  child: const Text(AppStrings.loginButton),
                                ),
                              ),

                              // دکمه ورود با اثر انگشت
                              if (_biometricAvailable && _biometricEnabled) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _loginWithBiometric,
                                  icon: const Icon(Icons.fingerprint, size: 22),
                                  label: const Text('ورود با اثر انگشت',
                                      style: TextStyle(
                                          fontFamily: 'Vazirmatn',
                                          fontSize: 14)),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    side: const BorderSide(
                                        color: AppColors.primary),
                                    foregroundColor: AppColors.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(AppStrings.appVersion,
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 12,
                          color: AppColors.textHint,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
