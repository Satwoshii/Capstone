import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../landingITso.dart';
import '../widgets/itso_drawer.dart';
import 'pc_history.dart';
import 'reportView.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuBlue     = Color(0xFF003087);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

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

  // ── Helpers (ALL ORIGINAL — UNTOUCHED) ──────────────────────────────────────
  Map<String, bool> _normalizePeripherals(dynamic raw) {
    final defaults = <String, bool>{
      'keyboard': true, 'mouse': true, 'monitor': true,
      'cables': true, 'system_unit': true,
    };
    if (raw is! Map) return defaults;
    bool parseBool(dynamic value) {
      if (value is bool)   return value;
      if (value is String) return value.toLowerCase() == 'true';
      return false;
    }
    final mapped = <String, bool>{};
    raw.forEach((key, value) =>
    mapped[key.toString().toLowerCase().trim()] = parseBool(value));
    return {...defaults, ...mapped};
  }

  int _extractPcNumber(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return match == null ? 0 : int.tryParse(match.group(0)!) ?? 0;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _nuDarkBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── Add Room dialog ──────────────────────────────────────────────────────────
  Future<void> _showAddRoomDialog() async {
    _roomCtrl.clear();
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: _nuDarkBlue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: const Text('Add Room',
                    style: TextStyle(color: _nuWhite, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: TextField(
                  controller: _roomCtrl,
                  decoration: InputDecoration(
                    labelText: 'Room Name / Number',
                    hintText: 'e.g. 706',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _nuDarkBlue, width: 1.5),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final app  = AppStateScope.of(context);
                        final room = _roomCtrl.text.trim();
                        if (room.isEmpty)              { _snack('Please enter a room name'); return; }
                        if (app.labs.contains(room))   { _snack('Room $room already exists'); return; }
                        await app.addLab(room);
                        if (!mounted) return;
                        Navigator.pop(context);
                        setState(() => _selectedLab = room);
                        _snack('Room $room added successfully');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEAF3DE),
                        foregroundColor: const Color(0xFF27500A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFF97C459)),
                        ),
                      ),
                      child: const Text('Add Room', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Delete Room ──────────────────────────────────────────────────────────────
  Future<void> _deleteRoom(String room) async {
    final pcSnap = await FirebaseFirestore.instance
        .collection('pcs').where('lab', isEqualTo: room).get();

    if (pcSnap.docs.isNotEmpty) {
      _snack('Cannot delete room $room — it still has ${pcSnap.docs.length} PC(s). Delete or move the PCs first.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: _nuDarkBlue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: const Text('Delete Room',
                    style: TextStyle(color: _nuWhite, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Are you sure you want to delete room $room?',
                    style: const TextStyle(fontSize: 14, height: 1.6)),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE24B4A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ) ?? false;

    if (!confirmed) return;

    final app = AppStateScope.of(context);
    await app.removeLab(room);
    if (!mounted) return;
    setState(() { if (_selectedLab == room) _selectedLab = null; });
    _snack('Room $room deleted successfully');
  }

  // ── Delete PC ────────────────────────────────────────────────────────────────
  Future<void> _deletePc(String docId, String pcLabel, String lab, String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: _nuDarkBlue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: const Text('Delete PC',
                    style: TextStyle(color: _nuWhite, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Are you sure you want to delete $pcLabel in room $lab?\n\nThis will also delete all reports associated with this PC.',
                    style: const TextStyle(fontSize: 14, height: 1.6)),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE24B4A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance.collection('pcs').doc(docId).delete();
      final reports = await FirebaseFirestore.instance
          .collection('reports').where('pc_code', isEqualTo: code).get();
      for (var doc in reports.docs) {
        await doc.reference.delete();
      }
      _snack('$pcLabel deleted successfully');
    } catch (e) {
      _snack('Error deleting PC: $e');
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final labs = AppStateScope.of(context).labs;
    if (_selectedLab != null && !labs.contains(_selectedLab)) _selectedLab = null;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LandingITSO()), (_) => false);
        return false;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF4F5F8),
        drawer: const ItsoDrawer(),

        // ── AppBar ────────────────────────────────────────────────────────────
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
                width: 38, height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white,
                  border: Border.all(color: _nuGold, width: 2),
                ),
                child: ClipOval(
                  child: Image.asset('assets/Images/NUSchoolLogo.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('PC MANAGEMENT',
                      style: TextStyle(color: _nuWhite, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2)),
                  Text('NATIONAL UNIVERSITY CLARK · ITSO',
                      style: TextStyle(color: _nuGold.withOpacity(0.85), fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 2)),
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
              icon: const Icon(Icons.arrow_back_ios_new, color: _nuGold, size: 18),
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LandingITSO()), (_) => false),
            ),
            const SizedBox(width: 8),
          ],
        ),

        // ── Body ──────────────────────────────────────────────────────────────
        body: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Toolbar ────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.07)),
                ),
                child: Row(
                  children: [
                    // Lab dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedLab,
                        decoration: InputDecoration(
                          hintText: 'Select Lab Room',
                          hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.black.withOpacity(0.12)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.black.withOpacity(0.12)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _nuDarkBlue, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        items: labs.map((lab) =>
                            DropdownMenuItem<String>(value: lab, child: Text(lab))).toList(),
                        onChanged: (value) => setState(() => _selectedLab = value),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Add Room
                    _ToolbarBtn(
                      label: 'Add Room',
                      icon: Icons.add,
                      bg: const Color(0xFFEAF3DE),
                      fg: const Color(0xFF27500A),
                      border: const Color(0xFF97C459),
                      onTap: _showAddRoomDialog,
                    ),
                    const SizedBox(width: 8),

                    // Delete Room
                    _ToolbarBtn(
                      label: 'Delete Room',
                      icon: Icons.delete_outline,
                      bg: const Color(0xFFFCEBEB),
                      fg: const Color(0xFF791F1F),
                      border: const Color(0xFFF09595),
                      onTap: _selectedLab == null ? null : () => _deleteRoom(_selectedLab!),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Lab banner ─────────────────────────────────────────────────
              if (_selectedLab != null)
                _LabBanner(lab: _selectedLab!),

              if (_selectedLab != null) const SizedBox(height: 20),

              // ── PC Grid ────────────────────────────────────────────────────
              Expanded(
                child: _selectedLab == null
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.meeting_room_outlined, size: 56, color: Colors.black12),
                      const SizedBox(height: 12),
                      const Text('Select a lab room to view PCs',
                          style: TextStyle(color: Colors.black38, fontSize: 15)),
                    ],
                  ),
                )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('pcs')
                      .where('lab', isEqualTo: _selectedLab)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: _nuDarkBlue));
                    }

                    final docs = snapshot.data!.docs.toList()
                      ..sort((a, b) =>
                          _extractPcNumber((a.data()['pc'] ?? '').toString())
                              .compareTo(_extractPcNumber((b.data()['pc'] ?? '').toString())));

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.desktop_windows_outlined, size: 56, color: Colors.black12),
                            const SizedBox(height: 12),
                            const Text('No PCs found in this lab',
                                style: TextStyle(color: Colors.black38, fontSize: 15)),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      itemCount: docs.length,
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 280,
                        mainAxisExtent: 400,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                      ),
                      itemBuilder: (context, index) {
                        final doc         = docs[index];
                        final data        = doc.data();
                        final lab         = (data['lab']         ?? '').toString();
                        final pcLabel     = (data['pc']          ?? 'PC').toString();
                        final code        = (data['code']        ?? doc.id).toString();
                        final comment     = (data['comment']     ?? '').toString();
                        final reportedBy  = (data['reported_by'] ?? '').toString();
                        final peripherals = _normalizePeripherals(data['peripherals']);
                        final hasProblem  = peripherals.values.any((v) => v == false);

                        return _PcCard(
                          pcLabel:    pcLabel,
                          hasProblem: hasProblem,
                          peripherals: peripherals,
                          onHistory: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => PcHistoryPage(
                                  lab: lab, pcLabel: pcLabel, code: code))),
                          onOpenProblem: hasProblem
                              ? () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ReportViewPage(
                                docId: doc.id,
                                lab: lab,
                                pcLabel: pcLabel,
                                code: code,
                                status: {
                                  'Keyboard':    peripherals['keyboard']    ?? true,
                                  'Mouse':       peripherals['mouse']       ?? true,
                                  'Monitor':     peripherals['monitor']     ?? true,
                                  'Cables':      peripherals['cables']      ?? true,
                                  'System Unit': peripherals['system_unit'] ?? true,
                                },
                                comment:    comment,
                                reportedBy: reportedBy,
                              )))
                              : null,
                          onDelete: () => _deletePc(doc.id, pcLabel, lab, code),
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

// ── Lab Banner ────────────────────────────────────────────────────────────────
class _LabBanner extends StatelessWidget {
  final String lab;
  const _LabBanner({required this.lab});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('pcs').where('lab', isEqualTo: lab).snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF003087), Color(0xFF001A52)]),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            border: const Border(left: BorderSide(color: _nuGold, width: 5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lab,
                      style: const TextStyle(color: _nuWhite, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  Text('PC INVENTORY',
                      style: TextStyle(color: _nuGold.withOpacity(0.8), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w500)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _nuGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _nuGold.withOpacity(0.3)),
                ),
                child: Text('$count PC${count != 1 ? 's' : ''} Loaded',
                    style: const TextStyle(color: _nuGold, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── PC Card ───────────────────────────────────────────────────────────────────
class _PcCard extends StatelessWidget {
  final String pcLabel;
  final bool hasProblem;
  final Map<String, bool> peripherals;
  final VoidCallback onHistory;
  final VoidCallback? onOpenProblem;
  final VoidCallback onDelete;

  const _PcCard({
    required this.pcLabel,
    required this.hasProblem,
    required this.peripherals,
    required this.onHistory,
    required this.onDelete,
    this.onOpenProblem,
  });

  @override
  Widget build(BuildContext context) {
    final bg          = hasProblem ? const Color(0xFFFCEBEB) : Colors.white;
    final borderColor = hasProblem ? const Color(0xFFE24B4A) : Colors.black.withOpacity(0.08);
    final borderWidth = hasProblem ? 2.0 : 1.0;
    final iconBoxBg   = hasProblem ? const Color(0xFFFEE2E2) : const Color(0xFFF4F5F8);
    final iconColor   = hasProblem ? const Color(0xFF991B1B) : _nuDarkBlue;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(pcLabel,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _nuDarkBlue)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasProblem ? const Color(0xFFE24B4A) : const Color(0xFFEAF3DE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  hasProblem ? 'Problem' : 'All OK',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: hasProblem ? Colors.white : const Color(0xFF27500A),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // PC icon box
          Container(
            height: 62,
            decoration: BoxDecoration(
              color: iconBoxBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Center(
              child: Icon(Icons.desktop_windows_outlined, size: 32, color: iconColor.withOpacity(0.7)),
            ),
          ),

          const SizedBox(height: 10),

          // Peripheral status rows
          _peripheralRow('Keyboard',   peripherals['keyboard']    ?? true),
          _peripheralRow('Mouse',      peripherals['mouse']       ?? true),
          _peripheralRow('Monitor',    peripherals['monitor']     ?? true),
          _peripheralRow('Cables',     peripherals['cables']      ?? true),
          _peripheralRow('System Unit',peripherals['system_unit'] ?? true),

          const Spacer(),

          Container(height: 1, color: Colors.black.withOpacity(0.06)),

          const SizedBox(height: 10),

          // PC History button
          _CardBtn(
            label: 'PC History',
            icon: Icons.history,
            bg: _nuGold,
            fg: _nuDarkBlue,
            onTap: onHistory,
          ),

          // Open Problem button (only if hasProblem)
          if (hasProblem) ...[
            const SizedBox(height: 6),
            _CardBtn(
              label: 'Open Problem',
              icon: Icons.warning_amber_rounded,
              bg: _nuDarkBlue,
              fg: _nuGold,
              onTap: onOpenProblem ?? () {},
            ),
          ],

          const SizedBox(height: 6),
          // Delete button
          _CardBtn(
            label: 'Delete PC',
            icon: Icons.delete_forever,
            bg: const Color(0xFFFCEBEB),
            fg: const Color(0xFF791F1F),
            onTap: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _peripheralRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: ok ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              ok ? 'OK' : 'Issue',
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: ok ? const Color(0xFF27500A) : const Color(0xFF791F1F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card Button ───────────────────────────────────────────────────────────────
class _CardBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg, fg;
  final VoidCallback onTap;
  const _CardBtn({required this.label, required this.icon, required this.bg, required this.fg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── Toolbar Button ────────────────────────────────────────────────────────────
class _ToolbarBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg, fg, border;
  final VoidCallback? onTap;
  const _ToolbarBtn({
    required this.label, required this.icon,
    required this.bg, required this.fg, required this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: Colors.black.withOpacity(0.04),
        disabledForegroundColor: Colors.black26,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: onTap == null ? Colors.black12 : border),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}
