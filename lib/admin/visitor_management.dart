import 'package:flutter/material.dart';
import '../visitor/models/tickets.dart';
import 'admin_models.dart';
import 'admin_store.dart';
import 'admin_widgets.dart';
import 'visitor_profile.dart';

class VisitorManagement extends StatefulWidget {
  final AdminStore store;
  final ValueChanged<AdminVisitor> onOpen;
  final String initialQuery;
  const VisitorManagement({
    super.key,
    required this.store,
    required this.onOpen,
    this.initialQuery = '',
  });
  @override
  State<VisitorManagement> createState() => _VisitorManagementState();
}

class _VisitorManagementState extends State<VisitorManagement> {
  late final searchText = TextEditingController(text: widget.initialQuery);
  @override
  void dispose() {
    searchText.dispose();
    super.dispose();
  }

  late String query = widget.initialQuery;
  String status = 'all', membership = 'all', risk = 'all', joined = 'all';
  int page = 0, perPage = 10;
  bool ascending = true;
  String sort = 'name';
  final Set<String> selected = {};
  List<AdminVisitor> get filtered {
    final today = parkToday();
    final list = widget.store.visitors.where((v) {
      if (status == 'all' && v.status == 'archived') return false;
      if (status != 'all' && v.status != status) return false;
      if (membership != 'all' && v.membership != membership) return false;
      if (risk != 'all' &&
          (risk == 'watchlisted' ? !v.watchlisted : v.risk != risk)) {
        return false;
      }
      if (joined != 'all') {
        final date = v.joined?.toUtc().add(const Duration(hours: 8));
        if (date == null ||
            date.isBefore(
              today.subtract(Duration(days: joined == 'week' ? 7 : 30)),
            )) {
          return false;
        }
      }
      final text =
          '${v.name} ${v.email} ${v.phone} ${v.id} ${visitorReference(v.id)}'
              .toLowerCase();
      return text.contains(query.toLowerCase().trim());
    }).toList();
    list.sort((a, b) {
      final result = sort == 'activity'
          ? (widget.store.lastSeen(a.id) ?? DateTime(1970)).compareTo(
              widget.store.lastSeen(b.id) ?? DateTime(1970),
            )
          : (sort == 'membership'
                ? a.membership.compareTo(b.membership)
                : a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return ascending ? result : -result;
    });
    return list;
  }

  void _change(VoidCallback action) => setState(() {
    action();
    page = 0;
  });
  Future<void> _status(List<String> ids, String next) async {
    final reason = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          next == 'active'
              ? 'Activate visitor accounts'
              : next == 'archived'
              ? 'Archive visitor accounts'
              : 'Suspend visitor accounts',
        ),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                next == 'archived'
                    ? 'Archive ${ids.length} selected account(s)? Records and bookings are kept. You can restore access from the Archived filter.'
                    : next == 'active'
                    ? 'Restore visitor-app access for ${ids.length} selected account(s)?'
                    : 'Suspend visitor-app access for ${ids.length} selected account(s)? Existing records and bookings are kept.',
              ),
              const SizedBox(height: 18),
              TextField(
                controller: reason,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Add an account-management reason',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          AdminButton(
            next == 'active'
                ? 'Activate'
                : next == 'archived'
                ? 'Archive'
                : 'Suspend',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (result != true || !mounted) return;
    final success = await widget.store.perform(
      () => widget.store.repository.setVisitorStatus(ids, next, text),
    );
    if (success && mounted) {
      setState(() => selected.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visitor account status updated.')),
      );
    }
  }

  Future<void> _watchlist(List<AdminVisitor> visitors, bool enabled) async {
    final done = await widget.store.perform(
      () => widget.store.repository.setWatchlist(visitors, enabled),
    );
    if (done && mounted) {
      setState(() => selected.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Visitors added to the watchlist.'
                : 'Visitors removed from the watchlist.',
          ),
        ),
      );
    }
  }

  void _export() => exportAdminCsv(
    context,
    'visitors-${visitDateString(parkToday())}.csv',
    [
      'Visitor',
      'Visitor ID',
      'Email',
      'Phone',
      'Membership',
      'Tickets',
      'Last activity',
      'Risk',
      'Status',
    ],
    filtered
        .map(
          (v) => [
            v.name,
            visitorReference(v.id),
            v.email,
            v.phone,
            v.membership,
            widget.store.visitorTickets(v).length,
            adminTimeLabel(widget.store.lastSeen(v.id)),
            v.risk,
            v.status,
          ],
        )
        .toList(),
  );
  @override
  Widget build(BuildContext context) {
    final store = widget.store, list = filtered;
    final lastPage = list.isEmpty ? 0 : (list.length - 1) ~/ perPage;
    final current = page.clamp(0, lastPage);
    final visible = list.skip(current * perPage).take(perPage).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminHeading(
          'Visitor Accounts',
          'View and manage registered visitors',
        ),
        const SizedBox(height: 26),
        AdminStats(
          children: [
            AdminStat(
              'Total Visitors',
              '${store.visitors.length}',
              'All registered visitors',
              Icons.people_outline,
            ),
            AdminStat(
              'Active Today',
              '${store.activeToday}',
              'Visitors active today',
              Icons.person_outline,
              color: const Color(0xFF278D52),
            ),
            AdminStat(
              'New This Month',
              '${store.newThisMonth}',
              'New visitor registrations',
              Icons.person_add_alt_1_outlined,
              color: const Color(0xFF3978D8),
            ),
            AdminStat(
              'Flagged Accounts',
              '${store.flagged}',
              'Require attention',
              Icons.flag_outlined,
              color: Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 24),
        AdminCard(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  key: const Key('visitor-search'),
                  controller: searchText,
                  onChanged: (v) => _change(() => query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Search name, email, phone or visitor ID',
                  ),
                ),
              ),
              AdminSelect(
                value: status,
                options: const {
                  'all': 'All Status',
                  'active': 'Active',
                  'suspended': 'Suspended',
                  'archived': 'Archived',
                },
                onChanged: (v) => _change(() => status = v),
                width: 135,
              ),
              AdminSelect(
                value: membership,
                options: const {
                  'all': 'All Memberships',
                  'normal': 'Normal Member',
                  'bronze': 'Bronze Member',
                  'silver': 'Silver Member',
                  'gold': 'Gold Member',
                },
                onChanged: (v) => _change(() => membership = v),
                width: 157,
              ),
              AdminSelect(
                value: risk,
                options: const {
                  'all': 'All Risk Levels',
                  'normal': 'Normal',
                  'review': 'Review',
                  'high': 'High',
                  'watchlisted': 'Watchlisted',
                },
                onChanged: (v) => _change(() => risk = v),
                width: 145,
              ),
              AdminSelect(
                value: joined,
                options: const {
                  'all': 'Date Joined',
                  'week': 'Last 7 days',
                  'month': 'Last 30 days',
                },
                onChanged: (v) => _change(() => joined = v),
                width: 145,
              ),
              AdminButton(
                'Export CSV',
                icon: Icons.download_outlined,
                onPressed: list.isEmpty ? null : _export,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AdminCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${selected.length} selected',
                    style: const TextStyle(fontSize: 12),
                  ),
                  AdminButton(
                    'Activate',
                    outlined: true,
                    onPressed: store.busy
                        ? null
                        : () => _status(selected.toList(), 'active'),
                  ),
                  AdminButton(
                    'Suspend',
                    outlined: true,
                    onPressed: store.busy
                        ? null
                        : () => _status(selected.toList(), 'suspended'),
                  ),
                  AdminButton(
                    'Add to Watchlist',
                    outlined: true,
                    onPressed: store.busy
                        ? null
                        : () => _watchlist(
                            store.visitors
                                .where((v) => selected.contains(v.id))
                                .toList(),
                            true,
                          ),
                  ),
                  AdminButton(
                    'Remove',
                    outlined: true,
                    onPressed: store.busy
                        ? null
                        : () => _status(selected.toList(), 'archived'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => selected.clear()),
                    child: const Text(
                      'Clear Selection',
                      style: TextStyle(color: adminRose, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        AdminCard(
          padding: EdgeInsets.zero,
          child: list.isEmpty
              ? const AdminEmpty(
                  'No matching visitors',
                  'Try changing your search or filters.',
                  icon: Icons.people_outline,
                )
              : AdminTable(
                  minWidth: 1170,
                  sortColumnIndex: sort == 'name'
                      ? 1
                      : sort == 'membership'
                      ? 4
                      : 6,
                  sortAscending: ascending,
                  columns: [
                    DataColumn(
                      label: Checkbox(
                        value:
                            visible.isNotEmpty &&
                            visible.every((v) => selected.contains(v.id)),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            selected.addAll(visible.map((v) => v.id));
                          } else {
                            selected.removeAll(visible.map((v) => v.id));
                          }
                        }),
                      ),
                    ),
                    DataColumn(
                      label: const Text('Visitor'),
                      onSort: (_, value) => setState(() {
                        sort = 'name';
                        ascending = value;
                      }),
                    ),
                    const DataColumn(label: Text('Visitor ID')),
                    const DataColumn(label: Text('Contact')),
                    DataColumn(
                      label: const Text('Membership'),
                      onSort: (_, value) => setState(() {
                        sort = 'membership';
                        ascending = value;
                      }),
                    ),
                    const DataColumn(label: Text('Tickets')),
                    DataColumn(
                      label: const Text('Last Activity'),
                      onSort: (_, value) => setState(() {
                        sort = 'activity';
                        ascending = value;
                      }),
                    ),
                    const DataColumn(label: Text('Risk')),
                    const DataColumn(label: Text('Status')),
                    const DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final v in visible)
                      DataRow(
                        cells: [
                          DataCell(
                            Checkbox(
                              value: selected.contains(v.id),
                              onChanged: store.busy
                                  ? null
                                  : (value) => setState(() {
                                      if (value == true) {
                                        selected.add(v.id);
                                      } else {
                                        selected.remove(v.id);
                                      }
                                    }),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () => widget.onOpen(v),
                              child: Row(
                                children: [
                                  AdminAvatar(v.name, photo: v.photo),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      v.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              visitorReference(v.id),
                              style: const TextStyle(
                                color: adminMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.email,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  v.phone.isEmpty ? 'Not provided' : v.phone,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: adminMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            AdminBadge(
                              '${titleCase(v.membership)} Member',
                              tone: v.membership,
                            ),
                          ),
                          DataCell(Text('${store.visitorTickets(v).length}')),
                          DataCell(
                            Text(
                              adminTimeLabel(store.lastSeen(v.id)),
                              style: const TextStyle(
                                color: adminMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          DataCell(
                            AdminBadge(
                              v.watchlisted ? 'Watchlisted' : titleCase(v.risk),
                              tone: v.watchlisted ? 'watchlisted' : v.risk,
                            ),
                          ),
                          DataCell(AdminBadge(titleCase(v.status))),
                          DataCell(
                            PopupMenuButton<String>(
                              tooltip: 'Actions for ${v.name}',
                              onSelected: (action) {
                                if (action == 'view') widget.onOpen(v);
                                if (action == 'edit') {
                                  editVisitor(context, store, v);
                                }
                                if (action == 'active' ||
                                    action == 'suspended' ||
                                    action == 'archived') {
                                  _status([v.id], action);
                                }
                                if (action == 'watch') {
                                  _watchlist([v], !v.watchlisted);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'view',
                                  child: Text('View Details'),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit Profile'),
                                ),
                                PopupMenuItem(
                                  value: v.status == 'active'
                                      ? 'suspended'
                                      : 'active',
                                  child: Text(
                                    v.status == 'active'
                                        ? 'Suspend Account'
                                        : 'Activate Account',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'watch',
                                  child: Text(
                                    v.watchlisted
                                        ? 'Remove from Watchlist'
                                        : 'Add to Watchlist',
                                  ),
                                ),
                                if (v.status != 'archived')
                                  const PopupMenuItem(
                                    value: 'archived',
                                    child: Text('Archive Account'),
                                  ),
                              ],
                              icon: const Icon(Icons.more_vert, size: 20),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        AdminCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                list.isEmpty
                    ? 'Showing 0 results'
                    : 'Showing ${current * perPage + 1} to ${(current + 1) * perPage > list.length ? list.length : (current + 1) * perPage} of ${list.length} results',
                style: const TextStyle(color: adminMuted, fontSize: 12),
              ),
              AdminSelect(
                value: '$perPage',
                options: const {
                  '5': '5 per page',
                  '10': '10 per page',
                  '25': '25 per page',
                  '50': '50 per page',
                },
                onChanged: (v) => _change(() => perPage = int.parse(v)),
                width: 125,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: current > 0
                        ? () => setState(() => page = current - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: adminRose,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${current + 1}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'of ${lastPage + 1}',
                    style: const TextStyle(color: adminMuted, fontSize: 12),
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed: current < lastPage
                        ? () => setState(() => page = current + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
