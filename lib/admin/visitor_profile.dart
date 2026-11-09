import 'package:flutter/material.dart';
import '../visitor/models/tickets.dart';
import 'admin_models.dart';
import 'admin_store.dart';
import 'admin_widgets.dart';

class VisitorProfile extends StatefulWidget {
  final String visitorId;
  final AdminStore store;
  final VoidCallback onBack;
  final ValueChanged<ParkTicket> onTicket;
  const VisitorProfile({
    super.key,
    required this.visitorId,
    required this.store,
    required this.onBack,
    required this.onTicket,
  });
  @override
  State<VisitorProfile> createState() => _VisitorProfileState();
}

class _VisitorProfileState extends State<VisitorProfile> {
  String tab = 'Overview';
  TextEditingController? note;
  @override
  void dispose() {
    note?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.store.visitors
        .where((v) => v.id == widget.visitorId)
        .firstOrNull;
    if (v == null) {
      return const AdminEmpty(
        'Visitor unavailable',
        'Return to the visitor list and refresh.',
      );
    }
    note ??= TextEditingController(text: v.note);
    final tickets = widget.store.visitorTickets(v),
        orders = widget.store.visitorOrders(v.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton(
              onPressed: widget.onBack,
              child: const Text('Visitors', style: TextStyle(color: adminRose)),
            ),
            const Text(' /  ', style: TextStyle(color: adminMuted)),
            Text(
              visitorReference(v.id),
              style: const TextStyle(color: adminMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'VISITOR PROFILE DETAILS',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        AdminCard(
          child: Wrap(
            spacing: 24,
            runSpacing: 18,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AdminAvatar(v.name, photo: v.photo, radius: 48),
              SizedBox(
                width: 225,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.name,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    _iconText(Icons.mail_outline, v.email),
                    const SizedBox(height: 8),
                    _iconText(
                      Icons.phone_outlined,
                      v.phone.isEmpty ? 'Not provided' : v.phone,
                    ),
                  ],
                ),
              ),
              AdminBadge(
                '${titleCase(v.membership)} Member',
                tone: v.membership,
              ),
              AdminBadge(titleCase(v.status)),
              AdminBadge('Risk: ${titleCase(v.risk)}', tone: v.risk),
              AdminButton(
                'Edit Profile',
                icon: Icons.edit_outlined,
                outlined: true,
                onPressed: () => editVisitor(context, widget.store, v),
              ),
              PopupMenuButton<String>(
                tooltip: 'More visitor actions',
                onSelected: (value) => widget.store.perform(
                  () =>
                      widget.store.repository.setWatchlist([v], !v.watchlisted),
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'watch',
                    child: Text(
                      v.watchlisted
                          ? 'Remove from Watchlist'
                          : 'Add to Watchlist',
                    ),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('More Actions', style: TextStyle(fontSize: 12)),
                      Icon(Icons.keyboard_arrow_down, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in [
                'Overview',
                'Activity',
                'Tickets & Orders',
                'Payments',
                'Security',
              ])
                InkWell(
                  onTap: () => setState(() => tab = item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: tab == item ? adminRose : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        color: tab == item ? adminRose : adminMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 18),
        if (tab == 'Overview')
          LayoutBuilder(
            builder: (context, c) {
              final leftWidth = c.maxWidth >= 950
                  ? (c.maxWidth - 16) * .6
                  : c.maxWidth;
              final left = Column(
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: leftWidth < 650
                            ? leftWidth
                            : (leftWidth - 16) * .6,
                        child: AdminCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _heading(
                                Icons.person_outline,
                                'Personal Information',
                              ),
                              const SizedBox(height: 18),
                              _detail(
                                'Date of Birth',
                                v.birthday == null
                                    ? 'Not provided'
                                    : displayParkDate(
                                        visitDateString(v.birthday!),
                                      ),
                              ),
                              _detail('Gender', v.gender),
                              _detail('Height', v.height),
                              _detail(
                                'Preferred Food',
                                v.food.isEmpty
                                    ? 'Not provided'
                                    : v.food.join(', '),
                              ),
                              _detail(
                                'Interests',
                                v.interests.isEmpty
                                    ? 'Not provided'
                                    : v.interests.join(', '),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: leftWidth < 650
                            ? leftWidth
                            : (leftWidth - 16) * .4,
                        child: AdminCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _heading(Icons.star_outline, 'Loyalty'),
                              const SizedBox(height: 25),
                              const Text(
                                'Total Points',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${v.points}',
                                style: const TextStyle(
                                  color: adminRose,
                                  fontSize: 37,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Text(
                                'points',
                                style: TextStyle(
                                  color: adminMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _heading(
                          Icons.confirmation_number_outlined,
                          'Current Tickets',
                        ),
                        const SizedBox(height: 14),
                        if (tickets
                            .where((t) => t.filter == 'Upcoming')
                            .isEmpty)
                          const Text(
                            'No active park tickets.',
                            style: TextStyle(color: adminMuted, fontSize: 13),
                          ),
                        for (final ticket
                            in tickets
                                .where((t) => t.filter == 'Upcoming')
                                .take(3))
                          _ticket(ticket),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _heading(Icons.note_alt_outlined, 'Admin Note'),
                        const SizedBox(height: 12),
                        TextField(
                          controller: note,
                          maxLines: 3,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            hintText: 'Add an admin note about this visitor…',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: AdminButton(
                            'Save Note',
                            onPressed: widget.store.busy
                                ? null
                                : () async {
                                    final done = await widget.store.perform(
                                      () => widget.store.repository.saveVisitor(
                                        v,
                                        {},
                                        {'notes': note!.text},
                                      ),
                                    );
                                    if (done && context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Admin note saved.'),
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final right = Column(
                children: [
                  AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _heading(Icons.badge_outlined, 'Account Summary'),
                        const SizedBox(height: 18),
                        _detail('Member Since', adminDateLabel(v.joined)),
                        _detail(
                          'Last Seen',
                          adminTimeLabel(widget.store.lastSeen(v.id)),
                        ),
                        _detail('Account Status', titleCase(v.status)),
                        _detail(
                          'Face Recognition',
                          v.data['faceRecognitionEnabled'] == true
                              ? 'Active'
                              : 'Not enabled',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _heading(Icons.history, 'Recent Activity'),
                        const SizedBox(height: 18),
                        ..._activity(v).take(6),
                      ],
                    ),
                  ),
                ],
              );
              return c.maxWidth >= 950
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: left),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: right),
                      ],
                    )
                  : Column(children: [left, const SizedBox(height: 16), right]);
            },
          ),
        if (tab == 'Activity')
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading(Icons.history, 'Visitor Activity'),
                const SizedBox(height: 18),
                ..._activity(v),
              ],
            ),
          ),
        if (tab == 'Tickets & Orders')
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading(Icons.confirmation_number_outlined, 'Park Tickets'),
                const SizedBox(height: 15),
                if (tickets.isEmpty)
                  const AdminEmpty(
                    'No tickets yet',
                    'This visitor has no linked park tickets.',
                  ),
                for (final t in tickets) _ticket(t),
              ],
            ),
          ),
        if (tab == 'Payments')
          AdminCard(
            child: orders.isEmpty
                ? const AdminEmpty(
                    'No booking payments',
                    'Completed booking amounts will appear here.',
                  )
                : AdminTable(
                    minWidth: 700,
                    columns: const [
                      DataColumn(label: Text('Booking ID')),
                      DataColumn(label: Text('Visit Date')),
                      DataColumn(label: Text('Guests')),
                      DataColumn(label: Text('Amount')),
                      DataColumn(label: Text('Method')),
                    ],
                    rows: [
                      for (final o in orders)
                        DataRow(
                          cells: [
                            DataCell(Text(o.reference)),
                            DataCell(Text(displayParkDate(o.visitDate))),
                            DataCell(Text('${o.quantity}')),
                            DataCell(Text(money(o.totalMinor))),
                            DataCell(Text(o.paymentMethod)),
                          ],
                        ),
                    ],
                  ),
          ),
        if (tab == 'Security')
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading(Icons.shield_outlined, 'Account Access'),
                const SizedBox(height: 18),
                _detail('Visitor ID', v.id),
                _detail('Account Status', titleCase(v.status)),
                _detail(
                  'Watchlist',
                  v.watchlisted ? 'On watchlist' : 'Not watchlisted',
                ),
                _detail('Risk Level', titleCase(v.risk)),
                _detail(
                  'Access Reason',
                  v.access['reason'] as String? ?? 'Not recorded',
                ),
                _detail(
                  'Last Access Update',
                  adminTimeLabel(adminDate(v.access['updatedAt'])),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _heading(IconData icon, String title) => Row(
    children: [
      Icon(icon, color: adminRose, size: 21),
      const SizedBox(width: 11),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
  Widget _iconText(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 15),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: adminMuted),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, color: adminMuted),
          ),
        ),
      ],
    ),
  );
  Widget _ticket(ParkTicket t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AdminCard(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.asset(
              ticketCastleAsset,
              width: 85,
              height: 65,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.packageName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  displayParkDate(t.visitDate),
                  style: const TextStyle(color: adminMuted, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  t.reference,
                  style: const TextStyle(fontSize: 10, color: adminMuted),
                ),
              ],
            ),
          ),
          AdminBadge(t.filter),
          AdminButton(
            'View Details',
            outlined: true,
            onPressed: () => widget.onTicket(t),
          ),
        ],
      ),
    ),
  );
  List<Widget> _activity(AdminVisitor v) {
    final events =
        <({DateTime? at, String title, String detail})>[
          for (final s in widget.store.sessions.where(
            (s) => s.ownerUid == v.id,
          ))
            (
              at: s.at,
              title: 'Visitor session',
              detail: 'Opened the visitor application',
            ),
          for (final o in widget.store.visitorOrders(v.id))
            (
              at: o.createdAt,
              title: 'Ticket booking',
              detail: '${o.quantity} ticket(s) · ${money(o.totalMinor)}',
            ),
          for (final a in widget.store.admissions.where(
            (a) => a.ownerUid == v.id,
          ))
            (
              at: a.at,
              title: 'Park admission',
              detail: 'Ticket scanned at park entrance',
            ),
        ]..sort(
          (a, b) => (b.at ?? DateTime(1970)).compareTo(a.at ?? DateTime(1970)),
        );
    if (events.isEmpty) {
      return [
        const Text(
          'No activity recorded yet.',
          style: TextStyle(color: adminMuted, fontSize: 13),
        ),
      ];
    }
    return events
        .map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.circle, color: adminRose, size: 10),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adminTimeLabel(e.at),
                        style: const TextStyle(color: adminMuted, fontSize: 10),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        e.detail,
                        style: const TextStyle(color: adminMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}

Future<void> editVisitor(
  BuildContext context,
  AdminStore store,
  AdminVisitor visitor,
) async {
  final name = TextEditingController(text: visitor.name),
      phone = TextEditingController(text: visitor.phone);
  String membership = visitor.membership, risk = visitor.risk;
  final form = GlobalKey<FormState>();
  final data =
      await showDialog<
        ({Map<String, dynamic> fields, Map<String, dynamic> metadata})
      >(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Edit Visitor Profile'),
            content: SizedBox(
              width: 470,
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                        ),
                        maxLength: 100,
                        validator: (v) => (v ?? '').trim().length < 2
                            ? 'Enter a full name.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                        ),
                        validator: (v) {
                          final number = (v ?? '').replaceAll(
                            RegExp(r'[\s-]'),
                            '',
                          );
                          return number.isEmpty ||
                                  RegExp(r'^\+?[0-9]{9,15}$').hasMatch(number)
                              ? null
                              : 'Enter a valid phone number.';
                        },
                      ),
                      const SizedBox(height: 20),
                      AdminSelect(
                        value: membership,
                        options: const {
                          'normal': 'Normal Member',
                          'bronze': 'Bronze Member',
                          'silver': 'Silver Member',
                          'gold': 'Gold Member',
                        },
                        onChanged: (v) => setState(() => membership = v),
                        width: 470,
                      ),
                      const SizedBox(height: 16),
                      AdminSelect(
                        value: risk,
                        options: const {
                          'normal': 'Risk: Normal',
                          'review': 'Risk: Review',
                          'high': 'Risk: High',
                        },
                        onChanged: (v) => setState(() => risk = v),
                        width: 470,
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
                'Save Changes',
                onPressed: () {
                  if (form.currentState!.validate()) {
                    Navigator.pop(context, (
                      fields: <String, dynamic>{
                        'fullName': name.text.trim(),
                        'phoneNumber': phone.text.replaceAll(
                          RegExp(r'[\s-]'),
                          '',
                        ),
                      },
                      metadata: <String, dynamic>{
                        'membership': membership,
                        'riskLevel': risk,
                      },
                    ));
                  }
                },
              ),
            ],
          ),
        ),
      );
  name.dispose();
  phone.dispose();
  if (data == null || !context.mounted) return;
  final done = await store.perform(
    () => store.repository.saveVisitor(visitor, data.fields, data.metadata),
  );
  if (done && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Visitor profile updated.')));
  }
}
