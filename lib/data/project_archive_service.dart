import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/models.dart';

class ProjectArchiveService {
  const ProjectArchiveService();

  String export(BingoProject project) {
    final payload = project.toJson();
    final encodedPayload = jsonEncode(payload);
    return const JsonEncoder.withIndent('  ').convert({
      'archiveVersion': 1,
      'checksum': sha256.convert(utf8.encode(encodedPayload)).toString(),
      'payload': payload,
    });
  }

  BingoProject import(String source) {
    final archive = jsonDecode(source) as Map<String, dynamic>;
    if (archive['archiveVersion'] != 1) {
      throw const FormatException(
        'This project archive version is not supported.',
      );
    }
    final payload = archive['payload'] as Map<String, dynamic>;
    final actual = sha256.convert(utf8.encode(jsonEncode(payload))).toString();
    if (archive['checksum'] != actual) {
      throw const FormatException('The project archive checksum is invalid.');
    }
    final project = BingoProject.fromJson(payload);
    final errors = project.rules.validate();
    if (errors.isNotEmpty || project.cardCount < 1 || project.cardCount > 18) {
      throw FormatException(
        errors.isEmpty ? 'Invalid card count.' : errors.join(' '),
      );
    }
    return project;
  }
}
