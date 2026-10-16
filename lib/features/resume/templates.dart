/// 40 original CV templates built from 8 layouts × 5 styles.
enum ResumeLayout { sidebarLeft, sidebarRight, headerBand, classic, timeline, split, minimal, boxed }

enum ResumeFont { sans, serif }

class ResumeTemplate {
  const ResumeTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.layout,
    required this.font,
    required this.color,
    this.upperHeadings = true,
    this.centered = false,
    this.initialsBadge = false,
  });

  final String id;
  final String name;
  final String category;
  final ResumeLayout layout;
  final ResumeFont font;
  final int color;
  final bool upperHeadings;
  final bool centered;
  final bool initialsBadge;

  bool get twoColumn => const {ResumeLayout.sidebarLeft, ResumeLayout.sidebarRight, ResumeLayout.split}.contains(layout);

  /// Single-column, text-only layouts read most reliably in hiring systems.
  bool get atsBest => !twoColumn;
}

const resumeCategories = ['Popular', 'Modern', 'Creative', 'Professional', 'Simple'];

/// The colours offered under every template.
const resumeColors = <int>[
  0xFF1E3A6E, // navy
  0xFF374151, // charcoal
  0xFF0F766E, // teal
  0xFF2563EB, // blue
  0xFF0E7490, // cyan
  0xFF7C3AED, // violet
  0xFFEA580C, // orange
  0xFFDC2626, // red
  0xFF15803D, // green
  0xFF8B6F5C, // taupe
];

const _styles = [
  // name suffix, font, upper headings, centered, initials badge
  ('Classic', ResumeFont.sans, true, false, false),
  ('Elegant', ResumeFont.serif, false, false, false),
  ('Bold', ResumeFont.sans, true, false, true),
  ('Soft', ResumeFont.sans, false, true, false),
  ('Formal', ResumeFont.serif, true, true, false),
];

const _layoutInfo = <ResumeLayout, (String, List<String>, List<int>)>{
  ResumeLayout.sidebarLeft: ('Sidebar', ['Popular', 'Popular', 'Modern', 'Creative', 'Professional'], [0xFF1E3A6E, 0xFF0F766E, 0xFF374151, 0xFF7C3AED, 0xFF8B6F5C]),
  ResumeLayout.sidebarRight: ('Right Panel', ['Popular', 'Modern', 'Creative', 'Creative', 'Professional'], [0xFF0E7490, 0xFF2563EB, 0xFFEA580C, 0xFFDC2626, 0xFF374151]),
  ResumeLayout.headerBand: ('Header', ['Popular', 'Popular', 'Creative', 'Modern', 'Professional'], [0xFF0F766E, 0xFF2563EB, 0xFFEA580C, 0xFF7C3AED, 0xFF1E3A6E]),
  ResumeLayout.classic: ('Classic', ['Popular', 'Professional', 'Professional', 'Simple', 'Simple'], [0xFF111827, 0xFF1E3A6E, 0xFF374151, 0xFF15803D, 0xFF8B6F5C]),
  ResumeLayout.timeline: ('Timeline', ['Modern', 'Modern', 'Creative', 'Popular', 'Professional'], [0xFF7C3AED, 0xFF0E7490, 0xFFDC2626, 0xFF2563EB, 0xFF374151]),
  ResumeLayout.split: ('Split', ['Creative', 'Modern', 'Creative', 'Popular', 'Modern'], [0xFFDC2626, 0xFF0F766E, 0xFFEA580C, 0xFF1E3A6E, 0xFF15803D]),
  ResumeLayout.minimal: ('Minimal', ['Simple', 'Simple', 'Modern', 'Popular', 'Simple'], [0xFF111827, 0xFF374151, 0xFF2563EB, 0xFF0F766E, 0xFF8B6F5C]),
  ResumeLayout.boxed: ('Blocks', ['Creative', 'Professional', 'Modern', 'Popular', 'Professional'], [0xFF2563EB, 0xFF1E3A6E, 0xFF7C3AED, 0xFFEA580C, 0xFF0F766E]),
};

final List<ResumeTemplate> resumeTemplates = [
  for (final e in _layoutInfo.entries)
    for (var i = 0; i < _styles.length; i++)
      ResumeTemplate(
        id: '${e.key.name}-$i',
        name: '${_styles[i].$1} ${e.value.$1}',
        category: e.value.$2[i],
        layout: e.key,
        font: _styles[i].$2,
        color: e.value.$3[i],
        upperHeadings: _styles[i].$3,
        centered: _styles[i].$4,
        initialsBadge: _styles[i].$5,
      ),
];

ResumeTemplate templateById(String id) => resumeTemplates.firstWhere((t) => t.id == id, orElse: () => resumeTemplates.first);
