import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../attractions/widgets/queue_attraction_card.dart';
import '../reservations/widgets/reservation_widgets.dart';
import '../visitor/models/tickets.dart' show parkToday, visitDateString;
import 'group_repository.dart';
import 'group_reservation_pages.dart';
import 'group_location_page.dart';

const groupIcons = {
  'castle': Icons.castle_outlined,
  'family': Icons.family_restroom,
  'friends': Icons.groups_outlined,
  'adventure': Icons.explore_outlined,
};

class GroupFrame extends StatelessWidget {
  final String title;
  final Widget body;
  const GroupFrame({super.key, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => ReservationFrame(
    title: title,
    helpLabel: 'Group help',
    onHelp: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Explore together'),
        content: const Text(
          'Create a group for your park visit. Share an invitation code with app users, or add guests and link their admission tickets. Each app user links their own ticket. The organiser can reserve an attraction for eligible members together. Location sharing is optional and can be stopped at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    ),
    body: body,
  );
}

class MemberAvatar extends StatelessWidget {
  final GroupRecord member;
  final double radius;
  const MemberAvatar({super.key, required this.member, this.radius = 22});
  @override
  Widget build(BuildContext context) {
    ImageProvider? avatar;
    try {
      if (member.data['avatarBase64'] is String) {
        avatar = MemoryImage(base64Decode(member.data['avatarBase64']));
      }
    } catch (_) {
      avatar = null;
    }
    final name = member.data['displayName'] as String? ?? 'Guest';
    return CircleAvatar(
      radius: radius,
      backgroundImage: avatar,
      backgroundColor: const Color(0xFFEEDDD8),
      child: avatar == null
          ? Text(
              name.isEmpty ? 'G' : name[0].toUpperCase(),
              style: const TextStyle(
                color: queueRose,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

class GroupsPage extends StatefulWidget {
  final GroupRepository repository;
  const GroupsPage({super.key, required this.repository});
  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  late final stream = widget.repository.groups();
  @override
  Widget build(BuildContext context) => GroupFrame(
    title: 'My Groups',
    body: StreamBuilder<List<GroupRecord>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load groups. Please reopen this page.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final group in snapshot.data!)
              Padding(
                padding: const EdgeInsets.only(bottom: 17),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupDetailPage(
                        repository: widget.repository,
                        id: group.id,
                      ),
                    ),
                  ),
                  child: ReservationPanel(
                    child: StreamBuilder<List<GroupRecord>>(
                      stream: widget.repository.members(group.id),
                      builder: (context, members) => Row(
                        children: [
                          SizedBox(
                            width: 100,
                            height: 65,
                            child: Stack(
                              children: [
                                for (
                                  int i = 0;
                                  i < (members.data?.length ?? 0).clamp(0, 3);
                                  i++
                                )
                                  Positioned(
                                    left: i * 24,
                                    top: 8,
                                    child: MemberAvatar(
                                      member: members.data![i],
                                      radius: 24,
                                    ),
                                  ),
                                if (members.data?.isEmpty ?? true)
                                  const Icon(
                                    Icons.groups_outlined,
                                    size: 55,
                                    color: queueRose,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: queueInk,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  members.hasError
                                      ? 'Members unavailable'
                                      : '${members.data?.length ?? 0} members',
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  '${members.data?.where((m) => m.data['ticketId'] != null).length ?? 0}/${members.data?.length ?? 0} tickets linked',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: queueRose,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  group.visitDate,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6D737A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (snapshot.data!.isEmpty)
              const ReservationPanel(
                child: Column(
                  children: [
                    Icon(Icons.groups_outlined, size: 75, color: queueRose),
                    SizedBox(height: 18),
                    Text(
                      'Adventures are better together',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Create your first group or join a friend’s invitation.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            ReservationButton(
              label: 'Create New Group',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupFormPage(repository: widget.repository),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JoinGroupPage(repository: widget.repository),
                ),
              ),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Join with Invitation'),
            ),
            const SizedBox(height: 14),
            const Text(
              'Manage tickets, locations and attraction reservations together.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF6D737A)),
            ),
          ],
        );
      },
    ),
  );
}

class GroupFormPage extends StatefulWidget {
  final GroupRepository repository;
  final GroupRecord? group;
  const GroupFormPage({super.key, required this.repository, this.group});
  @override
  State<GroupFormPage> createState() => _GroupFormPageState();
}

class _GroupFormPageState extends State<GroupFormPage> {
  late final name = TextEditingController(text: widget.group?.name ?? ''),
      description = TextEditingController(
        text: widget.group?.data['description'] as String? ?? '',
      );
  late String icon = widget.group?.data['icon'] as String? ?? 'castle',
      day = widget.group?.visitDate ?? visitDateString(parkToday());
  late final requestId = widget.repository.newRequestId();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> date() async {
    final today = parkToday(), parsed = DateTime.tryParse(day) ?? today;
    final chosen = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDate: parsed.isBefore(today) ? today : parsed,
    );
    if (chosen != null && mounted) {
      setState(() => day = visitDateString(chosen));
    }
  }

  Future<void> save() async {
    if (name.text.trim().length < 2) {
      setState(
        () => error = 'Enter a group name with at least two characters.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repository
          .request(widget.group == null ? 'create' : 'update', {
            'name': name.text.trim(),
            'description': description.text.trim(),
            'visitDate': day,
            'icon': icon,
            if (widget.group == null) 'requestId': requestId,
            if (widget.group != null) 'groupId': widget.group!.id,
          });
      if (mounted) {
        if (widget.group != null) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => GroupDetailPage(
                repository: widget.repository,
                id: result['groupId'] as String,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => GroupFrame(
    title: widget.group == null ? 'Create Group' : 'Edit Group',
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ReservationPanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Group Name',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: name,
                enabled: !busy,
                maxLength: 60,
                decoration: const InputDecoration(
                  hintText: 'e.g. Weekend Adventure',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Group Icon',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  for (final item in groupIcons.entries)
                    ChoiceChip(
                      avatar: Icon(item.value, size: 23),
                      label: Text(
                        item.key[0].toUpperCase() + item.key.substring(1),
                      ),
                      selected: icon == item.key,
                      onSelected: busy
                          ? null
                          : (_) => setState(() => icon = item.key),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.calendar_month_outlined,
                  color: queueRose,
                ),
                title: const Text('Visit Date'),
                subtitle: Text(day),
                trailing: const Icon(Icons.chevron_right),
                onTap: busy ? null : date,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                enabled: !busy,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Group notes (optional)',
                  hintText: 'Plan your day together',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Color(0xFFEEDDD8),
                  child: Icon(Icons.person_outline, color: queueRose),
                ),
                title: Text('You'),
                subtitle: Text('Group organiser'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Invite app users and add guest tickets after creating your group.',
                style: TextStyle(color: Color(0xFF6D737A), fontSize: 12),
              ),
              const SizedBox(height: 22),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Text(error!, style: const TextStyle(color: queueRose)),
                ),
              ReservationButton(
                label: widget.group == null ? 'Create Group' : 'Save Changes',
                onPressed: save,
                busy: busy,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class GroupDetailPage extends StatefulWidget {
  final GroupRepository repository;
  final String id;
  const GroupDetailPage({
    super.key,
    required this.repository,
    required this.id,
  });
  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  late final stream = widget.repository.group(widget.id),
      members = widget.repository.members(widget.id),
      bookings = widget.repository.bookings(widget.id);
  String? error;
  bool busy = false;
  Future<void> change(
    String action,
    Map<String, dynamic> data,
    String title,
    String message, {
    bool leave = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.request(action, {'groupId': widget.id, ...data});
      if (mounted && leave) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void link(GroupRecord member) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => GroupLinkTicketPage(
        repository: widget.repository,
        groupId: widget.id,
        member: member,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => StreamBuilder<GroupRecord?>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const GroupFrame(
          title: 'My Group',
          body: Center(
            child: Text('This group is unavailable. Return to My Groups.'),
          ),
        );
      }
      final group = snapshot.data;
      if (group == null) {
        return GroupFrame(
          title: 'My Group',
          body: Center(
            child: snapshot.connectionState == ConnectionState.waiting
                ? const CircularProgressIndicator()
                : const Text('This group has been removed.'),
          ),
        );
      }
      final owner = group.ownerUid == widget.repository.uid;
      return GroupFrame(
        title: group.name,
        body: StreamBuilder<List<GroupRecord>>(
          stream: members,
          builder: (context, people) {
            final list = people.data ?? <GroupRecord>[];
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      group.visitDate,
                      style: const TextStyle(color: queueRose),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      enabled: !busy,
                      onSelected: (action) {
                        if (action == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupFormPage(
                                repository: widget.repository,
                                group: group,
                              ),
                            ),
                          );
                        }
                        if (action == 'delete') {
                          change(
                            'erase',
                            {},
                            'Delete group?',
                            'Remove the group and its invitations. Cancel upcoming reservations first.',
                            leave: true,
                          );
                        }
                        if (action == 'leave') {
                          change(
                            'remove',
                            {'memberId': widget.repository.uid},
                            'Leave group?',
                            'Your group membership and shared location will be removed.',
                            leave: true,
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        if (owner)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit Group'),
                          ),
                        if (owner)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete Group'),
                          ),
                        if (!owner)
                          const PopupMenuItem(
                            value: 'leave',
                            child: Text('Leave Group'),
                          ),
                      ],
                    ),
                  ],
                ),
                ReservationPanel(
                  child: Row(
                    children: [
                      for (final m in list.take(3))
                        Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: MemberAvatar(member: m),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${list.length} members',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${list.where((m) => m.data['ticketId'] != null).length}/${list.length} tickets linked',
                              style: const TextStyle(
                                color: queueRose,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                ReservationPanel(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: owner
                              ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GroupInvitationPage(
                                      repository: widget.repository,
                                      group: group,
                                    ),
                                  ),
                                )
                              : null,
                          icon: const Icon(Icons.group_add_outlined),
                          label: const Text('Members'),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupLocationPage(
                                repository: widget.repository,
                                group: group,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.location_on_outlined),
                          label: const Text('Live Location'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 23),
                const Text(
                  'Members',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: queueInk,
                  ),
                ),
                const SizedBox(height: 12),
                if (people.hasError)
                  const Text('Unable to load group members.'),
                ReservationPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final m in list)
                        ListTile(
                          leading: MemberAvatar(member: m),
                          title: Text(
                            '${m.data['displayName'] ?? 'Guest'}${m.data['ownerUid'] == widget.repository.uid && m.data['isGuest'] != true ? ' (You)' : ''}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            m.data['isGuest'] == true
                                ? 'Guest • ${m.data['heightCm'] ?? 0} cm'
                                : m.data['memberId'] == group.ownerUid
                                ? 'Organiser'
                                : 'App member',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing:
                              !owner &&
                                  m.data['ownerUid'] != widget.repository.uid
                              ? Text(
                                  m.data['ticketId'] != null
                                      ? 'Ticket linked'
                                      : 'Ticket not linked',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: m.data['ticketId'] != null
                                        ? Colors.green.shade700
                                        : queueRose,
                                  ),
                                )
                              : PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'link') link(m);
                                    if (v == 'edit-guest') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => GroupInvitationPage(
                                            repository: widget.repository,
                                            group: group,
                                            guestMember: m,
                                          ),
                                        ),
                                      );
                                    }
                                    if (v == 'remove') {
                                      change(
                                        'remove',
                                        {'memberId': m.data['memberId']},
                                        'Remove member?',
                                        'Cancel this member’s upcoming reservation before removing them.',
                                      );
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    if (m.data['ownerUid'] ==
                                        widget.repository.uid)
                                      PopupMenuItem(
                                        value: 'link',
                                        child: Text(
                                          m.data['ticketId'] == null
                                              ? 'Link Ticket'
                                              : 'Change Linked Ticket',
                                        ),
                                      ),
                                    if (owner &&
                                        m.data['memberId'] != group.ownerUid)
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Text('Remove Member'),
                                      ),
                                    if (owner && m.data['isGuest'] == true)
                                      const PopupMenuItem(
                                        value: 'edit-guest',
                                        child: Text('Edit Guest Details'),
                                      ),
                                  ],
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        m.data['ticketId'] != null
                                            ? 'Ticket linked'
                                            : 'Link ticket',
                                        style: TextStyle(
                                          color: m.data['ticketId'] != null
                                              ? Colors.green.shade700
                                              : queueRose,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.chevron_right, size: 18),
                                    ],
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 23),
                const Text(
                  'Group Reservations',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: queueInk,
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<GroupRecord>>(
                  stream: bookings,
                  builder: (context, s) {
                    if (s.hasError) {
                      return const Text('Unable to load group reservations.');
                    }
                    final records = s.data ?? [];
                    return Column(
                      children: [
                        if (records.isEmpty)
                          const ReservationPanel(
                            child: Text(
                              'No group reservations yet. Choose an attraction to plan your next adventure.',
                            ),
                          ),
                        for (final b in records)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ReservationPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    b.data['attractionName'] as String? ??
                                        'Attraction',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  Text(
                                    '${(b.data['reservationIds'] as List?)?.length ?? 0} guests • ${b.data['status'] ?? ''}',
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => GroupBookingPassPage(
                                          repository: widget.repository,
                                          booking: b,
                                        ),
                                      ),
                                    ),
                                    child: const Text('View Group Passes'),
                                  ),
                                  if (owner && b.data['status'] == 'confirmed')
                                    TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => change(
                                              'cancel',
                                              {'bookingId': b.id},
                                              'Cancel group reservation?',
                                              'Release all places for this booking. Checked-in visits cannot be cancelled.',
                                            ),
                                      child: const Text(
                                        'Cancel Group Reservation',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                ReservationButton(
                  label: 'Make Group Reservation',
                  onPressed: owner && !busy
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GroupReservePage(
                              repository: widget.repository,
                              group: group,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                if (!owner)
                  const Text(
                    'The organiser reserves attractions for the group.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6D737A), fontSize: 12),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      error!,
                      style: const TextStyle(color: queueRose),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    },
  );
}

class GroupInvitationPage extends StatefulWidget {
  final GroupRepository repository;
  final GroupRecord group;
  final GroupRecord? guestMember;
  const GroupInvitationPage({
    super.key,
    required this.repository,
    required this.group,
    this.guestMember,
  });
  @override
  State<GroupInvitationPage> createState() => _GroupInvitationPageState();
}

class _GroupInvitationPageState extends State<GroupInvitationPage> {
  late String code = widget.group.data['inviteCode'] as String? ?? '';
  bool busy = false;
  late bool guest = widget.guestMember != null;
  late final name = TextEditingController(
        text: widget.guestMember?.data['displayName'] as String? ?? '',
      ),
      height = TextEditingController(
        text: widget.guestMember?.data['heightCm']?.toString() ?? '',
      );
  late String requestId = widget.repository.newRequestId();
  String? error;
  @override
  void dispose() {
    name.dispose();
    height.dispose();
    super.dispose();
  }

  Future<void> rotate() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repository.request('invite', {
        'groupId': widget.group.id,
      });
      if (mounted) setState(() => code = result['code'] as String);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> add() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository
          .request(widget.guestMember == null ? 'addGuest' : 'editGuest', {
            'groupId': widget.group.id,
            'name': name.text.trim(),
            'heightCm': int.tryParse(height.text.trim()),
            'requestId': requestId,
            if (widget.guestMember != null)
              'memberId': widget.guestMember!.data['memberId'],
          });
      if (mounted) {
        if (widget.guestMember != null) {
          Navigator.pop(context);
          return;
        }
        name.clear();
        height.clear();
        requestId = widget.repository.newRequestId();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Guest added. Link their admission ticket from the group member list.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => GroupFrame(
    title: widget.guestMember == null
        ? 'Add Group Member'
        : 'Edit Guest Details',
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.guestMember == null)
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Invite App User')),
              ButtonSegment(value: true, label: Text('Add Guest')),
            ],
            selected: {guest},
            onSelectionChanged: busy
                ? null
                : (v) => setState(() => guest = v.single),
          ),
        const SizedBox(height: 25),
        if (!guest)
          ReservationPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Share an invitation',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ask your friend to open My Groups → Join with Invitation and enter this code, or scan the QR.',
                ),
                const SizedBox(height: 20),
                Center(
                  child: QrImageView(
                    data: 'TPGROUP1:$code',
                    size: 210,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 15),
                SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: queueRose),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: code)).then((_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invitation code copied.'),
                            ),
                          );
                        }
                      }),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy Invitation Code'),
                ),
                const SizedBox(height: 10),
                ReservationButton(
                  label: 'Generate New Invitation',
                  onPressed: rotate,
                  busy: busy,
                ),
                const SizedBox(height: 18),
                const Text(
                  'New invitations are valid for 24 hours. Generating a new one immediately revokes the previous code.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6D737A)),
                ),
              ],
            ),
          ),
        if (guest)
          ReservationPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Bring a guest',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'For a visitor without an app account, enter their name and height, then link a separate ticket from your purchase.',
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: name,
                  enabled: !busy,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Guest name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: height,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Height (cm)',
                    hintText: 'Required for ride safety',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 22),
                ReservationButton(
                  label: widget.guestMember == null
                      ? 'Add Guest'
                      : 'Save Guest Details',
                  onPressed: add,
                  busy: busy,
                ),
              ],
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(error!, style: const TextStyle(color: queueRose)),
          ),
      ],
    ),
  );
}

class JoinGroupPage extends StatefulWidget {
  final GroupRepository repository;
  const JoinGroupPage({super.key, required this.repository});
  @override
  State<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  final code = TextEditingController();
  bool busy = false, camera = false;
  String? error;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> join([String? scanned]) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      camera = false;
      if (scanned != null) code.text = scanned;
    });
    try {
      final result = await widget.repository.request('join', {
        'code': code.text.trim(),
      });
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GroupDetailPage(
              repository: widget.repository,
              id: result['groupId'] as String,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => GroupFrame(
    title: 'Join a Group',
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 15),
        const Icon(Icons.group_add_outlined, size: 85, color: queueRose),
        const SizedBox(height: 20),
        const Text(
          'Your friends are waiting',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: queueInk,
          ),
        ),
        const SizedBox(height: 22),
        ReservationPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: code,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Invitation code',
                  hintText: 'Paste the organiser’s invitation',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => join(),
              ),
              const SizedBox(height: 18),
              if (camera)
                SizedBox(
                  height: 250,
                  child: MobileScanner(
                    onDetect: (c) {
                      final value = c.barcodes.firstOrNull?.rawValue;
                      if (value != null && !busy) join(value);
                    },
                    errorBuilder: (_, error) => const Center(
                      child: Text(
                        'Camera unavailable. Paste the invitation code instead.',
                      ),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => setState(() => camera = !camera),
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(camera ? 'Close Camera' : 'Scan Group QR'),
              ),
              const SizedBox(height: 15),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(error!, style: const TextStyle(color: queueRose)),
                ),
              ReservationButton(
                label: 'Join Group',
                onPressed: () => join(),
                busy: busy,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class GroupLinkTicketPage extends StatefulWidget {
  final GroupRepository repository;
  final String groupId;
  final GroupRecord member;
  const GroupLinkTicketPage({
    super.key,
    required this.repository,
    required this.groupId,
    required this.member,
  });
  @override
  State<GroupLinkTicketPage> createState() => _GroupLinkTicketPageState();
}

class _GroupLinkTicketPageState extends State<GroupLinkTicketPage> {
  List<Map<String, dynamic>> tickets = [];
  String? selected, error;
  bool loading = true, busy = false, camera = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.repository.request('tickets', {
        'groupId': widget.groupId,
        'memberId': widget.member.data['memberId'],
      });
      if (mounted) {
        setState(
          () => tickets = (result['tickets'] as List)
              .map((t) => Map<String, dynamic>.from(t))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> link([String? scanned]) async {
    if (busy) return;
    final value = scanned ?? selected;
    if (value == null) return;
    setState(() {
      busy = true;
      error = null;
      camera = false;
    });
    try {
      await widget.repository.request('link', {
        'groupId': widget.groupId,
        'memberId': widget.member.data['memberId'],
        'ticketId': value,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => GroupFrame(
    title: 'Link Member Ticket',
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ReservationPanel(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: MemberAvatar(member: widget.member, radius: 28),
            title: Text(
              widget.member.data['displayName'] as String? ?? 'Guest',
            ),
            subtitle: Text(
              widget.member.data['ticketId'] == null
                  ? 'Ticket not linked'
                  : 'Ticket linked',
            ),
          ),
        ),
        const SizedBox(height: 20),
        ReservationPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tickets found in this account',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 15),
              if (loading) const Center(child: CircularProgressIndicator()),
              if (!loading && tickets.isEmpty)
                const Text(
                  'No eligible ticket was found for this visitor and visit date. Buy an admission ticket or check its assigned guest.',
                ),
              for (final ticket in tickets)
                ListTile(
                  selected: selected == ticket['id'],
                  leading: Icon(
                    selected == ticket['id']
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: queueRose,
                  ),
                  onTap: busy
                      ? null
                      : () => setState(() => selected = ticket['id'] as String),
                  title: Text(ticket['label'] as String),
                  subtitle: Text(
                    '${ticket['guestName']}\n${ticket['visitDate']} – ${ticket['validUntil']}',
                  ),
                  isThreeLine: true,
                ),
              const SizedBox(height: 20),
              ReservationButton(
                label: 'Link Ticket',
                onPressed: selected == null ? null : () => link(),
                busy: busy,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (camera)
          SizedBox(
            height: 260,
            child: MobileScanner(
              onDetect: (c) {
                final value = c.barcodes.firstOrNull?.rawValue;
                if (value != null && !busy) link(value);
              },
              errorBuilder: (_, error) => const Center(
                child: Text('Camera unavailable. Select a ticket above.'),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: busy ? null : () => setState(() => camera = !camera),
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(camera ? 'Close Scanner' : 'Scan Ticket QR Instead'),
        ),
        const SizedBox(height: 15),
        const Text(
          'Each guest needs a separate ticket. A ticket cannot be used for overlapping attraction reservations.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6D737A)),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Text(error!, style: const TextStyle(color: queueRose)),
          ),
      ],
    ),
  );
}
