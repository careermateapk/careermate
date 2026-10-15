/// Job categories and sub-categories used to place a CV and to file jobs.
///
/// Each sub-category lists skill keywords and job-title keywords (lowercase).
/// Matching is whole-word, so "java" does not match "javascript".
/// Add or edit entries here; nothing else needs to change.
class SubCategory {
  const SubCategory(this.id, this.name, {this.skills = const [], this.titles = const []});
  final String id;
  final String name;
  final List<String> skills;
  final List<String> titles;
}

class JobCategory {
  const JobCategory(this.id, this.name, this.subs);
  final String id;
  final String name;
  final List<SubCategory> subs;
}

const jobCategories = <JobCategory>[
  JobCategory('it', 'IT & Software', [
    SubCategory('it_mobile', 'Mobile App Development',
        skills: ['flutter', 'dart', 'kotlin', 'swift', 'android', 'ios', 'react native', 'jetpack compose', 'swiftui', 'xcode', 'android studio'],
        titles: ['mobile developer', 'android developer', 'ios developer', 'flutter developer', 'app developer', 'mobile engineer']),
    SubCategory('it_frontend', 'Frontend Web',
        skills: ['html', 'css', 'javascript', 'typescript', 'react', 'angular', 'vue', 'next.js', 'tailwind', 'redux', 'sass', 'webpack'],
        titles: ['frontend developer', 'front end developer', 'ui developer', 'web developer', 'react developer']),
    SubCategory('it_backend', 'Backend Development',
        skills: ['java', 'spring boot', 'node.js', 'express', 'python', 'django', 'flask', 'fastapi', 'php', 'laravel', 'golang', 'c#', '.net', 'rest api', 'graphql', 'microservices', 'ruby'],
        titles: ['backend developer', 'back end developer', 'software engineer', 'software developer', 'java developer', 'python developer', 'php developer', 'full stack developer']),
    SubCategory('it_data', 'Data Science & Analytics',
        skills: ['sql', 'excel', 'power bi', 'tableau', 'pandas', 'numpy', 'machine learning', 'deep learning', 'statistics', 'r programming', 'tensorflow', 'pytorch', 'scikit-learn', 'data analysis', 'data visualization'],
        titles: ['data analyst', 'data scientist', 'business analyst', 'ml engineer', 'machine learning engineer', 'analytics']),
    SubCategory('it_devops', 'DevOps & Cloud',
        skills: ['aws', 'azure', 'gcp', 'google cloud', 'docker', 'kubernetes', 'terraform', 'jenkins', 'ci/cd', 'linux', 'ansible', 'github actions'],
        titles: ['devops engineer', 'cloud engineer', 'site reliability', 'sre', 'system administrator', 'sysadmin']),
    SubCategory('it_qa', 'QA & Testing',
        skills: ['selenium', 'manual testing', 'automation testing', 'test cases', 'jira', 'postman', 'appium', 'cypress', 'junit', 'testng'],
        titles: ['qa engineer', 'test engineer', 'tester', 'quality analyst', 'sdet']),
    SubCategory('it_security', 'Cyber Security',
        skills: ['network security', 'penetration testing', 'siem', 'firewall', 'ethical hacking', 'iso 27001', 'vapt'],
        titles: ['security analyst', 'security engineer', 'soc analyst']),
    SubCategory('it_support', 'IT Support & Networking',
        skills: ['troubleshooting', 'active directory', 'networking', 'ccna', 'windows server', 'hardware', 'lan', 'helpdesk'],
        titles: ['it support', 'desktop support', 'network engineer', 'technical support', 'system engineer']),
  ]),
  JobCategory('design', 'Design & Creative', [
    SubCategory('design_uiux', 'UI/UX Design',
        skills: ['figma', 'adobe xd', 'sketch', 'wireframing', 'prototyping', 'user research', 'design systems'],
        titles: ['ui designer', 'ux designer', 'product designer', 'ui/ux designer']),
    SubCategory('design_graphic', 'Graphic Design',
        skills: ['photoshop', 'illustrator', 'coreldraw', 'indesign', 'canva', 'branding', 'typography'],
        titles: ['graphic designer', 'visual designer']),
    SubCategory('design_video', 'Video & Animation',
        skills: ['premiere pro', 'after effects', 'final cut', 'video editing', 'motion graphics', 'davinci resolve', 'blender'],
        titles: ['video editor', 'animator', 'motion designer']),
  ]),
  JobCategory('finance', 'Banking, Finance & Accounts', [
    SubCategory('fin_accounts', 'Accounting',
        skills: ['tally', 'gst', 'tds', 'accounts payable', 'accounts receivable', 'bookkeeping', 'reconciliation', 'busy accounting', 'zoho books', 'quickbooks'],
        titles: ['accountant', 'accounts executive', 'accounts assistant', 'accounts manager']),
    SubCategory('fin_ca', 'Audit & Taxation',
        skills: ['audit', 'income tax', 'statutory audit', 'internal audit', 'itr', 'tax planning', 'ifrs', 'ind as'],
        titles: ['chartered accountant', 'auditor', 'tax consultant', 'article assistant']),
    SubCategory('fin_banking', 'Banking',
        skills: ['kyc', 'loans', 'credit appraisal', 'casa', 'branch banking', 'aml', 'retail banking'],
        titles: ['bank officer', 'relationship manager', 'credit officer', 'loan officer', 'cashier', 'probationary officer']),
    SubCategory('fin_analysis', 'Financial Analysis',
        skills: ['financial modelling', 'financial modeling', 'valuation', 'budgeting', 'forecasting', 'mis', 'variance analysis'],
        titles: ['financial analyst', 'finance executive', 'finance manager']),
    SubCategory('fin_insurance', 'Insurance',
        skills: ['insurance', 'claims', 'underwriting', 'policy servicing'],
        titles: ['insurance advisor', 'underwriter', 'claims executive']),
  ]),
  JobCategory('sales', 'Sales & Business Development', [
    SubCategory('sales_field', 'Field Sales',
        skills: ['field sales', 'lead generation', 'cold calling', 'target achievement', 'channel sales', 'dealer network'],
        titles: ['sales executive', 'sales officer', 'area sales manager', 'territory manager', 'field sales']),
    SubCategory('sales_inside', 'Inside Sales & Telesales',
        skills: ['inside sales', 'telesales', 'telecalling', 'crm', 'salesforce', 'hubspot'],
        titles: ['inside sales', 'telecaller', 'tele sales']),
    SubCategory('sales_bd', 'Business Development',
        skills: ['business development', 'b2b sales', 'client acquisition', 'negotiation', 'key accounts', 'partnerships'],
        titles: ['business development', 'bde', 'bdm', 'key account manager']),
    SubCategory('sales_retail', 'Retail Sales',
        skills: ['retail', 'store operations', 'visual merchandising', 'pos billing', 'customer handling'],
        titles: ['store manager', 'retail associate', 'sales associate', 'showroom']),
  ]),
  JobCategory('marketing', 'Marketing & Communication', [
    SubCategory('mkt_digital', 'Digital Marketing',
        skills: ['seo', 'sem', 'google ads', 'facebook ads', 'meta ads', 'social media marketing', 'google analytics', 'email marketing', 'performance marketing'],
        titles: ['digital marketing', 'seo executive', 'performance marketer', 'social media manager']),
    SubCategory('mkt_content', 'Content Writing',
        skills: ['content writing', 'copywriting', 'blogging', 'proofreading', 'technical writing'],
        titles: ['content writer', 'copywriter', 'editor', 'technical writer']),
    SubCategory('mkt_brand', 'Brand & Product Marketing',
        skills: ['brand management', 'market research', 'campaign management', 'product marketing', 'public relations'],
        titles: ['brand manager', 'marketing manager', 'marketing executive', 'pr executive']),
  ]),
  JobCategory('hr', 'HR & Admin', [
    SubCategory('hr_recruit', 'Recruitment',
        skills: ['recruitment', 'sourcing', 'screening', 'naukri', 'talent acquisition', 'onboarding'],
        titles: ['recruiter', 'talent acquisition', 'hr recruiter']),
    SubCategory('hr_generalist', 'HR Operations & Payroll',
        skills: ['payroll', 'pf', 'esic', 'hrms', 'employee engagement', 'compliance', 'labour law'],
        titles: ['hr executive', 'hr generalist', 'hr manager', 'payroll executive']),
    SubCategory('hr_admin', 'Admin & Office Support',
        skills: ['ms office', 'data entry', 'documentation', 'front desk', 'office administration', 'typing'],
        titles: ['admin executive', 'office assistant', 'receptionist', 'data entry operator', 'back office']),
  ]),
  JobCategory('customer', 'Customer Support & BPO', [
    SubCategory('cs_voice', 'Voice Process',
        skills: ['voice process', 'inbound calls', 'outbound calls', 'call handling', 'english communication'],
        titles: ['customer care', 'call centre', 'call center', 'customer support executive', 'csr']),
    SubCategory('cs_nonvoice', 'Non-voice & Chat Support',
        skills: ['chat support', 'email support', 'non voice', 'ticketing', 'zendesk', 'freshdesk'],
        titles: ['chat support', 'email support', 'process associate']),
  ]),
  JobCategory('health', 'Healthcare & Medical', [
    SubCategory('health_nursing', 'Nursing',
        skills: ['patient care', 'icu', 'nursing', 'vital signs', 'medication administration', 'gnm', 'anm', 'b.sc nursing'],
        titles: ['staff nurse', 'nurse', 'nursing officer', 'ward sister']),
    SubCategory('health_doctor', 'Doctors',
        skills: ['mbbs', 'm.d.', 'clinical', 'diagnosis', 'opd'],
        titles: ['medical officer', 'doctor', 'physician', 'resident doctor']),
    SubCategory('health_pharma', 'Pharmacy',
        skills: ['b.pharm', 'd.pharm', 'm.pharm', 'dispensing', 'pharmacovigilance', 'gmp', 'quality control'],
        titles: ['pharmacist', 'medical representative', 'drug safety']),
    SubCategory('health_lab', 'Lab & Allied Health',
        skills: ['dmlt', 'bmlt', 'phlebotomy', 'radiology', 'physiotherapy', 'x-ray', 'pathology'],
        titles: ['lab technician', 'physiotherapist', 'radiographer', 'phlebotomist']),
  ]),
  JobCategory('education', 'Education & Teaching', [
    SubCategory('edu_school', 'School Teaching',
        skills: ['b.ed', 'ctet', 'tet', 'lesson planning', 'classroom management', 'cbse', 'icse'],
        titles: ['teacher', 'pgt', 'tgt', 'prt', 'primary teacher']),
    SubCategory('edu_college', 'College & Coaching',
        skills: ['ugc net', 'phd', 'lecturing', 'jee', 'neet coaching'],
        titles: ['lecturer', 'assistant professor', 'professor', 'faculty', 'tutor']),
    SubCategory('edu_online', 'Online Tutoring & Edtech',
        skills: ['online teaching', 'curriculum design', 'instructional design', 'lms'],
        titles: ['online tutor', 'academic counsellor', 'instructional designer', 'subject matter expert']),
  ]),
  JobCategory('engineering', 'Engineering (Core)', [
    SubCategory('eng_mech', 'Mechanical',
        skills: ['autocad', 'solidworks', 'catia', 'creo', 'ansys', 'hvac', 'production planning', 'preventive maintenance', 'cnc'],
        titles: ['mechanical engineer', 'production engineer', 'maintenance engineer', 'design engineer']),
    SubCategory('eng_civil', 'Civil & Construction',
        skills: ['autocad', 'staad pro', 'revit', 'site supervision', 'estimation', 'quantity surveying', 'primavera'],
        titles: ['civil engineer', 'site engineer', 'site supervisor', 'quantity surveyor', 'project engineer']),
    SubCategory('eng_electrical', 'Electrical & Electronics',
        skills: ['plc', 'scada', 'electrical design', 'embedded', 'pcb', 'microcontroller', 'vlsi', 'matlab'],
        titles: ['electrical engineer', 'electronics engineer', 'embedded engineer', 'instrumentation engineer']),
    SubCategory('eng_quality', 'Quality & Production',
        skills: ['six sigma', 'iso 9001', 'kaizen', '5s', 'lean manufacturing', 'quality assurance'],
        titles: ['quality engineer', 'qc inspector', 'production supervisor']),
  ]),
  JobCategory('operations', 'Operations, Logistics & Supply Chain', [
    SubCategory('ops_supply', 'Supply Chain & Procurement',
        skills: ['procurement', 'vendor management', 'sap mm', 'inventory', 'purchase', 'sourcing'],
        titles: ['purchase executive', 'procurement', 'supply chain', 'buyer']),
    SubCategory('ops_logistics', 'Logistics & Warehouse',
        skills: ['warehouse', 'logistics', 'dispatch', 'wms', 'fleet', 'last mile', 'shipping'],
        titles: ['warehouse executive', 'logistics executive', 'store keeper', 'dispatch']),
    SubCategory('ops_delivery', 'Delivery & Driving',
        skills: ['driving licence', 'driving license', 'two wheeler', 'route planning'],
        titles: ['delivery executive', 'delivery boy', 'driver', 'rider']),
  ]),
  JobCategory('trades', 'Skilled Trades & Technicians', [
    SubCategory('trade_electrician', 'Electrician',
        skills: ['wiring', 'iti electrician', 'electrical maintenance', 'panel wiring'],
        titles: ['electrician', 'wireman']),
    SubCategory('trade_mechanic', 'Mechanic & Fitter',
        skills: ['iti fitter', 'fitter', 'welding', 'machining', 'lathe', 'turner'],
        titles: ['fitter', 'welder', 'mechanic', 'machinist', 'technician']),
    SubCategory('trade_ac', 'AC & Appliance Repair',
        skills: ['ac repair', 'refrigeration', 'appliance repair'],
        titles: ['ac technician', 'service technician']),
  ]),
  JobCategory('hospitality', 'Hospitality & Travel', [
    SubCategory('hosp_hotel', 'Hotel & Restaurant',
        skills: ['food and beverage', 'f&b', 'housekeeping', 'front office', 'hotel management', 'guest relations'],
        titles: ['steward', 'chef', 'cook', 'front office executive', 'housekeeping', 'hotel']),
    SubCategory('hosp_travel', 'Travel & Aviation',
        skills: ['ticketing', 'amadeus', 'galileo', 'tour planning', 'cabin crew', 'ground staff'],
        titles: ['travel consultant', 'cabin crew', 'ground staff', 'tour manager']),
  ]),
  JobCategory('legal', 'Legal', [
    SubCategory('legal_law', 'Lawyer & Legal Advisor',
        skills: ['llb', 'llm', 'litigation', 'contract drafting', 'legal research', 'corporate law'],
        titles: ['advocate', 'lawyer', 'legal advisor', 'legal executive', 'company secretary']),
  ]),
  JobCategory('product', 'Product & Project Management', [
    SubCategory('pm_product', 'Product Management',
        skills: ['product management', 'roadmap', 'user stories', 'product strategy', 'a/b testing'],
        titles: ['product manager', 'product owner', 'associate product manager']),
    SubCategory('pm_project', 'Project Management',
        skills: ['pmp', 'agile', 'scrum', 'project planning', 'stakeholder management', 'ms project', 'prince2'],
        titles: ['project manager', 'project coordinator', 'scrum master', 'program manager']),
  ]),
  JobCategory('government', 'Government & PSU', [
    SubCategory('gov_exams', 'Govt Exam Aspirant',
        skills: ['ssc', 'upsc', 'ibps', 'rrb', 'bpsc', 'state psc', 'gate'],
        titles: []),
  ]),
];

/// Looks up a sub-category by id.
SubCategory? subCategoryById(String id) {
  for (final c in jobCategories) {
    for (final s in c.subs) {
      if (s.id == id) return s;
    }
  }
  return null;
}

JobCategory? categoryById(String id) {
  for (final c in jobCategories) {
    if (c.id == id) return c;
  }
  return null;
}

JobCategory? categoryOfSub(String subId) {
  for (final c in jobCategories) {
    if (c.subs.any((s) => s.id == subId)) return c;
  }
  return null;
}
