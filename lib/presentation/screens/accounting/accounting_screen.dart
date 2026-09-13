import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_converter.dart';
import '../../../domain/models/customer.dart';
import '../../../domain/models/ledger_entry.dart';
import '../../../services/excel_service.dart';
import '../../../services/pdf_service.dart';
import '../../providers/cart_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../widgets/common/app_header_back_button.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../customers/customers_screen.dart';

class AccountingScreen extends ConsumerStatefulWidget {
  final int? customerId;
  const AccountingScreen({super.key, this.customerId});
  @override
  ConsumerState<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends ConsumerState<AccountingScreen> {
  final _search = TextEditingController();
  List<Customer> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    if (widget.customerId != null) {
      Future.microtask(
          () => _setFilter(LedgerFilter(customerId: widget.customerId)));
    }
  }

  Future<void> _loadCustomers() async {
    final customers = await ref.read(customerRepositoryProvider).getCustomers();
    if (mounted) setState(() => _customers = customers);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(ledgerEntriesProvider);
    final filter = ref.watch(ledgerFilterProvider);
    final loadedEntries = entries.value ?? const <LedgerEntry>[];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppHeaderBackButton(),
          title: const Text('حسابداری'),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'جست‌وجوی نام یا شماره تلفن مشتری...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => _setFilter(LedgerFilter(
                  query: value,
                  customerId: filter.customerId,
                  from: filter.from,
                  to: filter.to,
                  direction: filter.direction,
                  hasInvoice: filter.hasInvoice,
                  ascending: filter.ascending,
                  sortByAmount: filter.sortByAmount,
                )),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _filterChip(
                        'همه',
                        filter.direction == null && filter.hasInvoice == null,
                        () => _replace(filter,
                            clearDirection: true, clearInvoice: true)),
                    _filterChip(
                        'بدهکار',
                        filter.direction == LedgerDirection.debit,
                        () =>
                            _replace(filter, direction: LedgerDirection.debit)),
                    _filterChip(
                        'بستانکار',
                        filter.direction == LedgerDirection.credit,
                        () => _replace(filter,
                            direction: LedgerDirection.credit)),
                    _filterChip('دارای فاکتور', filter.hasInvoice == true,
                        () => _replace(filter, hasInvoice: true)),
                    _filterChip('بدون فاکتور', filter.hasInvoice == false,
                        () => _replace(filter, hasInvoice: false)),
                    PopupMenuButton<int>(
                      tooltip: 'فیلتر مشتری',
                      onSelected: (id) => _replace(filter,
                          customerId: id == -1 ? null : id,
                          clearCustomer: id == -1),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: -1, child: Text('همه مشتریان')),
                        ..._customers.map((customer) => PopupMenuItem(
                            value: customer.id, child: Text(customer.name))),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(children: [
                          const Icon(Icons.person_search_outlined),
                          const SizedBox(width: 4),
                          Text(_customerFilterLabel(filter.customerId)),
                        ]),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickRange(filter),
                      icon: const Icon(Icons.date_range_outlined, size: 18),
                      label: Text(filter.from == null
                          ? 'بازه تاریخ'
                          : '${DateConverter.toShamsi(filter.from!)} تا ${DateConverter.toShamsi(filter.to!)}'),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) => _setFilter(LedgerFilter(
                        query: filter.query,
                        customerId: filter.customerId,
                        from: filter.from,
                        to: filter.to,
                        direction: filter.direction,
                        hasInvoice: filter.hasInvoice,
                        sortByAmount: value.startsWith('amount'),
                        ascending: value.endsWith('asc'),
                      )),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'date_desc',
                            child: Text('تاریخ - جدیدترین')),
                        PopupMenuItem(
                            value: 'date_asc',
                            child: Text('تاریخ - قدیمی‌ترین')),
                        PopupMenuItem(
                            value: 'amount_desc',
                            child: Text('مبلغ - بیشترین')),
                        PopupMenuItem(
                            value: 'amount_asc', child: Text('مبلغ - کمترین')),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(children: [
                          Icon(Icons.sort),
                          SizedBox(width: 4),
                          Text('مرتب‌سازی')
                        ]),
                      ),
                    ),
                    if (filter.from != null ||
                        filter.direction != null ||
                        filter.hasInvoice != null ||
                        filter.customerId != null)
                      TextButton(
                          onPressed: () {
                            _search.clear();
                            _setFilter(const LedgerFilter());
                          },
                          child: const Text('پاک‌کردن فیلترها')),
                    OutlinedButton.icon(
                      onPressed: loadedEntries.isEmpty
                          ? null
                          : () => _exportExcel(loadedEntries),
                      icon: const Icon(Icons.table_view_outlined, size: 18),
                      label: const Text('Excel'),
                    ),
                    OutlinedButton.icon(
                      onPressed: loadedEntries.isEmpty
                          ? null
                          : () => _exportPdf(loadedEntries),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('PDF'),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
              child: entries.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('خطا در بارگذاری دفتر حساب: $error')),
            data: (items) => items.isEmpty
                ? const Center(child: Text('سندی ثبت نشده است'))
                : LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 760
                            ? _entriesCards(items)
                            : _entriesTable(items),
                  ),
          )),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEntryDialog(),
          icon: const Icon(Icons.add),
          label: const Text('ثبت سند'),
        ),
      ),
    );
  }

  Widget _entriesTable(List<LedgerEntry> entries) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('مشتری')),
              DataColumn(label: Text('تاریخ')),
              DataColumn(label: Text('نوع عملیات')),
              DataColumn(label: Text('بدهکار')),
              DataColumn(label: Text('بستانکار')),
              DataColumn(label: Text('مانده')),
              DataColumn(label: Text('شماره فاکتور')),
              DataColumn(label: Text('عملیات')),
            ],
            rows: entries
                .map((entry) => DataRow(
                      color: entry.isActive
                          ? null
                          : WidgetStatePropertyAll(
                              Colors.grey.withValues(alpha: .08)),
                      cells: [
                        DataCell(Text(entry.customerName),
                            onTap: () =>
                                context.go('/customers/${entry.customerId}')),
                        DataCell(
                            Text(DateConverter.toShamsi(entry.operationDate))),
                        DataCell(Text(entry.isActive
                            ? entry.type.label
                            : '${entry.type.label} (باطل)')),
                        DataCell(Text(entry.direction == LedgerDirection.debit
                            ? CurrencyFormatter.format(entry.amount.toDouble())
                            : '-')),
                        DataCell(Text(entry.direction == LedgerDirection.credit
                            ? CurrencyFormatter.format(entry.amount.toDouble())
                            : '-')),
                        DataCell(Text(CurrencyFormatter.format(
                            entry.balanceAfter.toDouble()))),
                        DataCell(Text(entry.invoiceNumber ?? '-'),
                            onTap: entry.invoiceId == null
                                ? null
                                : () =>
                                    context.go('/invoices/${entry.invoiceId}')),
                        DataCell(Wrap(spacing: 2, children: [
                          _actionButton(
                              icon: const Icon(Icons.visibility_outlined),
                              tooltip: 'جزئیات',
                              onPressed: () => _showDetails(entry)),
                          _actionButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: entry.invoiceId == null
                                  ? 'ویرایش'
                                  : 'مشاهده فاکتور مرتبط',
                              onPressed: !entry.isActive
                                  ? null
                                  : entry.invoiceId == null
                                      ? () => _openEntryDialog(entry: entry)
                                      : () => context
                                          .go('/invoices/${entry.invoiceId}')),
                          if (entry.isActive)
                            _actionButton(
                                icon: Icon(entry.invoiceId == null
                                    ? Icons.delete_outline
                                    : Icons.cancel_outlined),
                                tooltip:
                                    entry.invoiceId == null ? 'حذف' : 'ابطال',
                                onPressed: () => _remove(entry)),
                        ])),
                      ],
                    ))
                .toList(),
          ),
        ),
      );

  Widget _actionButton({
    required Widget icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) =>
      IconButton(
        icon: icon,
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: const EdgeInsets.all(6),
      );

  Widget _entriesCards(List<LedgerEntry> entries) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(entry.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Text(DateConverter.toShamsi(entry.operationDate)),
                  ]),
                  const SizedBox(height: 8),
                  Text('${entry.type.label}${entry.isActive ? '' : ' (باطل)'}'),
                  const SizedBox(height: 4),
                  Text(
                    'بدهکار: ${entry.direction == LedgerDirection.debit ? CurrencyFormatter.format(entry.amount.toDouble()) : '-'}',
                  ),
                  Text(
                    'بستانکار: ${entry.direction == LedgerDirection.credit ? CurrencyFormatter.format(entry.amount.toDouble()) : '-'}',
                  ),
                  Text(
                    'مانده: ${CurrencyFormatter.format(entry.balanceAfter.toDouble())}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (entry.invoiceNumber != null)
                    Text('شماره فاکتور: ${entry.invoiceNumber}'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(spacing: 4, children: [
                      _actionButton(
                        icon: const Icon(Icons.visibility_outlined),
                        tooltip: 'جزئیات',
                        onPressed: () => _showDetails(entry),
                      ),
                      _actionButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: entry.invoiceId == null
                            ? 'ویرایش'
                            : 'مشاهده فاکتور مرتبط',
                        onPressed: !entry.isActive
                            ? null
                            : entry.invoiceId == null
                                ? () => _openEntryDialog(entry: entry)
                                : () =>
                                    context.go('/invoices/${entry.invoiceId}'),
                      ),
                      if (entry.isActive)
                        _actionButton(
                          icon: Icon(entry.invoiceId == null
                              ? Icons.delete_outline
                              : Icons.cancel_outlined),
                          tooltip: entry.invoiceId == null ? 'حذف' : 'ابطال',
                          onPressed: () => _remove(entry),
                        ),
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Widget _filterChip(String label, bool selected, VoidCallback onTap) =>
      FilterChip(
        label: Text(label),
        selected: selected,
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        selectedColor: AppColors.primary.withValues(alpha: .14),
        checkmarkColor: AppColors.primary,
        side:
            BorderSide(color: selected ? AppColors.primary : AppColors.border),
        onSelected: (_) => onTap(),
      );

  void _setFilter(LedgerFilter value) =>
      ref.read(ledgerFilterProvider.notifier).state = value;

  LedgerFilter _replace(LedgerFilter old,
      {LedgerDirection? direction,
      bool clearDirection = false,
      bool? hasInvoice,
      bool clearInvoice = false,
      int? customerId,
      bool clearCustomer = false}) {
    final updated = LedgerFilter(
        query: old.query,
        customerId: clearCustomer ? null : customerId ?? old.customerId,
        from: old.from,
        to: old.to,
        direction: clearDirection ? null : direction ?? old.direction,
        hasInvoice: clearInvoice ? null : hasInvoice ?? old.hasInvoice,
        ascending: old.ascending,
        sortByAmount: old.sortByAmount);
    _setFilter(updated);
    return updated;
  }

  String _customerFilterLabel(int? id) {
    if (id == null) return 'مشتری';
    return _customers
            .where((customer) => customer.id == id)
            .map((customer) => customer.name)
            .firstOrNull ??
        'مشتری';
  }

  Future<void> _pickRange(LedgerFilter filter) async {
    final from = await showPersianDatePicker(
        context: context,
        initialDate: Jalali.fromDateTime(filter.from ?? DateTime.now()),
        firstDate: Jalali(1380),
        lastDate: Jalali(1450));
    if (from == null || !mounted) return;
    final to = await showPersianDatePicker(
        context: context,
        initialDate: Jalali.fromDateTime(filter.to ?? from.toDateTime()),
        firstDate: from,
        lastDate: Jalali(1450));
    if (to != null) {
      _setFilter(LedgerFilter(
          query: filter.query,
          customerId: filter.customerId,
          from: from.toDateTime(),
          to: to.toDateTime(),
          direction: filter.direction,
          hasInvoice: filter.hasInvoice,
          ascending: filter.ascending,
          sortByAmount: filter.sortByAmount));
    }
  }

  Future<void> _openEntryDialog({LedgerEntry? entry}) async {
    await showDialog(
        context: context, builder: (_) => _LedgerEntryDialog(entry: entry));
  }

  void _showDetails(LedgerEntry entry) => showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
            title: Text('جزئیات سند ${entry.type.label}'),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مشتری: ${entry.customerName}'),
                  Text(
                      'تاریخ ثبت: ${DateConverter.toShamsiWithTime(entry.operationDate)}'),
                  Text(
                      'مبلغ: ${CurrencyFormatter.format(entry.amount.toDouble())}'),
                  Text('فاکتور: ${entry.invoiceNumber ?? "ندارد"}'),
                  Text('توضیحات: ${entry.description ?? "-"}'),
                  Text(
                      'ایجاد: ${DateConverter.toShamsiWithTime(entry.createdAt)}'),
                  Text(
                      'آخرین ویرایش: ${DateConverter.toShamsiWithTime(entry.updatedAt)}'),
                ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('بستن'))
            ],
          ));

  Future<void> _exportExcel(List<LedgerEntry> entries) async {
    try {
      await ExcelService.exportLedger(entries);
    } catch (error) {
      if (mounted) _showExportError(error);
    }
  }

  Future<void> _exportPdf(List<LedgerEntry> entries) async {
    try {
      await PdfService.shareLedger(entries);
    } catch (error) {
      if (mounted) _showExportError(error);
    }
  }

  void _showExportError(Object error) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('ایجاد خروجی ناموفق بود: $error')));

  Future<void> _remove(LedgerEntry entry) async {
    final confirmed = await ConfirmDialog.show(context,
        title: entry.invoiceId == null ? 'حذف سند' : 'ابطال سند',
        message: entry.invoiceId == null
            ? 'آیا از حذف این سند مطمئن هستید؟'
            : 'این سند به فاکتور متصل است و با سند اصلاحی ابطال می‌شود. ادامه می‌دهید؟');
    if (confirmed != true) return;
    final repo = ref.read(ledgerRepositoryProvider);
    if (entry.invoiceId == null) {
      await repo.deleteManual(entry.id);
    } else {
      await repo.voidEntry(entry.id);
    }
  }
}

class _LedgerEntryDialog extends ConsumerStatefulWidget {
  final LedgerEntry? entry;
  const _LedgerEntryDialog({this.entry});
  @override
  ConsumerState<_LedgerEntryDialog> createState() => _LedgerEntryDialogState();
}

class _LedgerEntryDialogState extends ConsumerState<_LedgerEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;
  List<Customer> _customers = [];
  int? _customerId;
  LedgerEntryType _type = LedgerEntryType.debt;
  LedgerDirection _direction = LedgerDirection.debit;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _customerId = e?.customerId;
    _type = e?.type ?? LedgerEntryType.debt;
    _direction = e?.direction ?? LedgerDirection.debit;
    _date = e?.operationDate ?? DateTime.now();
    _amount = TextEditingController(
        text: e == null ? '' : CurrencyFormatter.formatNumber(e.amount));
    _description = TextEditingController(text: e?.description ?? '');
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final customers = await ref.read(customerRepositoryProvider).getCustomers();
    if (mounted) setState(() => _customers = customers);
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(widget.entry == null ? 'ثبت سند حساب' : 'ویرایش سند'),
        content: SizedBox(
            width: MediaQuery.sizeOf(context).width > 520
                ? 440
                : MediaQuery.sizeOf(context).width - 64,
            child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<int>(
                      initialValue: _customerId,
                      decoration: const InputDecoration(
                          labelText: 'مشتری',
                          prefixIcon: Icon(Icons.person_outline)),
                      items: _customers
                          .map((c) => DropdownMenuItem(
                              value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: widget.entry == null
                          ? (v) => setState(() => _customerId = v)
                          : null,
                      validator: (v) =>
                          v == null ? 'مشتری را انتخاب کنید' : null),
                  if (widget.entry == null)
                    Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                            onPressed: () => showDialog(
                                context: context,
                                builder: (_) => CustomerFormDialog(
                                    onSaved: _loadCustomers)),
                            icon: const Icon(Icons.person_add_outlined),
                            label: const Text('مشتری جدید'))),
                  DropdownButtonFormField<LedgerEntryType>(
                      initialValue: _type,
                      decoration:
                          const InputDecoration(labelText: 'نوع عملیات'),
                      items: LedgerEntryType.values
                          .where((e) => e != LedgerEntryType.reversal)
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e.label)))
                          .toList(),
                      onChanged: (v) => setState(() {
                            _type = v!;
                            _direction = v == LedgerEntryType.payment
                                ? LedgerDirection.credit
                                : LedgerDirection.debit;
                          })),
                  const SizedBox(height: 12),
                  SegmentedButton<LedgerDirection>(
                      segments: const [
                        ButtonSegment(
                            value: LedgerDirection.debit,
                            label: Text('بدهکار')),
                        ButtonSegment(
                            value: LedgerDirection.credit,
                            label: Text('بستانکار')),
                      ],
                      selected: {
                        _direction
                      },
                      onSelectionChanged: (v) =>
                          setState(() => _direction = v.first)),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'مبلغ', suffixText: 'تومان'),
                      validator: (v) =>
                          (CurrencyFormatter.parse(v ?? '') ?? 0) <= 0
                              ? 'مبلغ معتبر وارد کنید'
                              : null),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text('تاریخ: ${DateConverter.toShamsi(_date)}')),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _description,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'توضیحات')),
                ])))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('انصراف')),
          ElevatedButton(
              onPressed: _saving ? null : _save, child: const Text('ذخیره')),
        ],
      ));

  Future<void> _pickDate() async {
    final picked = await showPersianDatePicker(
        context: context,
        initialDate: Jalali.fromDateTime(_date),
        firstDate: Jalali(1380),
        lastDate: Jalali(1450));
    if (picked != null) setState(() => _date = picked.toDateTime());
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final amount = (CurrencyFormatter.parse(_amount.text) ?? 0).round();
      final repo = ref.read(ledgerRepositoryProvider);
      if (widget.entry == null) {
        await repo.create(
            customerId: _customerId!,
            type: _type,
            amount: amount,
            direction: _direction,
            operationDate: _date,
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim());
      } else {
        await repo.updateManual(widget.entry!,
            type: _type,
            amount: amount,
            direction: _direction,
            operationDate: _date,
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim());
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
