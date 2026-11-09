import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../visitor/widgets/rewards_widgets.dart';
import 'support_models.dart';
import 'support_repository.dart';

class SupportTabs extends StatelessWidget {
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool segmented;
  const SupportTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.segmented = false,
  });
  @override
  Widget build(BuildContext context) {
    if (!segmented) {
      return RewardTabs(
        labels: labels,
        selected: selected,
        onChanged: onChanged,
      );
    }
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: rewardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final label in labels)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: label == selected
                      ? const LinearGradient(
                          colors: [Color(0xFFB57978), Color(0xFFAB6E6C)],
                        )
                      : null,
                ),
                child: TextButton(
                  onPressed: () => onChanged(label),
                  style: TextButton.styleFrom(
                    foregroundColor: label == selected
                        ? Colors.white
                        : rewardInk,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SupportIcon extends StatelessWidget {
  final String name;
  final double size;
  const SupportIcon(this.name, {super.key, this.size = 38});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Image.asset('assets/images/support/$name.png', fit: BoxFit.contain),
  );
}

class SupportStatus extends StatelessWidget {
  final String status;
  final bool priority;
  const SupportStatus(this.status, {super.key, this.priority = false});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'resolved' => const Color(0xFF428278),
      'high' => const Color(0xFFBA464B),
      'in_progress' || 'medium' => const Color(0xFFB57935),
      'low' => const Color(0xFF568981),
      _ => const Color(0xFF597FB1),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        border: Border.all(color: color.withValues(alpha: .3)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        (priority ? supportPriorities : supportStatuses)[status] ?? status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class SupportAttachmentTile extends StatefulWidget {
  final SupportCase record;
  final SupportRepository repository;
  const SupportAttachmentTile({
    super.key,
    required this.record,
    required this.repository,
  });
  @override
  State<SupportAttachmentTile> createState() => _SupportAttachmentTileState();
}

class _SupportAttachmentTileState extends State<SupportAttachmentTile> {
  bool busy = false;
  Future<void> download() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final file = await widget.repository.attachment(widget.record);
      await FilePicker.saveFile(
        dialogTitle: 'Save attachment',
        fileName: file.name,
        bytes: file.bytes,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to download this attachment. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.record.attachment;
    if (file == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: rewardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          file['mime'] == 'application/pdf'
              ? Icons.picture_as_pdf_outlined
              : Icons.image_outlined,
          color: rewardRose,
        ),
        title: Text(
          file['name'] as String,
          style: const TextStyle(fontSize: 12),
        ),
        subtitle: Text(
          '${((file['size'] as num) / 1024).ceil()} KB',
          style: const TextStyle(fontSize: 10),
        ),
        trailing: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_outlined, color: rewardRose),
        onTap: busy ? null : download,
      ),
    );
  }
}

class SupportConversation extends StatelessWidget {
  final SupportCase record;
  final SupportRepository repository;
  const SupportConversation({
    super.key,
    required this.record,
    required this.repository,
  });
  Widget bubble(
    String name,
    String body,
    DateTime? date, {
    bool staff = false,
    Widget? attachment,
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: staff ? const Color(0xFFFFF6F1) : Colors.white,
      border: Border.all(color: rewardBorder),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: rewardRose.withValues(alpha: .15),
              child: Icon(
                staff ? Icons.support_agent : Icons.person_outline,
                size: 17,
                color: rewardRose,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              supportTime(date),
              style: const TextStyle(fontSize: 9, color: rewardMuted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SelectableText(
          body,
          style: const TextStyle(fontSize: 13, height: 1.5, color: rewardInk),
        ),
        ?attachment,
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      bubble(
        record.ownerName,
        record.message,
        record.createdAt,
        attachment: record.attachment == null
            ? null
            : SupportAttachmentTile(record: record, repository: repository),
      ),
      StreamBuilder<List<SupportMessage>>(
        stream: repository.messages(record.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text(
              'Unable to load replies. Reopen this request to try again.',
              style: TextStyle(color: rewardRose),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(15),
              child: Center(
                child: CircularProgressIndicator(color: rewardRose),
              ),
            );
          }
          if (snapshot.data!.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Your request has been received. Replies from our support team will appear here.',
                style: TextStyle(fontSize: 12, color: rewardMuted, height: 1.5),
              ),
            );
          }
          return Column(
            children: snapshot.data!
                .map(
                  (m) => bubble(
                    m.role == 'admin' ? 'Support Team · ${m.author}' : m.author,
                    m.body,
                    m.createdAt,
                    staff: m.role == 'admin',
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class SupportTimeline extends StatelessWidget {
  final SupportCase record;
  final SupportRepository repository;
  const SupportTimeline({
    super.key,
    required this.record,
    required this.repository,
  });
  @override
  Widget build(BuildContext context) => StreamBuilder<List<SupportEvent>>(
    stream: repository.events(record.id),
    builder: (context, snapshot) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.mark_email_read_outlined,
            color: rewardRose,
          ),
          title: const Text(
            'Request received',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            supportTime(record.createdAt),
            style: const TextStyle(fontSize: 11),
          ),
        ),
        if (record.firstResponseAt != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.forum_outlined, color: rewardRose),
            title: const Text(
              'Support team replied',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              supportTime(record.firstResponseAt),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        if (snapshot.hasError)
          const Text(
            'Unable to load the timeline.',
            style: TextStyle(color: rewardRose),
          ),
        for (final e in snapshot.data ?? <SupportEvent>[])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              e.data['action'] == 'resolved' ? Icons.task_alt : Icons.history,
              color: rewardRose,
            ),
            title: Text(
              e.description,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${e.actor} · ${supportTime(e.createdAt)}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
      ],
    ),
  );
}
