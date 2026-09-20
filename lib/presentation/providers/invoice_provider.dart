import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/invoice.dart';
import 'cart_provider.dart';

final invoicesStreamProvider = StreamProvider<List<Invoice>>((ref) {
  return ref.watch(invoiceRepositoryProvider).watchInvoices();
});

class InvoicePage {
  final List<Invoice> invoices;
  final bool hasNext;

  const InvoicePage(this.invoices, this.hasNext);
}

final invoicePageProvider =
    StreamProvider.family<InvoicePage, int>((ref, page) {
  const pageSize = 50;
  return ref
      .watch(invoiceRepositoryProvider)
      .watchInvoices(limit: pageSize + 1, offset: page * pageSize)
      .map((rows) => InvoicePage(
            rows.take(pageSize).toList(),
            rows.length > pageSize,
          ));
});

final recentInvoicesProvider = StreamProvider<List<Invoice>>((ref) {
  return ref.watch(invoiceRepositoryProvider).watchRecentInvoices();
});

final invoiceByIdProvider = FutureProvider.family<Invoice?, int>((ref, id) {
  return ref.watch(invoiceRepositoryProvider).findById(id);
});

final todaySalesTotalProvider = FutureProvider<double>((ref) {
  return ref.watch(invoiceRepositoryProvider).getTodaySalesTotal();
});
