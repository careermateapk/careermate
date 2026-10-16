import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'resume_data.dart';
import 'templates.dart';

/// Built-in PDF fonts only cover basic Latin, so replace a few symbols.
String clean(String s) => s
    .replaceAll('₹', 'Rs. ')
    .replaceAll(RegExp('[“”]'), '"')
    .replaceAll(RegExp('[‘’]'), "'")
    .replaceAll('…', '...')
    .replaceAll(RegExp(r'[^\x00-\xFF–—•]'), '');

class ResumePdf {
  ResumePdf(this.d, this.t, {int? color}) : accent = PdfColor.fromInt(color ?? d.color);
  final ResumeData d;
  final ResumeTemplate t;
  final PdfColor accent;

  PdfColor get tint => PdfColor(accent.red, accent.green, accent.blue, 0.10);
  static const ink = PdfColor.fromInt(0xFF1F2937);
  static const muted = PdfColor.fromInt(0xFF6B7280);

  pw.ThemeData get _theme => t.font == ResumeFont.serif
      ? pw.ThemeData.withFont(base: pw.Font.times(), bold: pw.Font.timesBold(), italic: pw.Font.timesItalic())
      : pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold(), italic: pw.Font.helveticaOblique());

  Future<Uint8List> build() async {
    final doc = pw.Document(title: '${clean(d.name)} CV', author: clean(d.name), creator: 'CareerMate');
    switch (t.layout) {
      case ResumeLayout.sidebarLeft:
      case ResumeLayout.sidebarRight:
        _sidebar(doc, left: t.layout == ResumeLayout.sidebarLeft);
      case ResumeLayout.split:
        _split(doc);
      default:
        _single(doc);
    }
    return doc.save();
  }

  // ------------------------------------------------------------------ pieces

  pw.Widget heading(String s, {PdfColor? color, bool onDark = false}) {
    final text = t.upperHeadings ? s.toUpperCase() : s;
    final c = color ?? (onDark ? PdfColors.white : accent);
    if (t.layout == ResumeLayout.boxed && !onDark) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 12, bottom: 6),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: accent,
        child: pw.Text(text, style: pw.TextStyle(color: PdfColors.white, fontSize: 10.5, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
      );
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12, bottom: 5),
      padding: const pw.EdgeInsets.only(bottom: 3),
      decoration: t.layout == ResumeLayout.classic || t.layout == ResumeLayout.minimal
          ? pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: t.layout == ResumeLayout.minimal ? PdfColors.grey300 : c, width: 0.8)))
          : null,
      child: pw.Text(text,
          style: pw.TextStyle(color: c, fontSize: t.upperHeadings ? 10.5 : 12.5, fontWeight: pw.FontWeight.bold, letterSpacing: t.upperHeadings ? 1.2 : 0)),
    );
  }

  pw.Widget bullets(List<String> items, {PdfColor color = ink}) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final b in items.where((b) => b.trim().isNotEmpty))
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Container(width: 3, height: 3, margin: const pw.EdgeInsets.only(top: 4, right: 6), decoration: pw.BoxDecoration(color: accent, shape: pw.BoxShape.circle)),
                pw.Expanded(child: pw.Text(clean(b), style: pw.TextStyle(fontSize: 9.5, color: color, lineSpacing: 1.5))),
              ]),
            ),
        ],
      );

  List<pw.Widget> jobs({bool timeline = false}) => [
        for (final j in d.jobs)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: timeline ? const pw.EdgeInsets.only(left: 12) : null,
            decoration: timeline ? pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: accent, width: 1.5))) : null,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Expanded(
                  child: pw.Text(clean([j.role, j.company].where((s) => s.isNotEmpty).join(', ')),
                      style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: ink)),
                ),
                if (j.dates.isNotEmpty) pw.Text(clean(j.dates), style: pw.TextStyle(fontSize: 9, color: accent, fontWeight: pw.FontWeight.bold)),
              ]),
              if (j.city.isNotEmpty) pw.Text(clean(j.city), style: const pw.TextStyle(fontSize: 9, color: muted)),
              bullets(j.bullets),
            ]),
          ),
      ];

  List<pw.Widget> education({PdfColor color = ink, PdfColor sub = muted}) => [
        for (final e in d.education)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(clean(e.degree), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
              if (e.school.isNotEmpty || e.city.isNotEmpty)
                pw.Text(clean([e.school, e.city].where((s) => s.isNotEmpty).join(', ')), style: pw.TextStyle(fontSize: 9, color: sub)),
              if (e.dates.isNotEmpty) pw.Text(clean(e.dates), style: pw.TextStyle(fontSize: 8.5, color: sub)),
            ]),
          ),
      ];

  pw.Widget chips(List<String> items) => pw.Wrap(spacing: 5, runSpacing: 5, children: [
        for (final s in items)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: pw.BoxDecoration(color: tint, borderRadius: pw.BorderRadius.circular(3)),
            child: pw.Text(clean(s), style: const pw.TextStyle(fontSize: 9, color: ink)),
          ),
      ]);

  pw.Widget lines(List<String> items, {PdfColor color = ink}) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [for (final s in items) pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3), child: pw.Text(clean(s), style: pw.TextStyle(fontSize: 9.5, color: color)))],
      );

  pw.Widget badge({PdfColor bg = PdfColors.white, PdfColor fg = PdfColors.black, double size = 46}) => pw.Container(
        width: size,
        height: size,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(color: bg, shape: pw.BoxShape.circle),
        child: pw.Text(clean(d.initials), style: pw.TextStyle(color: fg, fontSize: size * 0.36, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget nameBlock({PdfColor color = ink, PdfColor sub = muted, bool center = false}) => pw.Column(
        crossAxisAlignment: center ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(clean(d.name.isEmpty ? 'Your Name' : d.name),
              textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: color, letterSpacing: t.upperHeadings ? 0.5 : 0)),
          if (d.headline.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(clean(d.headline), style: pw.TextStyle(fontSize: 11.5, color: sub, fontWeight: pw.FontWeight.bold)),
            ),
        ],
      );

  List<pw.Widget> mainSections({bool withSkills = false, bool timeline = false}) => [
        if (d.summary.trim().isNotEmpty) ...[
          heading(t.upperHeadings ? 'Summary' : 'Professional summary'),
          pw.Text(clean(d.summary), style: const pw.TextStyle(fontSize: 9.8, color: ink, lineSpacing: 1.6)),
        ],
        if (d.jobs.isNotEmpty) ...[heading('Experience'), ...jobs(timeline: timeline)],
        if (withSkills && d.skills.isNotEmpty) ...[heading('Skills'), chips(d.skills)],
        if (withSkills && d.education.isNotEmpty) ...[heading('Education'), ...education()],
        if (withSkills && d.certifications.isNotEmpty) ...[heading('Certifications'), lines(d.certifications)],
        if (withSkills && d.languages.isNotEmpty) ...[heading('Languages'), pw.Text(clean(d.languages.join(' · ')), style: const pw.TextStyle(fontSize: 9.5))],
      ];

  // ------------------------------------------------------------------ layouts

  void _sidebar(pw.Document doc, {required bool left}) {
    const side = 175.0;
    const m = 18.0; // page margin; the coloured panel is drawn full-bleed behind it
    final page = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: _theme,
      margin: const pw.EdgeInsets.fromLTRB(m, 30, m, 24),
      buildBackground: (ctx) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Row(children: [
          if (left) pw.Container(width: side, color: accent),
          pw.Expanded(child: pw.Container(color: PdfColors.white)),
          if (!left) pw.Container(width: side, color: accent),
        ]),
      ),
    );
    final sideCol = pw.Partition(
      width: side - m - 12,
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (t.initialsBadge) ...[badge(fg: accent), pw.SizedBox(height: 14)],
          heading('Contact', onDark: true),
          lines(d.contactLine, color: PdfColors.white),
          if (d.skills.isNotEmpty) ...[heading('Skills', onDark: true), lines(d.skills, color: PdfColors.white)],
          if (d.education.isNotEmpty) ...[heading('Education', onDark: true), ...education(color: PdfColors.white, sub: PdfColors.grey200)],
          if (d.languages.isNotEmpty) ...[heading('Languages', onDark: true), lines(d.languages, color: PdfColors.white)],
          if (d.certifications.isNotEmpty) ...[heading('Certifications', onDark: true), lines(d.certifications, color: PdfColors.white)],
        ]),
    );
    final gap = pw.Partition(width: 12 + 20, child: pw.Column(children: [pw.SizedBox(width: 1)]));
    final mainCol = pw.Partition(
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        nameBlock(sub: accent),
        ...mainSections(),
      ]),
    );
    doc.addPage(pw.MultiPage(
      pageTheme: page,
      build: (ctx) => [pw.Partitions(children: left ? [sideCol, gap, mainCol] : [mainCol, gap, sideCol])],
    ));
  }

  void _split(pw.Document doc) {
    const side = 170.0;
    final page = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: _theme,
      margin: const pw.EdgeInsets.fromLTRB(30, 32, 16, 24),
      buildBackground: (ctx) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Row(children: [
          pw.Expanded(child: pw.Container(color: PdfColors.white)),
          pw.Container(width: side, color: tint, child: pw.Row(children: [pw.Container(width: 3, color: accent)])),
        ]),
      ),
    );
    doc.addPage(pw.MultiPage(
      pageTheme: page,
      build: (ctx) => [
        pw.Partitions(children: [
          pw.Partition(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(clean(d.name.isEmpty ? 'Your Name' : d.name), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: accent)),
              if (d.headline.isNotEmpty) pw.Text(clean(d.headline), style: const pw.TextStyle(fontSize: 11.5, color: muted)),
              ...mainSections(),
            ]),
          ),
          pw.Partition(width: 38, child: pw.Column(children: [pw.SizedBox(width: 1)])),
          pw.Partition(
            width: side - 16 - 14,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                if (t.initialsBadge) ...[badge(bg: accent, fg: PdfColors.white), pw.SizedBox(height: 10)],
                heading('Contact'),
                lines(d.contactLine),
                if (d.skills.isNotEmpty) ...[heading('Skills'), lines(d.skills)],
                if (d.education.isNotEmpty) ...[heading('Education'), ...education()],
                if (d.languages.isNotEmpty) ...[heading('Languages'), lines(d.languages)],
                if (d.certifications.isNotEmpty) ...[heading('Certifications'), lines(d.certifications)],
            ]),
          ),
        ]),
      ],
    ));
  }

  void _single(pw.Document doc) {
    final band = t.layout == ResumeLayout.headerBand;
    final center = t.centered || t.layout == ResumeLayout.classic;
    final page = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: _theme,
      margin: band ? const pw.EdgeInsets.fromLTRB(0, 0, 0, 30) : const pw.EdgeInsets.fromLTRB(40, 36, 40, 30),
    );
    final contact = pw.Text(clean(d.contactLine.join('   |   ')),
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(fontSize: 9.2, color: band ? PdfColors.white : muted));
    final header = band
        ? pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 4),
            padding: const pw.EdgeInsets.fromLTRB(36, 26, 36, 18),
            color: accent,
            child: pw.Row(children: [
              if (t.initialsBadge) ...[badge(fg: accent), pw.SizedBox(width: 14)],
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: center ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start, children: [
                  nameBlock(color: PdfColors.white, sub: PdfColors.grey100, center: center),
                  pw.SizedBox(height: 6),
                  contact,
                ]),
              ),
            ]),
          )
        : pw.Column(crossAxisAlignment: center ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start, children: [
            pw.Row(mainAxisAlignment: center ? pw.MainAxisAlignment.center : pw.MainAxisAlignment.start, children: [
              if (t.initialsBadge) ...[badge(bg: accent, fg: PdfColors.white, size: 40), pw.SizedBox(width: 12)],
              pw.Flexible(child: nameBlock(color: t.layout == ResumeLayout.minimal ? ink : accent, sub: muted, center: center)),
            ]),
            pw.SizedBox(height: 6),
            contact,
            if (t.layout == ResumeLayout.classic) pw.Container(margin: const pw.EdgeInsets.only(top: 8), height: 1.5, color: accent),
          ]);
    doc.addPage(pw.MultiPage(
      pageTheme: page,
      build: (ctx) => [
        header,
        for (final w in mainSections(withSkills: true, timeline: t.layout == ResumeLayout.timeline))
          band ? pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 36), child: w) : w,
      ],
    ));
  }
}
