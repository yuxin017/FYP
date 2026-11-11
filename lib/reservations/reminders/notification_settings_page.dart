import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../accounts/account_widgets.dart';
import '../../visitor/widgets/rewards_widgets.dart';
import 'reminder_delivery.dart';
import 'reservation_reminders.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key, this.uid, this.device});
  final String? uid;
  final ReminderDevice? device;
  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with WidgetsBindingObserver {
  late final uid = widget.uid ?? FirebaseAuth.instance.currentUser!.uid;
  late final device = widget.device ?? reservationReminderDevice;
  ReminderDeviceStatus? state;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (value == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    final next = await device.status(uid);
    if (mounted) setState(() => state = next);
  }

  Future<void> change(bool enabled) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (enabled) {
        await device.enable(uid);
      } else {
        await device.disable(uid);
      }
      await ReservationReminderSettings.refresh(uid);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : 'Notifications could not be updated. Check your connection and try again.',
        );
      }
    } finally {
      await load();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Notifications',
    busy: busy,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(22, 36, 22, 24),
      children: [
        RewardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              accountHeading('Reservation Reminders'),
              const SizedBox(height: 12),
              const Icon(
                Icons.notifications_active_outlined,
                size: 56,
                color: Color(0xFFAD7472),
              ),
              const SizedBox(height: 16),
              accountDescription(
                'Receive a notification 15 minutes before a confirmed attraction reservation, even when the application is closed.',
              ),
              const SizedBox(height: 18),
              if (state == null)
                const Center(child: CircularProgressIndicator())
              else
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notifications on this device'),
                  subtitle: Text(state!.enabled ? 'Enabled' : 'Off'),
                  value: state!.enabled,
                  onChanged: busy || !state!.supported ? null : change,
                ),
              if (state?.message != null) accountDescription(state!.message!),
              ValueListenableBuilder<String?>(
                valueListenable: ReservationReminderSettings.deliveryError,
                builder: (_, value, _) => accountFailure(error ?? value),
              ),
              const Divider(height: 30),
              accountDescription(
                'Choose “Notify me” when reviewing a reservation, or change its reminder in My Reservations. Cancelling a reservation removes its reminder when this device receives the update.',
              ),
              const SizedBox(height: 12),
              accountDescription(
                'Your device controls notification permissions. Focus modes, force-stopping the app or browser, and device power settings can affect delivery. Browser reminders require an internet connection and the park service to be running.',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
