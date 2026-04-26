import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:dailysync/config.dart';

class MoodScreen extends StatefulWidget {
  final String? token;
  final String? userId;
  const MoodScreen({super.key, this.token, this.userId});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  final List<Map<String, dynamic>> _moodLogs = [];
  final TextEditingController _noteController = TextEditingController();

  static const _moods = ['😊', '😐', '😢', '😡', '🥳', '😴', '😰'];
  static const _moodLabels = {
    '😊': 'Happy',
    '😐': 'Neutral',
    '😢': 'Sad',
    '😡': 'Angry',
    '🥳': 'Excited',
    '😴': 'Tired',
    '😰': 'Anxious',
  };
  static const _moodScores = {
    '😊': 5.0, '🥳': 5.0, '😐': 3.0, '😴': 2.0,
    '😢': 1.0, '😰': 1.0, '😡': 0.0,
  };
  static const _moodColors = {
    '😊': Color(0xFF4CAF50),
    '😐': Color(0xFF9E9E9E),
    '😢': Color(0xFF42A5F5),
    '😡': Color(0xFFEF5350),
    '🥳': Color(0xFFAB47BC),
    '😴': Color(0xFF78909C),
    '😰': Color(0xFFFF7043),
  };

  String _selectedMood = '😊';
  bool _isLoading = true;
  String _quote = 'Loading daily quote...';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.token}',
  };

  @override
  void initState() {
    super.initState();
    _loadMoods();
    _loadQuote();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadQuote() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/daily-quote'));
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() => _quote = data['quote'] ?? 'Stay consistent, one day at a time.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _quote = 'Stay consistent, one day at a time.');
    }
  }

  Future<void> _loadMoods() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/moods'), headers: _headers);
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success'] == true) {
        setState(() {
          _moodLogs..clear()..addAll(List<Map<String, dynamic>>.from(data['moods']));
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Server is waking up, please try again in a moment 😴'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logMood() async {
    // ✅ Note is now optional — removed the early return guard
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/moods'),
        headers: _headers,
        body: jsonEncode({
          'mood': _selectedMood,
          'note': _noteController.text.trim(),
          'date': DateTime.now().toIso8601String(),
        }),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success'] == true) {
        setState(() {
          _moodLogs.insert(0, Map<String, dynamic>.from(data['mood']));
          _noteController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Mood logged! $_selectedMood'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {}
  }

  // ✅ Delete mood
  Future<void> _deleteMood(int index) async {
    final log = _moodLogs[index];
    try {
      await http.delete(
        Uri.parse('$baseUrl/moods/${log['_id']}'),
        headers: _headers,
      );
      if (!mounted) return;
      setState(() => _moodLogs.removeAt(index));
    } catch (_) {}
  }

  Map<String, int> get _moodCounts {
    final counts = <String, int>{};
    for (final mood in _moodLogs) {
      final key = mood['mood']?.toString() ?? '';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  // ✅ Weekly line chart data — last 7 days
  List<FlSpot> get _weeklySpots {
    final now = DateTime.now();
    final spots = <FlSpot>[];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayLogs = _moodLogs.where((m) {
        try {
          final d = DateTime.parse(m['date'].toString()).toLocal();
          return d.year == day.year && d.month == day.month && d.day == day.day;
        } catch (_) { return false; }
      }).toList();
      if (dayLogs.isNotEmpty) {
        final avg = dayLogs.map((m) => _moodScores[m['mood']] ?? 3.0).reduce((a, b) => a + b) / dayLogs.length;
        spots.add(FlSpot((6 - i).toDouble(), avg));
      }
    }
    return spots;
  }

  Widget _buildQuoteBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(children: [
      const Text('💬', style: TextStyle(fontSize: 26)),
      const SizedBox(width: 12),
      Expanded(child: Text(_quote, style: const TextStyle(color: Colors.white, fontSize: 14, fontStyle: FontStyle.italic))),
    ]),
  );

  Widget _buildInputCard(bool isMobile) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('How are you feeling?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        // ✅ Emoji selector with labels underneath
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _moods.map((mood) {
            final isSelected = _selectedMood == mood;
            return GestureDetector(
              onTap: () => setState(() => _selectedMood = mood),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange.shade100 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? Colors.orange : Colors.transparent, width: 2),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(mood, style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 3),
                  // ✅ Label under emoji
                  Text(
                    _moodLabels[mood] ?? '',
                    style: TextStyle(fontSize: 9, color: isSelected ? Colors.orange.shade700 : Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (isMobile) ...[
          TextField(controller: _noteController, decoration: _noteDecoration()),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: _logButton()),
        ] else
          Row(children: [
            Expanded(child: TextField(controller: _noteController, decoration: _noteDecoration())),
            const SizedBox(width: 12),
            _logButton(),
          ]),
      ],
    ),
  );

  InputDecoration _noteDecoration() => InputDecoration(
    hintText: 'Write a note... (optional)',
    prefixIcon: const Icon(Icons.edit_note, color: Colors.orange),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.orange, width: 2),
    ),
    filled: true,
    fillColor: Colors.grey.shade50,
  );

  Widget _logButton() => ElevatedButton.icon(
    onPressed: _logMood,
    icon: const Icon(Icons.add, color: Colors.white),
    label: const Text('Log Mood', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.orange,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Widget _buildAnalyticsCard() {
    final counts = _moodCounts;
    final total = counts.values.fold(0, (a, b) => a + b);
    final topMood = counts.isEmpty ? null : counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    final spots = _weeklySpots;
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final last7 = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.pie_chart, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text('Mood Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 16),
          if (counts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Log your first mood to see analytics 📊', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              ),
            )
          else ...[
            Row(children: [
              _statChip('Total', '$total', Colors.orange),
              const SizedBox(width: 8),
              if (topMood != null) _statChip('Top mood', topMood.key, Colors.orange.shade300),
              const SizedBox(width: 8),
              _statChip('Types', '${counts.length}', Colors.orange.shade200),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: PieChart(PieChartData(
                sections: counts.entries.map((e) {
                  final color = _moodColors[e.key] ?? Colors.orange;
                  final pct = (e.value / total * 100).toStringAsFixed(0);
                  return PieChartSectionData(
                    value: e.value.toDouble(),
                    color: color,
                    title: '$pct%',
                    radius: 55,
                    titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    badgeWidget: Text(e.key, style: const TextStyle(fontSize: 18)),
                    badgePositionPercentageOffset: 1.35,
                  );
                }).toList(),
                centerSpaceRadius: 36,
                sectionsSpace: 3,
                pieTouchData: PieTouchData(enabled: false),
              )),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: counts.entries.map((e) {
                final color = _moodColors[e.key] ?? Colors.orange;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('${e.key} ${e.value}x', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                );
              }).toList(),
            ),
            // ✅ Weekly line chart
            if (spots.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(children: const [
                Icon(Icons.show_chart, color: Colors.orange, size: 18),
                SizedBox(width: 6),
                Text('7-Day Mood Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: LineChart(LineChartData(
                  minY: 0,
                  maxY: 5,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= 7) return const SizedBox();
                        return Text(
                          dayLabels[last7[idx].weekday - 1],
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        );
                      },
                    )),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                          radius: 4,
                          color: Colors.orange,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.orange.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                )),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    ),
  );

  Widget _buildHistoryList() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: const [
        Icon(Icons.history, color: Colors.orange, size: 20),
        SizedBox(width: 8),
        Text('Mood History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 12),
      if (_isLoading)
        const Center(child: CircularProgressIndicator(color: Colors.orange))
      else if (_moodLogs.isEmpty)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
          child: const Center(child: Text('No mood logs yet. How are you feeling? 😊', style: TextStyle(color: Colors.grey))),
        )
      else
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _moodLogs.length,
          itemBuilder: (context, index) {
            final log = _moodLogs[index];
            final color = _moodColors[log['mood']] ?? Colors.orange;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(log['mood'] ?? '', style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if ((log['note'] ?? '').toString().isNotEmpty)
                    Text(log['note'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(_formatDate(log['date']?.toString()), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ])),
                // ✅ Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _deleteMood(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            );
          },
        ),
    ],
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
              colors: [Color(0xFFE65100), Color(0xFFFF9800)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Mood', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      // ✅ Pull-to-refresh
      body: RefreshIndicator(
        color: Colors.orange,
        onRefresh: _loadMoods,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuoteBanner(),
                  const SizedBox(height: 20),
                  if (isMobile) ...[
                    _buildInputCard(true),
                    const SizedBox(height: 20),
                    _buildAnalyticsCard(),
                    const SizedBox(height: 20),
                    _buildHistoryList(),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: Column(children: [
                          _buildInputCard(false),
                          const SizedBox(height: 20),
                          _buildHistoryList(),
                        ])),
                        const SizedBox(width: 20),
                        Expanded(flex: 4, child: _buildAnalyticsCard()),
                      ],
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
