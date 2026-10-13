# சிட்டை — GitHub Actions-ல் `flutter create` உருவாக்கிய android/ folder-ஐ நமக்கு ஏற்றபடி மாற்றுகிறது.
# (நீங்கள் இதைத் தொட வேண்டியதில்லை. ஒவ்வொரு build-லும் தானாக ஓடும்.)
#   • app பெயர் "சிட்டை"   • permissions (internet, இடம், mic, notification, அதிர்வு)
#   • WhatsApp / அழை / இணையதளம் / குரல் தேடல் திறக்க <queries>
#   • minSdk 23            • KEYSTORE secret இருந்தால் release signing
#   • அறிவிப்பு channel "orders" + வெள்ளை icon
#   (KEYSTORE இல்லையெனில் APK மட்டும் சோதனை key-ல்; AAB-ஐ build.yml நிறுத்தும்)
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

    # 4) அறிவிப்பு: channel "orders" + வெள்ளை சிறிய icon (Firebase இந்த meta-data-வை எடுக்கும்)
    if "default_notification_channel_id" not in m:
        meta = (
            '        <meta-data android:name="com.google.firebase.messaging.default_notification_channel_id"\n'
            '            android:value="orders"/>\n'
            '        <meta-data android:name="com.google.firebase.messaging.default_notification_icon"\n'
            '            android:resource="@drawable/ic_stat_chittai"/>\n'
        )
        m = m.replace("</application>", meta + "    </application>", 1)

    write(MANIFEST, m)
    print("✅ AndroidManifest.xml மாற்றப்பட்டது")


def patch_notification():
    # வெள்ளை ஒற்றை-நிற icon (status bar-ல் நிறம் வராமல் சதுரமாகத் தெரியாமல் இருக்க)
    d = os.path.join(APP, "src", "main", "res", "drawable")
    os.makedirs(d, exist_ok=True)
    write(os.path.join(d, "ic_stat_chittai.xml"), """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp"
    android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFFFF"
        android:pathData="M12,22c1.1,0 2,-0.9 2,-2h-4c0,1.1 0.89,2 2,2zM18,16v-5c0,-3.07 -1.64,-5.64 -4.5,-6.32V4c0,-0.83 -0.67,-1.5 -1.5,-1.5s-1.5,0.67 -1.5,1.5v0.68C7.63,5.36 6,7.92 6,11v5l-2,2v1h16v-1l-2,-2z"/>
</vector>
""")
    # app தொடங்கும்போதே "orders" channel உருவாக்கு (முக்கியத்துவம் அதிகம்: ஒலி + பாப்-அப்)
    kdir = os.path.join(APP, "src", "main", "kotlin")
    main_act = None
    for root, _, files in os.walk(kdir):
        if "MainActivity.kt" in files:
            main_act = os.path.join(root, "MainActivity.kt")
    if not main_act:
        print("MainActivity.kt கிடைக்கவில்லை — channel-ஐ Firebase தானே உருவாக்கும்")
        return
    pkg = re.search(r"^package\s+([\w.]+)", read(main_act), re.M).group(1)
    write(main_act, """package %s

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel("orders", "ஆர்டர் அறிவிப்புகள்", NotificationManager.IMPORTANCE_HIGH)
            ch.description = "உங்கள் ஆர்டர் நிலை மாற்றங்கள்"
            getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }
}
""" % pkg)
    print("✅ அறிவிப்பு channel + icon சேர்க்கப்பட்டது")


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
    patch_notification()
    patch_gradle()
