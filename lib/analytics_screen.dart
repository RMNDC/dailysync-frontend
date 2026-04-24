import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:dailysync/config.dart';

class AnalyticsScreen extends StatefulWidget {
  final String? token;
  const AnalyticsScreen({super.key, this.token});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<Map<String, dynamic>> _habits = [];
  List<Map<String, dynamic>> _moods = [];
  List<Map<String, dynamic>> _goals = [];
  bool _isLoading = true;

  static const _moodScores = {
    '😊': 5.0, '🥳': 5.0, '😐': 3.0, '😴': 2.0,
    '😢': 1.0, '😰': 1.0, '😡': 0.0,
  };
  static const _moodColors = {
    '😊': Color(0xFF4CAF50), '😐': Color(0xFF9E9E9E),
    '😢': Color(0xFF42A5F5), '😡': Color(0xFFEF5350),
    '🥳': Color(0xFFAB47BC), '😴': Color(0xFF78909C),
    '😰': Color(0xFFFF7043),
  };

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.token}',
  };

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$BASE_URL/habits'), headers: _headers),
        http.get(Uri.parse('$BASE_URL/moods'), headers: _headers),
        http.get(Uri.parse('$BASE_URL/goals'), headers: _headers),
      ]);
      if (!mounted) return;
      final hData = jsonDecode(results[0].body);
      final mData = jsonDecode(results[1].body);
      final gData = jsonDecode(results[2].body);
      setState(() {
        if (hData['success'] == true) _habits = List<Map<String, dynamic>>.from(hData['habits']);
        if (mData['success'] == true) _moods = List<Map<String, dynamic>>.from(mData['moods']);
        if (gData['success'] == true) _goals = List<Map<String, dynamic>>.from(gData['goals']);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Server is waking up, please try again in a moment 😴'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Habits analytics ─────────────────────────────────────────────────────────

  Widget _buildHabitsInsights(bool isMobile) {
    final done = _habits.where((h) => h['done'] == true).length;
    final total = _habits.length;
    final rate = total == 0 ? 0 : (done / total * 100).round();
    final bestStreak = _habits.isEmpty ? 0 : _habits.map((h) => h['streak'] ?? 0).reduce((a, b) => a > b ? a : b);

    // Category breakdown
    final catCounts = <String, int>{};
    for (final h in _habits) {
      final cat = h['category']?.toString() ?? 'Other';
      catCounts[cat] = (catCounts[cat] ?? 0) + 1;
    }

    // Bar chart: one bar per habit, height = streak
    final habitsWithStreak = _habits.where((h) => (h['streak'] ?? 0) > 0).toList();

    return _insightCard(
      icon: Icons.track_changes_rounded,
      title: '💪 Habits Insights',
      color: Colors.teal,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Stats row
        Row(children: [
          _miniStat('$rate%', 'Completion', Colors.teal),
          const SizedBox(width: 8),
          _miniStat('$done/$total', 'Done Today', Colors.teal.shade300),
          const SizedBox(width: 8),
          _miniStat('🔥$bestStreak', 'Best Streak', Colors.deepOrange),
        ]),
        if (habitsWithStreak.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Streak per Habit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (habitsWithStreak.map((h) => (h['streak'] ?? 0) as int).reduce((a, b) => a > b ? a : b) + 2).toDouble(),
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, _) {
                    final idx = val.toInt();
                    if (idx >= habitsWithStreak.length) return const SizedBox();
                    final name = habitsWithStreak[idx]['name']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(name.length > 6 ? '${name.substring(0, 6)}..' : name,
                          style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    );
                  },
                )),
              ),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: habitsWithStreak.asMap().entries.map((e) =>
                BarChartGroupData(x: e.key, barRods: [
                  BarChartRodData(
                    toY: (e.value['streak'] ?? 0).toDouble(),
                    color: Colors.teal,
                    width: 20,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ])
              ).toList(),
            )),
          ),
        ],
        if (catCounts.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('By Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: catCounts.entries.map((e) =>
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('${e.key} · ${e.value}', style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600)),
            )
          ).toList()),
        ],
      ]),
    );
  }

  // ── Mood analytics ────────────────────────────────────────────────────────────

  Widget _buildMoodInsights(bool isMobile) {
    if (_moods.isEmpty) {
      return _insightCard(
        icon: Icons.mood_rounded,
        title: '😊 Mood Insights',
        color: Colors.orange,
        child: const Center(child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Log some moods to see insights!', style: TextStyle(color: Colors.grey)),
        )),
      );
    }

    // Most frequent mood this month
    final now = DateTime.now();
    final thisMonth = _moods.where((m) {
      try {
        final d = DateTime.parse(m['date'].toString()).toLocal();
        return d.year == now.year && d.month == now.month;
      } catch (_) { return false; }
    }).toList();

    final moodCounts = <String, int>{};
    for (final m in thisMonth) {
      final key = m['mood']?.toString() ?? '';
      moodCounts[key] = (moodCounts[key] ?? 0) + 1;
    }
    final topMood = moodCounts.isEmpty ? null : moodCounts.entries.reduce((a, b) => a.value > b.value ? a : b);

    // 14-day trend
    final spots = <FlSpot>[];
    for (int i = 13; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayLogs = _moods.where((m) {
        try {
          final d = DateTime.parse(m['date'].toString()).toLocal();
          return d.year == day.year && d.month == day.month && d.day == day.day;
        } catch (_) { return false; }
      }).toList();
      if (dayLogs.isNotEmpty) {
        final avg = dayLogs.map((m) => _moodScores[m['mood']] ?? 3.0).reduce((a, b) => a + b) / dayLogs.length;
        spots.add(FlSpot((13 - i).toDouble(), avg));
      }
    }

    // Day of week breakdown
    final dowScores = List.generate(7, (_) => <double>[]);
    for (final m in _moods) {
      try {
        final d = DateTime.parse(m['date'].toString()).toLocal();
        final score = _moodScores[m['mood']] ?? 3.0;
        dowScores[d.weekday - 1].add(score);
      } catch (_) {}
    }
    final dowAvg = dowScores.map((s) => s.isEmpty ? 0.0 : s.reduce((a, b) => a + b) / s.length).toList();
    final bestDow = dowAvg.indexOf(dowAvg.reduce((a, b) => a > b ? a : b));
    const dowLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return _insightCard(
      icon: Icons.mood_rounded,
      title: '😊 Mood Insights',
      color: Colors.orange,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _miniStat(topMood?.key ?? '—', 'Top This Month', Colors.orange),
          const SizedBox(width: 8),
          _miniStat('${thisMonth.length}', 'Logs This Month', Colors.orange.shade300),
          const SizedBox(width: 8),
          _miniStat(dowLabels[bestDow], 'Best Day', Colors.orange.shade200),
        ]),
        if (spots.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('14-Day Mood Trend', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: LineChart(LineChartData(
              minY: 0, maxY: 5,
              gridData: FlGridData(show: true, drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Colors.orange,
                barWidth: 2.5,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.08)),
              )],
            )),
          ),
        ],
        const SizedBox(height: 16),
        const Text('Best Day of Week', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: List.generate(7, (i) {
          final avg = dowAvg[i];
          final isBest = i == bestDow && avg > 0;
          return Expanded(child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isBest ? Colors.orange.withOpacity(0.15) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isBest ? Colors.orange : Colors.transparent, width: 1.5),
            ),
            child: Column(children: [
              Text(dowLabels[i], style: TextStyle(fontSize: 9, color: isBest ? Colors.orange : Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(avg > 0 ? avg.toStringAsFixed(1) : '-', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isBest ? Colors.orange : Colors.grey)),
            ]),
          ));
        })),
      ]),
    );
  }

  // ── Goals analytics ───────────────────────────────────────────────────────────

  Widget _buildGoalsInsights(bool isMobile) {
    final completed = _goals.where((g) => g['done'] == true).length;
    final total = _goals.length;
    final rate = total == 0 ? 0 : (completed / total * 100).round();
    final now = DateTime.now();
    final overdue = _goals.where((g) {
      if (g['done'] == true || g['dueDate'] == null) return false;
      try { return DateTime.parse(g['dueDate'].toString()).isBefore(now); } catch (_) { return false; }
    }).length;

    final priorityCounts = <String, int>{'High': 0, 'Medium': 0, 'Low': 0};
    for (final g in _goals.where((g) => g['done'] != true)) {
      final p = g['priority']?.toString() ?? 'Medium';
      priorityCounts[p] = (priorityCounts[p] ?? 0) + 1;
    }

    return _insightCard(
      icon: Icons.flag_rounded,
      title: '🎯 Goals Insights',
      color: Colors.purple,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _miniStat('$rate%', 'Completion', Colors.purple),
          const SizedBox(width: 8),
          _miniStat('$completed/$total', 'Done', Colors.purple.shade300),
          const SizedBox(width: 8),
          _miniStat('$overdue', 'Overdue', overdue > 0 ? Colors.red : Colors.grey),
        ]),
        const SizedBox(height: 20),
        const Text('Remaining by Priority', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 10),
        ...priorityCounts.entries.map((e) {
          final colors = {'High': Colors.red, 'Medium': Colors.orange, 'Low': Colors.green};
          final emojis = {'High': '🔴', 'Medium': '🟡', 'Low': '🟢'};
          final color = colors[e.key] ?? Colors.grey;
          final maxVal = priorityCounts.values.isEmpty ? 1 : priorityCounts.values.reduce((a, b) => a > b ? a : b);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(width: 60, child: Text('${emojis[e.key]} ${e.key}', style: const TextStyle(fontSize: 12))),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: maxVal == 0 ? 0 : e.value / maxVal,
                  minHeight: 10,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )),
              const SizedBox(width: 8),
              Text('${e.value}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
            ]),
          );
        }),
        if (overdue > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Text('$overdue goal${overdue > 1 ? 's are' : ' is'} overdue! Review them soon.', style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500)),
            ]),
          ),
        ],
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Widget _insightCard({required IconData icon, required String title, required Color color, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  Widget _miniStat(String value, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Analytics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: RefreshIndicator(
        color: Colors.blue,
        onRefresh: _loadAll,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.blue))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: isMobile
                        ? Column(children: [
                            _buildHabitsInsights(true),
                            const SizedBox(height: 20),
                            _buildMoodInsights(true),
                            const SizedBox(height: 20),
                            _buildGoalsInsights(true),
                          ])
                        : Column(children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(child: _buildHabitsInsights(false)),
                              const SizedBox(width: 20),
                              Expanded(child: _buildMoodInsights(false)),
                            ]),
                            const SizedBox(height: 20),
                            _buildGoalsInsights(false),
                          ]),
                  ),
                ),
              ),
      ),
    );
  }
}
