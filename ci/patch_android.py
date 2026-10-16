"""Extra Android settings needed by plugins:
- notifications plugin needs Java 8+ library desugaring
- Android 13+ needs the POST_NOTIFICATIONS permission declared."""
import pathlib
import re

kts = pathlib.Path("android/app/build.gradle.kts")
groovy = pathlib.Path("android/app/build.gradle")
if kts.exists():
    t = kts.read_text()
    t, n = re.subn(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", t, count=1)
    if n != 1:
        raise SystemExit("::error::compileOptions block not found in build.gradle.kts")
    t += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    kts.write_text(t)
else:
    t = groovy.read_text()
    t, n = re.subn(r"compileOptions\s*\{", "compileOptions {\n        coreLibraryDesugaringEnabled true", t, count=1)
    if n != 1:
        raise SystemExit("::error::compileOptions block not found in build.gradle")
    t += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    groovy.write_text(t)

m = pathlib.Path("android/app/src/main/AndroidManifest.xml")
x = m.read_text()
# "Share → CareerMate" from LinkedIn/WhatsApp: accept shared text, reuse the running app
x = x.replace('android:launchMode="singleTop"', 'android:launchMode="singleTask"', 1)
if "android.intent.action.SEND" not in x:
    x = x.replace("</activity>", """    <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="text/*" />
            </intent-filter>
        </activity>""", 1)
if "POST_NOTIFICATIONS" not in x:
    x = x.replace("<application", '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n    <application', 1)
m.write_text(x)
print("Android notification settings added")

# Some older plugins compile Kotlin for JVM 17 but Java for 11; don't fail the build for that.
gp = pathlib.Path("android/gradle.properties")
props = gp.read_text() if gp.exists() else ""
if "kotlin.jvm.target.validation.mode" not in props:
    gp.write_text(props.rstrip("\n") + "\nkotlin.jvm.target.validation.mode=warning\n")

# Release shrinking (R8): ML Kit's optional language packs are not included; don't fail on their missing classes.
pathlib.Path("android/app/proguard-rules.pro").write_text("""
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.android.play.core.**
""")
