import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/network/dio_client.dart';
import '../../data/remote/sync_service.dart';
import '../../services/notification_service.dart';
import 'product_provider.dart';

/// وضعیت فرآیند همگام‌سازی
enum SyncStatus { idle, syncing, success, failed, offline }

/// اطلاعات وضعیت sync در هر لحظه
class SyncState {
  final SyncStatus status;
  final String? message;        // پیام قابل نمایش به کاربر
  final DateTime? lastSyncTime; // آخرین بار موفقیت‌آمیز

  const SyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.lastSyncTime,
  });

  bool get isOnline => status != SyncStatus.offline;

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    DateTime? lastSyncTime,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

/// مدیریت همگام‌سازی آفلاین/آنلاین
/// وقتی اینترنت برمی‌گردد → sync خودکار انجام می‌شود
class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  SyncNotifier(this._ref) : super(const SyncState()) {
    _listenConnectivity();
  }

  /// گوش دادن به تغییرات اتصال شبکه
  void _listenConnectivity() {
    Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);

      if (hasConnection && state.status == SyncStatus.offline) {
        // اینترنت برگشت → sync خودکار
        state = state.copyWith(status: SyncStatus.idle);
        sync();
      } else if (!hasConnection) {
        state = state.copyWith(
          status: SyncStatus.offline,
          message: 'اتصال اینترنت قطع است',
        );
      }
    });
  }

  /// شروع فرآیند همگام‌سازی با سرور
  Future<void> sync() async {
    if (state.status == SyncStatus.syncing) return; // از اجرای موازی جلوگیری
    state = state.copyWith(
      status: SyncStatus.syncing,
      message: 'در حال همگام‌سازی...',
    );
    try {
      final db = _ref.read(databaseProvider);
      final dio = await DioClient.getInstance();
      final syncService = SyncService(db: db, dio: dio);
      final result = await syncService.syncAll(since: state.lastSyncTime);
      final msg = result.isSuccess
          ? 'همگام‌سازی موفق (${result.pushed} ارسال، ${result.pulled} دریافت)'
          : 'همگام‌سازی با ${result.errors.length} خطا';
      state = state.copyWith(
        status: result.isSuccess ? SyncStatus.success : SyncStatus.failed,
        message: msg,
        lastSyncTime: result.isSuccess ? DateTime.now() : state.lastSyncTime,
      );
      if (result.isSuccess) NotificationService.showSyncSuccess();
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.failed,
        message: 'همگام‌سازی ناموفق: $e',
      );
    }
  }

  /// بررسی وضعیت اتصال در لحظه
  Future<bool> checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}

/// Provider وضعیت sync
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref);
});

/// استریم وضعیت اتصال (true = آنلاین)
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});
