import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../services/biometric_service.dart';
import '../../../services/backup_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/common/app_header_back_button.dart';
import '../../widgets/common/confirm_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppHeaderBackButton(),
          title: const Text(AppStrings.settings),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const _SettingsSection(
              title: 'پروفایل فروشگاه',
              icon: Icons.store_outlined,
              initiallyExpanded: true,
              children: [_ProfileSection()],
            ),
            const _SettingsSection(
              title: 'حساب کاربری',
              icon: Icons.manage_accounts_outlined,
              children: [_AccountCredentialsTile()],
            ),
            if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)
              const _SettingsSection(
                title: 'امنیت',
                icon: Icons.security_outlined,
                children: [_BiometricTile()],
              ),
            const _SettingsSection(
              title: 'پشتیبان‌گیری',
              icon: Icons.backup_outlined,
              children: [_BackupSection()],
            ),
            _SettingsSection(
              title: 'سرور',
              icon: Icons.dns_outlined,
              children: [
                const _SettingsTile(
                  icon: Icons.cloud_sync,
                  iconColor: syncState.isOnline
                      ? AppColors.success
                      : AppColors.warning,
                  title: 'وضعیت سرور',
                  subtitle: syncState.isOnline
                      ? (syncState.lastSyncTime != null
                          ? 'آخرین sync: ${syncState.message ?? "همگام"}'
                          : 'آنلاین')
                      : AppStrings.offline,
                  trailing: TextButton(
                    onPressed: () => ref.read(syncProvider.notifier).sync(),
                    child: const Text('sync',
                        style: TextStyle(fontFamily: 'Vazirmatn')),
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.dns,
                  title: 'آدرس سرور',
                  subtitle: 'تنظیم API endpoint',
                  onTap: () => _showServerUrlDialog(context),
                ),
              ],
            ),
            if (Platform.isWindows)
              const _SettingsSection(
                title: 'دستگاه پوز',
                icon: Icons.credit_card_outlined,
                children: [_PosSettingsTile()],
              ),
            _SettingsSection(
              title: 'سایر',
              icon: Icons.more_horiz,
              children: [
                _SettingsTile(
                  icon: Icons.print,
                  title: AppStrings.printerSettings,
                  subtitle: 'تنظیم بلوتوث / وای‌فای / USB',
                  onTap: () => context.go('/settings/printer'),
                ),
                const Divider(height: 1),
                const _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'درباره اپلیکیشن',
                  subtitle: '${AppStrings.appName} - ${AppStrings.appVersion}',
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.logout,
                  iconColor: AppColors.error,
                  title: 'خروج از حساب',
                  titleColor: AppColors.error,
                  onTap: () async {
                    final confirmed = await ConfirmDialog.show(
                      context,
                      title: 'خروج',
                      message: 'آیا می‌خواهید از حساب خارج شوید؟',
                      confirmText: 'خروج',
                      confirmColor: AppColors.error,
                    );
                    if (confirmed == true && context.mounted) {
                      await ref.read(authProvider.notifier).logout();
                      if (!context.mounted) return;
                      context.go('/login');
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showServerUrlDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final current =
        prefs.getString(ApiConstants.baseUrlKey) ?? ApiConstants.defaultBaseUrl;
    final ctrl = TextEditingController(text: current);

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('آدرس سرور',
              style: TextStyle(
                  fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('آدرس کامل API را وارد کنید:',
                  style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: 'http://192.168.1.1:8000/api',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: AppColors.background,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppStrings.cancel,
                  style: TextStyle(fontFamily: 'Vazirmatn')),
            ),
            ElevatedButton(
              onPressed: () async {
                final url = ctrl.text.trim();
                if (url.isNotEmpty) {
                  await prefs.setString(ApiConstants.baseUrlKey, url);
                  DioClient.reset();
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('آدرس سرور ذخیره شد',
                        style: TextStyle(fontFamily: 'Vazirmatn')),
                    backgroundColor: AppColors.success,
                  ));
                }
              },
              child: const Text(AppStrings.save,
                  style: TextStyle(fontFamily: 'Vazirmatn')),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCredentialsTile extends ConsumerWidget {
  const _AccountCredentialsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _SettingsTile(
        icon: Icons.manage_accounts_outlined,
        title: 'نام کاربری و رمز عبور',
        subtitle: ref.watch(authProvider).username ?? 'کاربر محلی',
        onTap: () => showDialog(
          context: context,
          builder: (_) => const _CredentialsDialog(),
        ),
      );
}

class _CredentialsDialog extends ConsumerStatefulWidget {
  const _CredentialsDialog();
  @override
  ConsumerState<_CredentialsDialog> createState() => _CredentialsDialogState();
}

class _CredentialsDialogState extends ConsumerState<_CredentialsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _username =
        TextEditingController(text: ref.read(authProvider).username ?? '');
  }

  @override
  void dispose() {
    _username.dispose();
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تغییر اطلاعات ورود'),
          content: SizedBox(
              width: 420,
              child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                          controller: _username,
                          decoration: const InputDecoration(
                              labelText: 'نام کاربری',
                              prefixIcon: Icon(Icons.person_outline)),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'نام کاربری الزامی است'
                              : null),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _current,
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: 'رمز عبور فعلی',
                              prefixIcon: Icon(Icons.lock_outline)),
                          validator: (v) => v == null || v.isEmpty
                              ? 'رمز فعلی الزامی است'
                              : null),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _next,
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: 'رمز عبور جدید')),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _repeat,
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: 'تکرار رمز عبور جدید'),
                          validator: (v) =>
                              _next.text.isNotEmpty && v != _next.text
                                  ? 'تکرار رمز عبور یکسان نیست'
                                  : null),
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: AppColors.error,
                                    fontFamily: 'Vazirmatn'))),
                    ],
                  ))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('انصراف')),
            ElevatedButton(
                onPressed: _saving ? null : _save, child: const Text('ذخیره')),
          ],
        ),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).changeCredentials(
            username: _username.text.trim(),
            currentPassword: _current.text,
            newPassword: _next.text.isEmpty ? null : _next.text,
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─── عنوان بخش ───────────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) => ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        maintainState: true,
        leading: Icon(icon, color: AppColors.primary, size: 22),
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textSecondary,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(bottom: 4),
        shape: const Border(
          bottom: BorderSide(color: AppColors.border, width: 0.7),
        ),
        collapsedShape: const Border(
          bottom: BorderSide(color: AppColors.border, width: 0.7),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        children: children,
      );
}

// ─── اثر انگشت ───────────────────────────────────────────────────────────────

class _BiometricTile extends StatefulWidget {
  const _BiometricTile();

  @override
  State<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends State<_BiometricTile> {
  bool _available = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) {
      setState(() {
        _available = available;
        _enabled = enabled;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      // تأیید اثر انگشت قبل از فعال‌سازی
      final ok = await BiometricService.authenticate();
      if (!ok) return;
    }
    await BiometricService.setEnabled(value);
    if (mounted) setState(() => _enabled = value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          value ? 'ورود با اثر انگشت فعال شد' : 'ورود با اثر انگشت غیرفعال شد',
          style: const TextStyle(fontFamily: 'Vazirmatn'),
        ),
        backgroundColor: value ? AppColors.success : AppColors.textSecondary,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const _SettingsTile(
        icon: Icons.fingerprint,
        iconColor: AppColors.textHint,
        title: 'ورود با اثر انگشت',
        subtitle: 'دستگاه شما از این ویژگی پشتیبانی نمی‌کند',
      );
    }
    return _SettingsTile(
      icon: Icons.fingerprint,
      iconColor: _enabled ? AppColors.success : AppColors.primary,
      title: 'ورود با اثر انگشت',
      subtitle: _enabled ? 'فعال — در صفحه ورود نمایش داده می‌شود' : 'غیرفعال',
      trailing: Switch(
        value: _enabled,
        onChanged: _toggle,
        activeThumbColor: AppColors.success,
      ),
    );
  }
}

// ─── بکاپ ─────────────────────────────────────────────────────────────────────

class _BackupSection extends StatefulWidget {
  const _BackupSection();

  @override
  State<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<_BackupSection> {
  bool _autoEnabled = false;
  String _lastBackupLabel = 'در حال بارگذاری...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auto = await BackupService.isAutoEnabled();
    final label = await BackupService.getLastBackupLabel();
    if (mounted) {
      setState(() {
        _autoEnabled = auto;
        _lastBackupLabel = label ?? 'هرگز';
      });
    }
  }

  Future<void> _manualBackup() async {
    setState(() => _isLoading = true);
    final file = await BackupService.createBackup(share: true);
    if (mounted) {
      setState(() => _isLoading = false);
      if (file != null) {
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('بکاپ با موفقیت ایجاد شد',
              style: TextStyle(fontFamily: 'Vazirmatn')),
          backgroundColor: AppColors.success,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('خطا در ایجاد بکاپ',
              style: TextStyle(fontFamily: 'Vazirmatn')),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _toggleAuto(bool value) async {
    await BackupService.setAutoEnabled(value);
    if (mounted) setState(() => _autoEnabled = value);
  }

  Future<void> _restoreBackup() async {
    final selected = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'پشتیبان ShopCRM', extensions: ['zip']),
      ],
    );
    if (selected == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('بازیابی پشتیبان'),
          content: const Text(
            'ابتدا یک بکاپ ایمنی ساخته می‌شود. سپس اطلاعات فایل انتخابی '
            'بازیابی و برنامه به‌صورت خودکار دوباره اجرا خواهد شد. ادامه می‌دهید؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('بازیابی'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isLoading = true);
    final restored = await BackupService.restoreBackup(File(selected.path));
    if (mounted && !restored) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('فایل پشتیبان معتبر نیست یا بازیابی ناموفق بود'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingsTile(
          icon: Icons.backup_outlined,
          title: 'بکاپ دستی',
          subtitle: 'آخرین بکاپ: $_lastBackupLabel',
          trailing: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(
                  onPressed: _manualBackup,
                  child: const Text('بکاپ بگیر',
                      style: TextStyle(fontFamily: 'Vazirmatn')),
                ),
        ),
        const Divider(height: 1),
        _SettingsTile(
          icon: Icons.restore_outlined,
          title: 'بازیابی پشتیبان',
          subtitle: 'بازیابی امن دیتابیس و تصاویر از فایل ZIP',
          trailing: TextButton(
            onPressed: _isLoading ? null : _restoreBackup,
            child: const Text('انتخاب فایل'),
          ),
        ),
        const Divider(height: 1),
        _SettingsTile(
          icon: Icons.schedule,
          iconColor: _autoEnabled ? AppColors.success : AppColors.primary,
          title: 'بکاپ خودکار',
          subtitle:
              _autoEnabled ? 'هر ۳۰ دقیقه یک بکاپ ذخیره می‌شود' : 'غیرفعال',
          trailing: Switch(
            value: _autoEnabled,
            onChanged: _toggleAuto,
            activeThumbColor: AppColors.success,
          ),
        ),
      ],
    );
  }
}

// ─── پروفایل فروشگاه ─────────────────────────────────────────────────────────

class _ProfileSection extends StatefulWidget {
  const _ProfileSection();

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  String _ownerName = '';
  String _storeName = '';
  String _phone = '';

  static const _keyOwner = 'profile_owner_name';
  static const _keyStore = 'profile_store_name';
  static const _keyPhone = 'profile_phone';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _ownerName = prefs.getString(_keyOwner) ?? '';
        _storeName = prefs.getString(_keyStore) ?? '';
        _phone = prefs.getString(_keyPhone) ?? '';
      });
    }
  }

  void _openEdit() {
    final ownerCtrl = TextEditingController(text: _ownerName);
    final storeCtrl = TextEditingController(text: _storeName);
    final phoneCtrl = TextEditingController(text: _phone);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ویرایش پروفایل',
              style: TextStyle(
                  fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: storeCtrl,
                decoration: const InputDecoration(
                  labelText: 'نام فروشگاه',
                  labelStyle: TextStyle(fontFamily: 'Vazirmatn'),
                  prefixIcon: Icon(Icons.store_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ownerCtrl,
                decoration: const InputDecoration(
                  labelText: 'نام صاحب فروشگاه',
                  labelStyle: TextStyle(fontFamily: 'Vazirmatn'),
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'شماره تماس',
                  labelStyle: TextStyle(fontFamily: 'Vazirmatn'),
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppStrings.cancel,
                  style: TextStyle(fontFamily: 'Vazirmatn')),
            ),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(_keyOwner, ownerCtrl.text.trim());
                await prefs.setString(_keyStore, storeCtrl.text.trim());
                await prefs.setString(_keyPhone, phoneCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
              },
              child: const Text(AppStrings.save,
                  style: TextStyle(fontFamily: 'Vazirmatn')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _storeName.isNotEmpty ? _storeName : 'فروشگاه هوشمند';
    final displayOwner = _ownerName.isNotEmpty ? _ownerName : 'تنظیم نشده';

    return InkWell(
      onTap: _openEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                displayName.isNotEmpty ? displayName[0] : 'ف',
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text('مدیر: $displayOwner',
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      )),
                  if (_phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(_phone,
                        style: const TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        )),
                  ],
                ],
              ),
            ),
            const Icon(Icons.edit_outlined,
                color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── تنظیمات پوز (فقط ویندوز) ────────────────────────────────────────────────

class _PosSettingsTile extends StatefulWidget {
  const _PosSettingsTile();

  @override
  State<_PosSettingsTile> createState() => _PosSettingsTileState();
}

class _PosSettingsTileState extends State<_PosSettingsTile> {
  String _posMode = 'manual'; // manual | auto
  String _posPort = 'COM1';
  final _portOptions = [
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        // اتصال واقعی پوز هنوز پیاده‌سازی نشده است؛ مقدار قدیمی auto نیز
        // عمداً به حالت دستی برگردانده می‌شود تا پرداخت جعلی انجام نشود.
        _posMode = 'manual';
        _posPort = prefs.getString('pos_port') ?? 'COM1';
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pos_mode', 'manual');
    await prefs.setString('pos_port', _posPort);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تنظیمات پوز ذخیره شد',
            style: TextStyle(fontFamily: 'Vazirmatn')),
        backgroundColor: AppColors.success,
      ));
    }
  }

  void _showPosDialog() {
    String tempMode = _posMode;
    String tempPort = _posPort;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: const Text('تنظیمات دستگاه پوز',
                style: TextStyle(
                    fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('حالت اتصال پوز:',
                    style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 13,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(
                      width: 48,
                      child: Icon(
                        Icons.radio_button_checked,
                        color: AppColors.primary,
                      ),
                    ),
                    const Text('دستی (شماره پیگیری)',
                        style:
                            TextStyle(fontFamily: 'Vazirmatn', fontSize: 13)),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(
                      width: 48,
                      child: Icon(
                        Icons.radio_button_unchecked,
                        color: AppColors.textHint,
                      ),
                    ),
                    const Expanded(
                      child: Text('اتوماتیک (غیرفعال تا اتصال واقعی)',
                        style:
                            TextStyle(fontFamily: 'Vazirmatn', fontSize: 13)),
                    ),
                  ],
                ),
                if (tempMode == 'auto') ...[
                  const SizedBox(height: 12),
                  const Text('پورت سریال پوز:',
                      style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 13,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: tempPort,
                    items: _portOptions
                        .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p,
                                style:
                                    const TextStyle(fontFamily: 'Vazirmatn'))))
                        .toList(),
                    onChanged: (v) => setSt(() => tempPort = v!),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'مطمئن شوید دستگاه پوز به پورت مربوطه متصل است.',
                    style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 11,
                        color: AppColors.textHint),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(AppStrings.cancel,
                    style: TextStyle(fontFamily: 'Vazirmatn')),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _posMode = tempMode;
                    _posPort = tempPort;
                  });
                  _save();
                  Navigator.pop(ctx);
                },
                child: const Text(AppStrings.save,
                    style: TextStyle(fontFamily: 'Vazirmatn')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const modeLabel = 'دستی — حالت اتوماتیک فعلاً غیرفعال است';
    return _SettingsTile(
      icon: Icons.credit_card,
      iconColor: const Color(0xFF00695C),
      title: 'دستگاه پوز',
      subtitle: 'حالت: $modeLabel',
      onTap: _showPosDialog,
    );
  }
}

// ─── ردیف تنظیمات ────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
      ),
      title: Text(title,
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: titleColor ?? AppColors.textPrimary,
          )),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12,
                color: AppColors.textSecondary,
              ))
          : null,
      trailing:
          trailing ?? (onTap != null ? const Icon(Icons.chevron_left) : null),
      onTap: onTap,
    );
  }
}
