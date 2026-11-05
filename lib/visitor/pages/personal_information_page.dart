import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class PersonalInformationPage extends StatefulWidget {
const PersonalInformationPage({super.key});

@override
State<PersonalInformationPage> createState() =>
_PersonalInformationPageState();
}

class _PersonalInformationPageState
extends State<PersonalInformationPage> {
static const Color rose = Color(0xFFAD7472);
static const Color background = Color(0xFFFDF4EF);
static const Color dark = Color(0xFF263238);
static const Color grey = Color(0xFF80858B);

Uint8List? _selectedPhotoBytes;
String? _savedPhotoBase64;
String? _name;
String? _phone;
DateTime? _dateOfBirth;
String? _gender;

bool _initialized = false;
bool _saving = false;

void _initialize(Map<String, dynamic> data) {
if (_initialized) return;

_name = data['fullName'] as String?;
_phone = data['phoneNumber'] as String?;
_gender = data['gender'] as String?;
_savedPhotoBase64 = data['profilePhotoBase64'] as String?;

final rawDate = data['dateOfBirth'];

if (rawDate is Timestamp) {
_dateOfBirth = rawDate.toDate();
} else if (rawDate is String) {
_dateOfBirth = DateTime.tryParse(rawDate);
}

_initialized = true;
}

String _displayDate(DateTime? date) {
if (date == null) return '';

const months = [
'January', 'February', 'March', 'April',
'May', 'June', 'July', 'August',
'September', 'October', 'November', 'December',
];

return '${date.day} ${months[date.month - 1]} ${date.year}';
}

Future<void> _editText({
required String title,
required String currentValue,
required ValueChanged<String> onSave,
TextInputType keyboardType = TextInputType.text,
}) async {
final controller = TextEditingController(text: currentValue);
String? error;

await showDialog<void>(
context: context,
builder: (dialogContext) {
return StatefulBuilder(
builder: (dialogContext, setDialogState) {
return AlertDialog(
backgroundColor: Colors.white,
title: Text(title),
content: TextField(
controller: controller,
keyboardType: keyboardType,
autofocus: true,
decoration: InputDecoration(
labelText: title,
errorText: error,
focusedBorder: const UnderlineInputBorder(
borderSide: BorderSide(color: rose),
),
),
),
actions: [
TextButton(
onPressed: () =>
Navigator.pop(dialogContext),
child: const Text('Cancel'),
),
TextButton(
onPressed: () {
final value = controller.text.trim();

String? validationError;

if (title == 'Full Name') {
if (value.length < 2 ||
!RegExp(r'^[a-zA-Z ]+$')
    .hasMatch(value)) {
validationError =
'Enter a valid name using letters.';
}
} else if (title == 'Phone Number') {
if (!RegExp(r'^\+?[0-9]{9,15}$')
    .hasMatch(value)) {
validationError =
'Use a number such as +60123456789.';
}
}

if (validationError != null) {
setDialogState(
() => error = validationError,
);
return;
}

onSave(value);
Navigator.pop(dialogContext);
},
child: const Text(
'Done',
style: TextStyle(color: rose),
),
),
],
);
},
);
},
);

// Do not dispose immediately: dialog exit animation
// may still be using the controller.
}

Future<void> _changePhoto() async {
try {
final picked = await ImagePicker().pickImage(
source: ImageSource.gallery,
maxWidth: 800,
maxHeight: 800,
);

if (picked == null) return;

final originalBytes = await picked.readAsBytes();

final decoded = img.decodeImage(originalBytes);

if (decoded == null) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Unsupported image format. Please choose JPG or PNG.'),
),
);
return;
}

// Reduce image dimensions to 160 x 160 maximum.
final resized = img.copyResize(
decoded,
width: 160,
height: 160,
maintainAspect: true,
);

// Convert to compressed JPEG.
final compressedBytes = Uint8List.fromList(
img.encodeJpg(resized, quality: 65),
);

final encoded = base64Encode(compressedBytes);

// Keep the encoded avatar small for Firestore.
if (encoded.length > 150000) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Photo is too large. Please choose another image.'),
),
);
return;
}

if (!mounted) return;

setState(() {
_selectedPhotoBytes = compressedBytes;
});
} catch (e) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Unable to select photo: $e')),
);
}
}

Future<void> _editDate() async {
final today = DateTime.now();

final selected = await showDatePicker(
context: context,
initialDate: _dateOfBirth ?? DateTime(2005, 1, 1),
firstDate: DateTime(1900),
lastDate: today,
builder: (context, child) {
return Theme(
data: Theme.of(context).copyWith(
colorScheme: const ColorScheme.light(
primary: rose,
),
),
child: child!,
);
},
);

if (selected != null && mounted) {
setState(() => _dateOfBirth = selected);
}
}

Future<void> _editGender() async {
final selected = await showModalBottomSheet<String>(
context: context,
backgroundColor: Colors.white,
builder: (sheetContext) {
return SafeArea(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
const Padding(
padding: EdgeInsets.all(20),
child: Text(
'Select Gender',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
),
for (final option in [
'Female',
'Male',
'Other',
'Prefer not to say',
])
ListTile(
title: Text(option),
trailing: _gender == option
? const Icon(Icons.check, color: rose)
    : null,
onTap: () =>
Navigator.pop(sheetContext, option),
),
const SizedBox(height: 12),
],
),
);
},
);

if (selected != null && mounted) {
setState(() => _gender = selected);
}
}

Future<void> _saveChanges(
Map<String, dynamic> original,
User user,
) async {
if (_saving) return;

final updates = <String, dynamic>{};

final originalName = original['fullName'] as String?;
final originalPhone = original['phoneNumber'] as String?;
final originalGender = original['gender'] as String?;

if (_name != originalName && _name != null) {
updates['fullName'] = _name!.trim();
}

if (_phone != originalPhone && _phone != null) {
updates['phoneNumber'] = _phone!.trim();
}

if (_gender != originalGender && _gender != null) {
updates['gender'] = _gender;
}

if (_dateOfBirth != null) {
DateTime? originalDate;
final rawDate = original['dateOfBirth'];

if (rawDate is Timestamp) {
originalDate = rawDate.toDate();
} else if (rawDate is String) {
originalDate = DateTime.tryParse(rawDate);
}

final newDate = _dateOfBirth!;

if (originalDate == null ||
originalDate.year != newDate.year ||
originalDate.month != newDate.month ||
originalDate.day != newDate.day) {
updates['dateOfBirth'] = Timestamp.fromDate(
DateTime.utc(
newDate.year,
newDate.month,
newDate.day,
),
);
}
}

if (updates.isEmpty && _selectedPhotoBytes == null) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('No changes to save.')),
);
return;
}

setState(() => _saving = true);

try {
String? newPhotoBase64;

if (_selectedPhotoBytes != null) {
newPhotoBase64 = base64Encode(_selectedPhotoBytes!);

updates['profilePhotoBase64'] = newPhotoBase64;
}

await FirebaseFirestore.instance
    .collection('visitors')
    .doc(user.uid)
    .update(updates);

if (!mounted) return;

if (newPhotoBase64 != null) {
setState(() {
_savedPhotoBase64 = newPhotoBase64;
_selectedPhotoBytes = null;
});
}

if (updates.containsKey('fullName')) {
await user.updateDisplayName(_name!.trim());
}

if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Personal information saved successfully.'),
),
);
} on FirebaseException catch (e) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Unable to save: ${e.code}')),
);
} catch (_) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Unable to save changes.'),
),
);
} finally {
if (mounted) {
setState(() => _saving = false);
}
}
}

@override
Widget build(BuildContext context) {
final user = FirebaseAuth.instance.currentUser;

if (user == null) {
return const Scaffold(
body: Center(child: Text('Please log in again.')),
);
}

return Scaffold(
backgroundColor: background,
body: Stack(
children: [
Positioned(
top: 0,
left: 0,
right: 0,
height: 400,
child: ShaderMask(
blendMode: BlendMode.dstIn,
shaderCallback: (bounds) {
return const LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
Colors.white,
Colors.white,
Colors.transparent,
],
stops: [0.0, 0.35, 1.0],
).createShader(bounds);
},
child: Opacity(
opacity: 0.55,
child: Image.asset(
'assets/images/Background.png',
fit: BoxFit.cover,
alignment: Alignment.topCenter,
),
),
),
),
SafeArea(
child: StreamBuilder<
DocumentSnapshot<Map<String, dynamic>>>(
stream: FirebaseFirestore.instance
    .collection('visitors')
    .doc(user.uid)
    .snapshots(),
builder: (context, snapshot) {
if (snapshot.hasError) {
return const Center(
child: Text('Unable to load profile.'),
);
}

if (!snapshot.hasData) {
return const Center(
child: CircularProgressIndicator(
color: rose,
),
);
}

final data = snapshot.data!.data();

if (data == null) {
return const Center(
child: Text('Visitor profile not found.'),
);
}

_initialize(data);

return ListView(
padding: const EdgeInsets.fromLTRB(
16, 8, 16, 24,
),
children: [
_header(context),
const SizedBox(height: 26),
_profilePhoto(),
const SizedBox(height: 22),
_informationCard(
email: user.email ?? '',
emailVerified: user.emailVerified,
),
const SizedBox(height: 20),
SizedBox(
height: 50,
child: ElevatedButton(
onPressed: _saving
? null
    : () => _saveChanges(data, user),
style: ElevatedButton.styleFrom(
backgroundColor: rose,
foregroundColor: Colors.white,
disabledBackgroundColor: rose,
disabledForegroundColor: Colors.white,
elevation: 0,
shape: RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(14),
),
),
child: _saving
? const SizedBox(
width: 20,
height: 20,
child: CircularProgressIndicator(
color: Colors.white,
strokeWidth: 2,
),
)
    : const Text(
'Save Changes',
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.w600,
),
),
),
),
],
);
},
),
),
],
),
);
}

Widget _header(BuildContext context) {
return Row(
children: [
IconButton(
onPressed: () => Navigator.pop(context),
icon: const Icon(
Icons.arrow_back_ios_new,
size: 20,
color: rose,
),
),
const Expanded(
child: Text(
'Personal Information',
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.w700,
color: dark,
),
),
),
IconButton(
onPressed: null,
icon: const Icon(
Icons.help_outline,
size: 25,
color: rose,
),
),
],
);
}

Widget _profilePhoto() {
Uint8List? avatarBytes = _selectedPhotoBytes;

if (avatarBytes == null &&
_savedPhotoBase64 != null &&
_savedPhotoBase64!.isNotEmpty) {
try {
avatarBytes = base64Decode(_savedPhotoBase64!);
} catch (_) {
avatarBytes = null;
}
}

return Column(
children: [
ClipOval(
child: SizedBox(
width: 110,
height: 110,
child: avatarBytes != null
? Image.memory(
avatarBytes,
fit: BoxFit.cover,
gaplessPlayback: true,
)
    : const ColoredBox(
color: Color(0xFFF0DDDA),
child: Icon(
Icons.person,
size: 72,
color: rose,
),
),
),
),
const SizedBox(height: 12),
OutlinedButton(
onPressed: _saving ? null : _changePhoto,
style: OutlinedButton.styleFrom(
foregroundColor: rose,
side: const BorderSide(color: rose),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
),
child: const Text('Change Photo'),
),
],
);
}

Widget _informationCard({
required String email,
required bool emailVerified,
}) {
return Container(
padding: const EdgeInsets.symmetric(
horizontal: 18,
vertical: 4,
),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: const Color(0xFFF0E4DF),
),
boxShadow: const [
BoxShadow(
color: Color(0x0DAD7472),
blurRadius: 12,
offset: Offset(0, 3),
),
],
),
child: Column(
children: [
_infoRow(
label: 'Full Name',
value: _name,
onEdit: () => _editText(
title: 'Full Name',
currentValue: _name ?? '',
onSave: (value) =>
setState(() => _name = value),
),
),
_divider(),
_infoRow(
label: 'Email Address',
value: email,
verified: emailVerified,
onEdit: null,
),
_divider(),
_infoRow(
label: 'Phone Number',
value: _phone,
onEdit: () => _editText(
title: 'Phone Number',
currentValue: _phone ?? '+60',
keyboardType: TextInputType.phone,
onSave: (value) =>
setState(() => _phone = value),
),
),
_divider(),
_infoRow(
label: 'Date of Birth',
value: _dateOfBirth == null
? null
    : _displayDate(_dateOfBirth),
onEdit: _editDate,
),
_divider(),
_infoRow(
label: 'Gender',
value: _gender,
onEdit: _editGender,
),
],
),
);
}

Widget _infoRow({
required String label,
required String? value,
required VoidCallback? onEdit,
bool verified = false,
}) {
final missing = value == null || value.trim().isEmpty;

return SizedBox(
height: 78,
child: Row(
children: [
Expanded(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
label,
style: const TextStyle(
fontSize: 12,
color: grey,
),
),
const SizedBox(height: 6),
if (missing)
Align(
alignment: Alignment.centerLeft,
child: Container(
padding: const EdgeInsets.symmetric(
horizontal: 10,
vertical: 5,
),
decoration: BoxDecoration(
color: const Color(0xFFFFF3F0),
borderRadius:
BorderRadius.circular(20),
),
child: const Text(
'+ Add details',
style: TextStyle(
fontSize: 12,
fontWeight: FontWeight.w500,
color: rose,
),
),
),
)
else
Text(
value,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
fontSize: 15,
fontWeight: FontWeight.w600,
color: dark,
),
),
],
),
),
if (verified) ...[
Container(
padding: const EdgeInsets.symmetric(
horizontal: 10,
vertical: 5,
),
decoration: BoxDecoration(
border: Border.all(color: rose),
borderRadius: BorderRadius.circular(20),
),
child: const Text(
'Verified',
style: TextStyle(
color: rose,
fontSize: 10,
),
),
),
const SizedBox(width: 8),
],
IconButton(
tooltip: onEdit == null
? '$label editing unavailable'
    : 'Edit $label',
onPressed: onEdit,
icon: Icon(
Icons.edit_outlined,
color: onEdit == null
? const Color(0xFFCFBDB9)
    : rose,
size: 22,
),
),
],
),
);
}

Widget _divider() {
return const Divider(
height: 1,
color: Color(0xFFE9E3E0),
);
}
}