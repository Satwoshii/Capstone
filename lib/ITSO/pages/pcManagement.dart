import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../landingITso.dart';
import '../widgets/itso_drawer.dart';
import 'pc_history.dart';
import 'reportView.dart';

class PcManagementPage extends StatefulWidget {
  const PcManagementPage({super.key});

  @override
  State<PcManagementPage> createState() => _PcManagementPageState();
}

class _PcManagementPageState extends State<PcManagementPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _selectedLab;

  int _extractPcNumber(dynamic value) {
    if (value == null) return 0;
    final text = value.toString();
    final match = RegExp(r'\d+').firstMatch(text);
    if (match == null) return 0;
    return int.tryParse(match.group(0)!) ?? 0;
  }

  Map<String, bool> _normalizePeripherals(dynamic raw) {
    final defaults = <String, bool>{
      'Keyboard': true,
      'Mouse': true,
      'Monitor': true,
      'Cables': true,
      'System Unit': true,
    };

    if (raw is! Map) return defaults;

    bool parseBool(dynamic v) {
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      return false;
    }

    final mapped = <String, bool>{};

    raw.forEach((key, value) {
      final k = key.toString().toLowerCase().trim();
      if (k == 'keyboard') mapped['Keyboard'] = parseBool(value);
      if (k == 'mouse') mapped['Mouse'] = parseBool(value);
      if (k == 'monitor') mapped['Monitor'] = parseBool(value);
      if (k == 'cables' || k == 'cable') mapped['Cables'] = parseBool(value);
      if (k == 'system_unit' || k == 'system unit') {
        mapped['System Unit'] = parseBool(value);
      }
    });

    return {...defaults, ...mapped};
  }

  Future<List<String>> _fetchLabs() async {
    final snapshot = await FirebaseFirestore.instance.collection('pcs').get();

    final labs = snapshot.docs
        .map((e) => (e.data()['lab'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    labs.sort();
    return labs;
  }

  void _openPcHistory({
    required String lab,
    required String pcLabel,
    required String code,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PcHistoryPage(
          lab: lab,
          pcLabel: pcLabel,
          code: code,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LandingITSO()),
              (_) => false,
        );
        return false;
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const ItsoDrawer(),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          backgroundColor: color.primary,
          title: const Text(
            'ITSO View',
            style: TextStyle(color: Colors.white),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(4),
            child: SizedBox(
              height: 4,
              child: ColoredBox(color: Colors.amber),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              FutureBuilder<List<String>>(
                future: _fetchLabs(),
                builder: (context, snapshot) {
                  final labs = snapshot.data ?? [];

                  return Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedLab = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Change Room'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedLab,
                          decoration: const InputDecoration(
                            labelText: 'Select Lab Room',
                            border: OutlineInputBorder(),
                          ),
                          items: labs
                              .map(
                                (lab) => DropdownMenuItem(
                              value: lab,
                              child: Text(lab),
                            ),
                          )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedLab = value;
                            });
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              if (_selectedLab != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Lab: $_selectedLab',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: _selectedLab == null
                    ? const Center(
                  child: Text(
                    'Select a lab to view PCs',
                    style: TextStyle(fontSize: 16),
                  ),
                )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('pcs')
                      .where('lab', isEqualTo: _selectedLab)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No PCs found in this lab',
                          style: TextStyle(fontSize: 16),
                        ),
                      );
                    }

                    docs.sort((a, b) {
                      final aPc = _extractPcNumber(a.data()['pc']);
                      final bPc = _extractPcNumber(b.data()['pc']);
                      return aPc.compareTo(bPc);
                    });

                    return GridView.builder(
                      itemCount: docs.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.95,
                      ),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();

                        final lab = (data['lab'] ?? '').toString();
                        final pcLabel = (data['pc'] ?? 'PC').toString();
                        final code = (data['code'] ?? doc.id).toString();
                        final comment = (data['comment'] ?? '').toString();
                        final reportedBy = (data['reported_by'] ?? '').toString();
                        final peripherals = _normalizePeripherals(data['peripherals']);
                        final hasProblem = peripherals.values.any((e) => e == false);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: hasProblem ? Colors.red.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: hasProblem ? Colors.red : Colors.black26,
                              width: hasProblem ? 2 : 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x11000000),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.topLeft,
                                child: Text(
                                  pcLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 70,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: hasProblem ? Colors.red : Colors.black12,
                                  ),
                                ),
                                child: const Icon(Icons.desktop_windows, size: 42),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Column(
                                  children: peripherals.entries.map((entry) {
                                    final ok = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              entry.key,
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: ok ? Colors.green : Colors.red,
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              ok ? 'Ok' : 'No',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _openPcHistory(
                                    lab: lab,
                                    pcLabel: pcLabel,
                                    code: code,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.black,
                                    minimumSize: const Size.fromHeight(36),
                                  ),
                                  child: const Text('Pc History'),
                                ),
                              ),
                              if (hasProblem) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ReportViewPage(
                                            docId: doc.id,
                                            lab: lab,
                                            pcLabel: pcLabel,
                                            code: code,
                                            status: peripherals,
                                            comment: comment,
                                            reportedBy: reportedBy,
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.indigo,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size.fromHeight(36),
                                    ),
                                    child: const Text('Open Problem'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}