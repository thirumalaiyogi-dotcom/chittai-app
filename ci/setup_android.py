# சிட்டை — GitHub Actions-ல் `flutter create` உருவாக்கிய android/ folder-ஐ நமக்கு ஏற்றபடி மாற்றுகிறது.
# (நீங்கள் இதைத் தொட வேண்டியதில்லை. ஒவ்வொரு build-லும் தானாக ஓடும்.)
#   • app பெயர் "சிட்டை"   • permissions (internet, இடம், mic, notification, அதிர்வு)
#   • WhatsApp / அழை / இணையதளம் / குரல் தேடல் திறக்க <queries>
#   • minSdk 23            • KEYSTORE secret இருந்தால் release signing
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "android", "app")
MANIFEST = os.path.join(APP, "src", "main", "AndroidManifest.xml")


def read(p):
    with open(p, "r", encoding="utf-8") as f:
        return f.read()


def write(p, s):
    with open(p, "w", encoding="utf-8") as f:
        f.write(s)


def patch_manifest():
    if not os.path.exists(MANIFEST):
        print("AndroidManifest.xml கிடைக்கவில்லை:", MANIFEST)
        sys.exit(1)
    m = read(MANIFEST)

    # 1) app பெயர்
    m = re.sub(r'android:label="[^"]*"', 'android:label="சிட்டை"', m, count=1)

    # 2) permissions
    perms = [
        "android.permission.INTERNET",
        "android.permission.ACCESS_NETWORK_STATE",
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.ACCESS_COARSE_LOCATION",
        "android.permission.RECORD_AUDIO",
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.VIBRATE",
    ]
    add = ""
    for p in perms:
        if p not in m:
            add += '    <uses-permission android:name="%s"/>\n' % p
    if add:
        m = re.sub(r"(<manifest[^>]*>\s*\n)", lambda x: x.group(1) + add, m, count=1)

    # 3) வெளி app-களைத் திறக்க (Android 11+ விதி)
    intents = """        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="http"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.DIAL"/>
            <data android:scheme="tel"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="tel"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.SEND"/>
            <data android:mimeType="text/plain"/>
        </intent>
        <intent>
            <action android:name="android.speech.RecognitionService"/>
        </intent>
        <package android:name="com.whatsapp"/>
        <package android:name="com.whatsapp.w4b"/>
"""
    if "android.speech.RecognitionService" not in m:
        if "<queries>" in m:
            m = m.replace("<queries>", "<queries>\n" + intents, 1)
        else:
            m = m.replace("</manifest>", "    <queries>\n" + intents + "    </queries>\n</manifest>", 1)

    write(MANIFEST, m)
    print("✅ AndroidManifest.xml மாற்றப்பட்டது")


def patch_gradle():
    kts = os.path.join(APP, "build.gradle.kts")
    groovy = os.path.join(APP, "build.gradle")
    has_key = bool(os.environ.get("KEYSTORE_B64", "").strip())

    if has_key:
        import base64
        data = base64.b64decode(re.sub(r"\s+", "", os.environ["KEYSTORE_B64"]))
        with open(os.path.join(APP, "upload.jks"), "wb") as f:
            f.write(data)
        print("🔐 Keystore எழுதப்பட்டது (release signing)")
    else:
        print("ℹ️ KEYSTORE_B64 secret இல்லை — சோதனை (debug) key-ல் sign செய்யப்படும்")

    if os.path.exists(kts):
        g = read(kts)
        g = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 23", g)
        if has_key and 'create("release")' not in g:
            block = """    signingConfigs {
        create("release") {
            storeFile = file("upload.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }

    buildTypes {"""
            g = g.replace("    buildTypes {", block, 1)
            g = g.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")')
        write(kts, g)
        print("✅ build.gradle.kts மாற்றப்பட்டது")
    elif os.path.exists(groovy):
        g = read(groovy)
        g = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion", "minSdkVersion 23", g)
        if has_key and "signingConfigs {" not in g:
            block = """    signingConfigs {
        release {
            storeFile file("upload.jks")
            storePassword System.getenv("KEYSTORE_PASSWORD")
            keyAlias System.getenv("KEY_ALIAS")
            keyPassword System.getenv("KEY_PASSWORD")
        }
    }

    buildTypes {"""
            g = g.replace("    buildTypes {", block, 1)
            g = g.replace("signingConfig = signingConfigs.debug", "signingConfig = signingConfigs.release")
            g = g.replace("signingConfig signingConfigs.debug", "signingConfig signingConfigs.release")
        write(groovy, g)
        print("✅ build.gradle மாற்றப்பட்டது")
    else:
        print("build.gradle கிடைக்கவில்லை")
        sys.exit(1)


if __name__ == "__main__":
    patch_manifest()
    patch_gradle()
