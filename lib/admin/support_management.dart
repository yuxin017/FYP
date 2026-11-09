import 'dart:async';
import 'package:flutter/material.dart';
import '../support/support_models.dart';
import '../support/support_repository.dart';
import '../support/support_page.dart'
    show SupportReplyComposer, SupportReplyComposerState;
import '../support/support_widgets.dart';
import '../visitor/models/tickets.dart';
import '../visitor/services/ticket_journey.dart' show bookingError;
import 'admin_widgets.dart';

class SupportManagement extends StatefulWidget {
  final SupportRepository repository;
  final String adminName;
  const SupportManagement({
    super.key,
    required this.repository,
    required this.adminName,
  });
  @override
  State<SupportManagement> createState() => _SupportManagementState();
}

class _SupportManagementState extends State<SupportManagement> {
  List<SupportCase> records = [];
  String? selectedId, error;
  bool loading = true;
  StreamSubscription<List<SupportCase>>? subscription;
  String query = '',
      type = 'All',
      priority = 'All',
      status = 'All',
      assignee = 'All',
      category = 'All';
  DateTimeRange? dates;
  int page = 0, pageSize = 10;
  @override
  void initState() {
    super.initState();
    subscription = widget.repository.cases().listen(
      (value) {
        if (mounted) {
          setState(() {
            records = value;
            loading = false;
            error = null;
          });
        }
      },
      onError: (Object e) {
        if (mounted) {
          setState(() {
            error = bookingError(e);
            loading = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  List<SupportCase> get filtered => records
      .where(
        (r) =>
            r.matches(query) &&
            (type == 'All' || r.type == type) &&
            (priority == 'All' || r.priority == priority) &&
            (status == 'All' || r.status == status) &&
            (category == 'All' || r.category == category) &&
            (assignee == 'All' ||
                assignee == 'Mine' &&
                    r.assigneeUid == widget.repository.userId ||
                assignee == 'Unassigned' && r.assigneeUid.isEmpty) &&
            (dates == null ||
                r.createdAt != null &&
                    !parkToday(r.createdAt).isBefore(dates!.start) &&
                    !parkToday(r.createdAt).isAfter(dates!.end)),
      )
      .toList();
  Widget dropdown(
    String label,
    String value,
    Map<String, String> items,
    ValueChanged<String> changed, {
    double width = 125,
  }) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: items.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(
                e.value,
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() {
        changed(v!);
        page = 0;
      }),
    ),
  );
  Widget metric(
    String label,
    String value,
    IconData icon, {
    Color color = adminRose,
  }) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 10),
      child: AdminCard(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: .08),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 10, color: adminMuted),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  String get averageResponse {
    final values = records
        .where((r) => r.firstResponseAt != null && r.createdAt != null)
        .map((r) => r.firstResponseAt!.difference(r.createdAt!).inMinutes)
        .toList();
    if (values.isEmpty) return '—';
    final minutes = values.reduce((a, b) => a + b) ~/ values.length;
    return minutes >= 60 ? '${minutes ~/ 60}h ${minutes % 60}m' : '${minutes}m';
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final selected = records.where((r) => r.id == selectedId).firstOrNull;
      final panel = selected == null
          ? null
          : AdminSupportCasePanel(
              key: ValueKey(selected.id),
              record: selected,
              repository: widget.repository,
              adminName: widget.adminName,
              onClose: () => setState(() => selectedId = null),
            );
      if (panel != null && c.maxWidth < 1120) return panel;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Feedback & Complaints',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    color: adminDark,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Track, assign and resolve visitor cases',
                  style: TextStyle(fontSize: 12, color: adminMuted),
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: c.maxWidth - (panel == null ? 0 : 380) < 720
                        ? 720
                        : c.maxWidth - (panel == null ? 0 : 380),
                    child: Row(
                      children: [
                        metric(
                          'New',
                          '${records.where((r) => r.status == 'new').length}',
                          Icons.forum_outlined,
                        ),
                        metric(
                          'In Progress',
                          '${records.where((r) => r.status == 'in_progress').length}',
                          Icons.schedule,
                        ),
                        metric(
                          'Overdue',
                          '${records.where((r) => r.overdue).length}',
                          Icons.warning_amber_outlined,
                          color: const Color(0xFFBE494E),
                        ),
                        metric(
                          'Resolved This Month',
                          '${records.where((r) => r.resolvedAt != null && parkToday(r.resolvedAt).year == parkToday().year && parkToday(r.resolvedAt).month == parkToday().month).length}',
                          Icons.task_alt,
                        ),
                        metric(
                          'Average Response',
                          averageResponse,
                          Icons.timer_outlined,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AdminCard(
                  padding: const EdgeInsets.all(13),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 13,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 230,
                        child: TextField(
                          key: const Key('case-search'),
                          onChanged: (v) => setState(() {
                            query = v;
                            page = 0;
                          }),
                          decoration: const InputDecoration(
                            hintText: 'Search case ID, visitor or keyword…',
                            prefixIcon: Icon(Icons.search, size: 18),
                            isDense: true,
                          ),
                        ),
                      ),
                      dropdown('Type', type, {
                        'All': 'All',
                        ...supportTypes,
                      }, (v) => type = v),
                      dropdown(
                        'Priority',
                        priority,
                        {'All': 'All', ...supportPriorities},
                        (v) => priority = v,
                        width: 105,
                      ),
                      dropdown(
                        'Status',
                        status,
                        {'All': 'All', ...supportStatuses},
                        (v) => status = v,
                        width: 135,
                      ),
                      dropdown(
                        'Assigned To',
                        assignee,
                        const {
                          'All': 'All',
                          'Mine': 'Mine',
                          'Unassigned': 'Unassigned',
                        },
                        (v) => assignee = v,
                        width: 130,
                      ),
                      dropdown(
                        'Category',
                        category,
                        {
                          'All': 'All',
                          for (final item in supportCategories) item: item,
                        },
                        (v) => category = v,
                        width: 155,
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: parkToday(),
                            initialDateRange: dates,
                          );
                          if (range != null && mounted) {
                            setState(() {
                              dates = range;
                              page = 0;
                            });
                          }
                        },
                        icon: const Icon(Icons.date_range_outlined, size: 17),
                        label: Text(
                          dates == null
                              ? 'Submitted Date'
                              : '${displayParkDate(visitDateString(dates!.start))} – ${displayParkDate(visitDateString(dates!.end))}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      if (dates != null ||
                          type != 'All' ||
                          priority != 'All' ||
                          status != 'All' ||
                          assignee != 'All' ||
                          category != 'All')
                        TextButton(
                          onPressed: () => setState(() {
                            dates = null;
                            type = priority = status = assignee = category =
                                'All';
                            page = 0;
                          }),
                          child: const Text(
                            'Clear Filters',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (error != null)
                  AdminCard(
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                else if (loading)
                  const Padding(
                    padding: EdgeInsets.all(50),
                    child: Center(
                      child: CircularProgressIndicator(color: adminRose),
                    ),
                  )
                else
                  caseTable(),
              ],
            ),
          ),
          if (panel != null) ...[
            const SizedBox(width: 20),
            SizedBox(width: 360, child: panel),
          ],
        ],
      );
    },
  );
  Widget caseTable() {
    final rows = filtered;
    final maxPage = rows.isEmpty ? 0 : (rows.length - 1) ~/ pageSize;
    final current = page.clamp(0, maxPage);
    final start = current * pageSize;
    final shown = rows.skip(start).take(pageSize).toList();
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStatePropertyAll(
                Colors.grey.withValues(alpha: .025),
              ),
              dataRowMinHeight: 70,
              dataRowMaxHeight: 90,
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('Case ID')),
                DataColumn(label: Text('Visitor')),
                DataColumn(label: Text('Subject')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Submitted')),
                DataColumn(label: Text('Priority')),
                DataColumn(label: Text('Assignee')),
                DataColumn(label: Text('Target')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: shown
                  .map(
                    (r) => DataRow(
                      selected: r.id == selectedId,
                      onSelectChanged: (_) => setState(() => selectedId = r.id),
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 150,
                            child: Text(
                              r.reference,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 100,
                            child: Text(
                              r.ownerName,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: Text(
                              r.subject,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 110,
                            child: Text(
                              r.category,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 100,
                            child: Text(
                              supportTime(r.createdAt),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        DataCell(SupportStatus(r.priority, priority: true)),
                        DataCell(
                          Text(
                            r.assigneeName.isEmpty ? '—' : r.assigneeName,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        DataCell(
                          Text(
                            r.status == 'resolved'
                                ? 'Complete'
                                : r.overdue
                                ? 'Overdue'
                                : r.createdAt == null
                                ? '—'
                                : supportDay(
                                    supportDueDate(
                                      r.createdAt!,
                                    ).subtract(const Duration(seconds: 1)),
                                  ),
                            style: TextStyle(
                              fontSize: 10,
                              color: r.overdue ? Colors.red : adminMuted,
                            ),
                          ),
                        ),
                        DataCell(SupportStatus(r.status)),
                        DataCell(
                          IconButton(
                            tooltip: 'Open case',
                            onPressed: () => setState(() => selectedId = r.id),
                            icon: const Icon(
                              Icons.more_horiz,
                              color: adminMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.forum_outlined, size: 42, color: adminRose),
                  SizedBox(height: 12),
                  Text(
                    'No cases found',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Visitor submissions will appear here.',
                    style: TextStyle(color: adminMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text(
                  'Showing ${rows.isEmpty ? 0 : start + 1} to ${start + shown.length} of ${rows.length} results',
                  style: const TextStyle(fontSize: 11, color: adminMuted),
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
                    Text(
                      '${current + 1} / ${maxPage + 1}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    IconButton(
                      tooltip: 'Next page',
                      onPressed: current < maxPage
                          ? () => setState(() => page = current + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: pageSize,
                      items: [10, 20, 50]
                          .map(
                            (n) => DropdownMenuItem(
                              value: n,
                              child: Text(
                                '$n / page',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        pageSize = v!;
                        page = 0;
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSupportCasePanel extends StatefulWidget {
  final SupportCase record;
  final SupportRepository repository;
  final String adminName;
  final VoidCallback onClose;
  const AdminSupportCasePanel({
    super.key,
    required this.record,
    required this.repository,
    required this.adminName,
    required this.onClose,
  });
  @override
  State<AdminSupportCasePanel> createState() => _AdminSupportCasePanelState();
}

class _AdminSupportCasePanelState extends State<AdminSupportCasePanel> {
  late SupportCase base = widget.record;
  late String status = base.status,
      priority = base.priority,
      category = base.category,
      assignee = base.assigneeUid;
  String tab = 'Details';
  bool busy = false, dirty = false;
  String? error;
  final replyKey = GlobalKey<SupportReplyComposerState>();
  late final booking = widget.repository.relatedOrder(widget.record);
  @override
  void didUpdateWidget(covariant AdminSupportCasePanel old) {
    super.didUpdateWidget(old);
    if (!dirty && old.record.updatedAt != widget.record.updatedAt) {
      base = widget.record;
      status = base.status;
      priority = base.priority;
      category = base.category;
      assignee = base.assigneeUid;
    }
  }

  Future<void> save({bool resolve = false}) async {
    if (busy) return;
    var resolution = widget.record.resolution;
    final target = resolve ? 'resolved' : status;
    if (target == 'resolved') {
      final text = TextEditingController(text: resolution);
      final form = GlobalKey<FormState>();
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Resolve case'),
          content: Form(
            key: form,
            child: TextFormField(
              key: const Key('resolution-summary'),
              controller: text,
              minLines: 3,
              maxLines: 6,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Resolution summary',
                hintText: 'Explain the outcome for the visitor.',
              ),
              validator: (v) => v == null || v.trim().length < 5
                  ? 'Enter a summary of at least 5 characters.'
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, text.text.trim());
                }
              },
              child: const Text('Confirm Resolution'),
            ),
          ],
        ),
      );
      if (result == null || !mounted) return;
      resolution = result;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.updateCase(
        base,
        status: target,
        priority: priority,
        category: category,
        assigneeUid: assignee,
        assigneeName: assignee.isEmpty
            ? ''
            : assignee == widget.repository.userId
            ? widget.adminName
            : widget.record.assigneeName,
        resolution: resolution,
      );
      if (mounted) {
        setState(() {
          dirty = false;
          status = target;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = bookingError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    String label,
    String value,
    Map<String, String> choices,
    ValueChanged<String> onChanged,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$label-$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label, isDense: true),
    items: choices.entries
        .map(
          (e) => DropdownMenuItem(
            value: e.key,
            child: Text(
              e.value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        )
        .toList(),
    onChanged: busy
        ? null
        : (v) => setState(() {
            onChanged(v!);
            dirty = true;
          }),
  );
  @override
  Widget build(BuildContext context) => AdminCard(
    padding: const EdgeInsets.all(15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.record.reference,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SupportStatus(widget.record.status),
            IconButton(
              tooltip: 'Close case',
              onPressed: busy ? null : widget.onClose,
              icon: const Icon(Icons.close, size: 18, color: adminMuted),
            ),
          ],
        ),
        Text(
          widget.record.subject,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Submitted ${supportTime(widget.record.createdAt)} · Visitor App',
          style: const TextStyle(fontSize: 10, color: adminMuted),
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            for (final label in ['Details', 'Internal Notes', 'Timeline'])
              Expanded(
                child: TextButton(
                  onPressed: busy ? null : () => setState(() => tab = label),
                  style: TextButton.styleFrom(
                    foregroundColor: tab == label ? adminRose : adminMuted,
                    backgroundColor: tab == label
                        ? const Color(0xFFFFF2EF)
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 11,
                    ),
                  ),
                  child: Text(label, style: const TextStyle(fontSize: 11)),
                ),
              ),
          ],
        ),
        const Divider(color: adminBorder),
        if (tab == 'Details') ...[
          const Text(
            'Visitor Conversation',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 13),
          SupportConversation(
            record: widget.record,
            repository: widget.repository,
          ),
          if (widget.record.orderId.isNotEmpty)
            FutureBuilder<TicketOrder?>(
              future: booking,
              builder: (context, snapshot) {
                final order = snapshot.data;
                if (order == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: AdminCard(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 17,
                              color: adminRose,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Related Booking',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        SelectableText(
                          order.reference,
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${money(order.totalMinor)} · ${order.paymentMethod.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: adminMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          Text(
            widget.record.contactEmail.isEmpty
                ? 'Contact preference: in-app updates'
                : 'Contact email: ${widget.record.contactEmail}',
            style: const TextStyle(fontSize: 10, color: adminMuted),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: field('Assigned To', assignee, {
                  '': 'Unassigned',
                  widget.repository.userId!: '${widget.adminName} (me)',
                  if (widget.record.assigneeUid.isNotEmpty &&
                      widget.record.assigneeUid != widget.repository.userId)
                    widget.record.assigneeUid: widget.record.assigneeName,
                }, (v) => assignee = v),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: field(
                  'Priority',
                  priority,
                  supportPriorities,
                  (v) => priority = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: field(
                  'Status',
                  status,
                  supportStatuses,
                  (v) => status = v,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: field('Category', category, {
                  for (final item in supportCategories) item: item,
                }, (v) => category = v),
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          const SizedBox(height: 13),
          AdminButton(
            busy ? 'Saving…' : 'Save Changes',
            onPressed: busy ? null : save,
            outlined: true,
          ),
          if (widget.record.status == 'resolved') ...[
            const SizedBox(height: 16),
            const Text(
              'Resolution',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 7),
            Text(
              widget.record.resolution,
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ] else ...[
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Response Templates',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'received',
                  child: Text(
                    'Acknowledge request',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                DropdownMenuItem(
                  value: 'details',
                  child: Text(
                    'Request more details',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                DropdownMenuItem(
                  value: 'update',
                  child: Text(
                    'Progress update',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
              onChanged: busy
                  ? null
                  : (value) => replyKey.currentState?.useTemplate(
                      {
                        'received':
                            'Thank you for contacting us. We have received your request and our team is reviewing it.',
                        'details':
                            'Could you share the visit date, approximate time and booking reference so we can investigate? Please do not include passwords or card numbers.',
                        'update':
                            'Our team is looking into your request. We will update this conversation when we have more information.',
                      }[value]!,
                    ),
            ),
            const SizedBox(height: 13),
            SupportReplyComposer(
              key: replyKey,
              record: widget.record,
              repository: widget.repository,
              onBusy: (v) {
                if (mounted) setState(() => busy = v);
              },
            ),
            const SizedBox(height: 13),
            AdminButton(
              'Resolve Case',
              onPressed: busy ? null : () => save(resolve: true),
              icon: Icons.task_alt,
            ),
          ],
        ] else if (tab == 'Internal Notes') ...[
          const Text(
            'Private staff notes',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          const Text(
            'Visible only to authorised administrators.',
            style: TextStyle(fontSize: 11, color: adminMuted),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<SupportMessage>>(
            stream: widget.repository.notes(widget.record.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Unable to load internal notes.',
                  style: TextStyle(color: Colors.red),
                );
              }
              return Column(
                children: [
                  for (final note in snapshot.data ?? <SupportMessage>[])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AdminCard(
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFFFFFAEC),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.author,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              supportTime(note.createdAt),
                              style: const TextStyle(
                                fontSize: 9,
                                color: adminMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              note.body,
                              style: const TextStyle(fontSize: 12, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          SupportReplyComposer(
            key: ValueKey('notes-${widget.record.id}'),
            record: widget.record,
            repository: widget.repository,
            internal: true,
            onBusy: (v) {
              if (mounted) setState(() => busy = v);
            },
          ),
        ] else
          SupportTimeline(record: widget.record, repository: widget.repository),
      ],
    ),
  );
}
