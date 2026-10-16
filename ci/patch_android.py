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
if "POST_NOTIFICATIONS" not in x:
    x = x.replace("<application", '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n    <application', 1)
    m.write_text(x)
print("Android notification settings added")
