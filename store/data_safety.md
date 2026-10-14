# Data safety form — பதில்கள் (Play Console → App content → Data safety)

இவை இப்போதைய code-ஐ வைத்து நான் எழுதிய பரிந்துரை. இறுதி பொறுப்பு உன்னுடையது; Play Console கேள்விகள் மாறலாம்.

## பொது கேள்விகள்
- App தரவை சேகரிக்கிறதா / பகிர்கிறதா? → ஆம்
- இயக்கத்தில் (in transit) மறைகுறியாக்கம்? → ஆம (HTTPS)
- பயனர் தரவை நீக்கக் கோர வழி உண்டா? → ஆம (தொடர்பு வழியே; privacy policy-ல் உள்ளது)
- விளம்பரம்? → இல்லை
- கணக்கு உருவாக்கம்? → இல்லை (app-ல் login இல்லை)

## சேகரிக்கப்படும் தரவு வகைகள்
| தரவு | சேகரிப்பு | பகிர்வு | கட்டாயமா | நோக்கம் |
|---|---|---|---|---|
| Name (பெயர்) | ஆம | ஆம (கடை, டெலிவரி நபர்) | கட்டாயம் | App functionality |
| Phone number | ஆம | ஆம (டெலிவரி நபர்) | கட்டாயம் | App functionality |
| Address | ஆம | ஆம (டெலிவரி நபர்) | கட்டாயம் | App functionality |
| Approximate / Precise location | ஆம | ஆம (டெலிவரி நபர்) | விருப்பம் | App functionality |
| Purchase history (ஆர்டர் விவரம்) | ஆம | ஆம (கடை) | கட்டாயம் | App functionality |
| Device or other IDs (notification token) | ஆம | இல்லை (Firebase service provider) | விருப்பம் | App functionality |

## குறிப்புகள்
1. "பகிர்வு": கடை / டெலிவரி நபர் தனி நபர்கள் என்பதால் "ஆம" என்று அறிவிப்பது பாதுகாப்பு. Supabase, Firebase "service provider" (எங்கள் சார்பாக) — Play விதிப்படி இவை "பகிர்வு" அல்ல.
2. குரல் தேடல்: phone-ன் speech recognition பயன்படுகிறது; நாங்கள் பதிவு சேமிப்பதில்லை. இது "Voice or sound recordings" ஆக கணக்கில் வருமா என்பது Play-ன் வரையறையைப் பொறுத்தது. உறுதியில்லை என்றால் Play Console கேள்விக்கு "நிலையற்ற (ephemeral) செயலாக்கம், சேமிப்பில்லை" என்று பதிலளி; privacy policy-ல் இது ஏற்கனவே உள்ளது.
3. Analytics, crash reporting, விளம்பர SDK: இப்போது app-ல் இல்லை. பிற்பாடு சேர்த்தால் இந்த படிவத்தை புதுப்பிக்கவும்.
4. Permission விளக்கம் (Play கேட்கும்): இடம் → "டெலிவரி இடம் குறிக்கவும் கடையின் டெலிவரி பகுதியைச் சரிபார்க்கவும்"; மைக் → "குரல் தேடலுக்கு"; Notification → "ஆர்டர் நிலை அறிவிப்புக்கு".
