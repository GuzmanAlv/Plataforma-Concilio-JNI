import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/domain/council_period.dart';
import '../../../core/domain/money.dart';
import '../../../core/domain/civil_date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/treasury.dart';

class MovementsTable extends StatefulWidget {
  const MovementsTable({
    required this.offerings,
    required this.expenses,
    required this.filter,
    required this.onEdit,
    required this.onReceipt,
    this.onEditOffering,
    super.key,
  });
  final List<Offering> offerings;
  final List<Expense> expenses;
  final PeriodFilter filter;
  final ValueChanged<Expense> onEdit;
  final ValueChanged<String> onReceipt;
  final ValueChanged<Offering>? onEditOffering;
  @override
  State<MovementsTable> createState() => _MovementsTableState();
}

class _MovementsTableState extends State<MovementsTable> {
  int _sortColumn = 0;
  bool _ascending = false;
  int _page = 0;
  static const _pageSize = 20;
  @override
  Widget build(BuildContext context) {
    final rows =
        <
          ({
            CivilDate date,
            String title,
            String description,
            Money amount,
            Expense? expense,
            Offering? offering,
          })
        >[
          ...widget.offerings
              .where((o) => widget.filter.contains(o.date))
              .map(
                (o) => (
                  date: o.date,
                  title: 'Ofrenda del sábado',
                  description:
                      'Bruto ${o.gross.formatted} · Distrito ${o.district.formatted} · Colab. ${o.fixedContribution.formatted}',
                  amount: o.net,
                  expense: null,
                  offering: o,
                ),
              ),
          ...widget.expenses
              .where((e) => widget.filter.contains(e.date))
              .map(
                (e) => (
                  date: e.date,
                  title: e.name,
                  description: e.concept,
                  amount: Money.zero - e.amount,
                  expense: e,
                  offering: null,
                ),
              ),
        ];
    rows.sort((a, b) {
      final order = _sortColumn == 0
          ? a.date.compareTo(b.date)
          : _sortColumn == 2
          ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
          : a.amount.compareTo(b.amount);
      return _ascending ? order : -order;
    });
    void sort(int column, bool ascending) => setState(() {
      _sortColumn = column;
      _ascending = ascending;
      _page = 0;
    });
    final pageCount = (rows.length / _pageSize).ceil().clamp(1, 1000000);
    final page = _page.clamp(0, pageCount - 1);
    final visibleRows = rows.skip(page * _pageSize).take(_pageSize);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              sortColumnIndex: _sortColumn,
              sortAscending: _ascending,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF0EEFC)),
              dataRowMinHeight: 64,
              dataRowMaxHeight: 108,
              columns: [
                DataColumn(label: const Text('Fecha'), onSort: sort),
                const DataColumn(label: Text('Tipo')),
                DataColumn(label: const Text('Nombre'), onSort: sort),
                const DataColumn(label: Text('Descripción')),
                DataColumn(
                  label: const Text('Monto (S/)'),
                  numeric: true,
                  onSort: sort,
                ),
                const DataColumn(label: Text('Boleta')),
                const DataColumn(label: Text('Acciones')),
              ],
              rows: visibleRows.map((row) {
                final expense = row.expense;
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        DateFormat('dd/MM/yyyy').format(row.date.toDateTime()),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: expense == null
                              ? const Color(0xFFE7F5EE)
                              : const Color(0xFFFCECEE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(expense == null ? 'Ingreso' : 'Egreso'),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 160,
                        child: Text(
                          row.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 280,
                        child: Text(
                          row.description,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        row.amount.formatted,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: row.amount.isNegative
                              ? const Color(0xFFBA3E52)
                              : const Color(0xFF218259),
                        ),
                      ),
                    ),
                    DataCell(
                      expense?.receiptPath == null
                          ? const Text('—')
                          : TextButton.icon(
                              onPressed: () =>
                                  widget.onReceipt(expense!.receiptPath!),
                              icon: const Icon(Icons.image_outlined),
                              label: const Text('Ver'),
                            ),
                    ),
                    DataCell(
                      expense == null
                          ? widget.onEditOffering == null
                                ? const Text('—')
                                : TextButton.icon(
                                    onPressed: () =>
                                        widget.onEditOffering!(row.offering!),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Editar'),
                                  )
                          : TextButton.icon(
                              onPressed: () => widget.onEdit(expense),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Editar'),
                            ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          if (rows.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Sin movimientos registrados',
              message:
                  'Los ingresos y egresos del periodo aparecerán en esta tabla.',
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${rows.length} movimientos · Página ${page + 1} de $pageCount',
                ),
                IconButton(
                  tooltip: 'Movimientos anteriores',
                  onPressed: page == 0
                      ? null
                      : () => setState(() => _page = page - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Movimientos siguientes',
                  onPressed: page + 1 == pageCount
                      ? null
                      : () => setState(() => _page = page + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
                const Text('Desliza para ver todas las columnas.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
