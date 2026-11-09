import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../attractions/models/park_time.dart';
import '../../attractions/widgets/attraction_widgets.dart';
import '../../reservations/widgets/reservation_widgets.dart' show returnWindow;
import '../portal/admin_panel.dart';
import '../portal/admin_theme.dart';
import 'data/admin_reservation_repository.dart';

class ReservationsAdminPage extends StatefulWidget {
  const ReservationsAdminPage({super.key, required this.watchDay});

  final Stream<List<AdminReservation>> Function(DateTime day) watchDay;

  @override
  State<ReservationsAdminPage> createState() => _ReservationsAdminPageState();
}

enum _BookingStatus {
  confirmed('confirmed', 'Confirmed', Icons.event_available, Color(0xFF287644)),
  checkedIn('checked_in', 'Checked in', Icons.how_to_reg, Color(0xFF305E9B)),
  cancelled('cancelled', 'Cancelled', Icons.event_busy, Color(0xFFAB3F46)),
  missed('no_show', 'Missed', Icons.event_busy_outlined, Color(0xFFAB772B));

  const _BookingStatus(this.value, this.label, this.icon, this.color);

  final String value, label;
  final IconData icon;
  final Color color;
}

class _ReservationsAdminPageState extends State<ReservationsAdminPage> {
  static const _pageSize = 10;
  final _search = TextEditingController();
  late DateTime _day = DateUtils.dateOnly(ParkTime.local(DateTime.now()));
  late Stream<List<AdminReservation>> _bookings = widget.watchDay(_day);
  _BookingStatus? _status;
  int _page = 0;

  @override
  void didUpdateWidget(ReservationsAdminPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.watchDay != widget.watchDay) _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    _page = 0;
    _bookings = widget.watchDay(_day);
  }

  Future<void> _chooseDate() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _day,
      currentDate: ParkTime.local(DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Select visit date',
    );
    if (!mounted || day == null || DateUtils.isSameDay(day, _day)) return;
    setState(() {
      _day = day;
      _reload();
    });
  }

  String _dateLabel(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  Widget _badge(String value) {
    final status = _BookingStatus.values
        .where((s) => s.value == value)
        .firstOrNull;
    final color = status?.color ?? AdminTheme.muted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(status?.label ?? 'Unknown', style: TextStyle(color: color)),
      ),
    );
  }

  void _showDetails(AdminReservation item) {
    final booking = item.booking;
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Reservation details'),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        scrollable: true,
        content: SizedBox(
          width: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.attractionName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              _badge(booking.status),
              const SizedBox(height: 12),
              for (final (label, value) in [
                ('Visit date', ParkTime.date(booking.startsAt)),
                (
                  'Return window (Kuala Lumpur)',
                  returnWindow(booking.startsAt, booking.endsAt),
                ),
                if (item.visitorName != null) ('Visitor', item.visitorName!),
                (
                  'Visitor ID',
                  item.visitorId.isEmpty ? 'Unavailable' : item.visitorId,
                ),
                ('Reservation ID', booking.id),
                ('Ticket ID', booking.ticketId),
              ]) ...[
                const SizedBox(height: 10),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                SelectableText(value),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _overview(List<AdminReservation>? records) => AdminOverviewGrid(
    cards: [
      AdminOverviewCard(
        label: 'Total Reservations',
        note: 'For the selected visit date',
        count: records?.length,
        icon: Icons.confirmation_number_outlined,
        color: AdminTheme.rose,
        countColor: AdminTheme.ink,
      ),
      for (final status in _BookingStatus.values)
        AdminOverviewCard(
          label: status.label,
          note: switch (status) {
            _BookingStatus.confirmed => 'Confirmed return times',
            _BookingStatus.checkedIn => 'Visitors checked in',
            _BookingStatus.cancelled => 'Cancelled bookings',
            _BookingStatus.missed => 'Missed return windows',
          },
          count: records
              ?.where((item) => item.booking.status == status.value)
              .length,
          icon: status.icon,
          color: status.color,
        ),
    ],
  );

  Widget _filters() => Padding(
    padding: const EdgeInsets.all(16),
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 350,
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search visitor, attraction or ID',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
            onChanged: (_) => setState(() => _page = 0),
          ),
        ),
        SizedBox(
          width: 168,
          child: DropdownButtonFormField<_BookingStatus>(
            key: ValueKey(_status),
            initialValue: _status,
            isExpanded: true,
            items: [
              const DropdownMenuItem(child: Text('All Statuses')),
              for (final status in _BookingStatus.values)
                DropdownMenuItem(value: status, child: Text(status.label)),
            ],
            onChanged: (value) => setState(() {
              _status = value;
              _page = 0;
            }),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _chooseDate,
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminTheme.ink,
            minimumSize: const Size(0, 56),
            side: const BorderSide(color: AdminTheme.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text('Visit date  ${_dateLabel(_day)}'),
        ),
        IconButton(
          tooltip: 'Refresh reservations',
          onPressed: () => setState(_reload),
          icon: const Icon(Icons.refresh, color: AdminTheme.muted),
        ),
        if (_search.text.isNotEmpty || _status != null)
          TextButton(
            onPressed: () => setState(() {
              _search.clear();
              _status = null;
              _page = 0;
            }),
            child: const Text('Clear filters'),
          ),
      ],
    ),
  );

  Widget _cell(String value, {double width = 136}) => SizedBox(
    width: width,
    child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  Widget _table(List<AdminReservation> records) {
    final query = _search.text.trim().toLowerCase();
    final visible = records.where((item) {
      final booking = item.booking;
      return (_status == null || _status!.value == booking.status) &&
          [
            booking.attractionName,
            booking.id,
            booking.ticketId,
            item.visitorId,
            item.visitorName ?? '',
          ].any((value) => value.toLowerCase().contains(query));
    }).toList();
    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: AttractionMessage(
          icon: records.isEmpty
              ? Icons.event_available_outlined
              : Icons.search_off,
          title: records.isEmpty
              ? 'No reservations for this date'
              : 'No matching reservations',
          message: records.isEmpty
              ? 'Saved bookings appear here. Choose a different visit date to see other bookings.'
              : 'Change the search or status filter to see more bookings.',
        ),
      );
    }
    final pages = (visible.length / _pageSize).ceil();
    final page = math.min(_page, pages - 1);
    final start = page * _pageSize;
    final end = math.min(start + _pageSize, visible.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: 20,
                horizontalMargin: 18,
                dataRowMinHeight: 57,
                dataRowMaxHeight: 68,
                dividerThickness: .5,
                headingTextStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.ink,
                ),
                dataTextStyle: const TextStyle(
                  fontSize: 12,
                  color: AdminTheme.ink,
                ),
                columns: const [
                  DataColumn(label: Text('Reservation ID')),
                  DataColumn(label: Text('Visitor')),
                  DataColumn(label: Text('Attraction')),
                  DataColumn(label: Text('Return window')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final item in visible.getRange(start, end))
                    DataRow(
                      key: ValueKey(item.booking.id),
                      cells: [
                        DataCell(
                          _cell(item.booking.id, width: 122),
                          onTap: () => _showDetails(item),
                        ),
                        DataCell(
                          _cell(
                            item.visitorName ??
                                (item.visitorId.isEmpty
                                    ? 'Unavailable'
                                    : item.visitorId),
                          ),
                        ),
                        DataCell(_cell(item.booking.attractionName)),
                        DataCell(
                          Text(
                            returnWindow(
                              item.booking.startsAt,
                              item.booking.endsAt,
                            ),
                          ),
                        ),
                        DataCell(_badge(item.booking.status)),
                        DataCell(
                          IconButton(
                            tooltip: 'View details for ${item.booking.id}',
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 18,
                            ),
                            onPressed: () => _showDetails(item),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Wrap(
            spacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Showing ${start + 1} to $end of ${visible.length} results',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: page == 0
                        ? null
                        : () => setState(() => _page = page - 1),
                    icon: const Icon(Icons.chevron_left, size: 20),
                  ),
                  Text(
                    'Page ${page + 1} of $pages',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed: page + 1 >= pages
                        ? null
                        : () => setState(() => _page = page + 1),
                    icon: const Icon(Icons.chevron_right, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: StreamBuilder<List<AdminReservation>>(
      key: ValueKey(_day),
      stream: _bookings,
      builder: (context, snapshot) {
        final records = snapshot.connectionState == ConnectionState.waiting
            ? null
            : snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(28),
          children: [
            Text(
              'Reservation Management',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'View virtual queue bookings by visit date. Times shown in Kuala Lumpur time.',
              style: TextStyle(color: AdminTheme.muted),
            ),
            const SizedBox(height: 24),
            _overview(records),
            const SizedBox(height: 24),
            AdminPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _filters(),
                  const Divider(),
                  if (snapshot.hasError)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: AttractionMessage(
                        icon: Icons.cloud_off_outlined,
                        title: 'Could not load reservations',
                        message: attractionErrorMessage(snapshot.error!),
                        action: 'Try again',
                        onAction: () => setState(_reload),
                      ),
                    )
                  else if (records == null)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    _table(records),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
