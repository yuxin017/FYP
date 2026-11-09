import 'package:flutter/material.dart';
import '../../accounts/account_repository.dart';
import '../../accounts/account_widgets.dart';
import '../widgets/rewards_widgets.dart';

class PreferencesPage extends StatefulWidget {
  final AccountRepository? repository;
  const PreferencesPage({super.key, this.repository});
  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  late final repo = widget.repository ?? FirebaseAccountRepository(),
      stream = repo.profile();
  final nickname = TextEditingController(),
      heightText = TextEditingController();
  final food = <String>{}, interests = <String>{};
  Map<String, dynamic>? base;
  int? height;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    nickname.dispose();
    heightText.dispose();
    super.dispose();
  }

  Map<String, dynamic> get changes {
    if (base == null) return {};
    final next = {
      'nickname': nickname.text.trim(),
      'heightCm': height,
      'foodPreferences': food.toList()..sort(),
      'parkInterests': interests.toList()..sort(),
    };
    return Map.fromEntries(
      next.entries.where((e) {
        final old = base![e.key];
        if (old is List && e.value is List) {
          final a = old.whereType<String>().toList()..sort();
          return !accountSame(a, e.value);
        }
        return !accountSame(old ?? (e.key == 'nickname' ? '' : null), e.value);
      }),
    );
  }

  Widget choices(
    Map<String, String> options,
    Set<String> selected, {
    bool foodGroup = false,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final choice in options.entries)
        ChoiceChip(
          label: Text(
            choice.value,
            style: TextStyle(
              fontSize: 12,
              color: selected.contains(choice.key) ? Colors.white : rewardInk,
            ),
          ),
          selected: selected.contains(choice.key),
          showCheckmark: true,
          checkmarkColor: Colors.white,
          selectedColor: rewardRose,
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE2C8C3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          onSelected: busy
              ? null
              : (value) => setState(() {
                  if (value) {
                    if (foodGroup) {
                      if (choice.key == 'No preference') {
                        selected.clear();
                      } else {
                        selected.remove('No preference');
                      }
                    }
                    selected.add(choice.key);
                  } else {
                    selected.remove(choice.key);
                  }
                }),
        ),
    ],
  );
  Future<void> save() async {
    if (busy || base == null) return;
    setState(() => error = null);
    if (nickname.text.trim().length > 40) {
      setState(() => error = 'Keep your nickname within 40 characters.');
      return;
    }
    final next = int.tryParse(heightText.text.trim());
    if (heightText.text.trim().isNotEmpty &&
        (next == null || next < 50 || next > 250)) {
      setState(() => error = 'Enter a height between 50 and 250 cm.');
      return;
    }
    height = next;
    final updates = changes;
    if (updates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your preferences are up to date.')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await repo.save(base!, updates);
      if (mounted) {
        setState(() => base = {...base!, ...updates});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Preferences saved.')));
      }
    } catch (e) {
      if (mounted) setState(() => error = accountError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Preferences & Interests',
    dirty:
        changes.isNotEmpty ||
        (heightText.text.isNotEmpty && int.tryParse(heightText.text) == null),
    busy: busy,
    child: StreamBuilder<Map<String, dynamic>?>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: accountDescription(
              'Unable to load preferences. Reopen this page to retry.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: rewardRose),
          );
        }
        if (base == null) {
          base = Map.from(snapshot.data!);
          nickname.text = base!['nickname'] as String? ?? '';
          height = (base!['heightCm'] as num?)?.toInt();
          heightText.text = height?.toString() ?? '';
          food.addAll(
            (base!['foodPreferences'] as List? ?? []).whereType<String>(),
          );
          interests.addAll(
            (base!['parkInterests'] as List? ?? []).whereType<String>(),
          );
        }
        return ListView(
          primary: false,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            RewardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  accountHeading('About You'),
                  accountDescription('Nickname'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nickname,
                    maxLength: 40,
                    onChanged: (_) => setState(() {}),
                    decoration: accountInput('How should we call you?')
                        .copyWith(
                          counterText: '',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                  ),
                  const SizedBox(height: 19),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Height',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 92,
                        child: TextField(
                          controller: heightText,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          onChanged: (v) =>
                              setState(() => height = int.tryParse(v)),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                            suffixText: 'cm',
                            border: InputBorder.none,
                            hintText: 'Optional',
                          ),
                          style: const TextStyle(
                            color: rewardRose,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (height != null)
                        IconButton(
                          tooltip: 'Clear height',
                          visualDensity: VisualDensity.compact,
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  height = null;
                                  heightText.clear();
                                }),
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                            color: rewardRose,
                          ),
                        ),
                    ],
                  ),
                  Slider(
                    value: (height ?? 165).clamp(50, 250).toDouble(),
                    min: 50,
                    max: 250,
                    divisions: 200,
                    activeColor: rewardRose,
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            height = v.round();
                            heightText.text = height.toString();
                          }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            RewardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  accountHeading('Food Preferences'),
                  accountDescription('Select all that apply'),
                  const SizedBox(height: 12),
                  choices(foodChoices, food, foodGroup: true),
                ],
              ),
            ),
            const SizedBox(height: 14),
            RewardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  accountHeading('Park Interests'),
                  accountDescription(
                    'Help us personalise your recommendations',
                  ),
                  const SizedBox(height: 12),
                  choices(interestChoices, interests),
                ],
              ),
            ),
            accountFailure(error),
            const SizedBox(height: 15),
            RewardButton(
              busy ? 'Saving…' : 'Save Preferences',
              onPressed: busy ? null : save,
            ),
          ],
        );
      },
    ),
  );
}
