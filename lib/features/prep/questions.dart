/// Interview question bank. Tips explain what the interviewer wants; they are guidance, not scripted answers.
class PrepQuestion {
  const PrepQuestion(this.id, this.kind, this.text, this.tip, {this.keywords = const []});
  final String id;

  /// hr | behavioural | role
  final String kind;
  final String text;
  final String tip;

  /// Words a relevant answer usually touches on (used for simple feedback).
  final List<String> keywords;
}

const hrQuestions = <PrepQuestion>[
  PrepQuestion('hr1', 'hr', 'Tell me about yourself.', 'Keep it to 60–90 seconds: current role, 2–3 strengths with proof, and why this job is the next step.', keywords: ['experience', 'role', 'skills', 'currently', 'years']),
  PrepQuestion('hr2', 'hr', 'Why do you want to join our company?', 'Mention something specific about the company (product, clients, growth) and connect it to your skills.', keywords: ['company', 'growth', 'learn', 'product', 'team']),
  PrepQuestion('hr3', 'hr', 'Why are you leaving your current job?', 'Stay positive. Talk about growth, learning or a bigger role — never criticise your employer.', keywords: ['growth', 'opportunity', 'learn', 'responsibility']),
  PrepQuestion('hr4', 'hr', 'What are your strengths?', 'Pick two strengths that matter for this job and give a short real example for each.', keywords: ['example', 'for example', 'strength']),
  PrepQuestion('hr5', 'hr', 'What is your biggest weakness?', 'Choose a real but manageable weakness and show what you are doing to improve it.', keywords: ['improve', 'working on', 'learned']),
  PrepQuestion('hr6', 'hr', 'Where do you see yourself in five years?', 'Show ambition that fits the company: deeper expertise, leading people or bigger responsibilities.', keywords: ['lead', 'grow', 'expert', 'responsibility']),
  PrepQuestion('hr7', 'hr', 'What is your current CTC and expected CTC?', 'Give your real current CTC. For expected, quote a researched range and say you are open to discussing the full package.', keywords: ['lakh', 'lpa', 'ctc', 'range', 'negotiable']),
  PrepQuestion('hr8', 'hr', 'What is your notice period? Can you join early?', 'State your exact notice period and whether buy-out or early release is possible. Don’t promise what you can’t do.', keywords: ['notice', 'days', 'month', 'buyout', 'early']),
  PrepQuestion('hr9', 'hr', 'Why should we hire you?', 'Match 2–3 job requirements with proof from your work. End with what you’ll deliver in the first months.', keywords: ['requirement', 'experience', 'deliver', 'result']),
  PrepQuestion('hr10', 'hr', 'Are you comfortable with relocation or shifts?', 'Answer honestly. If yes, say so clearly; if there are limits, explain them politely.', keywords: ['yes', 'comfortable', 'relocate', 'shift']),
  PrepQuestion('hr11', 'hr', 'Explain the gap in your career.', 'Be brief and honest (study, family, health, relocation) and show what you did to stay current.', keywords: ['course', 'learned', 'family', 'ready']),
  PrepQuestion('hr12', 'hr', 'Do you have any questions for us?', 'Always ask 1–2: what success looks like in 90 days, team structure, or next steps in the process.', keywords: ['team', 'success', 'next steps', 'expectations']),
];

const behaviouralQuestions = <PrepQuestion>[
  PrepQuestion('b1', 'behavioural', 'Tell me about a time you solved a difficult problem at work.', 'Use STAR: Situation, Task, Action (what YOU did), Result (with a real number if you have one).', keywords: ['situation', 'problem', 'i ', 'result', 'solved']),
  PrepQuestion('b2', 'behavioural', 'Describe a time you missed a deadline or made a mistake.', 'Own it, explain the fix, and the lesson you now apply. Interviewers value honesty here.', keywords: ['mistake', 'learned', 'fixed', 'now i']),
  PrepQuestion('b3', 'behavioural', 'Tell me about a conflict with a colleague and how you handled it.', 'Focus on listening, finding common ground and the outcome — not on who was wrong.', keywords: ['discussed', 'understood', 'agreed', 'result']),
  PrepQuestion('b4', 'behavioural', 'Give an example of when you led a team or took ownership.', 'Show how you planned, divided work, supported people and what the team achieved.', keywords: ['team', 'led', 'planned', 'achieved']),
  PrepQuestion('b5', 'behavioural', 'Describe a time you handled a lot of work under pressure.', 'Explain how you prioritised, communicated and delivered. Mention the result.', keywords: ['prioritised', 'prioritized', 'deadline', 'delivered']),
  PrepQuestion('b6', 'behavioural', 'Tell me about an achievement you are proud of.', 'Pick a work achievement with a clear before/after and your personal contribution.', keywords: ['achieved', 'improved', 'increased', 'reduced', '%']),
  PrepQuestion('b7', 'behavioural', 'Describe a time you had to learn something new quickly.', 'Show your learning method (practice, asking experts, documentation) and how fast you became useful.', keywords: ['learned', 'weeks', 'practice', 'applied']),
  PrepQuestion('b8', 'behavioural', 'Tell me about a time you dealt with an unhappy customer or stakeholder.', 'Show empathy, the steps you took and how the relationship ended up.', keywords: ['customer', 'listened', 'resolved', 'satisfied']),
];

const roleQuestions = <String, List<PrepQuestion>>{
  'it': [
    PrepQuestion('it1', 'role', 'Walk me through a project you built end to end.', 'Cover the problem, your tech choices and why, your part, and the result (users, speed, bugs fixed).', keywords: ['built', 'architecture', 'api', 'users', 'deployed']),
    PrepQuestion('it2', 'role', 'How do you debug a production issue?', 'Describe reproducing, reading logs/metrics, isolating the cause, fixing safely and preventing it again.', keywords: ['logs', 'reproduce', 'root cause', 'test', 'monitor']),
    PrepQuestion('it3', 'role', 'How do you make sure your code is good quality?', 'Talk about tests, code reviews, readable naming, small pull requests and CI.', keywords: ['test', 'review', 'ci', 'clean']),
    PrepQuestion('it4', 'role', 'Explain a technical concept from your CV to a non-technical person.', 'Use a simple everyday comparison. Clarity matters more than jargon.', keywords: ['like', 'simple', 'example']),
    PrepQuestion('it5', 'role', 'How would you improve the performance of a slow application?', 'Measure first, find the bottleneck (DB, network, rendering), fix the biggest one, measure again.', keywords: ['measure', 'cache', 'query', 'profile']),
  ],
  'finance': [
    PrepQuestion('fi1', 'role', 'Walk me through your month-end closing process.', 'Mention reconciliations, accruals, provisions, ledger scrutiny, MIS and the timelines you meet.', keywords: ['reconciliation', 'accrual', 'ledger', 'mis', 'closing']),
    PrepQuestion('fi2', 'role', 'How do you handle GST returns and TDS compliance?', 'Name the returns you file (GSTR-1, 3B, 9), reconciliation with 2B, TDS sections and due dates.', keywords: ['gstr', '3b', '2b', 'tds', 'due date']),
    PrepQuestion('fi3', 'role', 'How do you do a bank reconciliation and handle differences?', 'Explain matching entries, timing differences, un-cleared cheques and correcting errors.', keywords: ['bank', 'statement', 'difference', 'cheque']),
    PrepQuestion('fi4', 'role', 'How do you manage accounts payable and vendor payments?', 'Invoice verification, 3-way match, approvals, payment cycles, ageing and vendor communication.', keywords: ['invoice', 'approval', 'ageing', 'vendor', 'payment']),
    PrepQuestion('fi5', 'role', 'How do you follow up on overdue receivables?', 'Ageing reports, reminders, escalation, credit terms and keeping the customer relationship.', keywords: ['ageing', 'follow', 'credit', 'collection']),
    PrepQuestion('fi6', 'role', 'Which accounting software have you used, and for what?', 'Name the tools (Tally, Zoho Books, SAP) and the exact tasks you did in each.', keywords: ['tally', 'zoho', 'sap', 'excel']),
  ],
  'sales': [
    PrepQuestion('sa1', 'role', 'How do you find and qualify new leads?', 'Explain your sources, how you judge fit (budget, need, decision-maker) and your follow-up rhythm.', keywords: ['lead', 'qualify', 'follow', 'pipeline']),
    PrepQuestion('sa2', 'role', 'Tell me about a deal you closed that was difficult.', 'Use STAR. Show the objection, how you handled it, and the deal value or impact.', keywords: ['objection', 'closed', 'value', 'client']),
    PrepQuestion('sa3', 'role', 'How do you handle the objection “your price is too high”?', 'Acknowledge, ask questions, then show value or adjust scope — avoid jumping straight to discounts.', keywords: ['value', 'understand', 'roi', 'benefit']),
    PrepQuestion('sa4', 'role', 'What were your targets and how did you perform against them?', 'Give real numbers: target, achievement and how you got there.', keywords: ['target', '%', 'achieved', 'quarter']),
  ],
  'marketing': [
    PrepQuestion('mk1', 'role', 'Tell me about a campaign you ran and its results.', 'Goal, audience, channels, budget and results (reach, leads, CAC) with real figures.', keywords: ['campaign', 'audience', 'leads', 'roi']),
    PrepQuestion('mk2', 'role', 'How do you measure whether marketing is working?', 'Talk about clear goals, the right metrics for each channel and tools like Google Analytics.', keywords: ['metrics', 'analytics', 'conversion', 'kpi']),
    PrepQuestion('mk3', 'role', 'How would you grow our social media presence?', 'Audit current state, define audience, content plan, consistency and measuring engagement.', keywords: ['content', 'audience', 'engagement', 'plan']),
  ],
  'hr': [
    PrepQuestion('hrr1', 'role', 'Walk me through your recruitment process for a role.', 'Requirement understanding, sourcing, screening, interviews, offer and joining follow-up.', keywords: ['sourcing', 'screening', 'offer', 'joining']),
    PrepQuestion('hrr2', 'role', 'How do you handle an employee grievance?', 'Listen, document, investigate fairly, follow policy, communicate the outcome.', keywords: ['listen', 'policy', 'confidential', 'resolve']),
    PrepQuestion('hrr3', 'role', 'What do you know about PF, ESI and other statutory compliance?', 'Explain the basics you handled: contributions, due dates, registers and filings.', keywords: ['pf', 'esi', 'compliance', 'payroll']),
  ],
  'customer': [
    PrepQuestion('cs1', 'role', 'How do you calm down an angry customer?', 'Listen without interrupting, apologise for the experience, own the next step and follow up.', keywords: ['listen', 'apologise', 'apologize', 'solution', 'follow']),
    PrepQuestion('cs2', 'role', 'How do you balance call quality with handling time (AHT)?', 'Show you resolve on the first contact while using scripts/knowledge base to stay efficient.', keywords: ['aht', 'quality', 'first call', 'resolution']),
    PrepQuestion('cs3', 'role', 'Are you comfortable with rotational shifts and night shifts?', 'Answer honestly and mention how you manage routine and health if yes.', keywords: ['shift', 'comfortable', 'night']),
  ],
  'design': [
    PrepQuestion('de1', 'role', 'Walk me through your design process using one portfolio project.', 'Problem, research, ideas, iterations, testing and the final outcome.', keywords: ['research', 'user', 'iteration', 'prototype']),
    PrepQuestion('de2', 'role', 'How do you handle feedback you disagree with?', 'Ask for the reason, explain your thinking with evidence, and agree on what to test.', keywords: ['feedback', 'reason', 'test', 'user']),
  ],
  'health': [
    PrepQuestion('he1', 'role', 'How do you handle an emergency situation on duty?', 'Explain staying calm, following protocol, prioritising and communicating with the team.', keywords: ['protocol', 'priority', 'team', 'calm']),
    PrepQuestion('he2', 'role', 'How do you make sure patients are safe and comfortable?', 'Hygiene, correct medication checks, clear communication and documentation.', keywords: ['hygiene', 'medication', 'patient', 'record']),
  ],
  'education': [
    PrepQuestion('ed1', 'role', 'How do you handle students who learn at different speeds?', 'Differentiated tasks, small groups, extra practice and regular checks of understanding.', keywords: ['students', 'different', 'practice', 'assessment']),
    PrepQuestion('ed2', 'role', 'How do you keep a class engaged?', 'Activities, real-life examples, questions and technology — give one example lesson.', keywords: ['activity', 'example', 'engage', 'lesson']),
  ],
  'engineering': [
    PrepQuestion('en1', 'role', 'Explain a technical problem you solved on site or in the plant.', 'STAR with the root cause, your fix, safety steps and the measurable result.', keywords: ['root cause', 'safety', 'fixed', 'downtime']),
    PrepQuestion('en2', 'role', 'Which software and standards do you work with?', 'Name tools (AutoCAD, SolidWorks, STAAD) and codes/standards you follow, with examples.', keywords: ['autocad', 'solidworks', 'standard', 'code']),
  ],
  'operations': [
    PrepQuestion('op1', 'role', 'How do you reduce delays in deliveries or operations?', 'Find the bottleneck with data, fix the process, track KPIs like TAT and on-time %.', keywords: ['tat', 'kpi', 'process', 'on-time']),
    PrepQuestion('op2', 'role', 'How do you manage inventory accuracy?', 'Cycle counts, FIFO, system updates, root cause of mismatches.', keywords: ['inventory', 'cycle count', 'fifo', 'stock']),
  ],
  'trades': [
    PrepQuestion('tr1', 'role', 'What safety steps do you follow before starting work?', 'PPE, checking tools, isolation/lock-out, and following site rules.', keywords: ['ppe', 'safety', 'check', 'isolation']),
    PrepQuestion('tr2', 'role', 'Tell me about a fault you found and repaired.', 'How you diagnosed it, the repair and how you tested it afterwards.', keywords: ['fault', 'tested', 'repaired', 'diagnose']),
  ],
  'hospitality': [
    PrepQuestion('ho1', 'role', 'How do you make a guest’s stay memorable?', 'Personal touches, anticipating needs and quick problem-solving — share an example.', keywords: ['guest', 'service', 'example']),
    PrepQuestion('ho2', 'role', 'How do you handle a complaint about a booking or room?', 'Listen, apologise, offer options, act fast and follow up.', keywords: ['complaint', 'apologise', 'options', 'follow']),
  ],
  'legal': [
    PrepQuestion('le1', 'role', 'Walk me through how you draft and review a contract.', 'Understanding the deal, key clauses, risks, negotiation points and approvals.', keywords: ['clause', 'risk', 'draft', 'review']),
    PrepQuestion('le2', 'role', 'How do you keep up with legal and regulatory changes?', 'Sources you follow, how you update teams and policies.', keywords: ['update', 'regulation', 'policy']),
  ],
  'product': [
    PrepQuestion('pm1', 'role', 'How do you decide what to build next?', 'User problems, data, business goals, effort vs impact, and saying no clearly.', keywords: ['user', 'data', 'impact', 'priority']),
    PrepQuestion('pm2', 'role', 'Tell me about a project that went off track and how you recovered it.', 'Early signals, re-planning, stakeholder communication and the final outcome.', keywords: ['risk', 'stakeholder', 'plan', 'delivered']),
  ],
  'government': [
    PrepQuestion('go1', 'role', 'Why do you want a government/PSU job?', 'Public service, stability and the specific role — avoid saying only “job security”.', keywords: ['public', 'service', 'responsibility']),
    PrepQuestion('go2', 'role', 'What do you know about this department or organisation?', 'Its role, recent schemes or projects, and how your skills fit.', keywords: ['scheme', 'department', 'role']),
  ],
};

const prepTips = <(String, String)>[
  ('Research the company', 'Read their website, recent news and the job description twice. Note 3 points to mention.'),
  ('Prepare 3 STAR stories', 'A problem you solved, a result you are proud of and a mistake you learned from — with your real numbers.'),
  ('Know your numbers', 'Current CTC, expected range, notice period and earliest joining date.'),
  ('Documents', 'Carry 2 printed CV copies, ID proof, certificates and a pen. For online interviews, test camera and internet.'),
  ('Dress and arrive early', 'Formal or smart-casual, 15 minutes early (or join the call 5 minutes early).'),
  ('Questions to ask', 'What does success look like in 90 days? Who will I work with? What are the next steps?'),
  ('After the interview', 'Send a short thank-you email the same day. Add a follow-up date in your tracker.'),
];
