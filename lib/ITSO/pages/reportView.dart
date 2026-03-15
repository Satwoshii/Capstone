import 'package:flutter/material.dart';
import '../widgets/itso_drawer.dart';

class ReportViewPage extends StatelessWidget {
  final String lab;
  final int pcNo;
  final Map<String, bool> status;
  final String comment;

  const ReportViewPage({
    super.key,
    required this.lab,
    required this.pcNo,
    required this.status,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    final key = GlobalKey<ScaffoldState>();
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      key: key,
      drawer: const ItsoDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => key.currentState?.openDrawer(),
          tooltip: 'Menu',
        ),
        backgroundColor: color.primary,
        elevation: 0,
        title: const Text('ITSO View', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: SizedBox(height: 4, child: ColoredBox(color: Colors.amber)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                child: Text('Lab: $lab', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PcPreview(number: pcNo, hasProblem: status.values.any((ok) => !ok)),
                  const SizedBox(width: 24),
                  Expanded(flex: 1, child: _Checklist(status: status)),
                  const SizedBox(width: 24),
                  Expanded(flex: 1, child: _CommentsBox(text: comment)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PcPreview extends StatelessWidget {
  final int number;
  final bool hasProblem;
  const _PcPreview({required this.number, required this.hasProblem});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PC # $number', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: hasProblem ? Colors.red : Colors.black26, width: hasProblem ? 2 : 1),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.desktop_windows, size: 56, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _Checklist extends StatelessWidget {
  final Map<String, bool> status;
  const _Checklist({required this.status});

  @override
  Widget build(BuildContext context) {
    final items = status.entries.toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 16),
        itemBuilder: (_, i) {
          final name = items[i].key;
          final ok = items[i].value;
          return Row(
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontSize: 16))),
              _StatusPill(ok: ok),
            ],
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool ok;
  const _StatusPill({required this.ok});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: ok ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(999)),
      child: Text(ok ? 'Ok' : 'No', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}

class _CommentsBox extends StatelessWidget {
  final String text;
  const _CommentsBox({required this.text});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Comments:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(12)),
            child: SingleChildScrollView(
              child: Text(text.isEmpty ? '—' : '"$text"', style: const TextStyle(fontSize: 14, height: 1.3)),
            ),
          ),
        ),
      ],
    );
  }
}