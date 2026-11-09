import 'package:flutter/material.dart';
import '../visitor/models/tickets.dart';
import 'admin_models.dart';
import 'admin_repository.dart';
import 'admin_store.dart';
import 'admin_widgets.dart';
import 'visitor_management.dart';
import 'visitor_profile.dart';
import 'ticket_management.dart';
import 'package_management.dart';
import 'admission_screen.dart';
import 'support_management.dart';
import 'attractions/attractions_admin_page.dart';
import 'reservations/reservations_admin_page.dart';
import 'portal/admin_theme.dart';
import 'ride_entry_page.dart';
import 'photos/photo_management.dart';
import 'operations/park_management_page.dart';
import 'operations/reports_page.dart';
import 'operations/landmark_management_page.dart';
import 'operations/anomaly_review_page.dart';
import 'operations/crowd_monitoring_page.dart';

class AdminShell extends StatefulWidget {
  final AdminRepository repository;
  final String adminName, adminEmail;
  final Future<void> Function() onSignOut;
  const AdminShell({
    super.key,
    required this.repository,
    required this.adminName,
    required this.adminEmail,
    required this.onSignOut,
  });
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late final repository = widget.repository;
  late final store = AdminStore(widget.repository);
  late final support = widget.repository.supportRepository;
  late final photos = widget.repository.photoRepository;
  late final park = widget.repository.parkRepository;
  final scaffold = GlobalKey<ScaffoldState>();
  final globalSearch = TextEditingController();
  final facilityNavigator = GlobalKey<NavigatorState>();
  late final facilities = repository.facilityStore,
      facilitySlots = repository.facilitySlots,
      facilityAccess = repository.facilityAccess;
  String page = 'visitors', query = '';
  String? visitorId;
  ParkTicket? scanTicket;
  @override
  void initState() {
    super.initState();
    store.start();
  }

  @override
  void dispose() {
    globalSearch.dispose();
    store.dispose();
    repository.dispose();
    super.dispose();
  }

  void open(String value) {
    if (page == 'facilities' &&
        (facilityNavigator.currentState?.canPop() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Save or close the facility editor before switching sections.',
          ),
        ),
      );
      return;
    }
    if (value == 'photo-kiosk') {
      Navigator.pushNamed(context, '/kiosk');
      return;
    }
    setState(() {
      page = value;
      visitorId = null;
      query = '';
      if (value == 'validation') scanTicket = null;
    });
    scaffold.currentState?.closeDrawer();
  }

  void validate(ParkTicket t) => setState(() {
    scanTicket = t;
    page = 'validation';
  });
  void search(String value) {
    if (value.trim().isEmpty) return;
    setState(() {
      query = value.trim();
      visitorId = null;
      page = 'visitors';
    });
  }

  Widget sidebar() => Container(
    width: 250,
    decoration: const BoxDecoration(
      color: Color(0xFFFCF7F5),
      border: Border(right: BorderSide(color: adminBorder)),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(35, 28, 35, 28),
          child: Image.asset(
            'assets/images/Theme_Park_Main_Logo.png',
            height: 145,
            fit: BoxFit.contain,
          ),
        ),
        Expanded(
          child: ListView(
            key: const Key('admin-sidebar-list'),
            padding: EdgeInsets.zero,
            children: [
              for (final item in [
                ('dashboard', 'Dashboard', Icons.dashboard_outlined),
                ('visitors', 'Visitors', Icons.people_outline),
                (
                  'tickets',
                  'Tickets & Orders',
                  Icons.confirmation_number_outlined,
                ),
                ('packages', 'Pass Packages', Icons.local_activity_outlined),
                ('photos', 'Smart Photos', Icons.photo_library_outlined),
                ('promotions', 'Promotions & Rewards', Icons.redeem_outlined),
                ('reports', 'Reports & Analytics', Icons.insights_outlined),
                ('crowd', 'Crowd Monitoring', Icons.hub_outlined),
                ('landmarks', 'Landmark References', Icons.location_searching),
                ('anomalies', 'Unusual Activity', Icons.policy_outlined),
                ('photo-kiosk', 'Photo Kiosk', Icons.local_printshop_outlined),
                ('facilities', 'Park Facilities', Icons.attractions_outlined),
                (
                  'reservations',
                  'Reservations',
                  Icons.event_available_outlined,
                ),
                ('validation', 'Ticket Validation', Icons.qr_code_scanner),
                (
                  'ride-entry',
                  'Attraction Check-in',
                  Icons.sensor_door_outlined,
                ),
                (
                  'activity',
                  'Activity Monitoring',
                  Icons.monitor_heart_outlined,
                ),
                ('support', 'Feedback & Complaints', Icons.forum_outlined),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => open(item.$1),
                      child: Container(
                        height: 49,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: page == item.$1
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFD07B7E),
                                    Color(0xFFC18A82),
                                  ],
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.$3,
                              size: 22,
                              color: page == item.$1 ? Colors.white : adminDark,
                            ),
                            const SizedBox(width: 17),
                            Expanded(
                              child: Text(
                                item.$2,
                                style: TextStyle(
                                  color: page == item.$1
                                      ? Colors.white
                                      : adminDark,
                                  fontSize: 13,
                                  fontWeight: page == item.$1
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: Opacity(
            opacity: .4,
            child: Image.asset(
              'assets/images/Background.png',
              fit: BoxFit.cover,
              width: 250,
              alignment: Alignment.bottomCenter,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 22),
          child: Text(
            'Version 1.0.0',
            style: TextStyle(color: adminMuted, fontSize: 11),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 1050;
        Widget body;
        if (store.loading) {
          body = const Center(
            child: Padding(
              padding: EdgeInsets.all(70),
              child: CircularProgressIndicator(color: adminRose),
            ),
          );
        } else if (page == 'visitors') {
          body = visitorId == null
              ? VisitorManagement(
                  key: ValueKey(query),
                  store: store,
                  initialQuery: query,
                  onOpen: (v) => setState(() => visitorId = v.id),
                )
              : VisitorProfile(
                  key: ValueKey(visitorId),
                  visitorId: visitorId!,
                  store: store,
                  onBack: () => setState(() => visitorId = null),
                  onTicket: (t) => showAdminTicket(context, t, validate),
                );
        } else if (page == 'facilities') {
          body = facilities == null || facilityAccess == null
              ? const AdminCard(
                  child: Text(
                    'Facility management is unavailable. Please reopen the portal.',
                  ),
                )
              : SizedBox(
                  height: (MediaQuery.sizeOf(context).height - 126)
                      .clamp(430, 2000)
                      .toDouble(),
                  child: Navigator(
                    key: facilityNavigator,
                    onGenerateRoute: (_) => MaterialPageRoute(
                      builder: (_) => Theme(
                        data: AdminTheme.data,
                        child: Scaffold(
                          backgroundColor: AdminTheme.background,
                          body: SingleChildScrollView(
                            child: AttractionsAdminPage(
                              store: facilities!,
                              adminAccess: facilityAccess!,
                              slotReader: facilitySlots,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
        } else if (page == 'reservations') {
          body = ReservationsAdminPage(watchDay: repository.reservations);
        } else if (page == 'tickets') {
          body = TicketManagement(store: store, onValidate: validate);
        } else if (page == 'ride-entry') {
          body = repository.visitRepository == null
              ? const AdminCard(
                  child: Text(
                    'Attraction check-in is unavailable. Please reopen the portal.',
                  ),
                )
              : RideEntryPage(repository: repository.visitRepository!);
        } else if (page == 'packages') {
          body = PackageManagement(store: store);
        } else if (page == 'photos') {
          body = photos == null
              ? const AdminCard(
                  child: Text(
                    'Unable to load photo management. Please reopen the portal.',
                  ),
                )
              : PhotoManagement(repository: photos!, visitors: store.visitors);
        } else if (page == 'anomalies') {
          body = park == null
              ? const AdminEmpty(
                  'Unable to load activity review',
                  'Please reopen the portal.',
                )
              : AnomalyReviewPage(
                  repository: park!,
                  visitors: store.visitors,
                  onVisitor: (id) => setState(() {
                    page = 'visitors';
                    visitorId = id;
                  }),
                );
        } else if (page == 'promotions' ||
            page == 'reports' ||
            page == 'crowd' ||
            page == 'landmarks') {
          body = park == null
              ? const AdminEmpty(
                  'Unable to load park management',
                  'Please reopen the portal.',
                )
              : page == 'landmarks'
              ? LandmarkManagementPage(repository: park!)
              : page == 'reports'
              ? ParkReportsPage(repository: park!)
              : page == 'crowd'
              ? CrowdMonitoringPage(
                  repository: park!,
                  onManageFacilities: () => open('facilities'),
                )
              : ParkManagementPage(repository: park!);
        } else if (page == 'validation') {
          body = AdmissionScreen(
            key: ValueKey(scanTicket?.id ?? 'scan'),
            store: store,
            initialTicket: scanTicket,
          );
        } else if (page == 'support') {
          body = support == null
              ? const AdminCard(
                  child: Text(
                    'Unable to load support. Please reopen the portal.',
                  ),
                )
              : SupportManagement(
                  repository: support!,
                  adminName: widget.adminName,
                );
        } else if (page == 'activity') {
          body = AdminActivityScreen(store: store);
        } else {
          body = AdminDashboard(store: store, onOpen: open);
        }
        return Scaffold(
          key: scaffold,
          drawer: wide
              ? null
              : Drawer(width: 250, child: SafeArea(child: sidebar())),
          body: Row(
            children: [
              if (wide) sidebar(),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 76,
                      padding: EdgeInsets.symmetric(horizontal: wide ? 25 : 14),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: adminBorder)),
                      ),
                      child: Row(
                        children: [
                          if (!wide)
                            IconButton(
                              tooltip: 'Open admin navigation',
                              onPressed: () =>
                                  scaffold.currentState?.openDrawer(),
                              icon: const Icon(Icons.menu),
                            ),
                          Expanded(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: TextField(
                                key: const Key('admin-global-search'),
                                controller: globalSearch,
                                onSubmitted: search,
                                decoration: InputDecoration(
                                  hintText: wide
                                      ? 'Search visitors by name, email or ID…'
                                      : 'Search visitors…',
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 21,
                                    color: adminMuted,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: 'Search visitors',
                                    onPressed: () => search(globalSearch.text),
                                    icon: const Icon(
                                      Icons.keyboard_return,
                                      size: 16,
                                      color: adminMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          IconButton(
                            tooltip: 'Recent account activity',
                            onPressed: () => open('activity'),
                            icon: Badge(
                              isLabelVisible: store.flagged > 0,
                              label: Text('${store.flagged}'),
                              backgroundColor: adminRose,
                              child: const Icon(
                                Icons.notifications_none,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          AdminAvatar(widget.adminName, radius: 20),
                          if (c.maxWidth >= 650) ...[
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.adminName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Administrator',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: adminMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          PopupMenuButton<String>(
                            tooltip: 'Administrator account',
                            onSelected: (value) {
                              if (value == 'signout') {
                                widget.onSignOut();
                              } else {
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/',
                                  (route) => false,
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                enabled: false,
                                child: Text(
                                  widget.adminEmail,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'visitor',
                                child: Text('Visitor App'),
                              ),
                              const PopupMenuItem(
                                value: 'signout',
                                child: Text('Sign Out'),
                              ),
                            ],
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (store.busy)
                      const LinearProgressIndicator(
                        color: adminRose,
                        minHeight: 2,
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(wide ? 25 : 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (store.error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: AdminCard(
                                  color: const Color(0xFFFFEFEE),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                        size: 21,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          store.error!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            body,
                            const SizedBox(height: 15),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class AdminDashboard extends StatelessWidget {
  final AdminStore store;
  final ValueChanged<String> onOpen;
  const AdminDashboard({super.key, required this.store, required this.onOpen});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AdminHeading(
        'Park Operations Overview',
        'Visitor accounts, ticket bookings and park admissions',
      ),
      const SizedBox(height: 26),
      AdminStats(
        children: [
          AdminStat(
            'Registered Visitors',
            '${store.visitors.length}',
            'All visitor accounts',
            Icons.people_outline,
          ),
          AdminStat(
            'Active Today',
            '${store.activeToday}',
            'Visitor app sessions today',
            Icons.person_outline,
            color: Colors.green,
          ),
          AdminStat(
            'Confirmed Bookings',
            '${store.orders.length}',
            'Saved ticket orders',
            Icons.receipt_long_outlined,
            color: Colors.blue,
          ),
          AdminStat(
            'Park Admissions',
            '${store.admissions.where((a) => adminDateLabel(a.at) == displayParkDate(visitDateString(parkToday()))).length}',
            'Successful admissions today',
            Icons.verified_outlined,
            color: Colors.orange,
          ),
        ],
      ),
      const SizedBox(height: 24),
      AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recent Bookings',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => onOpen('tickets'),
                  child: const Text(
                    'View All',
                    style: TextStyle(color: adminRose),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (store.orders.isEmpty)
              const AdminEmpty(
                'No bookings yet',
                'Completed visitor bookings will appear here.',
              ),
            for (final o in store.orders.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      color: adminRose,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.packageName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${o.reference} · ${displayParkDate(o.visitDate)}',
                            style: const TextStyle(
                              color: adminMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      money(o.totalMinor),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      AdminCard(
        child: Wrap(
          spacing: 18,
          runSpacing: 16,
          children: [
            AdminButton(
              'View Visitors',
              icon: Icons.people_outline,
              onPressed: () => onOpen('visitors'),
            ),
            AdminButton(
              'Manage Passes',
              icon: Icons.local_activity_outlined,
              outlined: true,
              onPressed: () => onOpen('packages'),
            ),
            AdminButton(
              'Validate Ticket',
              icon: Icons.qr_code_scanner,
              outlined: true,
              onPressed: () => onOpen('validation'),
            ),
          ],
        ),
      ),
    ],
  );
}

class AdminActivityScreen extends StatefulWidget {
  final AdminStore store;
  const AdminActivityScreen({super.key, required this.store});
  @override
  State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends State<AdminActivityScreen> {
  String type = 'all';
  bool live = true;
  List<AdminActivity>? frozen;
  @override
  Widget build(BuildContext context) {
    final source = live
        ? [
            ...widget.store.audit,
            ...widget.store.sessions,
            ...widget.store.admissions,
          ]
        : frozen ?? [];
    final list =
        source
            .where(
              (e) =>
                  type == 'all' ||
                  (type == 'session'
                      ? e.action == 'session_opened'
                      : type == 'admission'
                      ? e.data['outcome'] == 'admitted'
                      : e.data.containsKey('actorUid') &&
                            e.data['outcome'] != 'admitted'),
            )
            .toList()
          ..sort(
            (a, b) =>
                (b.at ?? DateTime(1970)).compareTo(a.at ?? DateTime(1970)),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminHeading(
          'Visitor Activity Monitoring',
          'Track account administration, visitor sessions and park admissions',
        ),
        const SizedBox(height: 26),
        AdminStats(
          children: [
            AdminStat(
              'Visitor Sessions',
              '${widget.store.sessions.length}',
              'Recorded application sessions',
              Icons.person_outline,
            ),
            AdminStat(
              'Admin Actions',
              '${widget.store.audit.length}',
              'Recorded management actions',
              Icons.edit_note_outlined,
            ),
            AdminStat(
              'Park Admissions',
              '${widget.store.admissions.length}',
              'Confirmed entry scans',
              Icons.qr_code_scanner,
              color: Colors.green,
            ),
            AdminStat(
              'Flagged Accounts',
              '${widget.store.flagged}',
              'Accounts requiring review',
              Icons.flag_outlined,
              color: Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 24),
        AdminCard(
          child: Wrap(
            spacing: 20,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Live updates', style: TextStyle(fontSize: 13)),
                  Switch(
                    value: live,
                    onChanged: (v) => setState(() {
                      if (!v) {
                        frozen = [
                          ...widget.store.audit,
                          ...widget.store.sessions,
                          ...widget.store.admissions,
                        ];
                      }
                      live = v;
                    }),
                  ),
                ],
              ),
              AdminSelect(
                value: type,
                options: const {
                  'all': 'All Activity',
                  'session': 'Visitor Sessions',
                  'admin': 'Admin Actions',
                  'admission': 'Park Admissions',
                },
                onChanged: (v) => setState(() => type = v),
                width: 190,
              ),
              AdminButton(
                'Export CSV',
                icon: Icons.download_outlined,
                onPressed: list.isEmpty
                    ? null
                    : () => exportAdminCsv(
                        context,
                        'park-activity.csv',
                        ['Time', 'Event', 'Actor', 'Target'],
                        list
                            .map(
                              (e) => [
                                adminTimeLabel(e.at),
                                e.data['outcome'] == 'admitted'
                                    ? 'Park admission'
                                    : e.action,
                                e.data['actorUid'] ?? e.ownerUid,
                                (e.data['targetIds'] as List?)?.join(', ') ??
                                    e.data['ticketId'] ??
                                    '',
                              ],
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AdminCard(
          padding: EdgeInsets.zero,
          child: list.isEmpty
              ? const AdminEmpty(
                  'No activity recorded',
                  'Actions and visitor sessions will appear here as they happen.',
                )
              : AdminTable(
                  minWidth: 900,
                  columns: const [
                    DataColumn(label: Text('Time')),
                    DataColumn(label: Text('Event')),
                    DataColumn(label: Text('Actor')),
                    DataColumn(label: Text('Target')),
                    DataColumn(label: Text('Result')),
                  ],
                  rows: [
                    for (final e in list.take(100))
                      DataRow(
                        cells: [
                          DataCell(Text(adminTimeLabel(e.at))),
                          DataCell(
                            Text(
                              e.data['outcome'] == 'admitted'
                                  ? 'Park admission'
                                  : e.action.replaceAll('_', ' '),
                            ),
                          ),
                          DataCell(
                            Text(
                              visitorReference(
                                e.data['actorUid'] as String? ?? e.ownerUid,
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 230,
                              child: Text(
                                (e.data['targetIds'] as List?)?.join(', ') ??
                                    e.data['ticketId'] as String? ??
                                    e.ownerUid,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          const DataCell(AdminBadge('Success', tone: 'active')),
                        ],
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
