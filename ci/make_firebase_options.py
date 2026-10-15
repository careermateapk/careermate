"""Turns google-services.json (uploaded to the repo root) into
lib/firebase_options.dart, and prints the Google web client ID.

Usage: python3 ci/make_firebase_options.py <google-services.json> <package name>
"""
import json
import sys

path, package = sys.argv[1], sys.argv[2]
data = json.load(open(path))
info = data["project_info"]

client = next(
    (c for c in data["client"] if c["client_info"]["android_client_info"]["package_name"] == package),
    None,
)
if client is None:
    sys.exit(f"::error::google-services.json has no Android app with package name {package}")

api_key = client["api_key"][0]["current_key"]
app_id = client["client_info"]["mobilesdk_app_id"]

# The "web" OAuth client (type 3) is what Google sign-in on Android needs.
web_client = ""
for c in data["client"]:
    for o in c.get("oauth_client", []):
        if o.get("client_type") == 3:
            web_client = o["client_id"]
    for o in c.get("services", {}).get("appinvite_service", {}).get("other_platform_oauth_client", []):
        if o.get("client_type") == 3 and not web_client:
            web_client = o["client_id"]

dart = f"""// Generated during the GitHub build from google-services.json. Do not edit.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {{
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
        apiKey: '{api_key}',
        appId: '{app_id}',
        messagingSenderId: '{info["project_number"]}',
        projectId: '{info["project_id"]}',
        storageBucket: '{info.get("storage_bucket", "")}',
      );
}}
"""
open("lib/firebase_options.dart", "w").write(dart)
print(web_client)
