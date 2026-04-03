import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
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
  final TextEditingController _roomCtrl = TextEditingController();

  String? _selectedLab;

  @override
  void dispose() {
    _roomCtrl.dispose();
    super.dispose();
  }

  Map<String, bool> _normalizePeripherals(dynamic raw) {
    final defaults = <String, bool>{
      'keyboard': true,
      'mouse': true,
      'monitor': true,
      'cables': true,
      'system_unit': true,
    };

    if (raw is! Map) return defaults;

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      return false;
    }

    final mapped = <String, bool>{};

    raw.forEach((key, value) {
      mapped[key.toString().toLowerCase().trim()] = parseBool(value);
    });

    return {...defaults, ...mapped};
  }

  int _extractPcNumber(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return match == null ? 0 : int.tryParse(match.group(0)!) ?? 0;
  }

  Future<void> _showAddRoomDialog() async {
    _roomCtrl.clear();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Room'),
        content: TextField(
          controller: _roomCtrl,
          decoration: const InputDecoration(
            labelText: 'Room Name / Number',
            border: OutlineInputBorder(),
            hintText: 'ex. 706',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final app = AppStateScope.of(context);
              final room = _roomCtrl.text.trim();

              if (room.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a room name')),
                );
                return;
              }

              if (app.labs.contains(room)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Room $room already exists')),
                );
                return;
              }

              await app.addLab(room);

              if (!mounted) return;
              Navigator.pop(context);

              setState(() {
                _selectedLab = room;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Room $room added successfully')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRoom(String room) async {
    final pcSnap = await FirebaseFirestore.instance
        .collection('pcs')
        .where('lab', isEqualTo: room)
        .get();

    if (pcSnap.docs.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete room $room because it still has ${pcSnap.docs.length} PC(s). Delete or move the PCs first.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text('Are you sure you want to delete room $room?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirmed) return;

    final app = AppStateScope.of(context);
    await app.removeLab(room);

    if (!mounted) return;

    setState(() {
      if (_selectedLab == room) {
        _selectedLab = null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Room $room deleted successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final labs = AppStateScope.of(context).labs;

    if (_selectedLab != null && !labs.contains(_selectedLab)) {
      _selectedLab = null;
    }

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
            child: SizedBox(height: 4, child: ColoredBox(color: Colors.amber)),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedLab,
                      decoration: const InputDecoration(
                        labelText: 'Select Lab Room',
                        border: OutlineInputBorder(),
                      ),
                      items: labs.map((lab) {
                        return DropdownMenuItem<String>(
                          value: lab,
                          child: Text(lab),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLab = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _showAddRoomDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Room'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _selectedLab == null
                        ? null
                        : () => _deleteRoom(_selectedLab!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete Room'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_selectedLab != null)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
                  child: Text('Select a lab to view PCs'),
                )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('pcs')
                      .where('lab', isEqualTo: _selectedLab)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final docs = snapshot.data!.docs.toList();

                    docs.sort((a, b) {
                      final aPc =
                      _extractPcNumber((a.data()['pc'] ?? '').toString());
                      final bPc =
                      _extractPcNumber((b.data()['pc'] ?? '').toString());
                      return aPc.compareTo(bPc);
                    });

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('No PCs found in this lab'),
                      );
                    }

                    return GridView.builder(
                      itemCount: docs.length,
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        childAspectRatio: 0.78,
                      ),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();

                        final lab = (data['lab'] ?? '').toString();
                        final pcLabel = (data['pc'] ?? 'PC').toString();
                        final code = (data['code'] ?? doc.id).toString();
                        final comment = (data['comment'] ?? '').toString();
                        final reportedBy =
                        (data['reported_by'] ?? '').toString();

                        final peripherals =
                        _normalizePeripherals(data['peripherals']);
                        final hasProblem =
                        peripherals.values.any((v) => v == false);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: hasProblem
                                ? Colors.red.shade50
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: hasProblem
                                  ? Colors.red
                                  : Colors.black26,
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
                              Text(
                                pcLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
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
                                    color: hasProblem
                                        ? Colors.red
                                        : Colors.black12,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.desktop_windows,
                                  size: 42,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Column(
                                  children: [
                                    _statusRow(
                                      'Keyboard',
                                      peripherals['keyboard'] ?? true,
                                    ),
                                    _statusRow(
                                      'Mouse',
                                      peripherals['mouse'] ?? true,
                                    ),
                                    _statusRow(
                                      'Monitor',
                                      peripherals['monitor'] ?? true,
                                    ),
                                    _statusRow(
                                      'Cables',
                                      peripherals['cables'] ?? true,
                                    ),
                                    _statusRow(
                                      'System Unit',
                                      peripherals['system_unit'] ?? true,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
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
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text('PC History'),
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
                                            status: {
                                              'Keyboard':
                                              peripherals['keyboard'] ??
                                                  true,
                                              'Mouse':
                                              peripherals['mouse'] ??
                                                  true,
                                              'Monitor':
                                              peripherals['monitor'] ??
                                                  true,
                                              'Cables':
                                              peripherals['cables'] ??
                                                  true,
                                              'System Unit': peripherals[
                                              'system_unit'] ??
                                                  true,
                                            },
                                            comment: comment,
                                            reportedBy: reportedBy,
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.indigo,
                                      foregroundColor: Colors.white,
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

  Widget _statusRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
  }
}