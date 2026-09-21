// Provider های مربوط به مشتریان
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/invoice.dart';
import 'cart_provider.dart';

/// جستجو در لیست مشتریان
final customerSearchQueryProvider = StateProvider<String>((ref) => '');

/// استریم همه مشتریان با پشتیبانی جستجو
final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  final query = ref.watch(customerSearchQueryProvider);
  return ref
      .watch(customerRepositoryProvider)
      .watchCustomers(search: query.isEmpty ? null : query);
});

/// مشتری با شناسه مشخص
final customerByIdProvider = FutureProvider.family<Customer?, int>((ref, id) {
  return ref.watch(customerRepositoryProvider).findById(id);
});

/// فاکتورهای یک مشتری خاص
final customerInvoicesProvider = FutureProvider.family<List<Invoice>, int>(
  (ref, customerId) {
    return ref.watch(invoiceRepositoryProvider).getCustomerInvoices(customerId);
  },
);

/// جمع بدهی همه مشتریان
final totalDebtAmountProvider = FutureProvider<double>((ref) {
  return ref.watch(customerRepositoryProvider).getTotalDebt();
});

/// StateNotifier برای ذخیره و ویرایش مشتری
class CustomerFormNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  CustomerFormNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> save(Customer customer) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(customerRepositoryProvider).saveCustomer(customer);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final customerFormProvider =
    StateNotifierProvider.autoDispose<CustomerFormNotifier, AsyncValue<void>>(
  (ref) => CustomerFormNotifier(ref),
);
