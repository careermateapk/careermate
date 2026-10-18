import 'package:careermate/features/jobs/benefits.dart';
import 'package:careermate/features/jobs/job_models.dart';
import 'package:careermate/features/skills/skill_bank.dart';
import 'package:flutter_test/flutter_test.dart';

JobItem job(String text, {String id = 'x'}) => JobItem(
      id: id, title: 'Accounts Executive', company: 'ACME', location: 'Delhi', remote: false, url: '', source: 'test',
      sourceName: 'Test', official: true, postedAt: null, dateKind: 'unknown', lastChecked: null, salaryMin: null,
      salaryMax: null, employmentType: null, snippet: text, skills: const [], subIds: const [], scamFlags: const []);

void main() {
  test('reads benefits from job text', () {
    final p = perksOf(job('Cab facility provided for night shift. PF and ESI. Medical insurance. 5 days working. Free meals.', id: 'a'));
    expect(p, containsAll([Perk.cab, Perk.nightShift, Perk.pf, Perk.esi, Perk.health, Perk.fiveDay, Perk.food]));
  });

  test('does not invent benefits', () {
    final p = perksOf(job('Prepare GST returns and reconcile bank statements.', id: 'b'));
    expect(p, isEmpty);
    expect(unknownBasics(p), containsAll([Perk.pf, Perk.dayShift]));
  });

  test('skill tests have valid answers and enough questions', () {
    for (final t in skillTests) {
      expect(t.questions.length, greaterThanOrEqualTo(questionsPerTest), reason: t.id);
      for (final q in t.questions) {
        expect(q.answer, inInclusiveRange(0, q.options.length - 1), reason: '${t.id}: ${q.q}');
        expect(q.options.toSet().length, q.options.length, reason: 'duplicate options in ${t.id}: ${q.q}');
      }
    }
  });
}
