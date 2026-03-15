import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/itso_drawer.dart';
import '../landingITso.dart';
import 'reportView.dart';

class PcManagementPage extends StatefulWidget {
  const PcManagementPage({super.key});

  @override
  State<PcManagementPage> createState() => _PcManagementPageState();
}

class _PcManagementPageState extends State<PcManagementPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _selectedLab;

  List<PcUnit> _loadPcUnitsForLab(String lab) {
    Map<String, bool> ok() => {
      'Keyboard': true, 'Mouse': true, 'Monitor': true, 'Cables': true,
    };
    final list = <PcUnit>[];
    for (var i = 1; i <= 6; i++) {
      final st = ok();
      var cmt = '';
      if (i == 4) { st['Keyboard'] = false; cmt = 'Keyboard keys are missing'; }
      list.add(PcUnit(number: i, status: st, comment: cmt));
    }
    return list;
  }

  Future<void> _showAddLabDialog(BuildContext context) async {
    final app = AppStateScope.of(context);
    final ctrl = TextEditingController();
    final lab = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Lab Room'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Room number (e.g., 723)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (lab != null && lab.isNotEmpty) {
      await app.addLab(lab);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final app = AppStateScope.of(context);

    // ITSO-only guard
    if (!(app.user?.isItso ?? false)) {
      Future.microtask(() => Navigator.of(context).pop());
    }

    return WillPopScope(
      onWillPop: () async {
        if (!mounted) return true;
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_selectedLab == null)
                _LabDropdown(
                  labs: app.labs,
                  onChanged: (v) => setState(() => _selectedLab = v),
                  onAddLab: () => _showAddLabDialog(context),
                )
              else
                _LabHeaderRow(
                  lab: _selectedLab!,
                  onChangeRoom: () => setState(() => _selectedLab = null),
                  onAddLab: () => _showAddLabDialog(context),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: _selectedLab == null
                    ? const Center(child: Text('Select a lab to view PC units', style: TextStyle(color: Colors.black54)))
                    : _PcGrid(
                  lab: _selectedLab!,
                  units: _loadPcUnitsForLab(_selectedLab!),
                  onPcTap: (u) {
                    if (!u.hasPeripheralProblem) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportViewPage(
                          lab: _selectedLab!, pcNo: u.number, status: u.status, comment: u.comment,
                        ),
                      ),
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

/* ---------------------- models & widgets ---------------------- */

class PcUnit {
  final int number;
  final Map<String, bool> status;
  final String comment;
  PcUnit({required this.number, required this.status, required this.comment});
  bool get hasPeripheralProblem => status.values.any((ok) => !ok);
  List<String> get peripherals => status.keys.toList();
}

class _LabDropdown extends StatelessWidget {
  final List<String> labs;
  final ValueChanged<String?> onChanged;
  final VoidCallback onAddLab;
  const _LabDropdown({required this.labs, required this.onChanged, required this.onAddLab});

  @override
  Widget build(BuildContext context) {
    final chip = Colors.amber.shade600;
    final border = Colors.amber.shade200;
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: chip, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Room Number', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onAddLab,
                  icon: const Icon(Icons.add, color: Colors.white, size: 16),
                  label: const Text('Add', style: TextStyle(color: Colors.white)),
                  style: TextButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                hint: const Text('Select lab', style: TextStyle(fontSize: 14)),
                isDense: true,
                value: null,
                items: labs.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabHeaderRow extends StatelessWidget {
  final String lab;
  final VoidCallback onChangeRoom;
  final VoidCallback onAddLab;
  const _LabHeaderRow({required this.lab, required this.onChangeRoom, required this.onAddLab});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton(
          onPressed: onChangeRoom,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber, foregroundColor: Colors.black87, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Change Room'),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
          child: Text('Lab: $lab', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        TextButton.icon(onPressed: onAddLab, icon: const Icon(Icons.add), label: const Text('Add Lab')),
        const Spacer(),
        Text('Peripheral Problem', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)),
        const SizedBox(width: 12),
        Container(
          width: 100, height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(6),
          child: const Text('Mouse\nKeyboard\nMonitor', style: TextStyle(fontSize: 12, height: 1.2)),
        ),
      ],
    );
  }
}

class _PcGrid extends StatelessWidget {
  final String lab;
  final List<PcUnit> units;
  final void Function(PcUnit unit) onPcTap;
  const _PcGrid({required this.lab, required this.units, required this.onPcTap});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3, crossAxisSpacing: 24, mainAxisSpacing: 24, childAspectRatio: 1,
      children: units.map((u) => _PcCard(unit: u, onTap: () => onPcTap(u))).toList(),
    );
  }
}

class _PcCard extends StatelessWidget {
  final PcUnit unit; final VoidCallback? onTap;
  const _PcCard({required this.unit, this.onTap});

  @override
  Widget build(BuildContext context) {
    final borderColor = unit.hasPeripheralProblem ? Colors.red : Colors.transparent;
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 2),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text('PC # ${unit.number}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(6)),
              alignment: Alignment.center,
              child: const Icon(Icons.desktop_windows, size: 40, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.topLeft,
            child: Text(unit.peripherals.join('\n'), style: const TextStyle(fontSize: 12, height: 1.2)),
          ),
        ],
      ),
    );
    return MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: card),
    );
  }
}