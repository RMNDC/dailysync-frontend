import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailysync/config.dart';
import 'goals_screen.dart';
import 'habits_screen.dart';
import 'mood_screen.dart';
import 'profile_screen.dart';
import 'signup_screen.dart';

void main() {
  runApp(const DailySyncApp());
}

class DailySyncApp extends StatelessWidget {
  const DailySyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DailySync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// ─── AUTH GATE ────────────────────────────────────────────────────────────────

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLogin());
  }

  void _checkLogin() {
    final token =
        html.window.sessionStorage['token'] ??
        html.window.localStorage['token'];
    final userId =
        html.window.sessionStorage['userId'] ??
        html.window.localStorage['userId'];

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(token: token, userId: userId),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF00897B),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🌿', style: TextStyle(fontSize: 56)),
            SizedBox(height: 12),
            Text(
              'DailySync',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ─── LOGIN ────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _message = '';
  bool _isLoading = false;
  bool _obscure = true;
  bool _keepSignedIn = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLoginPreference();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLoginPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final keepSignedIn = prefs.getBool('keep_signed_in') ?? false;
    final savedEmail = prefs.getString('saved_email') ?? '';

    if (savedEmail.isNotEmpty || keepSignedIn) {
      setState(() {
        _emailCtrl.text = savedEmail;
        _keepSignedIn = keepSignedIn;
      });
    }
  }

  void _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _message = 'Please enter your email and password.');
      return;
    }
    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text,
        }),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;

      if (data['success'] == true) {
        // Never save the raw password. Let the phone/browser password manager handle it.
        final prefs = await SharedPreferences.getInstance();
        if (_keepSignedIn) {
          await prefs.setString('saved_email', _emailCtrl.text.trim());
          await prefs.setBool('keep_signed_in', true);
        } else {
          await prefs.remove('saved_email');
          await prefs.setBool('keep_signed_in', false);
        }
        await prefs.remove('saved_password');
        await prefs.remove('remember_me');

        if (!mounted) return;

        TextInput.finishAutofillContext();

        final token = data['token'].toString();
        final userId = data['userId'].toString();

        if (_keepSignedIn) {
          html.window.localStorage['token'] = token;
          html.window.localStorage['userId'] = userId;
          html.window.sessionStorage.remove('token');
          html.window.sessionStorage.remove('userId');
        } else {
          html.window.sessionStorage['token'] = token;
          html.window.sessionStorage['userId'] = userId;
          html.window.localStorage.remove('token');
          html.window.localStorage.remove('userId');
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(token: token, userId: userId),
          ),
        );
      } else {
        setState(() => _message = data['message'] ?? 'Login failed.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Login failed. Check your credentials.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF004D40), Color(0xFF00897B), Color(0xFF80CBC4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 20 : 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🌿', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text(
                  'DailySync',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your personal daily dashboard',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 40),
                Container(
                  width: isMobile ? double.infinity : 420,
                  padding: EdgeInsets.all(isMobile ? 24 : 36),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 30,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome back!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Sign in to continue',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 28),
                      _label('Email'),
                      const SizedBox(height: 8),
                      _field(
                        controller: _emailCtrl,
                        hint: 'Enter your email',
                        icon: Icons.email_outlined,
                        keyboard: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      _label('Password'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Colors.teal,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.teal,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),

                      // Keep me signed in checkbox
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _keepSignedIn,
                            activeColor: Colors.teal,
                            onChanged: (v) =>
                                setState(() => _keepSignedIn = v ?? false),
                          ),
                          const Text(
                            'Keep me signed in',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),

                      if (_message.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _message,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignupScreen(),
                            ),
                          ),
                          child: const Text.rich(
                            TextSpan(
                              text: "Don't have an account? ",
                              style: TextStyle(color: Colors.grey),
                              children: [
                                TextSpan(
                                  text: 'Sign Up',
                                  style: TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
    Iterable<String>? autofillHints,
    TextInputAction? textInputAction,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.teal),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}

// ─── DASHBOARD SHELL ──────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  final String? token;
  final String? userId;
  const DashboardScreen({super.key, this.token, this.userId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  Key _homeKey = UniqueKey();

  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;

      // Recreate Home when returning to it so it fetches the latest profile image.
      if (index == 0) {
        _homeKey = UniqueKey();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('👋 Welcome back! You are logged in.'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _HomeTab(
        key: _homeKey,
        token: widget.token,
        userId: widget.userId,
        onTabChange: _changeTab,
      ),
      HabitsScreen(token: widget.token, userId: widget.userId),
      MoodScreen(token: widget.token, userId: widget.userId),
      GoalsScreen(token: widget.token, userId: widget.userId),
      ProfileScreen(token: widget.token, userId: widget.userId),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _changeTab,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.teal,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.track_changes_outlined),
              activeIcon: Icon(Icons.track_changes_rounded),
              label: 'Habits',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.mood_outlined),
              activeIcon: Icon(Icons.mood_rounded),
              label: 'Mood',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.flag_outlined),
              activeIcon: Icon(Icons.flag_rounded),
              label: 'Goals',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── HOME TAB ─────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  final String? token;
  final String? userId;
  final void Function(int) onTabChange;
  const _HomeTab({
    super.key,
    this.token,
    this.userId,
    required this.onTabChange,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  String _username = '';
  String? _profileImageBase64;

  int _habitsDone = 0;
  int _habitsTotal = 0;
  int _bestStreak = 0;
  bool _moodLogged = false;
  int _goalsLeft = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.token}',
  };

  Future<void> _loadAll() async {
    await Future.wait([
      _loadProfile(),
      _loadHabitsSummary(),
      _loadMoodSummary(),
      _loadGoalsSummary(),
    ]);
  }

  Future<void> _loadProfile() async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/profile'),
        headers: _headers,
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['success'] == true) {
        setState(() {
          _username = data['user']['username'] ?? '';
          _profileImageBase64 = data['user']['profileImage'];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadHabitsSummary() async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/habits'),
        headers: _headers,
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['success'] == true) {
        final habits = List<Map<String, dynamic>>.from(data['habits']);
        setState(() {
          _habitsTotal = habits.length;
          _habitsDone = habits.where((h) => h['done'] == true).length;
          _bestStreak = habits.isEmpty
              ? 0
              : habits
                    .map((h) => h['streak'] ?? 0)
                    .reduce((a, b) => a > b ? a : b);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMoodSummary() async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/moods'),
        headers: _headers,
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['success'] == true) {
        final moods = List<Map<String, dynamic>>.from(data['moods']);
        final today = DateTime.now();
        _moodLogged = moods.any((m) {
          try {
            final d = DateTime.parse(m['date'].toString()).toLocal();
            return d.year == today.year &&
                d.month == today.month &&
                d.day == today.day;
          } catch (_) {
            return false;
          }
        });
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _loadGoalsSummary() async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/goals'),
        headers: _headers,
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['success'] == true) {
        final goals = List<Map<String, dynamic>>.from(data['goals']);
        setState(
          () => _goalsLeft = goals.where((g) => g['done'] != true).length,
        );
      }
    } catch (_) {}
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 600;
    final crossAxisCount = isMobile ? 1 : 3;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF004D40), Color(0xFF00897B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            const Text('🌿', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              'DailySync',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 18 : 22,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              backgroundImage:
                  _profileImageBase64 != null && _profileImageBase64!.isNotEmpty
                  ? MemoryImage(base64Decode(_profileImageBase64!))
                  : null,
              child: _profileImageBase64 == null || _profileImageBase64!.isEmpty
                  ? const Icon(Icons.person, color: Colors.white, size: 20)
                  : null,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.teal,
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Hero banner
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 20 : 32,
                  28,
                  isMobile ? 20 : 32,
                  36,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF004D40), Color(0xFF00897B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting()}${_username.isNotEmpty ? ', $_username' : ''}! 👋',
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Here's your daily overview. Let's make today count!",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isMobile ? 13 : 15,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDailySummary(isMobile),
                        const SizedBox(height: 24),
                        Text(
                          'Quick Access',
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: isMobile ? 3.2 : 1.1,
                          children: [
                            _DashboardCard(
                              icon: Icons.track_changes_rounded,
                              label: 'Habits',
                              subtitle: 'Build daily streaks',
                              gradientColors: const [
                                Color(0xFF00897B),
                                Color(0xFF4DB6AC),
                              ],
                              isMobile: isMobile,
                              onTap: () => widget.onTabChange(1),
                            ),
                            _DashboardCard(
                              icon: Icons.mood_rounded,
                              label: 'Mood',
                              subtitle: 'Track how you feel',
                              gradientColors: const [
                                Color(0xFFF57C00),
                                Color(0xFFFFB74D),
                              ],
                              isMobile: isMobile,
                              onTap: () => widget.onTabChange(2),
                            ),
                            _DashboardCard(
                              icon: Icons.flag_rounded,
                              label: 'Goals',
                              subtitle: 'Achieve your dreams',
                              gradientColors: const [
                                Color(0xFF7B1FA2),
                                Color(0xFFBA68C8),
                              ],
                              isMobile: isMobile,
                              onTap: () => widget.onTabChange(3),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailySummary(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Summary",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryItem(
                '🔥',
                'Streak',
                '$_bestStreak days',
                Colors.deepOrange,
              ),
              _divider(),
              _summaryItem(
                '✅',
                'Habits',
                '$_habitsDone/$_habitsTotal',
                Colors.teal,
              ),
              _divider(),
              _summaryItem(
                '😊',
                'Mood',
                _moodLogged ? 'Logged' : 'Not yet',
                Colors.orange,
              ),
              _divider(),
              _summaryItem('🎯', 'Goals', '$_goalsLeft left', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String emoji, String label, String value, Color color) =>
      Expanded(
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      );

  Widget _divider() => Container(
    height: 40,
    width: 1,
    color: Colors.grey.shade200,
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );
}

// ─── DASHBOARD CARD ───────────────────────────────────────────────────────────

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradientColors;
  final bool isMobile;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradientColors,
    required this.isMobile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: isMobile
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white54,
                      size: 16,
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
