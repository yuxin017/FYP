import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../device/speech_input.dart';
import '../photos/photo_widgets.dart';
import '../photos/photo_repository.dart';
import '../visitor/visitor_main_page.dart';
import '../visitor/widgets/visitor_bottom_nav.dart';
import '../groups/group_pages.dart';
import '../groups/group_repository.dart';
import '../photos/photo_gallery_pages.dart';
import '../visitor/pages/rewards_page.dart';
import '../support/support_page.dart';
import 'intelligence_repository.dart';

class AssistantMessage {
  final String text, language;
  final bool fromVisitor;
  final List<String> actions;
  final DateTime time;
  AssistantMessage(
    this.text,
    this.language, {
    this.fromVisitor = false,
    this.actions = const [],
  }) : time = DateTime.now();
}

class ParkAssistantPage extends StatefulWidget {
  final ParkIntelligenceRepository repository;
  final String visitorName;
  const ParkAssistantPage({
    super.key,
    required this.repository,
    this.visitorName = '',
  });
  @override
  State<ParkAssistantPage> createState() => _ParkAssistantPageState();
}

class _ParkAssistantPageState extends State<ParkAssistantPage> {
  final input = TextEditingController(),
      scroll = ScrollController(),
      tts = FlutterTts();
  late final messages = <AssistantMessage>[
    AssistantMessage(
      'Hi${widget.visitorName.isEmpty ? '' : ' ${widget.visitorName}'}! Ask me anything about the park.',
      'en',
    ),
  ];
  String language = 'auto';
  bool busy = false, listening = false, speaking = false;
  String detect(String text) {
    if (language != 'auto') return language;
    if (RegExp(r'[\u3400-\u9fff]').hasMatch(text)) return 'zh';
    if (RegExp(
      r'\b(di|mana|tandas|tiket|beli|kumpulan|gambar|mata|ganjaran|bagaimana|boleh|masa|makanan|saya)\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      return 'ms';
    }
    return 'en';
  }

  String locale(String lang) =>
      {'en': 'en-GB', 'ms': 'ms-MY', 'zh': 'zh-CN'}[lang] ?? 'en-GB';
  String label(String lang) =>
      {
        'auto': 'Auto Detect',
        'en': 'English',
        'ms': 'Bahasa Melayu',
        'zh': '中文',
      }[lang] ??
      lang;
  Future<void> speak(AssistantMessage message) async {
    try {
      await tts.stop();
      await tts.setLanguage(locale(message.language));
      await tts.speak(message.text);
    } catch (_) {
      if (mounted) notice('Audio playback is unavailable on this device.');
    }
  }

  void notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> send([String? suggested, bool voice = false]) async {
    final question = (suggested ?? input.text).trim();
    if (question.isEmpty || busy) return;
    final lang = detect(question);
    input.clear();
    setState(() {
      busy = true;
      messages.add(AssistantMessage(question, lang, fromVisitor: true));
    });
    moveToLatest();
    try {
      final response = await widget.repository.request('assistant', {
        'message': question,
        'language': lang,
      });
      if (!mounted) return;
      final message = AssistantMessage(
        response['answer'] as String,
        lang,
        actions: (response['actions'] as List? ?? []).cast<String>(),
      );
      setState(() => messages.add(message));
      if (voice) await speak(message);
    } catch (e) {
      if (mounted) {
        setState(
          () => messages.add(
            AssistantMessage(photoError(e), lang, actions: const ['support']),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        moveToLatest();
      }
    }
  }

  Future<void> microphone() async {
    if (busy || listening) return;
    setState(() => listening = true);
    try {
      final text = await listenSpeech(
        locale(language == 'auto' ? 'en' : language),
      );
      if (text.isNotEmpty && mounted) await send(text, true);
    } catch (e) {
      if (mounted) {
        notice(
          e is StateError
              ? e.message.toString()
              : 'Voice input could not start. Please type your question.',
        );
      }
    } finally {
      if (mounted) setState(() => listening = false);
    }
  }

  void moveToLatest() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && scroll.hasClients) {
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });
  void action(String value) {
    if (['tickets', 'queue', 'map'].contains(value)) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      if (value == 'tickets') {
        VisitorMainPage.openTickets(context, 'hub');
      } else {
        VisitorMainPage.goTo(context, value == 'map' ? 2 : 3);
      }
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => switch (value) {
          'photos' => PhotoHubPage(repository: FirebasePhotoRepository()),
          'groups' => GroupsPage(repository: FirebaseGroupRepository()),
          'rewards' => const RewardsPage(),
          _ => const SupportPage(),
        },
      ),
    );
  }

  String actionLabel(String value) => switch (value) {
    'tickets' => 'Open Tickets',
    'queue' => 'Virtual Queue',
    'map' => 'Open Park Map',
    'photos' => 'My Park Photos',
    'groups' => 'My Groups',
    'rewards' => 'Points & Vouchers',
    _ => 'Help & Support',
  };
  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: photoBackground,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Scaffold(
          backgroundColor: photoBackground,
          appBar: AppBar(
            backgroundColor: photoBackground,
            surfaceTintColor: Colors.transparent,
            leading: const BackButton(color: photoRose),
            title: const Text(
              'Park Assistant',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: photoInk,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Contact park support',
                onPressed: () => action('support'),
                icon: const Icon(Icons.headset_mic_outlined, color: photoRose),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your park guide',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF647269),
                        ),
                      ),
                    ),
                    DropdownButton<String>(
                      value: language,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.expand_more, color: photoRose),
                      items: [
                        for (final code in ['auto', 'en', 'ms', 'zh'])
                          DropdownMenuItem(
                            value: code,
                            child: Text(
                              label(code),
                              style: const TextStyle(
                                fontSize: 12,
                                color: photoRose,
                              ),
                            ),
                          ),
                      ],
                      onChanged: busy || listening
                          ? null
                          : (v) => setState(() => language = v!),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 19,
                    vertical: 12,
                  ),
                  itemCount: messages.length + (busy ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == messages.length) {
                      return const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Finding an answer…',
                          style: TextStyle(color: photoRose),
                        ),
                      );
                    }
                    final m = messages[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 21),
                      child: Column(
                        crossAxisAlignment: m.fromVisitor
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!m.fromVisitor) ...[
                                CircleAvatar(
                                  radius: 21,
                                  backgroundColor: const Color(0xFFF3E4E0),
                                  child: Image.asset(
                                    'assets/images/Theme_Park_Main_Logo.png',
                                    height: 32,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Flexible(
                                child: Container(
                                  margin: EdgeInsets.only(
                                    left: m.fromVisitor ? 38 : 0,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: m.fromVisitor
                                        ? photoRose
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: photoBorder),
                                  ),
                                  child: Text(
                                    m.text,
                                    style: TextStyle(
                                      color: m.fromVisitor
                                          ? Colors.white
                                          : photoInk,
                                      fontSize: 15,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 53),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  TimeOfDay.fromDateTime(
                                    m.time,
                                  ).format(context),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF7F858A),
                                  ),
                                ),
                                if (m.fromVisitor && language == 'auto') ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    label(m.language),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: photoRose,
                                    ),
                                  ),
                                ],
                                if (!m.fromVisitor)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Read this answer',
                                    onPressed: () => speak(m),
                                    icon: const Icon(
                                      Icons.volume_up_outlined,
                                      size: 18,
                                      color: photoRose,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (m.actions.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 52, top: 6),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final a in m.actions)
                                    OutlinedButton.icon(
                                      onPressed: () => action(a),
                                      icon: const Icon(
                                        Icons.arrow_outward,
                                        size: 15,
                                      ),
                                      label: Text(
                                        actionLabel(a),
                                        style: const TextStyle(fontSize: 11),
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
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    for (final question in [
                      'How do I reserve a ride?',
                      'Where can I find my photos?',
                      'How can I use my points?',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 9),
                        child: ActionChip(
                          label: Text(
                            question,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onPressed: busy ? null : () => send(question),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 10, 17, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: photoBorder),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          enabled: !busy,
                          maxLength: 1000,
                          maxLines: 3,
                          minLines: 1,
                          onSubmitted: (_) => send(),
                          decoration: const InputDecoration(
                            hintText: 'Type a message…',
                            counterText: '',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: listening ? 'Listening…' : 'Use microphone',
                        onPressed: busy || listening ? null : microphone,
                        icon: Icon(
                          listening ? Icons.graphic_eq : Icons.mic_none,
                          color: photoRose,
                        ),
                      ),
                      IconButton.filled(
                        tooltip: 'Send message',
                        onPressed: busy ? null : () => send(),
                        style: IconButton.styleFrom(backgroundColor: photoRose),
                        icon: const Icon(Icons.send_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: OutlinedButton.icon(
                  onPressed: busy || listening ? null : microphone,
                  icon: const Icon(Icons.headset_mic_outlined),
                  label: Text(listening ? 'Listening…' : 'Talk to Assistant'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 5, 18, 9),
                child: Text(
                  'Answers use the current park catalogue and help guide.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Color(0xFF7C8289)),
                ),
              ),
            ],
          ),
          bottomNavigationBar: VisitorBottomNav(
            selectedIndex: 2,
            onTap: (index) {
              Navigator.of(context).popUntil((r) => r.isFirst);
              VisitorMainPage.goTo(context, index);
            },
          ),
        ),
      ),
    ),
  );
}
