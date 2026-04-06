import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

// ── NU Clark Brand Colors ──────────────────────────────────────────────────────
const Color _nuDarkBlue = Color(0xFF001A52);
const Color _nuGold     = Color(0xFFFFD700);
const Color _nuWhite    = Color(0xFFF8F9FF);

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with SingleTickerProviderStateMixin {
  String? selectedFileName;

  late AnimationController _fadeCtrl;
  late Animation<double>    _fadeAnim;
  late Animation<Offset>    _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── ALL ORIGINAL LOGIC — UNTOUCHED ────────────────────────────────────────
  Future<void> importExcelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          selectedFileName = result.files.single.name;
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Imported file: ${result.files.single.name}'),
          backgroundColor: const Color(0xFF3B6D11),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to import file: $e'),
        backgroundColor: _nuDarkBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _nuDarkBlue,
        elevation: 0,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: _nuGold, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
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
                const Text('SCHEDULE',
                    style: TextStyle(
                        color: _nuWhite, fontSize: 17,
                        fontWeight: FontWeight.w800, letterSpacing: 2)),
                Text('NATIONAL UNIVERSITY CLARK · FACULTY',
                    style: TextStyle(
                        color: _nuGold.withOpacity(0.85),
                        fontSize: 9, fontWeight: FontWeight.w500,
                        letterSpacing: 2)),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: _nuGold),
        ),
      ),

      // ── Body ────────────────────────────────────────────────────────────────
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // ── Upload panel ─────────────────────────────────────
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.black.withOpacity(0.07)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [

                          // Panel header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16)),
                              border: Border(
                                  bottom: BorderSide(
                                      color: Color(0xFFE5E7EB))),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                      color: _nuGold,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                const Text('Import Schedule',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _nuDarkBlue,
                                        letterSpacing: 0.3)),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              children: [

                                // Icon badge
                                Container(
                                  width: 72, height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _nuDarkBlue,
                                    border: Border.all(
                                        color: _nuGold, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _nuGold.withOpacity(0.2),
                                        blurRadius: 16, spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                      Icons.table_chart_outlined,
                                      color: _nuGold, size: 32),
                                ),

                                const SizedBox(height: 18),

                                const Text('Import Schedule Excel File',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: _nuDarkBlue)),
                                const SizedBox(height: 8),
                                Text(
                                  'Upload an .xlsx or .xls file containing\nyour class schedule.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black45,
                                      height: 1.5),
                                ),

                                const SizedBox(height: 28),

                                // Upload button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: importExcelFile,
                                    icon: const Icon(
                                        Icons.upload_file_outlined,
                                        size: 18),
                                    label: const Text('Import Excel File'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _nuDarkBlue,
                                      foregroundColor: _nuGold,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(10)),
                                      textStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // File status
                                AnimatedSwitcher(
                                  duration:
                                  const Duration(milliseconds: 300),
                                  child: selectedFileName == null
                                      ? _NoFileBox(key: const ValueKey('none'))
                                      : _FileBox(
                                      key: const ValueKey('file'),
                                      fileName: selectedFileName!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Tip card ─────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: _nuDarkBlue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _nuDarkBlue.withOpacity(0.12)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EEF8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.lightbulb_outline,
                                size: 16, color: _nuDarkBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Accepted formats',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _nuDarkBlue)),
                                const SizedBox(height: 4),
                                Text(
                                  'Only .xlsx and .xls files are supported. Make sure your schedule follows the required template format before importing.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── No file box ───────────────────────────────────────────────────────────────
class _NoFileBox extends StatelessWidget {
  const _NoFileBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.08),
            style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file_outlined,
              size: 18, color: Colors.black38),
          const SizedBox(width: 10),
          const Text('No file selected',
              style: TextStyle(fontSize: 13, color: Colors.black38)),
        ],
      ),
    );
  }
}

// ── File selected box ─────────────────────────────────────────────────────────
class _FileBox extends StatelessWidget {
  final String fileName;
  const _FileBox({super.key, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3DE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF97C459)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF3B6D11).withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.check_circle_outline,
                size: 18, color: Color(0xFF3B6D11)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('File selected',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B6D11),
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(fileName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF27500A)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}