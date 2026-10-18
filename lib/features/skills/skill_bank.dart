/// Skill tests. Each has more questions than are asked, so every attempt is a little different.
class SkillQuestion {
  const SkillQuestion(this.q, this.options, this.answer);
  final String q;
  final List<String> options;

  /// Index of the correct option.
  final int answer;
}

class SkillTest {
  const SkillTest(this.id, this.name, this.emoji, this.keywords, this.questions);
  final String id;
  final String name;
  final String emoji;

  /// CV skills that make this test relevant.
  final List<String> keywords;
  final List<SkillQuestion> questions;
}

const passMark = 7;
const questionsPerTest = 10;
const secondsPerQuestion = 45;

const skillTests = <SkillTest>[
  SkillTest('tally', 'Tally Prime', '🧾', ['tally', 'tally prime', 'tally erp'], [
    SkillQuestion('Which key opens a Payment voucher in Tally Prime?', ['F4', 'F5', 'F6', 'F8'], 1),
    SkillQuestion('Which key opens a Receipt voucher?', ['F5', 'F7', 'F6', 'F9'], 2),
    SkillQuestion('Which key opens a Sales voucher?', ['F8', 'F9', 'F4', 'F2'], 0),
    SkillQuestion('Which key opens a Purchase voucher?', ['F7', 'F8', 'F6', 'F9'], 3),
    SkillQuestion('Which key opens a Journal voucher?', ['F7', 'F5', 'F10', 'F3'], 0),
    SkillQuestion('A Contra voucher (F4) is used for…', ['Sales returns', 'Moving money between cash and bank accounts', 'Salary payment', 'Purchase of assets on credit'], 1),
    SkillQuestion('Which shortcut accepts (saves) a voucher?', ['Ctrl + A', 'Ctrl + S', 'Alt + A', 'Ctrl + Q'], 0),
    SkillQuestion('Which key changes the date while entering a voucher?', ['F1', 'F2', 'F11', 'F12'], 1),
    SkillQuestion('“Sundry Debtors” comes under which group?', ['Current Liabilities', 'Current Assets', 'Indirect Incomes', 'Capital Account'], 1),
    SkillQuestion('Bank charges are usually posted under…', ['Direct Expenses', 'Indirect Expenses', 'Current Assets', 'Duties & Taxes'], 1),
    SkillQuestion('A Credit Note is mainly used for…', ['Purchase returns', 'Sales returns', 'Cash withdrawal', 'Opening balance'], 1),
    SkillQuestion('A Debit Note is mainly used for…', ['Purchase returns', 'Sales returns', 'Bank deposit', 'Salary'], 0),
  ]),
  SkillTest('gst', 'GST', '🧮', ['gst', 'gstr', 'goods and services tax'], [
    SkillQuestion('GSTR-1 contains details of…', ['Inward supplies (purchases)', 'Outward supplies (sales)', 'Annual turnover only', 'TDS deducted'], 1),
    SkillQuestion('GSTR-3B is…', ['A summary return with tax payment', 'An annual audit report', 'A TDS certificate', 'An e-way bill'], 0),
    SkillQuestion('A sale within the same state attracts…', ['IGST', 'CGST + SGST', 'Only CGST', 'Customs duty'], 1),
    SkillQuestion('A sale from one state to another attracts…', ['IGST', 'CGST + SGST', 'Only SGST', 'No GST'], 0),
    SkillQuestion('GSTR-2B is…', ['A return filed by the buyer for sales', 'An auto-drafted statement of input tax credit', 'An e-invoice', 'The annual return'], 1),
    SkillQuestion('How many characters does a GSTIN have?', ['10', '12', '15', '16'], 2),
    SkillQuestion('The annual return for regular taxpayers is…', ['GSTR-9', 'GSTR-4', 'GSTR-7', 'GSTR-1'], 0),
    SkillQuestion('ITC stands for…', ['Income Tax Credit', 'Input Tax Credit', 'Interstate Tax Charge', 'Invoice Tax Code'], 1),
    SkillQuestion('HSN codes are used to classify…', ['Services', 'Goods', 'Employees', 'Bank accounts'], 1),
    SkillQuestion('SAC codes are used to classify…', ['Services', 'Goods', 'Imports only', 'Companies'], 0),
    SkillQuestion('Under reverse charge, who pays the GST?', ['The supplier', 'The recipient (buyer)', 'The bank', 'Nobody'], 1),
    SkillQuestion('Composition taxpayers pay tax quarterly using…', ['CMP-08', 'GSTR-3B', 'GSTR-8', 'ITC-04'], 0),
  ]),
  SkillTest('tds', 'TDS', '📑', ['tds', 'tax deducted at source'], [
    SkillQuestion('TDS on salary is deducted under section…', ['192', '194C', '194J', '194I'], 0),
    SkillQuestion('TDS on contractor payments falls under…', ['194J', '194C', '194H', '192'], 1),
    SkillQuestion('TDS on professional or technical fees falls under…', ['194C', '194I', '194J', '194A'], 2),
    SkillQuestion('TDS on rent falls under…', ['194I', '194C', '194Q', '192'], 0),
    SkillQuestion('Quarterly TDS return for salary is…', ['26Q', '24Q', '27Q', '16A'], 1),
    SkillQuestion('Quarterly TDS return for non-salary payments to residents is…', ['24Q', '26Q', '27EQ', 'Form 16'], 1),
    SkillQuestion('The TDS certificate for salary is…', ['Form 16', 'Form 16A', 'Form 26AS', 'Form 15G'], 0),
    SkillQuestion('TAN stands for…', ['Tax Account Number', 'Tax Deduction and Collection Account Number', 'Total Assessment Number', 'Taxpayer Assigned Number'], 1),
    SkillQuestion('TDS deducted in a month (other than March) is usually deposited by…', ['7th of next month', '15th of next month', '30th of next month', 'End of the quarter'], 0),
    SkillQuestion('Which statement shows TDS credited against a PAN?', ['Form 26AS', 'Form 16A only', 'GSTR-2B', 'Form 3CD'], 0),
  ]),
  SkillTest('excel', 'MS Excel', '📊', ['excel', 'ms excel', 'advanced excel', 'vlookup', 'pivot'], [
    SkillQuestion('Which function adds a range of numbers?', ['COUNT', 'SUM', 'ADD', 'TOTAL'], 1),
    SkillQuestion('In VLOOKUP, the last argument FALSE means…', ['Approximate match', 'Exact match', 'Search from bottom', 'Ignore blanks'], 1),
    SkillQuestion('Which is an absolute cell reference?', ['A1', '\$A1', 'A\$1', '\$A\$1'], 3),
    SkillQuestion('Which function counts non-empty cells?', ['COUNT', 'COUNTA', 'COUNTBLANK', 'SUM'], 1),
    SkillQuestion('Shortcut to turn on filters?', ['Ctrl + Shift + L', 'Ctrl + F', 'Alt + F', 'Ctrl + T + F'], 0),
    SkillQuestion('A Pivot Table is mainly used to…', ['Draw pictures', 'Summarise large data', 'Protect a sheet', 'Write macros only'], 1),
    SkillQuestion('If A1 is 50, =IF(A1>50,"Pass","Fail") shows…', ['Pass', 'Fail', '50', 'Error'], 1),
    SkillQuestion('SUMIF adds values that…', ['Are in bold', 'Meet one condition', 'Are text', 'Are hidden'], 1),
    SkillQuestion('=ROUND(2.567, 1) gives…', ['2.5', '2.6', '2.57', '3'], 1),
    SkillQuestion('To keep the top row visible while scrolling, use…', ['Freeze Panes', 'Wrap Text', 'Merge Cells', 'Group'], 0),
    SkillQuestion('Which joins text from A1 and B1?', ['=A1+B1', '=A1&B1', '=JOIN(A1:B1)', '=A1*B1'], 1),
    SkillQuestion('To delete repeated rows quickly, use…', ['Data → Remove Duplicates', 'Home → Clear', 'View → Zoom', 'Insert → Table'], 0),
  ]),
  SkillTest('accounts', 'Accounting basics', '📒', ['accounting', 'bookkeeping', 'accounts payable', 'accounts receivable', 'reconciliation', 'ledger'], [
    SkillQuestion('Golden rule for a Real account:', ['Debit the receiver, credit the giver', 'Debit what comes in, credit what goes out', 'Debit expenses, credit incomes', 'Credit everything'], 1),
    SkillQuestion('Golden rule for a Personal account:', ['Debit the receiver, credit the giver', 'Debit what comes in, credit what goes out', 'Debit incomes, credit expenses', 'Debit the giver'], 0),
    SkillQuestion('Golden rule for a Nominal account:', ['Debit all expenses and losses, credit all incomes and gains', 'Debit what goes out', 'Debit the giver', 'Credit all expenses'], 0),
    SkillQuestion('The accounting equation is…', ['Assets = Liabilities + Capital', 'Assets = Income − Expenses', 'Capital = Assets + Liabilities', 'Liabilities = Assets + Capital'], 0),
    SkillQuestion('Depreciation means…', ['Increase in asset value', 'Fall in value of a fixed asset over time', 'A type of income', 'Cash discount'], 1),
    SkillQuestion('A trial balance is prepared to…', ['Check the arithmetical accuracy of ledgers', 'Calculate tax', 'Pay salaries', 'Value stock'], 0),
    SkillQuestion('Prepaid expense is a…', ['Current liability', 'Current asset', 'Income', 'Capital'], 1),
    SkillQuestion('Outstanding salary is a…', ['Current asset', 'Current liability', 'Fixed asset', 'Income'], 1),
    SkillQuestion('A bank reconciliation statement matches…', ['Sales with purchases', 'Cash book bank balance with the bank statement', 'Assets with liabilities', 'Debtors with creditors'], 1),
    SkillQuestion('Under the accrual basis, income is recorded when it is…', ['Received in cash', 'Earned', 'Deposited in bank', 'Approved by audit'], 1),
    SkillQuestion('Goodwill is a…', ['Current asset', 'Intangible asset', 'Liability', 'Expense'], 1),
    SkillQuestion('Drawings by the owner reduce…', ['Capital', 'Assets only', 'Expenses', 'Sales'], 0),
  ]),
  SkillTest('sql', 'SQL', '🗄️', ['sql', 'mysql', 'postgresql', 'database'], [
    SkillQuestion('Which keyword reads data from a table?', ['GET', 'SELECT', 'READ', 'FETCH ROWS'], 1),
    SkillQuestion('Which clause filters rows?', ['ORDER BY', 'WHERE', 'GROUP BY', 'FROM'], 1),
    SkillQuestion('Which keyword removes duplicate rows from a result?', ['UNIQUE ROWS', 'DISTINCT', 'ONLY', 'SINGLE'], 1),
    SkillQuestion('Which clause sorts the result?', ['SORT BY', 'ORDER BY', 'GROUP BY', 'ARRANGE'], 1),
    SkillQuestion('Which clause filters groups after GROUP BY?', ['WHERE', 'HAVING', 'LIMIT', 'ON'], 1),
    SkillQuestion('An INNER JOIN returns…', ['All rows from both tables', 'Only rows that match in both tables', 'Only the left table', 'No rows'], 1),
    SkillQuestion('A LEFT JOIN returns…', ['Only matching rows', 'All rows from the left table plus matches from the right', 'All rows from the right table', 'Duplicates only'], 1),
    SkillQuestion('A primary key…', ['Can repeat', 'Uniquely identifies each row', 'Must be text', 'Is optional for every table and never used'], 1),
    SkillQuestion("WHERE name LIKE 'A%' finds names that…", ['End with A', 'Start with A', 'Contain only A', 'Have length A'], 1),
    SkillQuestion('How do you check for empty (NULL) values?', ['= NULL', 'IS NULL', '== NULL', 'EMPTY()'], 1),
    SkillQuestion('Which removes all rows but keeps the table?', ['DROP TABLE', 'TRUNCATE TABLE', 'DELETE TABLE', 'REMOVE'], 1),
    SkillQuestion('COUNT(*) counts…', ['Only non-null values in one column', 'All rows', 'Distinct values', 'Columns'], 1),
  ]),
  SkillTest('english', 'Workplace English', '💬', [], [
    SkillQuestion('Choose the correct sentence:', ['I am working here since 2019.', 'I have been working here since 2019.', 'I working here since 2019.', 'I have work here since 2019.'], 1),
    SkillQuestion('Choose the correct sentence:', ['She don’t know the answer.', 'She doesn’t know the answer.', 'She not know the answer.', 'She doesn’t knows the answer.'], 1),
    SkillQuestion('Each of the candidates ___ a laptop.', ['have', 'has', 'are having', 'were'], 1),
    SkillQuestion('I look forward to ___ from you.', ['hear', 'hearing', 'heard', 'be hear'], 1),
    SkillQuestion('Which spelling is correct?', ['Recieve', 'Receive', 'Receeve', 'Riceive'], 1),
    SkillQuestion('He is very good ___ Excel.', ['in', 'at', 'on', 'for'], 1),
    SkillQuestion('Most polite way to ask for details:', ['Send details.', 'Could you please share the job details?', 'Give me details now.', 'Details?'], 1),
    SkillQuestion('Best email subject for a job application:', ['Hi', 'Job', 'Application for Accounts Executive – Rahul Verma', 'Urgent!!!'], 2),
    SkillQuestion('Which word means “on time”?', ['Punctual', 'Casual', 'Partial', 'Eventual'], 0),
    SkillQuestion('Choose the correct sentence:', ['Please find attached my CV.', 'Please found attach my CV.', 'Please finding attached my CV.', 'Please find attaching my CV.'], 0),
  ]),
];

SkillTest? skillTestById(String id) {
  for (final t in skillTests) {
    if (t.id == id) return t;
  }
  return null;
}
