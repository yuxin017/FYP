import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../accounts/account_repository.dart';
import '../../accounts/account_widgets.dart';
import '../../accounts/security_pages.dart';
import '../widgets/rewards_widgets.dart';

class PersonalInformationPage extends StatefulWidget {
  final AccountRepository? repository;
  const PersonalInformationPage({super.key, this.repository});
  @override
  State<PersonalInformationPage> createState() =>
      _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<PersonalInformationPage> {
  late final repo = widget.repository ?? FirebaseAccountRepository();
  late final stream = repo.profile();
  Map<String, dynamic>? base;
  String name = '', phone = '', gender = '', photo = '';
  DateTime? dob;
  bool busy = false;
  String? error;
  Map<String, dynamic> get updates {
    if (base == null) return {};
    final candidates = <String, dynamic>{
      'fullName': name.trim(),
      'phoneNumber': phone.trim(),
      'gender': gender,
      'profilePhotoBase64': photo,
    };
    final result = <String, dynamic>{};
    for (final entry in candidates.entries) {
      if ((base![entry.key] ?? '') != entry.value) {
        result[entry.key] = entry.value;
      }
    }
    if (dob != null) {
      final previous = profileDate(base!['dateOfBirth']);
      if (previous == null ||
          previous.year != dob!.year ||
          previous.month != dob!.month ||
          previous.day != dob!.day) {
        result['dateOfBirth'] = Timestamp.fromDate(
          DateTime.utc(dob!.year, dob!.month, dob!.day),
        );
      }
    }
    return result;
  }

  void initialize(Map<String, dynamic> data) {
    base = Map.from(data);
    name = data['fullName'] as String? ?? '';
    phone = data['phoneNumber'] as String? ?? '';
    gender = data['gender'] as String? ?? '';
    photo = data['profilePhotoBase64'] as String? ?? '';
    dob = profileDate(data['dateOfBirth']);
  }

  Future<void> edit(
    String title,
    String value,
    String? Function(String?) validator,
    ValueChanged<String> save,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _ProfileEditDialog(title: title, value: value, validator: validator),
    );
    if (result != null && mounted) setState(() => save(result));
  }

  Future<void> avatar() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );
      if (files.isEmpty || !mounted) return;
      setState(() => busy = true);
      final bytes = prepareAvatar(await files.single.readAsBytes());
      if (mounted) setState(() => photo = base64Encode(bytes));
    } catch (e) {
      if (mounted) setState(() => error = accountError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy || base == null) return;
    final invalid = nameError(name) ?? phoneError(phone);
    if (invalid != null) {
      setState(() => error = invalid);
      return;
    }
    final change = updates;
    if (change.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your information is up to date.')),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.save(base!, change);
      if (mounted) {
        setState(() => base = {...base!, ...change});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Personal information saved.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = accountError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget row(
    String title,
    String value,
    VoidCallback? onTap, {
    bool verified = false,
  }) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 17),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: rewardMuted),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    value.isEmpty ? '+ Add details' : value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: value.isEmpty ? rewardRose : rewardInk,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (verified)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: rewardRose),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(
                  'Verified',
                  style: TextStyle(color: rewardRose, fontSize: 10),
                ),
              ),
            IconButton(
              tooltip: 'Edit $title',
              onPressed: busy ? null : onTap,
              icon: const Icon(
                Icons.edit_outlined,
                size: 21,
                color: rewardRose,
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1, color: rewardBorder),
    ],
  );
  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Personal Information',
    dirty: updates.isNotEmpty,
    busy: busy,
    child: StreamBuilder<Map<String, dynamic>?>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: accountDescription(
              'Unable to load your profile. Reopen this page to retry.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: rewardRose),
          );
        }
        if (base == null) initialize(snapshot.data!);
        ImageProvider? avatarImage;
        try {
          if (photo.isNotEmpty) avatarImage = MemoryImage(base64Decode(photo));
        } catch (_) {}
        return ListView(
          primary: false,
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFFF1DEDB),
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? const Icon(Icons.person, size: 69, color: rewardRose)
                    : null,
              ),
            ),
            Center(
              child: OutlinedButton(
                onPressed: busy ? null : avatar,
                child: const Text('Change Photo'),
              ),
            ),
            if (photo.isNotEmpty)
              Center(
                child: TextButton(
                  onPressed: busy ? null : () => setState(() => photo = ''),
                  child: const Text('Remove Photo'),
                ),
              ),
            const SizedBox(height: 14),
            RewardCard(
              child: Column(
                children: [
                  row(
                    'Full Name',
                    name,
                    () => edit('Full Name', name, nameError, (v) => name = v),
                  ),
                  row(
                    'Email Address',
                    repo.identity?.email ?? '',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EmailChangePage(repository: repo),
                      ),
                    ),
                    verified: repo.identity?.verified == true,
                  ),
                  row(
                    'Phone Number',
                    phone,
                    () => edit(
                      'Phone Number',
                      phone,
                      phoneError,
                      (v) => phone = v,
                    ),
                  ),
                  row(
                    'Date of Birth',
                    dob == null
                        ? ''
                        : '${dob!.day} ${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][dob!.month - 1]} ${dob!.year}',
                    () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: dob ?? DateTime(2005),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (date != null && mounted) setState(() => dob = date);
                    },
                  ),
                  row('Gender', gender, () async {
                    final result = await showModalBottomSheet<String>(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(18),
                              child: Text(
                                'Select Gender',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            for (final value in [
                              'Female',
                              'Male',
                              'Other',
                              'Prefer not to say',
                            ])
                              ListTile(
                                title: Text(value),
                                trailing: value == gender
                                    ? const Icon(Icons.check, color: rewardRose)
                                    : null,
                                onTap: () => Navigator.pop(ctx, value),
                              ),
                          ],
                        ),
                      ),
                    );
                    if (result != null && mounted) {
                      setState(() => gender = result);
                    }
                  }),
                ],
              ),
            ),
            accountFailure(error),
            const SizedBox(height: 12),
            RewardButton(
              busy ? 'Saving…' : 'Save Changes',
              onPressed: busy ? null : save,
            ),
            const SizedBox(height: 12),
            Center(
              child: accountDescription(
                'Keep your personal and contact details up to date.',
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ProfileEditDialog extends StatefulWidget {
  final String title, value;
  final String? Function(String?) validator;
  const _ProfileEditDialog({
    required this.title,
    required this.value,
    required this.validator,
  });
  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late final controller = TextEditingController(text: widget.value);
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: form,
      child: TextFormField(
        controller: controller,
        autofocus: true,
        keyboardType: widget.title == 'Phone Number'
            ? TextInputType.phone
            : TextInputType.name,
        decoration: accountInput(widget.title),
        validator: widget.validator,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, controller.text.trim());
          }
        },
        child: const Text('Done'),
      ),
    ],
  );
}
