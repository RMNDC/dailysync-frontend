import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dailysync/config.dart';

class HabitsScreen extends StatefulWidget {
  final String? token;
  final String? userId;
  const HabitsScreen({super.key, this.token, this.userId});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final List<Map<String, dynamic>> _habits = [];
  final TextEditingController _habitController = TextEditingController();
  bool _isLoading = true;
  bool _showAddForm = false;

  // Category definitions
  static const _categories = [
    {'name': 'Health',    'emoji': '🏥', 'color': Color(0xFF43A047)},
    {'name': 'Fitness',   'emoji': '💪', 'color': Color(0xFFEF5350)},
    {'name': 'Study',     'emoji': '📚', 'color': Color(0xFF1E88E5)},
    {'name': 'Spiritual', 'emoji': '🧘', 'color': Color(0xFFAB47BC)},
    {'name': 'Work',      'emoji': '💼', 'color': Color(0xFF00ACC1)},
    {'name': 'Personal',  'emoji': '🌱', 'color': Color(0xFFFFB300)},
  ];

  String _selectedCategory = 'Health';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.token}',
  };

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  @override
  void dispose() {
    _habitController.dispose();
    super.dispose();
  }

  void _loadHabits() async {
    try {
      final response = await http.get(Uri.parse('$BASE_URL/habits'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _habits.clear();
          _habits.addAll(List<Map<String, dynamic>>.from(data['habits']));
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _addHabit() async {
    if (_habitController.text.trim().isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/habits'),
        headers: _headers,
        body: jsonEncode({
          'name': _habitController.text.trim(),
          'category': _selectedCategory,
        }),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _habits.add(data['habit']);
          _habitController.clear();
          _showAddForm = false;
          _selectedCategory = 'Health';
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Habit added! 💪'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('Error adding habit: $e');
    }
  }

  void _toggleHabit(int index) async {
    final habit = _habits[index];
    final newDone = !(habit['done'] ?? false);
    try {
      final response = await http.put(
        Uri.parse('$BASE_URL/habits/${habit['_id']}'),
        headers: _headers,
        body: jsonEncode({'done': newDone}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() => _habits[index] = Map<String, dynamic>.from(data['habit']));
        if (newDone) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${habit['name']} done! Keep it up 🔥'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error toggling habit: $e');
    }
  }

  void _deleteHabit(int index) async {
    final habit = _habits[index];
    try {
      await http.delete(Uri.parse('$BASE_URL/habits/${habit['_id']}'), headers: _headers);
      setState(() => _habits.removeAt(index));
    } catch (e) {
      debugPrint('Error deleting habit: $e');
    }
  }

  Map<String, dynamic> _categoryFor(String? name) {
    return _categories.firstWhere(
      (c) => c['name'] == name,
      orElse: () => _categories[0],
    );
  }

  // ── Header banner ─────────────────────────────────────────────────────────

  Widget _buildHeader(int done, int total, bool isMobile) {
    final pct = total == 0 ? 0 : (done / total * 100).round();
    final bestStreak = _habits.isEmpty
        ? 0
        : _habits.map((h) => h['streak'] ?? 0).reduce((a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            total == 0
                ? "Let's build some routines 🌱"
                : done == total
                    ? "All done for today! 🎉"
                    : "$done of $total habits done today",
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 18 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: done / total,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              _headerStat('$pct%', 'Today'),
              _headerStat('$bestStreak', 'Best 🔥'),
              _headerStat('$total', 'Total'),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label) => Expanded(
    child: Column(children: [
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]),
  );

  // ── Add form (collapsible) ────────────────────────────────────────────────

  Widget _buildAddForm() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('New Habit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () => setState(() => _showAddForm = false),
                  child: const Icon(Icons.close, color: Colors.grey, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _habitController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. Drink water after waking up',
                prefixIcon: const Icon(Icons.edit_outlined, color: Colors.teal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onSubmitted: (_) => _addHabit(),
            ),
            const SizedBox(height: 14),
            const Text('Category', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['name'];
                final color = cat['color'] as Color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat['name'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? color : Colors.transparent),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(cat['emoji'] as String, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(
                        cat['name'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black54,
                        ),
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addHabit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Add Habit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Habit card — big, tappable, routine-style ─────────────────────────────

  Widget _buildHabitCard(int index) {
    final habit = _habits[index];
    final isDone = habit['done'] == true;
    final streak = habit['streak'] ?? 0;
    final cat = _categoryFor(habit['category']?.toString());
    final color = cat['color'] as Color;
    final emoji = cat['emoji'] as String;

    return GestureDetector(
      onTap: () => _toggleHabit(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDone ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDone ? color.withOpacity(0.4) : Colors.grey.shade200,
            width: isDone ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDone ? color.withOpacity(0.15) : Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Big tap circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDone ? color : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone ? color : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 26)
                    : Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),

            // Name + category + streak
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit['name'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDone ? Colors.grey : Colors.black87,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$emoji ${cat['name']}',
                        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (streak > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '🔥 $streak day${streak > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),

            // Delete
            GestureDetector(
              onTap: () => _deleteHabit(index),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() => Container(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('🌱', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 16),
      const Text('No habits yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      const SizedBox(height: 8),
      const Text(
        'Start small — even one habit a day\nmakes a difference over time.',
        style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: () => setState(() => _showAddForm = true),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add your first habit', style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 700;
    final done = _habits.where((h) => h['done'] == true).length;
    final total = _habits.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00695C), Color(0xFF00897B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Habits', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          // + button in AppBar to add habit
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _showAddForm = !_showAddForm),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _showAddForm ? Colors.white : Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _showAddForm ? Icons.close : Icons.add,
                  color: _showAddForm ? Colors.teal : Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.teal,
        onRefresh: () async {
          setState(() => _isLoading = true);
          _loadHabits();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Header banner (part of scroll)
              _buildHeader(done, total, isMobile),

              Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Add form (collapsible)
                        if (_showAddForm) ...[
                          _buildAddForm(),
                          const SizedBox(height: 20),
                        ],

                        // Habit cards
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator(color: Colors.teal))
                        else if (_habits.isEmpty)
                          _buildEmptyState()
                        else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Your Routines',
                                style: TextStyle(
                                  fontSize: isMobile ? 15 : 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                '$done/$total done',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(_habits.length, (i) => _buildHabitCard(i)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Floating + button when form is hidden and habits exist
      floatingActionButton: !_showAddForm && _habits.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => setState(() => _showAddForm = true),
              backgroundColor: Colors.teal,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
