import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dailysync/config.dart';

// ─── CATEGORY DEFINITIONS ─────────────────────────────────────────────────────

class GoalCategory {
  final String name;
  final String emoji;
  final Color color;
  const GoalCategory({
    required this.name,
    required this.emoji,
    required this.color,
  });
}

const List<GoalCategory> kGoalCategories = [
  GoalCategory(name: 'All', emoji: '📋', color: Colors.purple),
  GoalCategory(name: 'Personal', emoji: '🌱', color: Color(0xFF00ACC1)),
  GoalCategory(name: 'Career', emoji: '💼', color: Color(0xFF1E88E5)),
  GoalCategory(name: 'Health', emoji: '🏥', color: Color(0xFF43A047)),
  GoalCategory(name: 'Finance', emoji: '💰', color: Color(0xFFFFB300)),
  GoalCategory(name: 'Learning', emoji: '📚', color: Color(0xFFAB47BC)),
  GoalCategory(name: 'Other', emoji: '🎯', color: Color(0xFFEF5350)),
];

// ─── PRIORITY DEFINITIONS ─────────────────────────────────────────────────────

class GoalPriority {
  final String name;
  final String emoji;
  final Color color;
  const GoalPriority({
    required this.name,
    required this.emoji,
    required this.color,
  });
}

const List<GoalPriority> kPriorities = [
  GoalPriority(name: 'High', emoji: '🔴', color: Color(0xFFEF5350)),
  GoalPriority(name: 'Medium', emoji: '🟡', color: Color(0xFFFFB300)),
  GoalPriority(name: 'Low', emoji: '🟢', color: Color(0xFF43A047)),
];

GoalCategory _categoryFor(String? name) => kGoalCategories.firstWhere(
  (c) => c.name == name,
  orElse: () => kGoalCategories[1],
);

GoalPriority _priorityFor(String? name) =>
    kPriorities.firstWhere((p) => p.name == name, orElse: () => kPriorities[1]);

// ─── SCREEN ───────────────────────────────────────────────────────────────────

class GoalsScreen extends StatefulWidget {
  final String? token;
  final String? userId;
  const GoalsScreen({super.key, this.token, this.userId});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final List<Map<String, dynamic>> _goals = [];
  final TextEditingController _goalController = TextEditingController();

  bool _isLoading = true;

  // Add form state
  String _selectedCategory = 'Personal';
  String _selectedPriority = 'Medium';
  DateTime? _selectedDueDate;

  // Filter
  String _filterCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.token}',
  };

  // ── API calls ────────────────────────────────────────────────────────────────

  void _loadGoals() async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/goals'),
        headers: _headers,
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _goals.clear();
          _goals.addAll(List<Map<String, dynamic>>.from(data['goals']));
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _addGoal() async {
    if (_goalController.text.trim().isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/goals'),
        headers: _headers,
        body: jsonEncode({
          'name': _goalController.text.trim(),
          'category': _selectedCategory,
          'priority': _selectedPriority,
          'dueDate': _selectedDueDate?.toIso8601String(),
        }),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _goals.add(data['goal']);
          _goalController.clear();
          _selectedDueDate = null;
          _selectedCategory = 'Personal';
          _selectedPriority = 'Medium';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal added! 🎯'),
            backgroundColor: Colors.purple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding goal: $e');
    }
  }

  void _toggleGoal(int index) async {
    final goal = _goals[index];
    final newDone = !(goal['done'] ?? false);
    try {
      await http.put(
        Uri.parse('$BASE_URL/goals/${goal['_id']}'),
        headers: _headers,
        body: jsonEncode({'done': newDone}),
      );
      setState(() => _goals[index]['done'] = newDone);
      if (newDone) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal completed! 🎉'),
            backgroundColor: Colors.purple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling goal: $e');
    }
  }

  void _deleteGoal(int index) async {
    final goal = _goals[index];
    try {
      await http.delete(
        Uri.parse('$BASE_URL/goals/${goal['_id']}'),
        headers: _headers,
      );
      setState(() => _goals.removeAt(index));
    } catch (e) {
      debugPrint('Error deleting goal: $e');
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.purple),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDueDate = picked);
  }

  // ── Filtered list ────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filtered {
    if (_filterCategory == 'All') return _goals;
    return _goals.where((g) => g['category'] == _filterCategory).toList();
  }

  // ── Circular progress card ────────────────────────────────────────────────────

  Widget _buildProgressCard(int completed, int total, double progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Goal Progress',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            total == 0
                ? 'No goals yet. Dream big! 🚀'
                : '$completed of $total completed',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // ✅ Stat chips
          Row(
            children: [
              _statChip('🎯', '$total', 'Total'),
              const SizedBox(width: 8),
              _statChip('✅', '$completed', 'Done'),
              const SizedBox(width: 8),
              _statChip('⏳', '${total - completed}', 'Left'),
              const SizedBox(width: 8),
              _statChip(
                '📊',
                '${(progress * 100).toStringAsFixed(0)}%',
                'Progress',
              ),
            ],
          ),

          if (total > 0) ...[
            const SizedBox(height: 24),

            // ✅ Circular progress indicator — replaces the confusing bar chart
            Center(
              child: SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 14,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'complete',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(Colors.white, 'Completed'),
                const SizedBox(width: 16),
                _legendDot(Colors.white30, 'Remaining'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statChip(String emoji, String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ],
      ),
    ),
  );

  Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ],
  );

  // ── Category filter chips ─────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kGoalCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = kGoalCategories[i];
          final isSelected = _filterCategory == cat.name;
          return GestureDetector(
            onTap: () => setState(() => _filterCategory = cat.name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? cat.color : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? cat.color : Colors.grey.shade300,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: cat.color.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Add form ──────────────────────────────────────────────────────────────────

  Widget _buildAddForm(bool isMobile) => Container(
    padding: const EdgeInsets.all(20),
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
          'Add New Goal',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),

        // ✅ Category picker
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        _buildCategoryPicker(),
        const SizedBox(height: 14),

        // ✅ Priority picker
        const Text(
          'Priority',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        _buildPriorityPicker(),
        const SizedBox(height: 14),

        // ✅ Due date picker
        const Text(
          'Due Date (optional)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDueDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedDueDate != null
                    ? Colors.purple
                    : Colors.grey.shade300,
                width: _selectedDueDate != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: _selectedDueDate != null ? Colors.purple : Colors.grey,
                ),
                const SizedBox(width: 10),
                Text(
                  _selectedDueDate != null
                      ? '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}'
                      : 'Pick a due date',
                  style: TextStyle(
                    color: _selectedDueDate != null
                        ? Colors.purple
                        : Colors.grey,
                    fontWeight: _selectedDueDate != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
                if (_selectedDueDate != null) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _selectedDueDate = null),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Goal name input + add button
        if (isMobile) ...[
          TextField(
            controller: _goalController,
            decoration: _inputDecoration(),
            onSubmitted: (_) => _addGoal(),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addGoal,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Goal',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: _buttonStyle(),
            ),
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _goalController,
                  decoration: _inputDecoration(),
                  onSubmitted: (_) => _addGoal(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _addGoal,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Add',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: _buttonStyle(),
              ),
            ],
          ),
      ],
    ),
  );

  Widget _buildCategoryPicker() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: kGoalCategories.skip(1).map((cat) {
      final isSelected = _selectedCategory == cat.name;
      return GestureDetector(
        onTap: () => setState(() => _selectedCategory = cat.name),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? cat.color : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? cat.color : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(cat.emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                cat.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList(),
  );

  Widget _buildPriorityPicker() => Row(
    children: kPriorities.map((p) {
      final isSelected = _selectedPriority == p.name;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _selectedPriority = p.name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? p.color.withOpacity(0.12)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? p.color : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(p.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? p.color : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList(),
  );

  InputDecoration _inputDecoration() => InputDecoration(
    hintText: 'e.g. Read 10 books this year',
    prefixIcon: const Icon(Icons.flag_outlined, color: Colors.purple),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.purple, width: 2),
    ),
    filled: true,
    fillColor: Colors.grey.shade50,
  );

  ButtonStyle _buttonStyle() => ElevatedButton.styleFrom(
    backgroundColor: Colors.purple,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  // ── Goal list ─────────────────────────────────────────────────────────────────

  Widget _buildGoalList() {
    if (_isLoading)
      return const Center(
        child: CircularProgressIndicator(color: Colors.purple),
      );

    final filtered = _filtered;

    if (_goals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('🚀', style: TextStyle(fontSize: 40)),
            SizedBox(height: 10),
            Text(
              'No goals yet!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            SizedBox(height: 4),
            Text(
              'Add your first goal above and start achieving!',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No goals in "$_filterCategory" yet.\nAdd one above!',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Sort: High priority first, then Medium, then Low; incomplete before complete
    final sorted = [...filtered]
      ..sort((a, b) {
        if (a['done'] != b['done']) return (a['done'] == true) ? 1 : -1;
        const order = {'High': 0, 'Medium': 1, 'Low': 2};
        return (order[a['priority']] ?? 1).compareTo(order[b['priority']] ?? 1);
      });

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final goal = sorted[index];
        final isDone = goal['done'] == true;
        final cat = _categoryFor(goal['category']);
        final priority = _priorityFor(goal['priority']);
        final realIndex = _goals.indexOf(goal);

        // Due date parsing
        String? dueDateStr;
        bool isOverdue = false;
        if (goal['dueDate'] != null) {
          try {
            final due = DateTime.parse(goal['dueDate'].toString()).toLocal();
            dueDateStr = '${due.day}/${due.month}/${due.year}';
            isOverdue = !isDone && due.isBefore(DateTime.now());
          } catch (_) {}
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDone
                  ? Colors.purple.shade100
                  : isOverdue
                  ? Colors.red.shade100
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: GestureDetector(
              onTap: () => _toggleGoal(realIndex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDone ? Colors.purple : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.purple, width: 2),
                ),
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Category + priority tags
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 6, bottom: 4),
                      decoration: BoxDecoration(
                        color: cat.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat.emoji, style: const TextStyle(fontSize: 10)),
                          const SizedBox(width: 3),
                          Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 10,
                              color: cat.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: priority.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            priority.emoji,
                            style: const TextStyle(fontSize: 10),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            priority.name,
                            style: TextStyle(
                              fontSize: 10,
                              color: priority.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  goal['name'],
                  style: TextStyle(
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? Colors.grey : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDone)
                  const Text(
                    'Completed ✅',
                    style: TextStyle(fontSize: 12, color: Colors.purple),
                  ),
                // ✅ Due date display
                if (dueDateStr != null)
                  Text(
                    isOverdue
                        ? '⚠️ Overdue · $dueDateStr'
                        : '📅 Due $dueDateStr',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOverdue ? Colors.red : Colors.grey,
                      fontWeight: isOverdue
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteGoal(realIndex),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 700;
    final completed = _goals.where((g) => g['done'] == true).length;
    final total = _goals.length;
    final progress = total == 0 ? 0.0 : completed / total;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Goals',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        color: Colors.purple,
        onRefresh: () async {
          setState(() => _isLoading = true);
          _loadGoals();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProgressCard(completed, total, progress),
                        const SizedBox(height: 20),
                        _buildAddForm(true),
                        const SizedBox(height: 16),
                        _buildFilterChips(),
                        const SizedBox(height: 16),
                        _buildGoalList(),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAddForm(false),
                              const SizedBox(height: 16),
                              _buildFilterChips(),
                              const SizedBox(height: 16),
                              _buildGoalList(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 4,
                          child: _buildProgressCard(completed, total, progress),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
