import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'support_attachment.dart';
import '../visitor/models/tickets.dart';
import '../visitor/services/ticket_journey.dart' show bookingError;
import '../visitor/widgets/rewards_widgets.dart';
import 'support_models.dart';
import 'support_repository.dart';
import 'support_widgets.dart' show SupportTabs;

class SupportSubmitForm extends StatefulWidget {
  final SupportRepository repository;
  final PendingSupportStore pendingStore;
  final String initialType;
  final ValueChanged<SupportCase> onSent;
  final VoidCallback onSignIn;
  final ValueChanged<bool>? onBusy;
  const SupportSubmitForm({
    super.key,
    required this.repository,
    required this.pendingStore,
    required this.initialType,
    required this.onSent,
    required this.onSignIn,
    this.onBusy,
  });
  @override
  State<SupportSubmitForm> createState() => SupportSubmitFormState();
}

class SupportSubmitFormState extends State<SupportSubmitForm> {
  final form = GlobalKey<FormState>();
  final subject = TextEditingController(), message = TextEditingController();
  late String type = widget.initialType,
      category = 'App Experience',
      orderId = '';
  bool consent = false, busy = false, loading = true, pending = false;
  String? error, id;
  SupportAttachment? file;
  bool get hasUnsentChanges =>
      !pending &&
      (subject.text.isNotEmpty || message.text.isNotEmpty || file != null);
  SupportDraft get draft => SupportDraft(
    type: type,
    category: category,
    subject: subject.text,
    message: message.text,
    orderId: orderId,
    contactConsent: consent,
    attachment: file,
  );
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final uid = widget.repository.userId;
      if (uid != null) {
        final saved = await widget.pendingStore.load(uid);
        if (saved != null && mounted) {
          id = saved.id;
          final d = saved.draft;
          type = d.type;
          category = d.category;
          subject.text = d.subject;
          message.text = d.message;
          orderId = d.orderId;
          consent = d.contactConsent;
          file = d.attachment;
          pending = true;
        }
      }
    } catch (_) {
      error =
          'Unable to restore the previous draft. Please reopen this page before sending.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  void setBusy(bool value) {
    setState(() => busy = value);
    widget.onBusy?.call(value);
  }

  Future<void> attach() async {
    if (busy || pending) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result.isEmpty || !mounted) return;
    setBusy(true);
    setState(() => error = null);
    try {
      final selected = result.single;
      final prepared = prepareSupportAttachment(
        selected.name,
        await selected.readAsBytes(),
      );
      if (!mounted) return;
      setState(() => file = prepared);
    } catch (e) {
      if (mounted) setState(() => error = bookingError(e));
    } finally {
      if (mounted) setBusy(false);
    }
  }

  Future<void> send() async {
    if (busy || !form.currentState!.validate()) return;
    final value = draft;
    if (value.validation != null) {
      setState(() => error = value.validation);
      return;
    }
    setBusy(true);
    setState(() => error = null);
    try {
      final uid = widget.repository.userId;
      if (uid == null) {
        throw StateError('Please sign in before sending a request.');
      }
      id ??= newSupportId();
      await widget.pendingStore.save(uid, PendingSupportSubmission(id!, value));
      if (mounted) setState(() => pending = true);
      final record = await widget.repository.submit(id!, value);
      await widget.pendingStore.clear(uid);
      if (mounted) widget.onSent(record);
    } catch (e) {
      if (mounted) setState(() => error = bookingError(e));
    } finally {
      if (mounted) {
        setBusy(false);
      } else {
        widget.onBusy?.call(false);
      }
    }
  }

  Future<void> reviewPending() async {
    if (busy || id == null) return;
    setBusy(true);
    setState(() => error = null);
    try {
      final previous = await widget.repository.findCase(id!);
      if (previous != null) {
        await widget.pendingStore.clear(widget.repository.userId!);
        if (mounted) widget.onSent(previous);
      } else {
        await widget.pendingStore.clear(widget.repository.userId!);
        if (mounted) {
          setState(() {
            pending = false;
            id = null;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = bookingError(e));
    } finally {
      if (mounted) {
        setBusy(false);
      } else {
        widget.onBusy?.call(false);
      }
    }
  }

  InputDecoration decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF91979A)),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: Color(0xFFDCDAD8)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: Color(0xFFDCDAD8)),
    ),
  );
  Widget label(String value) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Text(
      value,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (widget.repository.userId == null) {
      return ListView(
        primary: false,
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 30),
          const Icon(Icons.support_agent, size: 70, color: rewardRose),
          const SizedBox(height: 20),
          const Text(
            'Let’s keep your request together',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          const Text(
            'Sign in to send a request and receive updates in My Requests.',
            textAlign: TextAlign.center,
            style: TextStyle(color: rewardMuted, height: 1.5),
          ),
          const SizedBox(height: 24),
          RewardButton('Sign In', onPressed: widget.onSignIn),
        ],
      );
    }
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: rewardRose));
    }
    final locked = busy || pending;
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 35, 16, 24),
      children: [
        RewardCard(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SupportTabs(
                  labels: const ['Feedback', 'Problem', 'Complaint'],
                  selected: supportTypes[type]!,
                  segmented: true,
                  onChanged: (v) {
                    if (!locked) {
                      setState(
                        () => type = supportTypes.entries
                            .firstWhere((e) => e.value == v)
                            .key,
                      );
                    }
                  },
                ),
                if (pending)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Your previous submission is waiting for confirmation. Retry it to avoid sending a duplicate.',
                          style: TextStyle(
                            fontSize: 12,
                            color: rewardMuted,
                            height: 1.5,
                          ),
                        ),
                        TextButton(
                          onPressed: busy ? null : reviewPending,
                          child: const Text('Check Submission / Edit Draft'),
                        ),
                      ],
                    ),
                  ),
                label('Category'),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: decoration('Choose a category'),
                  items: supportCategories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(fontSize: 14)),
                        ),
                      )
                      .toList(),
                  onChanged: locked
                      ? null
                      : (v) => setState(() => category = v!),
                ),
                label('Subject'),
                TextFormField(
                  key: const Key('support-subject'),
                  controller: subject,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                  enabled: !locked,
                  maxLength: 100,
                  decoration: decoration(
                    'Enter a short title',
                  ).copyWith(counterText: ''),
                  validator: (v) => v == null || v.trim().length < 3
                      ? 'Enter a subject of at least 3 characters.'
                      : null,
                ),
                label('Message'),
                TextFormField(
                  key: const Key('support-message'),
                  controller: message,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                  enabled: !locked,
                  maxLength: 500,
                  minLines: 6,
                  maxLines: 10,
                  decoration: decoration(
                    'Tell us what happened or what we can improve',
                  ),
                  validator: (v) => v == null || v.trim().length < 10
                      ? 'Enter a message of at least 10 characters.'
                      : null,
                ),
                if (category == 'Tickets & Admission' ||
                    category == 'Payments & Billing' ||
                    orderId.isNotEmpty) ...[
                  label('Related Booking (optional)'),
                  StreamBuilder<List<TicketOrder>>(
                    stream: widget.repository.orders(),
                    builder: (context, snapshot) {
                      final orders = snapshot.data ?? [];
                      final value = orders.any((o) => o.id == orderId)
                          ? orderId
                          : '';
                      return DropdownButtonFormField<String>(
                        key: ValueKey('booking-$value'),
                        initialValue: value,
                        isExpanded: true,
                        decoration: decoration('Select your booking'),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('No booking selected'),
                          ),
                          for (final order in orders)
                            DropdownMenuItem(
                              value: order.id,
                              child: Text(
                                '${order.reference} · ${money(order.totalMinor)}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                        onChanged: locked
                            ? null
                            : (v) => setState(() => orderId = v!),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: locked ? null : attach,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 17,
                    ),
                    side: const BorderSide(color: Color(0xFFDCDAD8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          file?.name ?? 'Add photo or document (optional)',
                          style: const TextStyle(
                            fontSize: 13,
                            color: rewardMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.attach_file, color: rewardRose),
                    ],
                  ),
                ),
                if (file != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${(file!.size / 1024).ceil()} KB attached',
                          style: const TextStyle(
                            fontSize: 11,
                            color: rewardMuted,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: locked
                            ? null
                            : () => setState(() => file = null),
                        child: const Text('Remove'),
                      ),
                    ],
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'JPG, PNG or PDF · up to 500 KB. Larger photos are resized.',
                      style: TextStyle(fontSize: 10, color: rewardMuted),
                    ),
                  ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  activeColor: rewardRose,
                  title: const Text(
                    'I agree to be contacted about this submission.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: consent,
                  onChanged: locked
                      ? null
                      : (v) => setState(() => consent = v!),
                ),
                const Text(
                  'Replies and status updates are always available in My Requests.',
                  style: TextStyle(fontSize: 11, color: rewardMuted),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: Color(0xFFAE4749),
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                RewardButton(
                  busy
                      ? 'Sending…'
                      : pending
                      ? 'Retry Submission'
                      : 'Submit',
                  onPressed: busy ? null : send,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'We aim to respond within 5 working days.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: rewardMuted),
        ),
      ],
    );
  }
}
