import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'resume_data.dart';
import 'templates.dart';

String _x(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Word file with the same content and colour. It uses a simple one-column layout so it stays easy to edit.
Uint8List buildDocx(ResumeData d, ResumeTemplate t) {
  final hex = (d.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  final font = t.font == ResumeFont.serif ? 'Times New Roman' : 'Calibri';
  String run(String text, {bool bold = false, int size = 21, String? color, bool italic = false}) =>
      '<w:r><w:rPr><w:rFonts w:ascii="$font" w:hAnsi="$font" w:cs="$font"/>${bold ? '<w:b/>' : ''}${italic ? '<w:i/>' : ''}'
      '${color != null ? '<w:color w:val="$color"/>' : ''}<w:sz w:val="$size"/></w:rPr><w:t xml:space="preserve">${_x(text)}</w:t></w:r>';
  String para(String runs, {int after = 60, String align = 'left', bool rule = false, bool bullet = false}) =>
      '<w:p><w:pPr>${bullet ? '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>' : ''}'
      '<w:spacing w:after="$after"/><w:jc w:val="$align"/>'
      '${rule ? '<w:pBdr><w:bottom w:val="single" w:sz="8" w:space="2" w:color="$hex"/></w:pBdr>' : ''}</w:pPr>$runs</w:p>';
  final center = t.centered || t.layout == ResumeLayout.classic;
  final al = center ? 'center' : 'left';
  final body = StringBuffer()
    ..write(para(run(d.name.isEmpty ? 'Your Name' : d.name, bold: true, size: 44, color: hex), after: 20, align: al))
    ..write(d.headline.isEmpty ? '' : para(run(d.headline, bold: true, size: 24, color: '555555'), after: 40, align: al))
    ..write(para(run(d.contactLine.join('  |  '), size: 19, color: '555555'), after: 120, align: al, rule: true));
  void head(String s) => body.write(para(run(t.upperHeadings ? s.toUpperCase() : s, bold: true, size: 23, color: hex), after: 60, rule: true));
  if (d.summary.trim().isNotEmpty) {
    head('Summary');
    body.write(para(run(d.summary), after: 120));
  }
  if (d.jobs.isNotEmpty) {
    head('Experience');
    for (final j in d.jobs) {
      body.write(para(
          run([j.role, j.company].where((s) => s.isNotEmpty).join(', '), bold: true, size: 22) +
              (j.dates.isEmpty ? '' : run('   ${j.dates}', size: 19, color: hex, bold: true)),
          after: 10));
      if (j.city.isNotEmpty) body.write(para(run(j.city, size: 19, color: '777777', italic: true), after: 20));
      for (final b in j.bullets.where((b) => b.trim().isNotEmpty)) {
        body.write(para(run(b, size: 20), after: 20, bullet: true));
      }
      body.write(para('', after: 60));
    }
  }
  if (d.skills.isNotEmpty) {
    head('Skills');
    body.write(para(run(d.skills.join(' • ')), after: 120));
  }
  if (d.education.isNotEmpty) {
    head('Education');
    for (final e in d.education) {
      body.write(para(run(e.degree, bold: true, size: 21) + (e.dates.isEmpty ? '' : run('   ${e.dates}', size: 19, color: '777777')), after: 10));
      final sub = [e.school, e.city].where((s) => s.isNotEmpty).join(', ');
      if (sub.isNotEmpty) body.write(para(run(sub, size: 19, color: '555555'), after: 60));
    }
  }
  if (d.certifications.isNotEmpty) {
    head('Certifications');
    for (final c in d.certifications) {
      body.write(para(run(c, size: 20), after: 20, bullet: true));
    }
  }
  if (d.languages.isNotEmpty) {
    head('Languages');
    body.write(para(run(d.languages.join(' · ')), after: 60));
  }

  final document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body>$body'
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1000" w:right="1000" w:bottom="1000" w:left="1000" w:header="0" w:footer="0" w:gutter="0"/></w:sectPr>'
      '</w:body></w:document>';
  const numbering = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:abstractNum w:abstractNumId="0"><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/>'
      '<w:lvlJc w:val="left"/><w:pPr><w:ind w:left="360" w:hanging="240"/></w:pPr></w:lvl></w:abstractNum>'
      '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num></w:numbering>';
  const contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>'
      '</Types>';
  const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>';
  const docRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>'
      '</Relationships>';
  final archive = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('[Content_Types].xml', contentTypes);
  add('_rels/.rels', rels);
  add('word/document.xml', document);
  add('word/_rels/document.xml.rels', docRels);
  add('word/numbering.xml', numbering);
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Plain text, for online forms that only accept text.
String buildTxt(ResumeData d) {
  final b = StringBuffer()
    ..writeln(d.name.toUpperCase())
    ..writeln(d.headline)
    ..writeln(d.contactLine.join(' | '))
    ..writeln();
  void head(String s) => b
    ..writeln(s.toUpperCase())
    ..writeln('-' * s.length);
  if (d.summary.trim().isNotEmpty) {
    head('Summary');
    b
      ..writeln(d.summary)
      ..writeln();
  }
  if (d.jobs.isNotEmpty) {
    head('Experience');
    for (final j in d.jobs) {
      b.writeln([j.role, j.company, j.city].where((s) => s.isNotEmpty).join(', '));
      if (j.dates.isNotEmpty) b.writeln(j.dates);
      for (final p in j.bullets.where((p) => p.trim().isNotEmpty)) {
        b.writeln('- $p');
      }
      b.writeln();
    }
  }
  if (d.skills.isNotEmpty) {
    head('Skills');
    b
      ..writeln(d.skills.join(', '))
      ..writeln();
  }
  if (d.education.isNotEmpty) {
    head('Education');
    for (final e in d.education) {
      b.writeln([e.degree, e.school, e.city, e.dates].where((s) => s.isNotEmpty).join(', '));
    }
    b.writeln();
  }
  if (d.certifications.isNotEmpty) {
    head('Certifications');
    for (final c in d.certifications) {
      b.writeln('- $c');
    }
    b.writeln();
  }
  if (d.languages.isNotEmpty) {
    head('Languages');
    b.writeln(d.languages.join(', '));
  }
  return b.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
