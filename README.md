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
