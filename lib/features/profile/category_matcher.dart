import 'cv_parser.dart';
import 'taxonomy.dart';

class SubMatch {
  SubMatch(this.sub, this.category, this.score, this.matchedSkills, this.matchedTitles);
  final SubCategory sub;
  final JobCategory category;
  final double score;
  final List<String> matchedSkills;
  final List<String> matchedTitles;

  /// 0–100, relative to the strongest sub-category for this CV.
  int strength = 0;
}

class CategoryResult {
  CategoryResult(this.main, this.subs);
  final JobCategory? main;

  /// Best first. Only sub-categories with some evidence in the CV.
  final List<SubMatch> subs;
}

/// Places a CV in the taxonomy using the skills and job titles found in it.
/// A job title counts 3×, because it says what the person actually did.
class CategoryMatcher {
  const CategoryMatcher();

  CategoryResult match({required List<String> skills, required List<String> titles}) {
    final skillSet = skills.map((s) => s.toLowerCase()).toSet();
    final titleText = titles.map((t) => t.toLowerCase()).join(' | ');
    final results = <SubMatch>[];

    for (final c in jobCategories) {
      for (final s in c.subs) {
        final ms = s.skills.where(skillSet.contains).toList();
        final mt = s.titles.where((t) => CvParser.containsWord(titleText, t)).toList();
        final score = ms.length + mt.length * 3.0;
        if (score > 0) results.add(SubMatch(s, c, score, ms, mt));
      }
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    if (results.isEmpty) return CategoryResult(null, const []);

    // Main category = the one with the most total evidence.
    final totals = <String, double>{};
    for (final r in results) {
      totals[r.category.id] = (totals[r.category.id] ?? 0) + r.score;
    }
    final mainId = totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final main = categoryById(mainId);

    final top = results.first.score;
    for (final r in results) {
      r.strength = (30 + 65 * (r.score / top)).round().clamp(0, 95).toInt();
    }
    return CategoryResult(main, results.take(8).toList());
  }
}
