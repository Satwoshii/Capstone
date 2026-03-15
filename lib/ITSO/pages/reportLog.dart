// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../widgets/itso_drawer.dart';
import '../landingITso.dart';

class ReportLogPage extends StatefulWidget {
  const ReportLogPage({super.key});

  @override
  State<ReportLogPage> createState() => _ReportLogPageState();
}

class _ReportLogPageState extends State<ReportLogPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // --- Demo data (replace with DB later) ---
  final List<ReportEntry> _pcReports = <ReportEntry>[
    ReportEntry(time: '12:00', pcNo: 1, room: '717', reports: 10, peripheral: 'Mouse'),
    ReportEntry(time: '09:00', pcNo: 2, room: '709', reports: 1, peripheral: 'Keyboard'),
    ReportEntry(time: '05:00', pcNo: 3, room: '708', reports: 4, peripheral: 'PC'),
  ];

  Map<int, int> get _pcIncidentCounts {
    final map = <int, int>{};
    for (final r in _pcReports) {
      map[r.pcNo] = (map[r.pcNo] ?? 0) + r.reports;
    }
    return map;
  }

  List<PeripheralCount> get _peripheralRanking {
    final counts = <String, int>{};
    for (final r in _pcReports) {
      counts[r.peripheral] = (counts[r.peripheral] ?? 0) + r.reports;
    }
    final list =
    counts.entries.map((e) => PeripheralCount(name: e.key, count: e.value)).toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  // --- Robust CSV export (append <a> to DOM, click, remove) ---
  void _exportCsv() {
    final rows = <List<String>>[
      ['PC Reports'],
      ['Time', 'PC', 'Room No.', 'No.Reports', 'Peripheral'],
      ..._pcReports.map((r) => [r.time, '#${r.pcNo}', r.room, r.reports.toString(), r.peripheral]),
      [],
      ['Peripheral Problems'],
      ['Peripheral', 'No.Reports'],
      ..._peripheralRanking.map((p) => [p.name, p.count.toString()]),
      [],
      ['Frequently Reported PC'],
      ['PC', 'No.Reports'],
      ..._pcIncidentCounts.entries.map((e) => ['PC #${e.key}', e.value.toString()]),
    ];

    String escape(String s) {
      final needsQuote = s.contains(',') || s.contains('"') || s.contains('\n');
      s = s.replaceAll('"', '""');
      return needsQuote ? '"$s"' : s;
    }

    final csv = rows.map((r) => r.map(escape).join(',')).join('\n');
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final a = html.AnchorElement(href: url)
      ..download = 'ITSO_Report_Log.csv'
      ..style.display = 'none';
    html.document.body?.append(a);
    a.click();
    a.remove();
    html.Url.revokeObjectUrl(url);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV exported')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        // If the drawer is currently open, close it and stay on this page.
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.of(context).pop(); // closes the drawer route
          return false;
        }
        // Otherwise, go cleanly back to Landing to avoid stale overlays.
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LandingITSO()),
                (_) => false,
          );
        }
        return false;
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const ItsoDrawer(),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: 'Menu',
          ),
          backgroundColor: color.primary,
          elevation: 0,
          title: const Text('ITSO View',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  elevation: 0,
                ),
                onPressed: () {
                  // Defer to next microtask to avoid pointer-frame route mutations on web
                  Future.microtask(_exportCsv);
                },
                icon: const Icon(Icons.file_download),
                label: const Text('Export'),
              ),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(4),
            child: SizedBox(height: 4, child: ColoredBox(color: Colors.amber)),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _Card(title: 'PC Reports', child: _PcReportsTable(entries: _pcReports)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: _Card(title: 'Peripheral Problems', child: _PeripheralTable(items: _peripheralRanking)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _Card(title: 'Frequently Reported PC', child: _HorizontalBars(data: _pcIncidentCounts)),
            ),
          ]),
        ),
      ),
    );
  }
}

/* ---------- Local models & widgets ---------- */

class ReportEntry {
  final String time;
  final int pcNo;
  final String room;
  final int reports;
  final String peripheral;
  ReportEntry({
    required this.time,
    required this.pcNo,
    required this.room,
    required this.reports,
    required this.peripheral,
  });
}

class PeripheralCount {
  final String name;
  final int count;
  PeripheralCount({required this.name, required this.count});
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const Divider(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PcReportsTable extends StatelessWidget {
  final List<ReportEntry> entries;
  const _PcReportsTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
        columns: const [
          DataColumn(label: Text('Time')),
          DataColumn(label: Text('PC')),
          DataColumn(label: Text('Room No.')),
          DataColumn(label: Text('No.Reports')),
          DataColumn(label: Text('Peripheral')),
        ],
        rows: entries
            .map(
              (r) => DataRow(
            cells: [
              DataCell(Text(r.time)),
              DataCell(Text('#${r.pcNo}')),
              DataCell(Text(r.room)),
              DataCell(Text('${r.reports}')),
              DataCell(Text(r.peripheral)),
            ],
          ),
        )
            .toList(),
      ),
    );
  }
}

class _PeripheralTable extends StatelessWidget {
  final List<PeripheralCount> items;
  const _PeripheralTable({required this.items});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
        columns: const [
          DataColumn(label: Text('Peripheral')),
          DataColumn(label: Text('No.Reports')),
        ],
        rows: items
            .map(
              (p) => DataRow(
            cells: [
              DataCell(Text(p.name)),
              DataCell(Text('${p.count}')),
            ],
          ),
        )
            .toList(),
      ),
    );
  }
}

class _HorizontalBars extends StatelessWidget {
  final Map<int, int> data; // PC -> count
  const _HorizontalBars({required this.data});
  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data'));
    }
    final maxVal =
    data.values.reduce((a, b) => a > b ? a : b).toDouble(); // safe: non-empty
    final entries = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final pc = entries[index].key;
          final count = entries[index].value.toDouble();

          return Row(
            children: [
              SizedBox(
                width: 56,
                child: Text('PC #$pc', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth = (count / maxVal) * constraints.maxWidth;
                    return Stack(
                      children: [
                        Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black12),
                          ),
                        ),
                        Container(
                          height: 18,
                          width: barWidth,
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade400,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 28, child: Text('${count.toInt()}')),
            ],
          );
        },
      ),
    );
  }
}