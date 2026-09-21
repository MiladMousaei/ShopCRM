import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/customers_table.dart';

part 'customers_dao.g.dart';

@DriftAccessor(tables: [CustomersTable])
class CustomersDao extends DatabaseAccessor<AppDatabase> with _$CustomersDaoMixin {
  CustomersDao(super.db);

  Future<List<CustomersTableData>> getAllCustomers() =>
      select(customersTable).get();

  Stream<List<CustomersTableData>> watchAllCustomers() =>
      select(customersTable).watch();

  Stream<List<CustomersTableData>> watchCustomersBySearch(String query) {
    final q = '%$query%';
    return (select(customersTable)
      ..where((t) => t.name.like(q) | t.phone.like(q)))
        .watch();
  }

  Future<CustomersTableData?> findById(int id) =>
      (select(customersTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<CustomersTableData?> findByPhone(String phone) =>
      (select(customersTable)..where((t) => t.phone.equals(phone))).getSingleOrNull();

  Future<int> insertCustomer(CustomersTableCompanion customer) =>
      into(customersTable).insert(customer);

  Future<int> updateCustomer(int id, CustomersTableCompanion customer) =>
      (update(customersTable)..where((t) => t.id.equals(id))).write(customer);

  Future<void> updateDebt(int id, double newDebt) =>
      (update(customersTable)..where((t) => t.id.equals(id)))
          .write(CustomersTableCompanion(
            totalDebt: Value(newDebt),
            updatedAt: Value(DateTime.now()),
            syncStatus: const Value('pending'),
          ));

  Future<List<CustomersTableData>> getDebtors() =>
      (select(customersTable)
        ..where((t) => t.totalDebt.isBiggerThanValue(0))
        ..orderBy([(t) => OrderingTerm.desc(t.totalDebt)]))
          .get();

  Future<double> getTotalDebt() async {
    final customers = await getDebtors();
    return customers.fold<double>(0.0, (sum, c) => sum + c.totalDebt);
  }

  Future<List<CustomersTableData>> getPendingCustomers() =>
      (select(customersTable)..where((t) => t.syncStatus.equals('pending'))).get();

  Future<void> markAsSynced(int id, int serverId) =>
      (update(customersTable)..where((t) => t.id.equals(id)))
          .write(CustomersTableCompanion(
            serverId: Value(serverId),
            syncStatus: const Value('synced'),
          ));
}
