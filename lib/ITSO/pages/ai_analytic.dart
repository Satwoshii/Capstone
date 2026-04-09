import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/itso_drawer.dart';

const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue = Color(0xFF003087);
const Color _nuGold = Color(0xFFFFD700);
const Color _nuWhite = Color(0xFFF8F9FF);

class AiAnalyticsPage extends StatefulWidget {
  const AiAnalyticsPage({super.key});

  @override
  State<AiAnalyticsPage> createState() => _AiAnalyticsPageState();
}

class _AiAnalyticsPageState extends State<AiAnalyticsPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _range = 'all';
  String _selectedLab = 'all';
  bool _isGeneratingInsight = false;
  String _latestInsight =
      'Press “Generate AI Insight” to create a fresh ITSO summary from the current filtered reports.';

  DateTime? _getStartDate() {
    final now = DateTime.now();
    switch (_range) {
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case 'week':
        return now.subtract(const Duration(days: 7));
      case 'month':
        return now.subtract(const Duration(days: 30));
      default:
        return null;
    }
  }

  String _safeString(dynamic value, [String fallback = '—']) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  bool _safeBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return false;
  }

  DateTime? _readDate(Map<String, dynamic> data) {
    final raw = data['timestamp'] ?? data['created_at'] ?? data['resolved_at'];
    if (raw is Timestamp) return raw.toDate();
    return null;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final startDate = _getStartDate();

    return docs.where((doc) {
      final data = doc.data();
      final lab = _safeString(data['lab'], '').toLowerCase();
      final docDate = _readDate(data);

      final matchesLab =
          _selectedLab == 'all' || lab == _selectedLab.toLowerCase();
      final matchesDate =
          startDate == null || (docDate != null && !docDate.isBefore(startDate));

      return matchesLab && matchesDate;
    }).toList();
  }

  Map<String, int> _countByStringField(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      String field,
      ) {
    final map = <String, int>{};
    for (final doc in docs) {
      final value = _safeString(doc.data()[field], 'Unknown');
      map[value] = (map[value] ?? 0) + 1;
    }
    return map;
  }

  String _topKey(Map<String, int> map, [String fallback = '—']) {
    if (map.isEmpty) return fallback;
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  int _topValue(Map<String, int> map) {
    if (map.isEmpty) return 0;
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.value;
  }

  Future<void> _generateInsight(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs,
      ) async {
    setState(() => _isGeneratingInsight = true);

    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (filteredDocs.isEmpty) {
      setState(() {
        _latestInsight =
        'No reports were found for the selected filters, so there is no AI insight to generate yet.';
        _isGeneratingInsight = false;
      });
      return;
    }

    final byLab = _countByStringField(filteredDocs, 'lab');
    final byPc = _countByStringField(filteredDocs, 'pc_code');
    final byCategory = _countByStringField(filteredDocs, 'ai_category');
    final byPriority = _countByStringField(filteredDocs, 'ai_priority');
    final byAction = _countByStringField(filteredDocs, 'ai_itso_action');

    int resolved = 0;
    int escalated = 0;
    int attemptedFix = 0;
    int unresolved = 0;
    int highPriority = 0;
    int repeatedPcReports = 0;

    for (final doc in filteredDocs) {
      final data = doc.data();
      if (_safeBool(data['ai_resolved'])) resolved++;
      if (_safeBool(data['ai_escalate_to_itso'])) escalated++;
      if (_safeBool(data['ai_attempted_fix'])) attemptedFix++;
      if (!_safeBool(data['ai_resolved'])) unresolved++;
      if (_safeString(data['ai_priority'], '').toLowerCase() == 'high') {
        highPriority++;
      }
    }

    for (final count in byPc.values) {
      if (count >= 2) repeatedPcReports++;
    }

    final total = filteredDocs.length;
    final topLab = _topKey(byLab);
    final topLabCount = _topValue(byLab);
    final topPc = _topKey(byPc);
    final topPcCount = _topValue(byPc);
    final topCategory = _topKey(byCategory);
    final topPriority = _topKey(byPriority);
    final topAction = _topKey(byAction, 'Inspect the affected PC');

    final resolvedPercent = ((resolved / total) * 100).round();
    final escalatedPercent = ((escalated / total) * 100).round();

    String maintenanceLine;
    final topCategoryLower = topCategory.toLowerCase();
    if (topCategoryLower.contains('hardware') || topCategoryLower.contains('peripheral')) {
      maintenanceLine =
      'Recommended action: prepare spare peripherals and physically inspect the affected computers in $topLab, especially $topPc.';
    } else if (topCategoryLower.contains('software')) {
      maintenanceLine =
      'Recommended action: review installed software and recheck system configuration for the affected units, especially $topPc.';
    } else if (topCategoryLower.contains('network')) {
      maintenanceLine =
      'Recommended action: inspect network connectivity and cabling for the reported area, starting with $topLab.';
    } else {
      maintenanceLine =
      'Recommended action: prioritize the repeated units and inspect the most frequently reported computer first: $topPc.';
    }

    final insight = StringBuffer()
      ..write(
          'AI Insight: Based on $total filtered report${total == 1 ? '' : 's'}, the highest concentration of issues is in Lab $topLab')
      ..write(topLab == '—' ? '' : ' with $topLabCount case${topLabCount == 1 ? '' : 's'}')
      ..write('. ')
      ..write(
          'The most frequently reported PC is $topPc with $topPcCount report${topPcCount == 1 ? '' : 's'}, which suggests repeated failure or repeated student concern. ')
      ..write(
          'The dominant issue category is $topCategory, and the most common priority level is $topPriority. ')
      ..write(
          '$resolvedPercent% of the selected reports were marked as resolved by AI guidance, while $escalatedPercent% were escalated to ITSO. ')
      ..write(
          'AI troubleshooting was attempted in $attemptedFix case${attemptedFix == 1 ? '' : 's'}, and there are $unresolved unresolved case${unresolved == 1 ? '' : 's'} still needing attention. ')
      ..write(
          repeatedPcReports > 0
              ? '$repeatedPcReports PC${repeatedPcReports == 1 ? ' shows' : 's show'} repeated reporting patterns, so recurring hardware or workstation-level checks are recommended. '
              : 'No repeated PC pattern was strongly detected in the current filtered set. ')
      ..write(
          topAction != '—' ? 'The most common suggested ITSO action is: $topAction. ' : '')
      ..write(maintenanceLine);

    setState(() {
      _latestInsight = insight.toString();
      _isGeneratingInsight = false;
    });
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE6EAF2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _nuBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.analytics, color: _nuBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: _nuDarkBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listSection({
    required String title,
    required Map<String, int> data,
    IconData icon = Icons.bar_chart,
  }) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE6EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _nuBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _nuDarkBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Text(
              'No data available.',
              style: TextStyle(color: Colors.black54),
            )
          else
            ...entries.take(8).map(
                  (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _nuBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        entry.value.toString(),
                        style: const TextStyle(
                          color: _nuDarkBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _insightCard(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_nuDarkBlue, _nuBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome, color: _nuGold),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'AI Insight Generator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _latestInsight,
            style: const TextStyle(
              color: Colors.white,
              height: 1.45,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _isGeneratingInsight
                    ? null
                    : () => _generateInsight(docs),
                icon: _isGeneratingInsight
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.psychology_alt),
                label: Text(
                  _isGeneratingInsight
                      ? 'Generating...'
                      : 'Generate AI Insight',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _nuGold,
                  foregroundColor: _nuDarkBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _latestInsight =
                    'Press “Generate AI Insight” to create a fresh ITSO summary from the current filtered reports.';
                  });
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.45)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF4F5F8),
      drawer: const ItsoDrawer(),
      appBar: AppBar(
        backgroundColor: _nuDarkBlue,
        elevation: 0,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: _nuGold, size: 26),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: _nuGold, width: 2),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/Images/NUSchoolLogo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'AI ANALYTICS',
                  style: TextStyle(
                    color: _nuWhite,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'NATIONAL UNIVERSITY CLARK · ITSO',
                  style: TextStyle(
                    color: _nuGold.withOpacity(0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: _nuGold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _nuGold),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('reports').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Failed to load reports: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          final allDocs = snapshot.data?.docs ?? [];
          final labs = allDocs
              .map((e) => _safeString(e.data()['lab'], ''))
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

          final filteredDocs = _applyFilters(allDocs);
          final byCategory = _countByStringField(filteredDocs, 'ai_category');
          final byPriority = _countByStringField(filteredDocs, 'ai_priority');
          final byLab = _countByStringField(filteredDocs, 'lab');
          final byPc = _countByStringField(filteredDocs, 'pc_code');
          final byAction = _countByStringField(filteredDocs, 'ai_itso_action');

          int resolved = 0;
          int escalated = 0;
          int attemptedFix = 0;
          int highPriority = 0;

          for (final doc in filteredDocs) {
            final data = doc.data();
            if (_safeBool(data['ai_resolved'])) resolved++;
            if (_safeBool(data['ai_escalate_to_itso'])) escalated++;
            if (_safeBool(data['ai_attempted_fix'])) attemptedFix++;
            if (_safeString(data['ai_priority'], '').toLowerCase() == 'high') {
              highPriority++;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildDropdown(
                      label: 'Range',
                      value: _range,
                      items: const {
                        'all': 'All Time',
                        'today': 'Today',
                        'week': 'Last 7 Days',
                        'month': 'Last 30 Days',
                      },
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _range = value);
                      },
                    ),
                    _buildDropdown(
                      label: 'Lab',
                      value: _selectedLab,
                      items: {
                        'all': 'All Labs',
                        ...{for (final lab in labs) lab: lab},
                      },
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedLab = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _insightCard(filteredDocs),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 1100
                      ? 4
                      : MediaQuery.of(context).size.width > 700
                      ? 2
                      : 1,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.6,
                  children: [
                    _metricCard(
                      title: 'Total Reports',
                      value: filteredDocs.length.toString(),
                      icon: Icons.description,
                    ),
                    _metricCard(
                      title: 'AI Resolved',
                      value: resolved.toString(),
                      icon: Icons.verified,
                    ),
                    _metricCard(
                      title: 'Escalated to ITSO',
                      value: escalated.toString(),
                      icon: Icons.warning_amber_rounded,
                    ),
                    _metricCard(
                      title: 'AI Attempted Fix',
                      value: attemptedFix.toString(),
                      icon: Icons.build_circle_outlined,
                    ),
                    _metricCard(
                      title: 'High Priority',
                      value: highPriority.toString(),
                      icon: Icons.priority_high,
                    ),
                    _metricCard(
                      title: 'Top Lab',
                      value: _topKey(byLab),
                      icon: Icons.meeting_room,
                    ),
                    _metricCard(
                      title: 'Top PC',
                      value: _topKey(byPc),
                      icon: Icons.computer,
                    ),
                    _metricCard(
                      title: 'Top Issue',
                      value: _topKey(byCategory),
                      icon: Icons.category,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 1100
                      ? 3
                      : MediaQuery.of(context).size.width > 700
                      ? 2
                      : 1,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.15,
                  children: [
                    _listSection(
                      title: 'Reports by Category',
                      data: byCategory,
                      icon: Icons.category_outlined,
                    ),
                    _listSection(
                      title: 'Reports by Priority',
                      data: byPriority,
                      icon: Icons.flag_outlined,
                    ),
                    _listSection(
                      title: 'Reports by Lab',
                      data: byLab,
                      icon: Icons.meeting_room_outlined,
                    ),
                    _listSection(
                      title: 'Top Problem PCs',
                      data: byPc,
                      icon: Icons.desktop_windows_outlined,
                    ),
                    _listSection(
                      title: 'Most Common ITSO Actions',
                      data: byAction,
                      icon: Icons.handyman_outlined,
                    ),
                    _listSection(
                      title: 'AI Performance',
                      data: {
                        'Resolved by AI': resolved,
                        'Escalated to ITSO': escalated,
                        'AI Attempted Fix': attemptedFix,
                        'High Priority': highPriority,
                      },
                      icon: Icons.auto_graph,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E6EF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox.shrink(),
            items: items.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
