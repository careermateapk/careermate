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
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="image/*" />
            </intent-filter>
        </activity>""", 1)
if "POST_NOTIFICATIONS" not in x:
    x = x.replace("<application", '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n    <application', 1)
m.write_text(x)
print("Android notification settings added")

# Some older plugins compile Kotlin for JVM 17 but Java for 11; don't fail the build for that.
gp = pathlib.Path("android/gradle.properties")
props = gp.read_text() if gp.exists() else ""
import re as _re
# Keep Gradle's memory below what the build machine has (big apps were being killed mid-build).
props = _re.sub(r"(?m)^org\.gradle\.jvmargs=.*$", "", props)
props = props.rstrip("\n") + "\norg.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g\nkotlin.daemon.jvmargs=-Xmx2g\n"
if "kotlin.jvm.target.validation.mode" not in props:
    props += "kotlin.jvm.target.validation.mode=warning\n"
gp.write_text(props)

# Release shrinking (R8): ML Kit's optional language packs are not included; don't fail on their missing classes.
pathlib.Path("android/app/proguard-rules.pro").write_text("""
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.android.play.core.**
# Flutter plugins talk to Dart through generated code; R8 must not rename or drop it
# (shared_preferences crashed at start with NoSuchMethodError on getAll).
-keep class io.flutter.plugins.** { *; }
-keep interface io.flutter.plugins.** { *; }
-keep class dev.flutter.pigeon.** { *; }
-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*
""")
