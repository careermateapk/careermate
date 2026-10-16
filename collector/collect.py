#!/usr/bin/env python3
"""CareerMate job collector.

Reads public job feeds that companies publish for this purpose (Greenhouse,
Lever, Ashby, SmartRecruiters, Workable job boards) and the Adzuna job search
API, keeps jobs in India or open to India-based remote workers that were
published in the last 30 days, removes duplicates, files each job under the
app's job sub-categories, and writes them to Firestore.

Runs on GitHub Actions. Uses only the Python standard library.

Environment:
  ADZUNA_APP_ID, ADZUNA_APP_KEY   optional; Adzuna is skipped without them
  COLLECTOR_EMAIL, COLLECTOR_PASSWORD
                                  optional; without them it is a dry run
"""
import concurrent.futures as cf
import datetime as dt
import hashlib
import html
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(ROOT)
NOW = dt.datetime.now(dt.timezone.utc)
WINDOW_DAYS = 30
MAX_JOBS_PER_SUB = 150
UA = "CareerMateJobCollector/1.0 (+https://github.com/careermateapk)"

INDIA_PLACES = [
    "india", "delhi", "new delhi", "ncr", "mumbai", "bengaluru", "bangalore", "hyderabad", "chennai", "kolkata",
    "pune", "ahmedabad", "jaipur", "lucknow", "noida", "gurgaon", "gurugram", "ghaziabad", "faridabad", "chandigarh",
    "mohali", "kochi", "cochin", "thiruvananthapuram", "trivandrum", "coimbatore", "indore", "bhopal", "nagpur",
    "surat", "vadodara", "patna", "ranchi", "bhubaneswar", "guwahati", "visakhapatnam", "vijayawada", "mysuru",
    "mysore", "mangaluru", "mangalore", "thane", "navi mumbai", "dehradun", "goa", "raipur", "kanpur", "varanasi",
]
REMOTE_OK = ["india", "apac", "asia", "anywhere", "worldwide", "global", "emea & apac"]
TITLE_FALLBACK = [
    (r"\b(nurse|nursing)\b", "health_nursing"),
    (r"\b(pharmac|drug safety|pharmacovigilance)", "health_pharma"),
    (r"\b(doctor|physician|medical officer)\b", "health_doctor"),
    (r"\b(teacher|faculty|lecturer|professor|tutor)\b", "edu_school"),
    (r"\b(product manager|product owner|product management)\b", "pm_product"),
    (r"\b(project manager|program manager|programme manager|scrum master|pmo|delivery manager)\b", "pm_project"),
    (r"\b(security|cyber|threat|soc\b|iam\b|identity)", "it_security"),
    (r"\b(test|tester|qa\b|quality assurance|sdet)", "it_qa"),
    (r"\b(devops|sre\b|site reliability|cloud|infrastructure|platform engineer|kubernetes|network engineer)", "it_devops"),
    (r"\b(data|analytics|analyst|machine learning|ml\b|ai\b|scientist|bi\b|insights)", "it_data"),
    (r"\b(android|ios|mobile)\b", "it_mobile"),
    (r"\b(frontend|front end|front-end|ui engineer|web developer)\b", "it_frontend"),
    (r"\b(mechanical|manufacturing|production|plant|maintenance)\b", "eng_mech"),
    (r"\b(electrical|electronics|embedded|hardware|vlsi|firmware|asic)\b", "eng_electrical"),
    (r"\b(civil|construction|site engineer|structural)\b", "eng_civil"),
    (r"\b(software|developer|programmer|sde\b|full ?stack|backend|back end|engineer)", "it_backend"),
    (r"\b(designer|ux\b|ui\b|design)\b", "design_uiux"),
    (r"\b(recruit|talent acquisition|sourcer)", "hr_recruit"),
    (r"\b(hr\b|human resources|people partner|payroll|hrbp)", "hr_generalist"),
    (r"\b(account(ant|ing)|accounts|bookkeep|reconciliation)", "fin_accounts"),
    (r"\b(audit|tax|taxation)\b", "fin_ca"),
    (r"\b(finance|financial|fp&a|treasury|credit)\b", "fin_analysis"),
    (r"\b(marketing|seo\b|growth|campaign|brand)\b", "mkt_digital"),
    (r"\b(content|writer|copywriter|editor)\b", "mkt_content"),
    (r"\b(business development|partnership|bdm\b|bde\b)", "sales_bd"),
    (r"\b(sales|account executive|account manager|customer success)\b", "sales_bd"),
    (r"\b(support|service desk|helpdesk|technical support)\b", "it_support"),
    (r"\b(customer|process associate|voice|chat)\b", "cs_nonvoice"),
    (r"\b(supply chain|procurement|purchase|sourcing|buyer)\b", "ops_supply"),
    (r"\b(logistics|warehouse|dispatch|fleet)\b", "ops_logistics"),
    (r"\b(quality|six sigma)\b", "eng_quality"),
    (r"\b(legal|counsel|lawyer|compliance|paralegal)\b", "legal_law"),
    (r"\b(admin|administrative|office assistant|receptionist|executive assistant)\b", "hr_admin"),
]
SCAM_WORDS = ["registration fee", "security deposit", "pay to apply", "processing fee", "refundable deposit",
              "training fee", "send money", "upi payment"]

# ---------------------------------------------------------------- utilities


def log(msg):
    print(msg, flush=True)


def notice(msg):
    print(f"::notice::{msg}", flush=True)


def get_json(url, timeout=25):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8", "replace"))


def post_json(url, body, headers=None, method="POST", timeout=30):
    data = json.dumps(body).encode()
    h = {"Content-Type": "application/json", "User-Agent": UA}
    h.update(headers or {})
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:300]}") from None


def strip_html(s):
    s = html.unescape(s or "")
    s = re.sub(r"<(br|/p|/li|/div|/h\d)[^>]*>", "\n", s, flags=re.I)
    s = re.sub(r"<[^>]+>", " ", s)
    s = html.unescape(s)
    s = re.sub(r"[ \t\r\f\v]+", " ", s)
    s = re.sub(r"\n\s*\n+", "\n", s)
    return s.strip()


def parse_date(v):
    """ISO string, epoch ms, or YYYY-MM-DD → aware UTC datetime (or None)."""
    if v in (None, ""):
        return None
    try:
        if isinstance(v, (int, float)):
            return dt.datetime.fromtimestamp(v / 1000 if v > 1e11 else v, dt.timezone.utc)
        s = str(v).strip().replace("Z", "+00:00")
        if re.fullmatch(r"\d{4}-\d{2}-\d{2}", s):
            return dt.datetime.fromisoformat(s).replace(tzinfo=dt.timezone.utc)
        d = dt.datetime.fromisoformat(s)
        return d if d.tzinfo else d.replace(tzinfo=dt.timezone.utc)
    except Exception:
        return None


def word_in(text, kw):
    return re.search(r"(?<![a-z0-9+#])" + re.escape(kw) + r"(?![a-z0-9+#])", text) is not None


def place_ok(location, remote):
    loc = (location or "").lower()
    if any(word_in(loc, p) for p in INDIA_PLACES):
        return "india"
    if remote or "remote" in loc:
        if any(w in loc for w in REMOTE_OK) or loc.strip() in ("", "remote"):
            return "remote"
    return None


def norm(s):
    return re.sub(r"[^a-z0-9]+", " ", (s or "").lower()).strip()


# ---------------------------------------------------------------- taxonomy (read from the app's Dart file)


def load_taxonomy():
    src = open(os.path.join(REPO, "lib", "features", "profile", "taxonomy.dart"), encoding="utf-8").read()
    subs = []
    for cat in re.finditer(r"JobCategory\('([^']+)',\s*'([^']+)',\s*\[(.*?)\n  \]\),", src, re.S):
        cat_id, body = cat.group(1), cat.group(3)
        for m in re.finditer(r"SubCategory\('([^']+)',\s*'([^']+)'(.*?)\)(?:,|\n)", body, re.S):
            rest = m.group(3)

            def lst(name):
                mm = re.search(name + r":\s*\[(.*?)\]", rest, re.S)
                return re.findall(r"'([^']*)'", mm.group(1)) if mm else []

            subs.append({"id": m.group(1), "name": m.group(2), "cat": cat_id,
                         "skills": lst("skills"), "titles": lst("titles")})
    if len(subs) < 20:
        raise SystemExit(f"::error::Could not read the taxonomy (found {len(subs)} sub-categories)")
    return subs


def classify(job, subs):
    title = job["title"].lower()
    body = (job["title"] + " \n " + job.get("description", "")).lower()
    scored, skills = [], set()
    for s in subs:
        t_hits = [t for t in s["titles"] if word_in(title, t)]
        k_hits = [k for k in s["skills"] if word_in(body, k)]
        skills.update(k_hits)
        score = 3 * len(t_hits) + len(k_hits)
        if t_hits or len(k_hits) >= 3:
            scored.append((score, s))
    if not scored:
        # Fallback: broad words in the job title (most big-company titles are generic).
        by_id = {s["id"]: s for s in subs}
        for pattern, sid in TITLE_FALLBACK:
            if sid in by_id and re.search(pattern, title):
                scored.append((1, by_id[sid]))
                break
    scored.sort(key=lambda x: -x[0])
    job["subIds"] = [s["id"] for _, s in scored[:3]]
    job["catId"] = scored[0][1]["cat"] if scored else None
    job["skills"] = sorted(skills)[:20]
    return job


# ---------------------------------------------------------------- sources


def make_job(source, source_name, official, company, title, location, url, posted, desc, remote=False,
             salary_min=None, salary_max=None, emp_type=None, date_kind="published"):
    where = place_ok(location, remote)
    if not where or not title or not url:
        return None
    d = parse_date(posted)
    if d and d < NOW - dt.timedelta(days=WINDOW_DAYS):
        return None
    text = strip_html(desc)
    low = text.lower()
    return {
        "id": hashlib.sha1(url.encode()).hexdigest()[:16],
        "title": title.strip()[:140],
        "company": (company or "").strip()[:80],
        "location": (location or ("Remote" if remote else "")).strip()[:120],
        "remote": bool(remote or "remote" in (location or "").lower()),
        "url": url,
        "source": source,
        "sourceName": source_name,
        "official": official,
        "postedAt": d.isoformat() if d else None,
        "dateKind": date_kind if d else "unknown",
        "salaryMin": salary_min,
        "salaryMax": salary_max,
        "employmentType": emp_type,
        "description": text[:4000],
        "snippet": text[:400],
        "scamFlags": [w for w in SCAM_WORDS
                      if re.search(r"(?<!no )(?<!without )(?<!zero )(?<!never )" + re.escape(w), low)],
    }


def greenhouse(token):
    data = get_json(f"https://boards-api.greenhouse.io/v1/boards/{token}/jobs?content=true")
    company = data.get("meta", {}).get("name") if isinstance(data.get("meta"), dict) else None
    out = []
    for j in data.get("jobs", []):
        published = j.get("first_published")
        out.append(make_job(
            "greenhouse", "Company careers page (Greenhouse)", True, company or j.get("company_name") or token.title(),
            j.get("title"), (j.get("location") or {}).get("name", ""), j.get("absolute_url"),
            published or j.get("updated_at"), j.get("content", ""),
            date_kind="published" if published else "updated"))
    return out


def lever(company):
    data = get_json(f"https://api.lever.co/v0/postings/{company}?mode=json")
    out = []
    for j in data if isinstance(data, list) else []:
        cats = j.get("categories") or {}
        locs = cats.get("allLocations") or [cats.get("location") or ""]
        out.append(make_job(
            "lever", "Company careers page (Lever)", True, company.replace("-", " ").title(), j.get("text"),
            ", ".join(l for l in locs if l), j.get("hostedUrl"), j.get("createdAt"),
            j.get("descriptionPlain") or j.get("description", ""),
            remote=(j.get("workplaceType") == "remote"), emp_type=cats.get("commitment")))
    return out


def ashby(board):
    data = get_json(f"https://api.ashbyhq.com/posting-api/job-board/{board}?includeCompensation=true")
    out = []
    for j in data.get("jobs", []):
        if j.get("isListed") is False:
            continue
        locs = [j.get("location") or ""] + [s.get("location", "") for s in j.get("secondaryLocations") or []]
        addr = ((j.get("address") or {}).get("postalAddress") or {}).get("addressCountry") or ""
        out.append(make_job(
            "ashby", "Company careers page (Ashby)", True, board.replace("-", " ").title(), j.get("title"),
            ", ".join(x for x in locs + [addr] if x), j.get("jobUrl"), j.get("publishedAt"),
            j.get("descriptionPlain") or j.get("descriptionHtml", ""), remote=bool(j.get("isRemote")),
            emp_type=j.get("employmentType")))
    return out


def smartrecruiters(company_id):
    items, offset = [], 0
    while offset < 600:
        data = get_json(f"https://api.smartrecruiters.com/v1/companies/{company_id}/postings?country=in&limit=100&offset={offset}")
        page = data.get("content", [])
        items.extend(page)
        if len(page) < 100:
            break
        offset += 100
    out = []
    for j in items:
        loc = j.get("location") or {}
        location = ", ".join(x for x in [loc.get("city"), loc.get("region"), "India" if loc.get("country") == "in" else loc.get("country")] if x)
        out.append(make_job(
            "smartrecruiters", "Company careers page (SmartRecruiters)", True,
            (j.get("company") or {}).get("name") or company_id, j.get("name"), location,
            f"https://jobs.smartrecruiters.com/{company_id}/{j.get('id')}", j.get("releasedDate"),
            " ".join(filter(None, [(j.get("function") or {}).get("label"), (j.get("industry") or {}).get("label"),
                                   (j.get("experienceLevel") or {}).get("label")])),
            remote=bool(loc.get("remote")), emp_type=(j.get("typeOfEmployment") or {}).get("label")))
    return out


def workable(account):
    data = get_json(f"https://apply.workable.com/api/v1/widget/accounts/{account}?details=true")
    company = data.get("name") or account.title()
    out = []
    for j in data.get("jobs", []):
        location = ", ".join(x for x in [j.get("city"), j.get("state"), j.get("country")] if x)
        out.append(make_job(
            "workable", "Company careers page (Workable)", True, company, j.get("title"), location,
            j.get("url") or j.get("shortlink"), j.get("published_on") or j.get("created_at"),
            j.get("description", ""), remote=bool(j.get("telecommuting")), emp_type=j.get("employment_type")))
    return out


def adzuna(query, app_id, app_key):
    q = urllib.parse.urlencode({
        "app_id": app_id, "app_key": app_key, "results_per_page": 50, "what": query,
        "max_days_old": WINDOW_DAYS, "sort_by": "date", "content-type": "application/json",
    })
    data = get_json(f"https://api.adzuna.com/v1/api/jobs/in/search/1?{q}")
    out = []
    for j in data.get("results", []):
        predicted = str(j.get("salary_is_predicted", "0")) == "1"
        out.append(make_job(
            "adzuna", "Adzuna", False, (j.get("company") or {}).get("display_name", ""), j.get("title"),
            ((j.get("location") or {}).get("display_name") or "") + ", India", j.get("redirect_url"), j.get("created"),
            j.get("description", ""),
            salary_min=None if predicted else j.get("salary_min"), salary_max=None if predicted else j.get("salary_max")))
    return out


# ---------------------------------------------------------------- Firestore (REST, signed in as the collector user)


def to_value(v):
    if v is None:
        return {"nullValue": None}
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, float):
        return {"doubleValue": v}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: to_value(x) for k, x in v.items()}}}
    if isinstance(v, (list, tuple)):
        return {"arrayValue": {"values": [to_value(x) for x in v]}}
    return {"stringValue": str(v)}


class Firestore:
    def __init__(self, project_id, api_key, email, password):
        self.base = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents"
        self.token = self._sign_in(api_key, email, password)

    @staticmethod
    def _sign_in(api_key, email, password):
        body = {"email": email, "password": password, "returnSecureToken": True}
        root = "https://identitytoolkit.googleapis.com/v1/accounts"
        try:
            return post_json(f"{root}:signInWithPassword?key={api_key}", body)["idToken"]
        except RuntimeError as e:
            msg = str(e)
            if "EMAIL_NOT_FOUND" not in msg and "INVALID_LOGIN_CREDENTIALS" not in msg:
                raise
        try:
            r = post_json(f"{root}:signUp?key={api_key}", body)
            notice(f"Created the collector account {email}.")
            return r["idToken"]
        except RuntimeError as e:
            if "EMAIL_EXISTS" in str(e):
                raise SystemExit("::error::COLLECTOR_PASSWORD does not match the collector account. "
                                 "Delete that user in Firebase Authentication and run again.") from None
            raise

    def set(self, path, data):
        post_json(f"{self.base}/{path}", {"fields": {k: to_value(v) for k, v in data.items()}},
                  headers={"Authorization": f"Bearer {self.token}"}, method="PATCH")


# ---------------------------------------------------------------- main


def main():
    cfg = json.load(open(os.path.join(ROOT, "companies.json")))
    subs = load_taxonomy()
    tasks = []
    for name in cfg.get("greenhouse", []):
        tasks.append(("Greenhouse", name, greenhouse, (name,)))
    for name in cfg.get("lever", []):
        tasks.append(("Lever", name, lever, (name,)))
    for name in cfg.get("ashby", []):
        tasks.append(("Ashby", name, ashby, (name,)))
    for name in cfg.get("smartrecruiters", []):
        tasks.append(("SmartRecruiters", name, smartrecruiters, (name,)))
    for name in cfg.get("workable", []):
        tasks.append(("Workable", name, workable, (name,)))
    az_id, az_key = os.environ.get("ADZUNA_APP_ID", "").strip(), os.environ.get("ADZUNA_APP_KEY", "").strip()
    if az_id and az_key:
        for q in cfg.get("adzuna_queries", []):
            tasks.append(("Adzuna", q, adzuna, (q, az_id, az_key)))
    else:
        notice("Adzuna skipped: ADZUNA_APP_ID / ADZUNA_APP_KEY secrets are not set.")

    jobs, stats = [], {}
    working, empty, failed = [], [], []
    with cf.ThreadPoolExecutor(max_workers=12) as pool:
        futs = {pool.submit(fn, *args): (src, name) for src, name, fn, args in tasks}
        for f in cf.as_completed(futs):
            src, name = futs[f]
            st = stats.setdefault(src, {"boards": 0, "ok": 0, "jobs": 0, "errors": 0})
            st["boards"] += 1
            try:
                got = [j for j in f.result() if j]
                st["ok"] += 1
                st["jobs"] += len(got)
                jobs.extend(got)
                (working if got else empty).append(f"{src}:{name}({len(got)})" if got else f"{src}:{name}")
            except Exception as e:
                st["errors"] += 1
                failed.append(f"{src}:{name} → {str(e)[:80]}")

    # Remove duplicates: same company + title + city. Prefer official sources and newer dates.
    jobs.sort(key=lambda j: (not j["official"], -(parse_date(j["postedAt"]) or NOW - dt.timedelta(days=99)).timestamp()))
    seen, unique = set(), []
    for j in jobs:
        key = (norm(j["company"]), norm(j["title"]), norm(j["location"].split(",")[0]))
        if key in seen:
            continue
        seen.add(key)
        unique.append(classify(j, subs))

    by_sub = {s["id"]: [] for s in subs}
    unfiled = 0
    for j in unique:
        if not j["subIds"]:
            unfiled += 1
        for sid in j["subIds"]:
            by_sub[sid].append(j)

    filed = sum(1 for j in unique if j["subIds"])
    summary = (f"Collected {len(jobs)} jobs → {len(unique)} after removing duplicates → {filed} filed into "
               f"categories ({unfiled} did not fit any category).")
    notice(summary)
    for src, st in sorted(stats.items()):
        notice(f"{src}: {st['jobs']} jobs from {st['ok']} of {st['boards']} boards ({st['errors']} failed)")
    top = sorted(((len(v), k) for k, v in by_sub.items() if v), reverse=True)[:12]
    notice("Busiest sub-categories: " + ", ".join(f"{k}={n}" for n, k in top))
    notice("Boards with jobs: " + ", ".join(sorted(working))[:3500])
    if failed:
        notice("Boards that failed (likely wrong name): " + "; ".join(sorted(failed))[:3500])
    if empty:
        notice("Boards with no India/remote jobs: " + ", ".join(sorted(empty))[:3500])

    os.makedirs(os.path.join(ROOT, "out"), exist_ok=True)
    json.dump(unique, open(os.path.join(ROOT, "out", "jobs.json"), "w"), indent=1)

    email, password = os.environ.get("COLLECTOR_EMAIL", "").strip(), os.environ.get("COLLECTOR_PASSWORD", "").strip()
    if not (email and password):
        notice("Dry run: COLLECTOR_PASSWORD is not set, so nothing was written to Firebase.")
        return

    gs = json.load(open(os.path.join(REPO, "google-services.json")))
    project_id = gs["project_info"]["project_id"]
    api_key = gs["client"][0]["api_key"][0]["current_key"]
    db = Firestore(project_id, api_key, email, password)

    light_keys = ["id", "title", "company", "location", "remote", "url", "source", "sourceName", "official",
                  "postedAt", "dateKind", "salaryMin", "salaryMax", "employmentType", "snippet", "skills", "subIds",
                  "catId", "scamFlags"]
    checked = NOW.isoformat()
    written = 0
    for sid, items in by_sub.items():
        items.sort(key=lambda j: -(parse_date(j["postedAt"]) or NOW - dt.timedelta(days=60)).timestamp())
        light = [dict({k: j.get(k) for k in light_keys}, lastChecked=checked) for j in items[:MAX_JOBS_PER_SUB]]
        db.set(f"jobs_index/{sid}", {"updatedAt": checked, "count": len(items), "jobs": light})
        written += 1
    db.set("meta/jobs", {
        "updatedAt": checked, "total": len(unique), "filed": filed,
        "sources": {k: v for k, v in stats.items()},
    })
    notice(f"Wrote {written} category documents to Firebase.")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:
        print(f"::error::Collector failed: {e}", flush=True)
        sys.exit(1)
