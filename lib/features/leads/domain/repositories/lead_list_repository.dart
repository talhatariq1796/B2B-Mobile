import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/lead.dart';

/// Raw bytes of the exported spreadsheet plus the filename the server
/// suggested via `Content-Disposition` (falls back to `leads.xlsx` if that
/// header is missing/unparseable) — the caller just needs to write these
/// bytes out and hand the file to the user, not parse anything.
class LeadExportFile {
  const LeadExportFile({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

/// Domain-facing contract for GET /api/leads/ — the persistent record of
/// every Lead this workspace has scanned, across devices/sessions. Stats
/// (total/created/partial/failed) are derived client-side from this list
/// rather than calling GET /api/leads/stats/ separately — the counts are
/// otherwise redundant to compute twice.
abstract class LeadListRepository {
  Future<Either<Failure, List<Lead>>> getLeads();

  /// GET /api/leads/export/ — a full .xlsx export of every lead this
  /// workspace can see (no filters).
  Future<Either<Failure, LeadExportFile>> exportToExcel();
}
