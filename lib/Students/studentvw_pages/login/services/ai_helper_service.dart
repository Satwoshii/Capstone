import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiHelperResult {
  final String category;
  final String priority;
  final String studentTip;
  final bool escalateToItso;
  final String itsoAction;
  final String actionDoneTemplate;

  const AiHelperResult({
    required this.category,
    required this.priority,
    required this.studentTip,
    required this.escalateToItso,
    required this.itsoAction,
    required this.actionDoneTemplate,
  });

  factory AiHelperResult.fromMap(Map<String, dynamic> map) {
    return AiHelperResult(
      category: (map['category'] ?? '').toString(),
      priority: (map['priority'] ?? 'medium').toString(),
      studentTip: (map['student_tip'] ?? '').toString(),
      escalateToItso: map['escalate_to_itso'] == true,
      itsoAction: (map['itso_action'] ?? '').toString(),
      actionDoneTemplate: (map['action_done_template'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'priority': priority,
      'student_tip': studentTip,
      'escalate_to_itso': escalateToItso,
      'itso_action': itsoAction,
      'action_done_template': actionDoneTemplate,
    };
  }
}

class AiHelperService {
  static const String _endpoint =
      'https://us-central1-test-1fc5d.cloudfunctions.net/generateStudentAiHelperHttp';

  static Future<AiHelperResult?> generate({
    required String pcCode,
    required String lab,
    required String pc,
    required String comment,
    required Map<String, bool> peripherals,
  }) async {
    try {
      final payload = {
        'pcCode': pcCode,
        'lab': lab,
        'pc': pc,
        'comment': comment,
        'peripherals': peripherals,
      };

      debugPrint('AI HELPER REQUEST: ${jsonEncode(payload)}');

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      debugPrint('AI HELPER STATUS: ${response.statusCode}');
      debugPrint('AI HELPER BODY: ${response.body}');

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      if (decoded['success'] != true) {
        return null;
      }

      final result = decoded['result'];
      if (result is! Map) {
        return null;
      }

      return AiHelperResult.fromMap(
        Map<String, dynamic>.from(result),
      );
    } catch (e, st) {
      debugPrint('AI HELPER ERROR: $e');
      debugPrint('$st');
      return null;
    }
  }
}