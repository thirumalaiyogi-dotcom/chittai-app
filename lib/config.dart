// Crispy — நிலையான அமைப்புகள் (web app index.html-ல் உள்ள அதே மதிப்புகள்)

const String kSbUrl = 'https://cerstnckjygvcfekfxcp.supabase.co';

// anon key மட்டும் (பொது key — service_role key ஒருபோதும் app-ல் வைக்கக் கூடாது)
const String kSbKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNlcnN0bmNranlndmNmZWtmeGNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzOTY2NDEsImV4cCI6MjA5Mzk3MjY0MX0.Yl-5QyyEyiwmXG9u1kL08CxIanU-22Fx-HicEe2VYi8';

// பழைய தரவில் கடை இல்லாத பொருட்கள் இந்தக் கடையைச் சேர்ந்தவை
const String kDefaultShopId = 'grocery';

// Support WhatsApp எண் (server-ல் app_settings.support_phone இருந்தால் அதுவே)
const String kDefaultWaNum = '917539967593';

// HTML: "Crispy · பதிப்பு 11-10-2026.3"
const String kAppVersion = '11-10-2026.3';

// தேடல் வடிகட்டல் அளவுகள்
const double kSrNearKm = 3;
const double kSrFastMin = 30;

// 🔔 Firebase push (Firebase Console → Project settings → Your apps → Android app)
// நான்கும் நிரம்பும் வரை push வசதி மறைந்திருக்கும் — app வேறு எதுவும் பாதிக்காது
const String kFbApiKey = 'AIzaSyDEqm8v7WzDnfHTcuiEzCw09ENVwV6ZlIU';
const String kFbAppId = '1:514345808750:android:58b0f6974fb4bd8d7f877f';
const String kFbSenderId = '514345808750';
const String kFbProjectId = 'chittai-6536e';
