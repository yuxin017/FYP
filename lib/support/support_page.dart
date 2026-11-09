import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/login_page.dart';
import '../visitor/services/ticket_journey.dart' show bookingError;
import '../visitor/visitor_main_page.dart';
import '../visitor/widgets/rewards_widgets.dart';
import '../visitor/widgets/visitor_bottom_nav.dart';
import 'support_content.dart';
import 'support_form.dart';
import 'support_models.dart';
import 'support_repository.dart';
import 'support_widgets.dart';

class SupportPage extends StatefulWidget {
  final SupportRepository? repository;
  final PendingSupportStore? pendingStore;
  final String initialSection;
  const SupportPage({
    super.key,
    this.repository,
    this.pendingStore,
    this.initialSection = 'home',
  });
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  late final repository = widget.repository ?? FirebaseSupportRepository();
  late String section = widget.initialSection;
  final history = <String>[];
  final formKey = GlobalKey<SupportSubmitFormState>();
  final search = TextEditingController();
  String query = '',
      guideCategory = 'Getting Started',
      faqCategory = 'All',
      requestStatus = 'All',
      type = 'feedback',
      detailTab = 'Conversation';
  SupportGuide guide = supportGuides.first;
  SupportCase? selected;
  List<SupportCase> records = [];
  bool busy = false, loading = true;
  String? error;
  StreamSubscription<List<SupportCase>>? subscription;
  @override
  void initState() {
    super.initState();
    subscription = repository.cases().listen(
      (data) {
        if (mounted) {
          setState(() {
            records = data;
            loading = false;
          });
        }
      },
      onError: (Object e) {
        if (mounted) {
          setState(() {
            error = bookingError(e);
            loading = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    subscription?.cancel();
    search.dispose();
    super.dispose();
  }

  void go(String value) {
    setState(() {
      history.add(section);
      section = value;
      query = '';
      search.clear();
      error = null;
    });
  }

  Future<bool> leaveForm() async {
    if (section != 'form' || formKey.currentState?.hasUnsentChanges != true) {
      return true;
    }
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave this form?'),
            content: const Text('Your unsent changes will be discarded.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep Writing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave Form'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> back() async {
    if (busy || !await leaveForm() || !mounted) return;
    if (history.isEmpty) {
      Navigator.pop(context);
    } else {
      setState(() {
        section = history.removeLast();
        query = '';
        search.clear();
        error = null;
      });
    }
  }

  void article(SupportGuide value) {
    guide = value;
    guideCategory = value.category;
    go('article');
  }

  void form(String value) {
    type = value;
    go('form');
  }

  Future<void> nav(int index) async {
    if (busy || !await leaveForm() || !mounted) return;
    Navigator.pop(context);
    VisitorMainPage.goTo(context, index);
  }

  void help() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Here to help'),
      content: const Text(
        'Search our guides and FAQs for quick answers. Sign in to send feedback, report a problem or make a complaint. My Requests keeps your conversation and case updates in one place. For urgent assistance during your visit, contact the nearest park staff member.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final title = switch (section) {
      'guides' || 'article' => 'User Guide',
      'faq' => 'Frequently Asked Questions',
      'form' => 'Feedback & Complaints',
      'requests' => 'My Requests',
      'case' => 'Request Details',
      'sent' => 'Request Received',
      _ => 'Help & Support',
    };
    Widget body = switch (section) {
      'guides' => guides(),
      'article' => articlePage(),
      'faq' => faqs(),
      'requests' => requests(),
      'case' => caseDetails(),
      'sent' => confirmation(),
      'form' => SupportSubmitForm(
        key: formKey,
        repository: repository,
        pendingStore: widget.pendingStore ?? PendingSupportStore(),
        initialType: type,
        onSignIn: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        ),
        onBusy: (v) {
          if (mounted) setState(() => busy = v);
        },
        onSent: (record) {
          setState(() {
            selected = record;
            section = 'sent';
            history
              ..clear()
              ..add('home');
            busy = false;
          });
        },
      ),
      _ => home(),
    };
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: rewardRose,
          primary: rewardRose,
          surface: Colors.white,
        ),
        textTheme: Theme.of(
          context,
        ).textTheme.apply(bodyColor: rewardInk, displayColor: rewardInk),
      ),
      child: PopScope(
        canPop: !busy && history.isEmpty,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) back();
        },
        child: ColoredBox(
          color: rewardBackground,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Scaffold(
                backgroundColor: rewardBackground,
                bottomNavigationBar: repository.userId == null
                    ? null
                    : VisitorBottomNav(selectedIndex: 4, onTap: nav),
                body: RewardsBackground(
                  child: SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Back',
                                onPressed: busy ? null : back,
                                icon: const Icon(
                                  Icons.arrow_back_ios_new,
                                  size: 20,
                                  color: rewardRose,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize:
                                        MediaQuery.sizeOf(context).width < 400
                                        ? 17
                                        : 19,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Support help',
                                onPressed: help,
                                icon: const Icon(
                                  Icons.help_outline,
                                  color: rewardRose,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (busy)
                          const LinearProgressIndicator(
                            color: rewardRose,
                            minHeight: 2,
                          ),
                        Expanded(
                          child: Semantics(
                            key: ValueKey(
                              '$section:${section == 'article'
                                  ? guide.id
                                  : section == 'case'
                                  ? selected?.id
                                  : ''}',
                            ),
                            container: true,
                            explicitChildNodes: true,
                            child: body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget searchBox(String hint, {VoidCallback? onSearch}) => TextField(
    key: const Key('support-search'),
    controller: search,
    onChanged: (v) => setState(() => query = v),
    onSubmitted: (_) => onSearch?.call(),
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search, color: rewardRose),
      suffixIcon: query.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              onPressed: () {
                search.clear();
                setState(() => query = '');
              },
              icon: const Icon(Icons.close, size: 18),
            ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFDDD9D6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFDDD9D6)),
      ),
    ),
  );
  Widget menu(String icon, String title, String subtitle, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              SupportIcon(icon),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: rewardMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 27, color: rewardRose),
            ],
          ),
        ),
      );
  Widget home() => ListView(
    primary: false,
    padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
    children: [
      searchBox(
        'How can we help?',
        onSearch: () {
          final value = query;
          go('faq');
          setState(() {
            query = value;
            search.text = value;
          });
        },
      ),
      if (query.isNotEmpty) ...[
        const SizedBox(height: 12),
        for (final f
            in supportFaqs
                .where(
                  (f) => '${f.question} ${f.answer}'.toLowerCase().contains(
                    query.toLowerCase(),
                  ),
                )
                .take(3))
          ListTile(
            dense: true,
            title: Text(f.question, style: const TextStyle(fontSize: 13)),
            trailing: const Icon(Icons.chevron_right, color: rewardRose),
            onTap: () {
              final value = query;
              go('faq');
              setState(() {
                query = value;
                search.text = value;
              });
            },
          ),
        TextButton(
          onPressed: () {
            final value = query;
            go('faq');
            setState(() {
              query = value;
              search.text = value;
            });
          },
          child: const Text('View All Answers'),
        ),
      ],
      const SizedBox(height: 28),
      RewardCard(
        padding: const EdgeInsets.fromLTRB(17, 18, 17, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Learn & Explore',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            menu(
              'guides',
              'Tutorials & User Guides',
              'Learn how to use app features',
              () => go('guides'),
            ),
            const Divider(height: 1, color: rewardBorder),
            menu(
              'faq',
              'Frequently Asked Questions',
              'Quick answers to common questions',
              () => go('faq'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      RewardCard(
        padding: const EdgeInsets.fromLTRB(17, 18, 17, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Us',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            menu(
              'feedback',
              'Submit Feedback',
              'Share ideas to improve the app',
              () => form('feedback'),
            ),
            const Divider(height: 1, color: rewardBorder),
            menu(
              'problem',
              'Report a Problem',
              'Tell us about an issue',
              () => form('problem'),
            ),
            const Divider(height: 1, color: rewardBorder),
            menu(
              'complaint',
              'Submit a Complaint',
              'Send a formal complaint',
              () => form('complaint'),
            ),
          ],
        ),
      ),
      if (repository.userId != null) ...[
        const SizedBox(height: 18),
        RewardButton(
          'My Requests',
          onPressed: () => go('requests'),
          outlined: true,
        ),
      ],
      const SizedBox(height: 22),
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule_outlined, color: rewardRose, size: 20),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Support hours: 9:00 AM–6:00 PM (MYT)',
              style: TextStyle(fontSize: 12, color: rewardMuted),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'For urgent park assistance, speak to the nearest staff member.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: rewardMuted, height: 1.5),
      ),
    ],
  );
  Widget guides() {
    final rows = supportGuides
        .where(
          (g) => query.isNotEmpty
              ? '${g.title} ${g.subtitle} ${g.steps.join(' ')}'
                    .toLowerCase()
                    .contains(query.toLowerCase())
              : g.category == guideCategory,
        )
        .toList();
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      children: [
        searchBox('Search guides'),
        const SizedBox(height: 25),
        SupportTabs(
          labels: const ['Getting Started', 'Tickets', 'At the Park'],
          selected: guideCategory,
          segmented: true,
          onChanged: (v) => setState(() => guideCategory = v),
        ),
        const SizedBox(height: 22),
        Text(
          query.isEmpty ? guideCategory : 'Search Results',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          query.isEmpty
              ? {
                  'Getting Started': 'Everything you need to begin your visit',
                  'Tickets': 'Book, find and present your park passes',
                  'At the Park': 'Make the most of your visit',
                }[guideCategory]!
              : '${rows.length} guides found',
          style: const TextStyle(fontSize: 14, color: rewardMuted),
        ),
        const SizedBox(height: 18),
        if (rows.isEmpty)
          empty('No matching guides', 'Try another word or browse a category.'),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: guideCard(rows[i], i == 0 && query.isEmpty),
          ),
        const SizedBox(height: 18),
        const Text(
          'Popular Guides',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: popular('scan', Icons.qr_code_2, 'Scan & Add Tickets'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: popular(
                'rewards',
                Icons.stars_outlined,
                'Points & Vouchers',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        contactCard(),
      ],
    );
  }

  IconData guideIcon(String name) => switch (name) {
    'login' => Icons.login,
    'password' => Icons.lock_reset_outlined,
    'ticket' => Icons.confirmation_number_outlined,
    'scan' => Icons.qr_code_2,
    'reward' => Icons.stars_outlined,
    _ => Icons.person_add_outlined,
  };
  Widget guideCard(SupportGuide value, bool featured) => InkWell(
    onTap: () => article(value),
    child: RewardCard(
      padding: featured ? EdgeInsets.zero : const EdgeInsets.all(16),
      child: featured
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 140, child: miniGuide(value)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              value.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              value.subtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: rewardMuted,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${value.steps.length} steps',
                                    style: const TextStyle(
                                      color: rewardRose,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: rewardRose,
                                  size: 28,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Row(
              children: [
                Icon(guideIcon(value.icon), size: 38, color: rewardRose),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        value.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: rewardMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: rewardRose),
              ],
            ),
    ),
  );
  Widget miniGuide(SupportGuide value) => Container(
    padding: const EdgeInsets.all(10),
    decoration: const BoxDecoration(
      color: Color(0xFFF9ECE5),
      image: DecorationImage(
        image: AssetImage('assets/images/Background.png'),
        fit: BoxFit.cover,
        opacity: .4,
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/images/Theme_Park_Main_Logo.png', height: 48),
        const SizedBox(height: 8),
        Text(
          value.id == 'login' ? 'Welcome Back' : value.title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(7),
          ),
          child: value.id == 'login'
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Email Address',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    thumbnailField(Icons.mail_outline, 'Your email'),
                    const SizedBox(height: 6),
                    thumbnailField(Icons.lock_outline, 'Password'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rewardRose,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'Log In',
                        style: TextStyle(fontSize: 8, color: Colors.white),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Icon(guideIcon(value.icon), size: 38, color: rewardRose),
                    const SizedBox(height: 9),
                    Text(
                      '${value.steps.length} steps',
                      style: const TextStyle(fontSize: 9, color: rewardRose),
                    ),
                  ],
                ),
        ),
      ],
    ),
  );
  Widget thumbnailField(IconData icon, String hint) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      border: Border.all(color: rewardBorder),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Row(
      children: [
        Icon(icon, size: 9, color: rewardInk),
        const SizedBox(width: 4),
        Text(hint, style: const TextStyle(fontSize: 7, color: rewardMuted)),
      ],
    ),
  );
  Widget popular(String id, IconData icon, String title) => InkWell(
    onTap: () => article(supportGuides.firstWhere((g) => g.id == id)),
    child: RewardCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 34, color: rewardRose),
          const SizedBox(height: 13),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
  Widget articlePage() {
    final siblings = supportGuides
        .where((g) => g.category == guide.category)
        .toList();
    final index = siblings.indexOf(guide);
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(22, 15, 22, 24),
      children: [
        SupportTabs(
          labels: const ['Getting Started', 'Tickets', 'At the Park'],
          selected: guide.category,
          segmented: true,
          onChanged: (v) {
            setState(
              () => guide = supportGuides.firstWhere((g) => g.category == v),
            );
          },
        ),
        const SizedBox(height: 16),
        SupportTabs(
          labels: siblings
              .map(
                (g) => g.id == 'login'
                    ? 'Log In'
                    : g.id == 'register'
                    ? 'Register'
                    : g.id == 'reset'
                    ? 'Forgot Password'
                    : g.title,
              )
              .toList(),
          selected: guide.id == 'login'
              ? 'Log In'
              : guide.id == 'register'
              ? 'Register'
              : guide.id == 'reset'
              ? 'Forgot Password'
              : guide.title,
          onChanged: (v) => setState(
            () => guide = siblings.firstWhere(
              (g) =>
                  (g.id == 'login'
                      ? 'Log In'
                      : g.id == 'register'
                      ? 'Register'
                      : g.id == 'reset'
                      ? 'Forgot Password'
                      : g.title) ==
                  v,
            ),
          ),
        ),
        const SizedBox(height: 18),
        RewardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (guide.id == 'login')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: loginDiagram(),
                )
              else
                SizedBox(height: 280, child: miniGuide(guide)),
              const SizedBox(height: 18),
              Text(
                guide.id == 'login' ? 'Log in to your account' : guide.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: rewardBorder),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < guide.steps.length; i++)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: i == 0
                              ? null
                              : const Border(
                                  top: BorderSide(color: rewardBorder),
                                ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: rewardRose,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                guide.steps[i],
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7F2),
                  border: Border.all(color: rewardBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: rewardRose),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        guide.id == 'login'
                            ? 'New user? Tap Sign Up to create an account.'
                            : 'Need more help? Search the FAQs or contact our support team.',
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => go('faq'),
                child: const Text(
                  'View related questions',
                  style: TextStyle(color: rewardRose),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RewardButton(
                      'Previous',
                      onPressed: index > 0
                          ? () => setState(() => guide = siblings[index - 1])
                          : null,
                      outlined: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: RewardButton(
                      index + 1 < siblings.length
                          ? 'Next: ${siblings[index + 1].id == 'register' ? 'Register' : 'Guide'}'
                          : 'All Guides',
                      onPressed: () => index + 1 < siblings.length
                          ? setState(() => guide = siblings[index + 1])
                          : go('guides'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget loginDiagram() => Container(
    padding: const EdgeInsets.fromLTRB(13, 22, 13, 25),
    decoration: BoxDecoration(
      color: const Color(0xFFF8EAE4),
      borderRadius: BorderRadius.circular(13),
      image: const DecorationImage(
        image: AssetImage('assets/images/Background.png'),
        fit: BoxFit.cover,
        opacity: .5,
      ),
    ),
    child: Column(
      children: [
        Image.asset('assets/images/Theme_Park_Main_Logo.png', height: 115),
        const SizedBox(height: 18),
        const Text(
          'Welcome Back',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Log in to continue your adventure',
          style: TextStyle(fontSize: 10, color: rewardMuted),
        ),
        const SizedBox(height: 18),
        RewardCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Log in with   Email Address',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              diagramField('1', Icons.mail_outline, 'Your registered email'),
              const SizedBox(height: 12),
              diagramField('2', Icons.lock_outline, 'Your password'),
              const SizedBox(height: 10),
              const Text(
                'Remember me             Forgot Password?',
                style: TextStyle(fontSize: 8, color: rewardMuted),
              ),
              const SizedBox(height: 14),
              Container(
                height: 35,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rewardRose,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '3     Log In',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 23),
        const Text(
          '4   Continue after email verification',
          style: TextStyle(
            fontSize: 11,
            color: rewardRose,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Not a member yet?    Sign Up',
          style: TextStyle(fontSize: 10, color: rewardMuted),
        ),
      ],
    ),
  );
  Widget diagramField(String number, IconData icon, String hint) => Row(
    children: [
      CircleAvatar(
        radius: 10,
        backgroundColor: rewardRose,
        child: Text(
          number,
          style: const TextStyle(fontSize: 10, color: Colors.white),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Container(
          height: 39,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: rewardBorder),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: rewardInk),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  hint,
                  style: const TextStyle(fontSize: 9, color: rewardMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Widget faqs() {
    final rows = supportFaqs
        .where(
          (f) =>
              (faqCategory == 'All' || f.category == faqCategory) &&
              '${f.question} ${f.answer}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      children: [
        searchBox('Search a question'),
        const SizedBox(height: 25),
        SupportTabs(
          labels: const ['All', 'Account', 'Tickets', 'Park Visit', 'Payments'],
          selected: faqCategory,
          onChanged: (v) => setState(() => faqCategory = v),
        ),
        const SizedBox(height: 23),
        const Text(
          'Common Questions',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 15),
        if (rows.isEmpty)
          empty(
            'No matching questions',
            'Try another search or contact our support team.',
          )
        else
          RewardCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  Column(
                    children: [
                      if (i > 0) const Divider(height: 1, color: rewardBorder),
                      ExpansionTile(
                        key: ValueKey(
                          '${rows[i].question}:$faqCategory:$query',
                        ),
                        initiallyExpanded: i == 0,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 5,
                        ),
                        title: Text(
                          rows[i].question,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        iconColor: rewardRose,
                        collapsedIconColor: rewardRose,
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          5,
                          16,
                          20,
                        ),
                        children: [
                          Text(
                            rows[i].answer,
                            style: const TextStyle(
                              fontSize: 13,
                              color: rewardMuted,
                              height: 1.6,
                            ),
                          ),
                          if (rows[i].guideId != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => article(
                                  supportGuides.firstWhere(
                                    (g) => g.id == rows[i].guideId,
                                  ),
                                ),
                                child: const Text(
                                  'View related guide',
                                  style: TextStyle(
                                    color: rewardRose,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        const SizedBox(height: 25),
        const Text(
          'Still need help?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 13),
        contactCard(),
      ],
    );
  }

  Widget contactCard() => RewardCard(
    child: Row(
      children: [
        const Icon(Icons.headset_mic_outlined, color: rewardRose, size: 37),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contact our support team',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              SizedBox(height: 5),
              Text(
                'Send feedback or report a problem',
                style: TextStyle(color: rewardMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => form('problem'),
          child: const Text(
            'Contact Support',
            style: TextStyle(fontSize: 12, color: rewardRose),
          ),
        ),
      ],
    ),
  );
  Widget empty(String title, String text) => RewardCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Icon(Icons.forum_outlined, size: 44, color: rewardRose),
          const SizedBox(height: 15),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: rewardMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
  Widget requests() {
    final rows = records
        .where(
          (r) =>
              (requestStatus == 'All' ||
                  supportStatuses[r.status] == requestStatus) &&
              r.matches(query),
        )
        .toList();
    return ListView(
      primary: false,
      padding: const EdgeInsets.all(22),
      children: [
        searchBox('Search your requests'),
        const SizedBox(height: 20),
        SupportTabs(
          labels: const ['All', 'New', 'In Progress', 'Resolved'],
          selected: requestStatus,
          onChanged: (v) => setState(() => requestStatus = v),
        ),
        const SizedBox(height: 20),
        if (error != null)
          empty('Unable to load requests', error!)
        else if (loading)
          const Center(child: CircularProgressIndicator(color: rewardRose))
        else if (rows.isEmpty)
          empty(
            'No requests found',
            'Your feedback, problems and complaints will appear here.',
          ),
        for (final record in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: InkWell(
              onTap: () {
                selected = record;
                detailTab = 'Conversation';
                go('case');
              },
              child: RewardCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.reference,
                            style: const TextStyle(
                              fontSize: 10,
                              color: rewardMuted,
                            ),
                          ),
                        ),
                        SupportStatus(record.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      record.subject,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${supportTypes[record.type]} · ${record.category}',
                      style: const TextStyle(fontSize: 12, color: rewardMuted),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Updated ${supportDay(record.updatedAt)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: rewardMuted,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: rewardRose),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        RewardButton('New Request', onPressed: () => form('feedback')),
      ],
    );
  }

  Widget confirmation() => ListView(
    primary: false,
    padding: const EdgeInsets.fromLTRB(24, 30, 24, 25),
    children: [
      const Icon(Icons.check_circle_outline, color: rewardRose, size: 85),
      const SizedBox(height: 23),
      const Text(
        'Thank you for reaching out',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      const Text(
        'Your request has been saved. Our team will review it, and you can follow updates in My Requests.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: rewardMuted, height: 1.6),
      ),
      const SizedBox(height: 24),
      RewardCard(
        child: Column(
          children: [
            Text(
              selected!.reference,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: rewardRose,
              ),
            ),
            const SizedBox(height: 10),
            Text(selected!.subject, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const SupportStatus('new'),
          ],
        ),
      ),
      const SizedBox(height: 25),
      RewardButton(
        'View My Request',
        onPressed: () {
          setState(() {
            history
              ..clear()
              ..add('home')
              ..add('requests');
            section = 'case';
          });
        },
      ),
      const SizedBox(height: 13),
      RewardButton(
        'Back to Help & Support',
        outlined: true,
        onPressed: () {
          setState(() {
            history.clear();
            section = 'home';
          });
        },
      ),
    ],
  );
  Widget caseDetails() {
    final record =
        records.where((r) => r.id == selected!.id).firstOrNull ?? selected!;
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(22, 15, 22, 25),
      children: [
        RewardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      record.reference,
                      style: const TextStyle(fontSize: 11, color: rewardMuted),
                    ),
                  ),
                  SupportStatus(record.status),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                record.subject,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${supportTypes[record.type]} · ${record.category}',
                style: const TextStyle(fontSize: 12, color: rewardMuted),
              ),
              const SizedBox(height: 6),
              Text(
                'Submitted ${supportTime(record.createdAt)}',
                style: const TextStyle(fontSize: 11, color: rewardMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SupportTabs(
          labels: const ['Conversation', 'Timeline'],
          selected: detailTab,
          segmented: true,
          onChanged: (v) => setState(() => detailTab = v),
        ),
        const SizedBox(height: 17),
        if (detailTab == 'Timeline')
          RewardCard(
            child: SupportTimeline(record: record, repository: repository),
          )
        else
          SupportConversation(record: record, repository: repository),
        if (record.status == 'resolved')
          RewardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Resolution',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  record.resolution,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                RewardButton(
                  'Reopen Request',
                  outlined: true,
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          try {
                            await repository.reopen(record);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(bookingError(e))),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                ),
              ],
            ),
          )
        else if (detailTab == 'Conversation')
          SupportReplyComposer(
            key: ValueKey(record.id),
            record: record,
            repository: repository,
            onBusy: (v) {
              if (mounted) setState(() => busy = v);
            },
          ),
      ],
    );
  }
}

class SupportReplyComposer extends StatefulWidget {
  final SupportCase record;
  final SupportRepository repository;
  final ValueChanged<bool>? onBusy;
  final bool internal;
  const SupportReplyComposer({
    super.key,
    required this.record,
    required this.repository,
    this.onBusy,
    this.internal = false,
  });
  @override
  State<SupportReplyComposer> createState() => SupportReplyComposerState();
}

class SupportReplyComposerState extends State<SupportReplyComposer> {
  final text = TextEditingController();
  bool busy = false;
  String id = newSupportId();
  String? error;
  void useTemplate(String value) {
    if (busy) return;
    text.text = value;
    setState(() {
      id = newSupportId();
      error = null;
    });
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    widget.onBusy?.call(true);
    try {
      if (widget.internal) {
        await widget.repository.note(widget.record, id, text.text);
      } else {
        await widget.repository.reply(widget.record, id, text.text);
      }
      if (mounted) {
        text.clear();
        setState(() => id = newSupportId());
      }
    } catch (e) {
      if (mounted) setState(() => error = bookingError(e));
    } finally {
      if (mounted) setState(() => busy = false);
      widget.onBusy?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) => RewardCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.internal
              ? 'Add Internal Note'
              : 'Reply to ${widget.repository.isAdmin ? 'Visitor' : 'Support'}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TextField(
          key: Key(widget.internal ? 'support-note' : 'support-reply'),
          controller: text,
          enabled: !busy,
          minLines: 3,
          maxLines: 7,
          maxLength: 2000,
          onChanged: (_) => id = newSupportId(),
          decoration: InputDecoration(
            hintText: widget.internal
                ? 'Only administrators can read this note.'
                : 'Type your message…',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: rewardBorder),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              error!,
              style: const TextStyle(color: rewardRose, fontSize: 12),
            ),
          ),
        RewardButton(
          busy
              ? 'Sending…'
              : widget.internal
              ? 'Save Internal Note'
              : 'Send Reply',
          onPressed: busy ? null : send,
        ),
      ],
    ),
  );
}
