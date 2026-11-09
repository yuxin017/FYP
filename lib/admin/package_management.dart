import 'package:flutter/material.dart';
import '../visitor/models/tickets.dart';
import 'admin_models.dart';
import 'admin_store.dart';
import 'admin_widgets.dart';

class PackageManagement extends StatefulWidget {
  final AdminStore store;
  const PackageManagement({super.key, required this.store});
  @override
  State<PackageManagement> createState() => _PackageManagementState();
}

class _PackageManagementState extends State<PackageManagement> {
  String query = '', status = 'all', category = 'all';
  @override
  Widget build(BuildContext context) {
    final list =
        widget.store.packages
            .where(
              (p) =>
                  (status == 'all' || p.active == (status == 'active')) &&
                  (category == 'all' || p.pass.category == category) &&
                  p.pass.name.toLowerCase().contains(
                    query.toLowerCase().trim(),
                  ),
            )
            .toList()
          ..sort((a, b) => a.pass.sortOrder.compareTo(b.pass.sortOrder));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminHeading(
          'Pass Packages',
          'Manage visitor pass availability and prices',
          action: AdminButton(
            'Add Pass Package',
            icon: Icons.add,
            onPressed: widget.store.busy
                ? null
                : () => editPackage(context, widget.store),
          ),
        ),
        const SizedBox(height: 26),
        AdminStats(
          children: [
            AdminStat(
              'Total Packages',
              '${widget.store.packages.length}',
              'Day, annual and add-on passes',
              Icons.local_activity_outlined,
            ),
            AdminStat(
              'Active',
              '${widget.store.packages.where((p) => p.active).length}',
              'Available in the visitor catalog',
              Icons.check_circle_outline,
              color: const Color(0xFF278D52),
            ),
            AdminStat(
              'Inactive',
              '${widget.store.packages.where((p) => !p.active).length}',
              'Hidden from new bookings',
              Icons.pause_circle_outline,
              color: Colors.orange,
            ),
            AdminStat(
              'Currency',
              'MYR',
              'Prices shown in Malaysian ringgit',
              Icons.payments_outlined,
              color: const Color(0xFF3978D8),
            ),
          ],
        ),
        const SizedBox(height: 24),
        AdminCard(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 330,
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Search pass packages',
                  ),
                ),
              ),
              AdminSelect(
                value: status,
                options: const {
                  'all': 'All Status',
                  'active': 'Active',
                  'inactive': 'Inactive',
                },
                onChanged: (v) => setState(() => status = v),
              ),
              AdminSelect(
                value: category,
                options: const {
                  'all': 'All Categories',
                  'day': 'Day Pass',
                  'annual': 'Annual Pass',
                  'addon': 'Add-ons',
                },
                onChanged: (v) => setState(() => category = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AdminCard(
          padding: EdgeInsets.zero,
          child: list.isEmpty
              ? const AdminEmpty(
                  'No matching pass packages',
                  'Add a pass or change the selected filters.',
                )
              : AdminTable(
                  minWidth: 1000,
                  columns: const [
                    DataColumn(label: Text('Pass Package')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Adult Fare')),
                    DataColumn(label: Text('Child Fare')),
                    DataColumn(label: Text('Validity')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final p in list)
                      DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: Image.asset(
                                    p.pass.imageAsset,
                                    width: 65,
                                    height: 46,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 220,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.pass.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        p.pass.description,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: adminMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              p.pass.category == 'annual'
                                  ? 'Annual Pass'
                                  : p.pass.category == 'addon'
                                  ? 'Add-on'
                                  : 'Day Pass',
                            ),
                          ),
                          DataCell(Text(money(p.pass.priceMinor))),
                          DataCell(Text(money(p.pass.childPrice))),
                          DataCell(
                            Text(
                              '${p.pass.durationDays} ${p.pass.durationDays == 1 ? 'day' : 'days'}',
                            ),
                          ),
                          DataCell(
                            AdminBadge(p.active ? 'Active' : 'Inactive'),
                          ),
                          DataCell(
                            AdminButton(
                              'Edit Pass',
                              icon: Icons.edit_outlined,
                              outlined: true,
                              onPressed: widget.store.busy
                                  ? null
                                  : () => editPackage(
                                      context,
                                      widget.store,
                                      package: p,
                                    ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        const AdminCard(
          child: Row(
            children: [
              Icon(Icons.info_outline, color: adminRose, size: 21),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Changes apply to new bookings. Previously issued tickets retain their booked fare and admission dates.',
                  style: TextStyle(fontSize: 12, color: adminMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> editPackage(
  BuildContext context,
  AdminStore store, {
  AdminPackage? package,
}) async {
  final result = await showDialog<PackageDraft>(
    context: context,
    builder: (_) => PackageEditor(package: package),
  );
  if (result == null || !context.mounted) return;
  final done = await store.perform(
    () => store.repository.savePackage(package?.id, result),
  );
  if (done && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pass package saved. The visitor catalog is updated.'),
      ),
    );
  }
}

class PackageEditor extends StatefulWidget {
  final AdminPackage? package;
  const PackageEditor({super.key, this.package});
  @override
  State<PackageEditor> createState() => _PackageEditorState();
}

class _PackageEditorState extends State<PackageEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
        text: widget.package?.pass.name ?? '',
      ),
      description = TextEditingController(
        text: widget.package?.pass.description ?? '',
      ),
      adult = TextEditingController(
        text: widget.package == null
            ? ''
            : (widget.package!.pass.priceMinor / 100).toStringAsFixed(2),
      ),
      child = TextEditingController(
        text: widget.package?.pass.childPriceMinor == null
            ? ''
            : (widget.package!.pass.childPriceMinor! / 100).toStringAsFixed(2),
      ),
      days = TextEditingController(
        text: '${widget.package?.pass.durationDays ?? 1}',
      ),
      sort = TextEditingController(
        text: '${widget.package?.pass.sortOrder ?? 0}',
      );
  late String category = widget.package?.pass.category ?? 'day';
  late bool active = widget.package?.active ?? true;
  @override
  void dispose() {
    for (final c in [name, description, adult, child, days, sort]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.package == null ? 'Add Pass Package' : 'Edit Pass Package',
    ),
    content: SizedBox(
      width: 580,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  category == 'annual' ? ticketAnnualAsset : ticketCastleAsset,
                  width: 580,
                  height: 130,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: name,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Pass Name'),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'Enter a pass name.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: description,
                maxLines: 2,
                maxLength: 2000,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              AdminSelect(
                value: category,
                options: const {
                  'day': 'Day Pass',
                  'annual': 'Annual Pass',
                  'addon': 'Add-on',
                },
                onChanged: (v) => setState(() => category = v),
                width: 580,
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: adult,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Adult Fare (RM)',
                      ),
                      validator: (v) => parseMoneyMinor(v ?? '') == null
                          ? 'Enter a fare from RM0.01 to RM100,000.'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: child,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Child Fare (RM)',
                        hintText: 'Same as adult if empty',
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ||
                              parseMoneyMinor(v!) != null
                          ? null
                          : 'Enter a valid child fare.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: days,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Validity (days)',
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return n != null && n >= 1 && n <= 365
                            ? null
                            : 'Choose 1–365 days.';
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: sort,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Display Order',
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return n != null && n >= 0 && n <= 999
                            ? null
                            : 'Choose 0–999.';
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Active in visitor catalog',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: const Text(
                  'Inactive passes cannot be selected for new bookings.',
                  style: TextStyle(fontSize: 12),
                ),
                value: active,
                onChanged: (v) => setState(() => active = v),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      AdminButton(
        'Save Package',
        onPressed: () {
          if (!form.currentState!.validate()) return;
          Navigator.pop(
            context,
            PackageDraft(
              name: name.text,
              description: description.text,
              category: category,
              priceMinor: parseMoneyMinor(adult.text)!,
              childPriceMinor: child.text.trim().isEmpty
                  ? null
                  : parseMoneyMinor(child.text),
              durationDays: int.parse(days.text),
              sortOrder: int.parse(sort.text),
              active: active,
            ),
          );
        },
      ),
    ],
  );
}
