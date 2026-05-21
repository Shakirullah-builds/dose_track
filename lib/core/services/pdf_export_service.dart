import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:dose_vault/core/models/medication.dart';

/// Generates a professional PDF adherence report and opens the native share sheet.
///
/// Why a static utility class?
/// → The PDF generation has no mutable state and doesn't depend on the widget tree.
///   A static method keeps the call site a one-liner (same pattern as TopToast).
///
/// The report is designed to look medical-grade:
/// - Clean header with title + date + horizontal rule
/// - Summary stat blocks (Taken / Skipped)
/// - Alternating-row data table with grey header
/// - Discreet footer with privacy note
class PdfExportService {
  PdfExportService._();

  static final _dateFormat = DateFormat('MMM d, yyyy');
  static final _timeFormat = DateFormat('h:mm a');

  /// Generates a full adherence report and opens the OS share sheet.
  ///
  /// [logs] — the complete dose log history (all dates).
  /// [medMap] — lookup map from medication ID → Medication object.
  /// [totalTaken] / [totalSkipped] — pre-computed from the provider.
  static Future<void> generateAndShareReport({
    required List<DoseLog> logs,
    required Map<String, Medication> medMap,
    required int totalTaken,
    required int totalSkipped,
  }) async {
    final pdf = pw.Document(
      title: 'DoseVault Patient Adherence Report',
      author: 'DoseVault App',
    );

    // Sort logs newest-first for the table
    final sortedLogs = List<DoseLog>.from(logs)
      ..sort((a, b) => b.date.compareTo(a.date));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(context),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummary(totalTaken, totalSkipped),
          pw.SizedBox(height: 24),
          _buildTable(sortedLogs, medMap),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'DoseVault_Report.pdf',
    );
  }

  // ── Header ──────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DoseVault',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#2563EB'),
              ),
            ),
            pw.Text(
              _dateFormat.format(DateTime.now()),
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Patient Adherence Report',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Divider(thickness: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 16),
      ],
    );
  }

  // ── Summary Stats ───────────────────────────────────────────────────

  static pw.Widget _buildSummary(int taken, int skipped) {
    return pw.Row(
      children: [
        _statBlock(
          label: 'Total Doses Taken',
          value: taken.toString(),
          color: PdfColor.fromHex('#02563EB'),
        ),
        pw.SizedBox(width: 24),
        _statBlock(
          label: 'Total Doses Skipped',
          value: skipped.toString(),
          color: PdfColor.fromHex('#E53935'),
        ),
      ],
    );
  }

  static pw.Widget _statBlock({
    required String label,
    required String value,
    required PdfColor color,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );
  }

  // ── Data Table ──────────────────────────────────────────────────────

  static pw.Widget _buildTable(
    List<DoseLog> logs,
    Map<String, Medication> medMap,
  ) {
    final headers = ['Date', 'Time', 'Medication', 'Dosage', 'Status'];

    final data = logs.map((log) {
      final med = medMap[log.medicationId];
      final medName = med?.name ?? 'Unknown';
      final dosage = med != null
          ? '${med.dosage.toStringAsFixed(0)} ${med.unit}'
          : '—';
      final status = log.status == 'taken' ? 'Taken' : 'Skipped';
      final dateStr = _dateFormat.format(log.date);
      final timeStr = log.actionTime != null
          ? _timeFormat.format(log.actionTime!)
          : (med != null ? med.scheduledTime : '—');

      return [dateStr, timeStr, medName, dosage, status];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: null,
      headerStyle: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.grey800,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerLeft,
      },
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellHeight: 32,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerLeft,
      },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }

  // ── Footer ──────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 0.5, color: PdfColors.grey300),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            'Generated securely via DoseVault.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ),
      ],
    );
  }
}
