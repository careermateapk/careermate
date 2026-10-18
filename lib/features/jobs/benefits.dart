import 'job_models.dart';

/// Benefits and working conditions read from a job's own text. Only what the job says — nothing guessed.
enum Perk { cab, pf, esi, health, food, wfh, hybrid, dayShift, nightShift, rotational, fiveDay, sixDay, maternity, creche, posh, bonus }

extension PerkInfo on Perk {
  String get emoji => switch (this) {
        Perk.cab => '🚌',
        Perk.pf => '🏦',
        Perk.esi => '🏥',
        Perk.health => '🩺',
        Perk.food => '🍱',
        Perk.wfh => '🏠',
        Perk.hybrid => '🏠',
        Perk.dayShift => '☀️',
        Perk.nightShift => '🌙',
        Perk.rotational => '🔄',
        Perk.fiveDay => '📅',
        Perk.sixDay => '📅',
        Perk.maternity => '🤱',
        Perk.creche => '🧸',
        Perk.posh => '🛡️',
        Perk.bonus => '💰',
      };

  String get label => switch (this) {
        Perk.cab => 'Cab',
        Perk.pf => 'PF',
        Perk.esi => 'ESI',
        Perk.health => 'Health cover',
        Perk.food => 'Food',
        Perk.wfh => 'Work from home',
        Perk.hybrid => 'Hybrid',
        Perk.dayShift => 'Day shift',
        Perk.nightShift => 'Night shift',
        Perk.rotational => 'Rotational shift',
        Perk.fiveDay => '5-day week',
        Perk.sixDay => '6-day week',
        Perk.maternity => 'Maternity benefits',
        Perk.creche => 'Creche',
        Perk.posh => 'POSH policy',
        Perk.bonus => 'Bonus / incentives',
      };

  /// Shown in amber: worth knowing before applying.
  bool get caution => this == Perk.nightShift || this == Perk.rotational || this == Perk.sixDay;
}

const _patterns = <Perk, String>{
  Perk.cab: r'\b(cab|cabs|pick ?up (and|&) drop|pick-up|transport(ation)? (facility|provided)|drop facility|shuttle)\b',
  Perk.pf: r'\b(pf|provident fund|epf)\b',
  Perk.esi: r'\b(esi|esic)\b',
  Perk.health: r'\b(health insurance|medical insurance|mediclaim|medical cover|health cover|group insurance)\b',
  Perk.food: r'\b(free (meals?|food|lunch)|meals? provided|food provided|lunch provided|cafeteria|canteen)\b',
  Perk.wfh: r'\b(work from home|wfh|fully remote|100% remote|remote job|remote role)\b',
  Perk.hybrid: r'\bhybrid\b',
  Perk.dayShift: r'\b(day shift|general shift|morning shift|9(:00)? ?(am)? ?(to|-) ?6(:00)? ?pm|10(:00)? ?(am)? ?(to|-) ?7(:00)? ?pm)\b',
  Perk.nightShift: r'\b(night shift|us shift|uk shift|graveyard shift|night shifts)\b',
  Perk.rotational: r'\b(rotational shifts?|rotating shifts?)\b',
  Perk.fiveDay: r'\b(5 days? (working|a week|week)|five days? (working|a week)|5-day (work )?week|saturday (and|&) sunday off|sat(urday)?-sun(day)? off)\b',
  Perk.sixDay: r'\b(6 days? (working|a week|week)|six days? (working|a week)|6-day (work )?week|monday to saturday|mon-sat)\b',
  Perk.maternity: r'\b(maternity (leave|benefits?)|paid parental leave)\b',
  Perk.creche: r'\b(creche|day ?care)\b',
  Perk.posh: r'\b(posh|prevention of sexual harassment|internal complaints committee)\b',
  Perk.bonus: r'\b(incentives?|performance bonus|annual bonus|joining bonus)\b',
};

final _cache = <String, Set<Perk>>{};

Set<Perk> perksOf(JobItem j) => _cache.putIfAbsent(j.id, () {
      final t = '${j.title}\n${j.fullText}\n${j.employmentType ?? ''}'.toLowerCase();
      final out = <Perk>{};
      _patterns.forEach((p, re) {
        if (RegExp(re).hasMatch(t)) out.add(p);
      });
      if (j.remote) out.add(Perk.wfh);
      if (out.contains(Perk.wfh)) out.remove(Perk.hybrid);
      return out;
    });

/// "Not mentioned" items worth asking HR about.
List<Perk> unknownBasics(Set<Perk> perks) => [
      if (!perks.contains(Perk.pf)) Perk.pf,
      if (!perks.any((p) => p == Perk.dayShift || p == Perk.nightShift || p == Perk.rotational)) Perk.dayShift,
    ];
