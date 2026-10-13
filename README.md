# சிட்டை — வாடிக்கையாளர் app (Flutter)

web app `index.html`-ன் Flutter வடிவம். அதே Supabase, அதே கணக்கு விதிகள்.

## APK எப்படி எடுப்பது
1. GitHub-ல் இந்த repo → **Actions** tab
2. மேலே உள்ள கடைசி **"Build சிட்டை app"** (பச்சை ✓ இருக்க வேண்டும்)
3. கீழே **Artifacts** → `chittai-apk` → download → zip-ஐத் திறந்து `app-release.apk`-ஐ install செய்யுங்கள்

## கோப்புகள்
- `lib/` — app code (Dart)
- `pubspec.yaml` — packages
- `.github/workflows/build.yml` — தானியங்கி build
- `ci/setup_android.py` — app பெயர், permissions, signing
- `assets/icon.png` — app icon (உங்கள் logo-வை இதே பெயரில் மாற்றலாம், 1024×1024)

## 🔔 Push அறிவிப்பு அமைப்பு (ஒரு முறை மட்டும்)
1. **Firebase project** — console.firebase.google.com → project `chittai` → Android app `com.chittai.customer` சேர்க்கப்பட்டிருக்க வேண்டும். (Firebase அமைப்புகள் `lib/config.dart`-ல் உள்ளன; google-services.json தேவையில்லை.)
2. **FCM_SERVICE_ACCOUNT secret** — Firebase → Project settings → Service accounts → *Generate new private key* → JSON கோப்பின் முழு உள்ளடக்கத்தையும் Supabase → Edge Functions → Secrets → `FCM_SERVICE_ACCOUNT` என்ற பெயரில் சேமிக்கவும். (இந்த JSON-ஐ யாரிடமும் பகிர வேண்டாம்; GitHub-ல் போட வேண்டாம்.)
3. **notify deploy** — `backend/notify.ts` முழுவதையும் Supabase → Edge Functions → `notify` → paste செய்து **Deploy**.
4. **push_fcm.sql** — `backend/push_fcm.sql` முழுவதையும் Supabase → SQL Editor-ல் paste செய்து **Run**. முடிவில் `fn_ok = true` வர வேண்டும். (மீண்டும் run செய்தாலும் பாதிப்பில்லை.)
5. **API key பாதுகாப்பு** — Google Cloud Console → APIs & Services → Credentials → Firebase Android API key → *Application restrictions: Android apps* → package `com.chittai.customer` + app-ன் **SHA-1** சேர்க்கவும்.
   - Play Store-ல் வெளியிட்ட பிறகு: Play Console → Setup → App signing → **App signing key certificate**-ன் SHA-1 (மேலும் உங்கள் upload key SHA-1) இரண்டையும் சேர்க்கவும்.
   - இல்லையெனில் Play-வில் இருந்து install செய்தவர்களுக்கு notification வராமல் போகலாம்.

## 🔐 Play Store AAB
GitHub → Settings → Secrets and variables → Actions: `KEYSTORE_B64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` சேர்க்கவும். இவை இல்லையெனில் AAB step வேண்டுமென்றே நிற்கும் (சோதனை key-ல் sign செய்யாமல் இருக்க); APK மட்டும் கிடைக்கும்.

## எழுத்துருக்கள்
Noto Sans Tamil + Poppins `assets/google_fonts/`-ல் app-க்குள்ளேயே உள்ளன — இணையம் இல்லாமலும் சரியாகத் தெரியும்.
