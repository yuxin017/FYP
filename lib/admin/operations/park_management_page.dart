import 'package:flutter/material.dart';
import '../../photos/photo_repository.dart';
import '../admin_models.dart';
import '../admin_widgets.dart';
import 'park_admin_repository.dart';
import '../../park/venue_configuration.dart';

class ParkManagementPage extends StatefulWidget {
  final ParkAdminRepository repository;
  const ParkManagementPage({super.key, required this.repository});
  @override
  State<ParkManagementPage> createState() => _ParkManagementPageState();
}

class _ParkManagementPageState extends State<ParkManagementPage> {
  late final campaigns = widget.repository.records('campaigns'),
      rewards = widget.repository.records('rewardCatalogue'),
      loyalty = widget.repository.settings('loyalty'),
      photos = widget.repository.settings('photos'),
      weather = widget.repository.settings('weather');
  String tab = 'Promotions', query = '';
  int page = 0;
  Future<void> edit(String kind, Map<String, dynamic> data) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ParkPolicyEditor(
        repository: widget.repository,
        kind: kind,
        initial: data,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AdminHeading(
        'Promotions & Rewards',
        'Manage park offers, earning rules and visitor benefits.',
      ),
      const SizedBox(height: 23),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final section in [
            'Promotions',
            'Reward Catalogue',
            'Loyalty Rules',
            'Photo Prices',
            'Weather Benefits',
          ])
            ChoiceChip(
              label: Text(section),
              selected: tab == section,
              onSelected: (_) => setState(() {
                tab = section;
                query = '';
                page = 0;
              }),
            ),
        ],
      ),
      const SizedBox(height: 22),
      if (tab == 'Promotions' || tab == 'Reward Catalogue') ...[
        Row(
          children: [
            Expanded(
              child: TextField(
                key: ValueKey(tab),
                onChanged: (v) => setState(() {
                  query = v;
                  page = 0;
                }),
                decoration: const InputDecoration(
                  hintText: 'Search name or code',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 18),
            AdminButton(
              tab == 'Promotions' ? 'Create Campaign' : 'Add Reward',
              icon: Icons.add,
              onPressed: () =>
                  edit(tab == 'Promotions' ? 'campaign' : 'reward', {}),
            ),
          ],
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: tab == 'Promotions' ? campaigns : rewards,
          builder: (context, s) {
            if (s.hasError) {
              return const AdminEmpty(
                'Unable to load offers',
                'Check your connection and reopen this section.',
              );
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = s.data!,
                rows =
                    all
                        .where(
                          (d) => '${d['name']} ${d['code'] ?? ''}'
                              .toLowerCase()
                              .contains(query.toLowerCase()),
                        )
                        .toList()
                      ..sort(
                        (a, b) => (a['name'] ?? '').toString().compareTo(
                          (b['name'] ?? '').toString(),
                        ),
                      );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminStats(
                  children: [
                    AdminStat(
                      'Total Offers',
                      '${all.length}',
                      'Configured offers',
                      Icons.local_offer_outlined,
                    ),
                    AdminStat(
                      'Active',
                      '${all.where((d) => d['active'] == true).length}',
                      'Currently enabled',
                      Icons.check_circle_outline,
                    ),
                    AdminStat(
                      tab == 'Promotions'
                          ? 'Redemptions'
                          : 'Available Categories',
                      tab == 'Promotions'
                          ? '${all.fold<int>(0, (n, d) => n + (d['usageCount'] as int? ?? 0))}'
                          : '${all.map((d) => d['category']).toSet().length}',
                      'Across this catalogue',
                      Icons.redeem_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (rows.isEmpty)
                  const AdminEmpty(
                    'No matching offers',
                    'Create a campaign or reward to publish a visitor benefit.',
                  ),
                for (final row in rows.skip(page * 8).take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: AdminCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.redeem_outlined,
                                    color: adminRose,
                                    size: 34,
                                  ),
                                  const SizedBox(width: 15),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 320,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row['name'] as String,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          tab == 'Promotions'
                                              ? row['code'] as String
                                              : '${row['pointsCost']} points • ${row['category']}',
                                          style: const TextStyle(
                                            color: adminMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              AdminBadge(
                                row['active'] == true ? 'Active' : 'Inactive',
                                tone: row['active'] == true
                                    ? 'active'
                                    : 'archived',
                              ),
                              AdminButton(
                                'Edit Details',
                                outlined: true,
                                icon: Icons.edit_outlined,
                                onPressed: () => edit(
                                  tab == 'Promotions' ? 'campaign' : 'reward',
                                  row,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 28),
                          Text(
                            tab == 'Promotions'
                                ? '${row['type'] == 'percent' ? '${row['value']}%' : photoMoney(row['value'] as num)} off • ${adminDateLabel(adminDate(row['startsAt']))} – ${adminDateLabel(adminDate(row['endsAt']))}'
                                : '${row['benefit']} • Valid for ${row['validityDays']} days',
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (tab == 'Promotions')
                            Padding(
                              padding: const EdgeInsets.only(top: 9),
                              child: Text(
                                '${(row['scopes'] as List).join(' & ')} • ${row['usageCount'] ?? 0} used • Limit ${row['perUserLimit']} per visitor',
                                style: const TextStyle(
                                  color: adminMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${rows.isEmpty ? 0 : page * 8 + 1}–${(page * 8 + 8).clamp(0, rows.length)} of ${rows.length}',
                    ),
                    IconButton(
                      onPressed: page > 0 ? () => setState(() => page--) : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      onPressed: (page + 1) * 8 < rows.length
                          ? () => setState(() => page++)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ] else
        StreamBuilder<Map<String, dynamic>>(
          stream: tab == 'Loyalty Rules'
              ? loyalty
              : tab == 'Photo Prices'
              ? photos
              : weather,
          builder: (context, s) {
            if (s.hasError) {
              return const AdminEmpty(
                'Unable to load park settings',
                'Please reopen this section.',
              );
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final d = s.data!,
                kind = tab == 'Loyalty Rules'
                    ? 'loyalty'
                    : tab == 'Photo Prices'
                    ? 'photos'
                    : 'weather';
            final entries = kind == 'loyalty'
                ? {
                    'Purchase earnings':
                        '${d['purchasePointsPerRinggit'] ?? 1} points per RM 1',
                    'Attraction check-in':
                        '${d['ridePoints'] ?? 10} points per visit',
                    'Missed reservation policy': d['noShowEnabled'] == true
                        ? '${d['noShowPenalty'] ?? 0} points deducted from missed reservation ${d['noShowThreshold'] ?? 2} onwards'
                        : 'No points deduction',
                  }
                : kind == 'photos'
                ? {
                    'Digital copy': photoMoney(
                      d['digitalPriceMinor'] as num? ?? 2500,
                    ),
                    'Printed photo': photoMoney(
                      d['printPriceMinor'] as num? ?? 3500,
                    ),
                    'Digital + print bundle': photoMoney(
                      d['bundlePriceMinor'] as num? ?? 5000,
                    ),
                    'Large print upgrade': photoMoney(
                      d['largePrintSurchargeMinor'] as num? ?? 1000,
                    ),
                    'Collection kiosk': d['kioskName'] ?? 'Park Photo Kiosk',
                  }
                : {
                    'Weather compensation': d['enabled'] == true
                        ? 'Enabled'
                        : 'Disabled',
                    'Park': d['parkName'] ?? 'Theme Park',
                    'Park coordinates': d['latitude'] == null
                        ? 'Not set'
                        : '${d['latitude']}, ${d['longitude']}',
                    'Rain threshold': '${d['rainThresholdMm'] ?? 2} mm',
                    'Voucher benefit': d['voucherBenefit'] ?? 'Not set',
                    'Validity': '${d['validityDays'] ?? 30} days',
                  };
            return AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        kind == 'weather'
                            ? Icons.cloud_outlined
                            : kind == 'photos'
                            ? Icons.photo_outlined
                            : Icons.stars_outlined,
                        color: adminRose,
                        size: 40,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          tab,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      AdminButton(
                        'Edit Settings',
                        icon: Icons.tune,
                        outlined: true,
                        onPressed: () => edit(kind, d),
                      ),
                    ],
                  ),
                  const Divider(height: 34),
                  for (final entry in entries.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(color: adminMuted),
                          ),
                          Text(
                            '${entry.value}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 30),
                  Text(
                    kind == 'loyalty'
                        ? 'Rules apply to future purchases and new missed reservations. A visitor’s points balance cannot fall below zero.'
                        : kind == 'photos'
                        ? 'Price changes apply to new orders. Confirmed orders keep the price and print options recorded at purchase.'
                        : 'Weather benefits use observed precipitation at the park location. Eligible visitors with a park ticket for the affected day can collect one voucher.',
                    style: const TextStyle(color: adminMuted, height: 1.6),
                  ),
                  if (kind == 'weather') ...[
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AdminButton(
                        'Refresh Weather',
                        outlined: true,
                        icon: Icons.refresh,
                        onPressed: d['enabled'] == true
                            ? () async {
                                try {
                                  final result = await widget.repository
                                      .request('refreshWeather', {});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          result['raining'] == true
                                              ? 'Rain threshold met. Weather benefit is available.'
                                              : 'Weather updated.',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(photoError(e))),
                                    );
                                  }
                                }
                              }
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
    ],
  );
}

class ParkPolicyEditor extends StatefulWidget {
  final ParkAdminRepository repository;
  final String kind;
  final Map<String, dynamic> initial;
  const ParkPolicyEditor({
    super.key,
    required this.repository,
    required this.kind,
    required this.initial,
  });
  @override
  State<ParkPolicyEditor> createState() => _ParkPolicyEditorState();
}

class _ParkPolicyEditorState extends State<ParkPolicyEditor> {
  final fields = <String, TextEditingController>{},
      form = GlobalKey<FormState>();
  late final d = Map<String, dynamic>.from(widget.initial);
  late String type = d['type'] as String? ?? 'percent',
      category = d['category'] as String? ?? 'shopping';
  late bool active = d['active'] != false,
      public = d['public'] != false,
      allowPoints = d['allowPoints'] != false,
      enabled = d['enabled'] == true,
      noShow = d['noShowEnabled'] == true;
  late final scopes = (d['scopes'] as List? ?? ['photos'])
      .cast<String>()
      .toSet();
  late DateTime
  start = adminDate(d['startsAt']) ?? DateTime.now(),
  end = adminDate(d['endsAt']) ?? DateTime.now().add(const Duration(days: 30));
  bool busy = false;
  String? error;
  String get kind => widget.kind;
  TextEditingController controller(
    String key,
    Object? fallback, {
    bool money = false,
    bool lines = false,
  }) => fields.putIfAbsent(
    key,
    () => TextEditingController(
      text: lines
          ? ((d[key] as List?)?.join('\n') ?? fallback?.toString() ?? '')
          : money
          ? (((d[key] ?? fallback) as num) / 100).toStringAsFixed(2)
          : (d[key] ?? fallback)?.toString() ?? '',
    ),
  );
  Widget input(
    String key,
    String label, {
    Object? value = '',
    bool number = false,
    bool money = false,
    int lines = 1,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 17),
    child: TextFormField(
      controller: controller(key, value, money: money, lines: lines > 1),
      enabled: !busy,
      maxLines: lines,
      keyboardType: number || money
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixText: money ? 'RM ' : null,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: (v) {
        if ([
          'latitude',
          'longitude',
          'kioskLatitude',
          'kioskLongitude',
          'description',
          'subtitle',
          'terms',
          'instructions',
        ].contains(key)) {
          return null;
        }
        if (v == null || v.trim().isEmpty) return 'Complete this field.';
        if ((number || money) && num.tryParse(v) == null) {
          return 'Enter a number.';
        }
        if (key == 'noShowThreshold') {
          final count = int.tryParse(v);
          if (count == null || count < 2 || count > 20) {
            return 'Enter a whole number from 2 to 20.';
          }
        }
        return null;
      },
    ),
  );
  Future<void> date(bool first) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: first ? start : end,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (selected != null) {
      setState(() {
        if (first) {
          start = selected;
        } else {
          end = DateTime(selected.year, selected.month, selected.day, 23, 59);
        }
      });
    }
  }

  dynamic value(
    String key, {
    bool money = false,
    bool decimal = false,
    bool optional = false,
  }) {
    final raw = fields[key]?.text.trim() ?? '';
    if (optional && raw.isEmpty) return null;
    if (money) return (double.parse(raw) * 100).round();
    if (decimal) return double.parse(raw);
    return int.parse(raw);
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final payload = <String, dynamic>{};
      for (final entry in fields.entries) {
        payload[entry.key] = entry.value.text.trim();
      }
      String action;
      if (kind == 'campaign') {
        action = 'saveCampaign';
        payload.addAll({
          'type': type,
          'value': value('value', money: type == 'fixed'),
          'minimumMinor': value('minimumMinor', money: true),
          'maximumDiscountMinor': value('maximumDiscountMinor', money: true),
          'perUserLimit': value('perUserLimit'),
          'totalUsageLimit': value('totalUsageLimit'),
          'startsAt': start.toUtc().toIso8601String(),
          'endsAt': end.toUtc().toIso8601String(),
          'active': active,
          'public': public,
          'allowPoints': allowPoints,
          'scopes': scopes.toList(),
        });
      } else if (kind == 'reward') {
        action = 'saveReward';
        payload.addAll({
          'id': ?d['id'],
          'pointsCost': value('pointsCost'),
          'validityDays': value('validityDays'),
          'sortOrder': value('sortOrder'),
          'category': category,
          'active': active,
          'terms': (payload['terms'] as String)
              .split('\n')
              .where((s) => s.trim().isNotEmpty)
              .toList(),
          'instructions': (payload['instructions'] as String)
              .split('\n')
              .where((s) => s.trim().isNotEmpty)
              .toList(),
        });
      } else if (kind == 'loyalty') {
        action = 'saveLoyalty';
        for (final key in [
          'purchasePointsPerRinggit',
          'ridePoints',
          'noShowPenalty',
          'noShowThreshold',
        ]) {
          payload[key] = value(key);
        }
        payload['noShowEnabled'] = noShow;
      } else if (kind == 'photos') {
        action = 'savePhotoSettings';
        for (final key in [
          'digitalPriceMinor',
          'printPriceMinor',
          'bundlePriceMinor',
          'largePrintSurchargeMinor',
        ]) {
          payload[key] = value(key, money: true);
        }
        for (final key in ['kioskLatitude', 'kioskLongitude']) {
          payload[key] = value(key, decimal: true, optional: true);
        }
      } else {
        action = 'saveWeather';
        payload.addAll({
          'enabled': enabled,
          'latitude': value('latitude', decimal: true, optional: true),
          'longitude': value('longitude', decimal: true, optional: true),
          'rainThresholdMm': value('rainThresholdMm', decimal: true),
          'validityDays': value('validityDays'),
        });
      }
      await widget.repository.request(action, payload);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? 'Review the numbers in this form.'
              : photoError(e),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 860),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      kind == 'campaign'
                          ? 'Campaign Details'
                          : kind == 'reward'
                          ? 'Reward Details'
                          : kind == 'loyalty'
                          ? 'Loyalty Rules'
                          : kind == 'photos'
                          ? 'Photo Prices & Kiosk'
                          : 'Weather Benefit Rules',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (kind == 'campaign') ...[
                        input('name', 'Campaign Name'),
                        input(
                          'code',
                          'Promotion Code',
                          helper: 'Share this code with visitors.',
                        ),
                        input('description', 'Description'),
                        DropdownButtonFormField<String>(
                          initialValue: type,
                          decoration: const InputDecoration(
                            labelText: 'Discount Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'percent',
                              child: Text('Percentage'),
                            ),
                            DropdownMenuItem(
                              value: 'fixed',
                              child: Text('Fixed Amount'),
                            ),
                          ],
                          onChanged: busy
                              ? null
                              : (v) => setState(() {
                                  type = v!;
                                  fields.remove('value')?.dispose();
                                }),
                        ),
                        const SizedBox(height: 18),
                        input(
                          'value',
                          type == 'percent'
                              ? 'Discount (%)'
                              : 'Discount Amount',
                          number: type == 'percent',
                          money: type == 'fixed',
                          value: 10,
                        ),
                        input(
                          'minimumMinor',
                          'Minimum Spend',
                          money: true,
                          value: 0,
                        ),
                        input(
                          'maximumDiscountMinor',
                          'Maximum Discount (0 = no cap)',
                          money: true,
                          value: 0,
                        ),
                        input(
                          'perUserLimit',
                          'Redemptions per Visitor',
                          number: true,
                          value: 1,
                        ),
                        input(
                          'totalUsageLimit',
                          'Total Redemptions (0 = unlimited)',
                          number: true,
                          value: 0,
                        ),
                        Wrap(
                          spacing: 18,
                          children: [
                            for (final scope in ['photos', 'tickets'])
                              FilterChip(
                                label: Text(
                                  scope == 'photos'
                                      ? 'Photo Purchases'
                                      : 'Ticket Purchases',
                                ),
                                selected: scopes.contains(scope),
                                onSelected: busy
                                    ? null
                                    : (v) => setState(() {
                                        v
                                            ? scopes.add(scope)
                                            : scopes.remove(scope);
                                      }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: busy ? null : () => date(true),
                                icon: const Icon(Icons.calendar_today_outlined),
                                label: Text('From ${adminDateLabel(start)}'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: busy ? null : () => date(false),
                                icon: const Icon(Icons.event_outlined),
                                label: Text('Until ${adminDateLabel(end)}'),
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active campaign'),
                          value: active,
                          onChanged: busy
                              ? null
                              : (v) => setState(() => active = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Show in visitor offers'),
                          value: public,
                          onChanged: busy
                              ? null
                              : (v) => setState(() => public = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Allow loyalty points with this offer',
                          ),
                          value: allowPoints,
                          onChanged: busy
                              ? null
                              : (v) => setState(() => allowPoints = v),
                        ),
                      ] else if (kind == 'reward') ...[
                        input('name', 'Reward Name'),
                        input('subtitle', 'Subtitle'),
                        input('benefit', 'Benefit'),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final c in ['shopping', 'dining', 'photo'])
                              DropdownMenuItem(
                                value: c,
                                child: Text(titleCase(c)),
                              ),
                          ],
                          onChanged: busy
                              ? null
                              : (v) => setState(() => category = v!),
                        ),
                        const SizedBox(height: 18),
                        input(
                          'pointsCost',
                          'Points Required',
                          number: true,
                          value: 100,
                        ),
                        input(
                          'validityDays',
                          'Valid for (days)',
                          number: true,
                          value: 30,
                        ),
                        input(
                          'sortOrder',
                          'Display Order',
                          number: true,
                          value: 0,
                        ),
                        input('terms', 'Terms (one per line)', lines: 4),
                        input(
                          'instructions',
                          'How to Use (one step per line)',
                          lines: 4,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Available to redeem'),
                          value: active,
                          onChanged: busy
                              ? null
                              : (v) => setState(() => active = v),
                        ),
                      ] else if (kind == 'loyalty') ...[
                        input(
                          'purchasePointsPerRinggit',
                          'Points per RM 1 Spent',
                          number: true,
                          value: 1,
                        ),
                        input(
                          'ridePoints',
                          'Points per Attraction Check-in',
                          number: true,
                          value: 10,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Deduct points for missed reservations',
                          ),
                          subtitle: const Text(
                            'Applies only to reservations made after this policy is enabled.',
                          ),
                          value: noShow,
                          onChanged: busy
                              ? null
                              : (v) => setState(() => noShow = v),
                        ),
                        input(
                          'noShowThreshold',
                          'Missed Reservations Before Deduction',
                          number: true,
                          value: 2,
                          helper: '2–20 missed reservations',
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 18),
                          child: Text(
                            'Deductions begin when the missed-reservation count reaches this limit. Turning this policy off and on starts a new count.',
                            style: TextStyle(color: adminMuted, height: 1.5),
                          ),
                        ),
                        input(
                          'noShowPenalty',
                          'Missed Reservation Deduction',
                          number: true,
                          value: 0,
                        ),
                      ] else if (kind == 'photos') ...[
                        input(
                          'digitalPriceMinor',
                          'Digital Copy',
                          money: true,
                          value: 2500,
                        ),
                        input(
                          'printPriceMinor',
                          'Printed Photo',
                          money: true,
                          value: 3500,
                        ),
                        input(
                          'bundlePriceMinor',
                          'Digital + Print Bundle',
                          money: true,
                          value: 5000,
                        ),
                        input(
                          'largePrintSurchargeMinor',
                          '8 × 10 Upgrade per Copy',
                          money: true,
                          value: 1000,
                        ),
                        input(
                          'kioskName',
                          'Collection Kiosk Name',
                          value: 'Park Photo Kiosk',
                        ),
                        input(
                          'kioskLatitude',
                          'Kiosk Latitude (optional)',
                          number: true,
                        ),
                        input(
                          'kioskLongitude',
                          'Kiosk Longitude (optional)',
                          number: true,
                        ),
                      ] else ...[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable weather benefits'),
                          value: enabled,
                          onChanged: busy
                              ? null
                              : (v) => setState(() => enabled = v),
                        ),
                        input(
                          'parkName',
                          'Park Name',
                          value: VenueConfiguration.name,
                        ),
                        input(
                          'latitude',
                          'Park Latitude',
                          number: true,
                          value: VenueConfiguration.latitude,
                        ),
                        input(
                          'longitude',
                          'Park Longitude',
                          number: true,
                          value: VenueConfiguration.longitude,
                        ),
                        input(
                          'rainThresholdMm',
                          'Observed Rain Threshold (mm)',
                          number: true,
                          value: 2,
                        ),
                        input(
                          'voucherBenefit',
                          'Compensation Benefit',
                          value: 'Rainy-day park benefit',
                        ),
                        input(
                          'validityDays',
                          'Voucher Validity (days)',
                          number: true,
                          value: 30,
                        ),
                        const Text(
                          'Open-Meteo provides the weather observation. A visitor needs a valid park ticket for the affected day to collect the benefit.',
                          style: TextStyle(color: adminMuted, height: 1.6),
                        ),
                      ],
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 14),
                  AdminButton(
                    busy ? 'Saving…' : 'Save Changes',
                    onPressed: busy ? null : save,
                    icon: Icons.check,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
