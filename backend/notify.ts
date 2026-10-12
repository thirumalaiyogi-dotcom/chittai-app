// சிட்டை — "notify" Edge Function (v10: + 📱 Play Store app-க்கு Firebase (FCM) notification · v9: + 🧾 கடை பில் கையிருப்பு எச்சரிக்கை · v8: + 🌙 இரவு சுருக்கம் · v7: + 📦 கையிருப்பு எச்சரிக்கை · 📅 முன்பதிவு · ⚡ தானியங்கி ஏற்பு · ரத்து ஆனால் கடை / delivery / அட்மினுக்கும் தகவல்)
// Supabase Dashboard → Edge Functions → notify → Code → index.ts-ல் உள்ளதை முழுவதும் அழித்து இதை paste → Deploy.
// Called only by the database trigger. Sends push notifications to the right phones.
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const SECRET = Deno.env.get("SITTA_PUSH_SECRET") ?? "";
const VAPID_PUBLIC = Deno.env.get("VAPID_PUBLIC_KEY") ?? "";
const VAPID_PRIVATE = Deno.env.get("VAPID_PRIVATE_KEY") ?? "";
const SITE = "https://thirumalaiyogi-dotcom.github.io/Test-app/";
webpush.setVapidDetails(SITE, VAPID_PUBLIC, VAPID_PRIVATE);

// ═══ v10: Play Store app (Flutter) — Firebase Cloud Messaging ═══
// app சேமிக்கும் வரி: order_push_subscriptions.endpoint = "fcm:<token>" (save_order_fcm). மற்ற எல்லாம் முன்பு போலவே web push.
// Secret: FCM_SERVICE_ACCOUNT = Firebase service account JSON முழுவதும் (இல்லையெனில் FCM வரிகள் அமைதியாகத் தவிர்க்கப்படும்)
const FCM_SA = Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "";
let fcmTok = { t: "", exp: 0, project: "" };
const b64url = (b: Uint8Array) => btoa(String.fromCharCode(...b)).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
const b64json = (o: unknown) => b64url(new TextEncoder().encode(JSON.stringify(o)));
async function fcmAccess(): Promise<{ token: string; project: string } | null> {
  if (!FCM_SA) return null;
  const now = Math.floor(Date.now() / 1000);
  if (fcmTok.t && fcmTok.exp - 60 > now) return { token: fcmTok.t, project: fcmTok.project };
  try {
    const sa = JSON.parse(FCM_SA);
    const head = b64json({ alg: "RS256", typ: "JWT" });
    const claim = b64json({ iss: sa.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging", aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600 });
    const pem = String(sa.private_key).replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
    const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
    const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
    const sig = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${head}.${claim}`)));
    const r = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${head}.${claim}.${b64url(sig)}`,
    });
    const j = await r.json();
    if (!j.access_token) return null;
    fcmTok = { t: j.access_token, exp: now + (Number(j.expires_in) || 3600), project: String(sa.project_id) };
    return { token: fcmTok.t, project: fcmTok.project };
  } catch {
    return null;
  }
}
async function fcmSend(token: string, m: Msg, orderId: string): Promise<"ok" | "gone" | "fail"> {
  const a = await fcmAccess();
  if (!a) return "fail";
  try {
    const r = await fetch(`https://fcm.googleapis.com/v1/projects/${a.project}/messages:send`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${a.token}` },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: m.title, body: m.body },
          data: { order_id: orderId, tag: m.tag },
          android: { priority: "HIGH", ttl: "3600s", notification: { tag: m.tag, channel_id: "orders", sound: "default" } },
        },
      }),
    });
    if (r.ok) return "ok";
    const t = await r.text();
    // token உண்மையில் செல்லாதபோது மட்டும் நீக்கு (வேறு INVALID_ARGUMENT = நம் message பிழை → token-ஐ வைத்திரு)
    const dead = r.status === 404 || t.includes("UNREGISTERED") ||
      (t.includes("INVALID_ARGUMENT") && /registration[ -]?token/i.test(t));
    return dead ? "gone" : "fail";
  } catch {
    return "fail";
  }
}

const json = (d: unknown, status = 200) =>
  new Response(JSON.stringify(d), { status, headers: { "Content-Type": "application/json" } });
const rs = (n: unknown) => String(Math.round((Number(n) || 0) * 100) / 100);

type Msg = { title: string; body: string; url: string; tag: string; sticky?: boolean };
type Sub = { endpoint: string; p256dh: string; auth: string };

Deno.serve(async (req) => {
  if (!SECRET || req.headers.get("x-sitta-secret") !== SECRET) return json({ ok: false }, 403);
  let ev = "", orderId = "", userId = "", remind = false, by = "", prev = "", auto = false, sName = "", sPack = "", sQty = -1, sShop = "", sUnit = "";
  try { const b = await req.json(); ev = String(b.event || ""); orderId = String(b.order_id || ""); userId = String(b.user_id || ""); remind = b.remind === true; by = String(b.by || ""); prev = String(b.prev || ""); auto = b.auto === true; sName = String(b.name || "").slice(0, 80); sPack = String(b.pack || "").slice(0, 40); sQty = Number.isFinite(+b.qty) ? +b.qty : -1; sShop = String(b.shop_id || "").slice(0, 64); sUnit = String(b.unit || "").slice(0, 12); } catch { return json({ ok: false }, 400); }

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // சோதனை notification: அட்மின் "சோதனை அனுப்பு" அழுத்தும்போது (admin_test_push)
  if (ev === "test") {
    if (!/^[0-9a-f-]{36}$/i.test(userId)) return json({ ok: false }, 400);
    const { data: who } = await sb.from("profiles").select("role").eq("id", userId).maybeSingle();
    const page = who?.role === "merchant" ? "shop.html" : who?.role === "delivery" ? "delivery.html" : "admin.html";
    const { data: subs } = await sb.from("push_subscriptions").select("endpoint,user_id,p256dh,auth").eq("user_id", userId);
    let n = 0;
    await Promise.all((subs ?? []).map(async (s: Sub & { user_id: string }) => {
      try {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
          JSON.stringify({ title: "🔔 சோதனை notification", body: "சிட்டை notification இந்த phone-ல் சரியாக வேலை செய்கிறது ✅", url: page, tag: "sitta-test" }), { TTL: 600, urgency: "high" });
        n++;
      } catch (e) {
        const code = (e as { statusCode?: number }).statusCode;
        if (code === 404 || code === 410) await sb.from("push_subscriptions").delete().eq("endpoint", s.endpoint).eq("user_id", s.user_id);
      }
    }));
    return json({ ok: true, sent: n });
  }
  // 🌙 இரவு சுருக்கம் (summary.sql — தினமும் இரவு 10 மணிக்கு): அட்மின் phone-களுக்கு மட்டும்
  if (ev === "summary") {
    const nowIst = new Date(Date.now() + 5.5 * 3600e3);
    const from = new Date(Date.UTC(nowIst.getUTCFullYear(), nowIst.getUTCMonth(), nowIst.getUTCDate()) - 5.5 * 3600e3).toISOString();
    const { data: rows } = await sb.from("orders").select("order_status,total,pay_mode,created_at,delivered_at").gte("created_at", from).limit(5000);
    const R = rows ?? [];
    const dl = R.filter((r: any) => r.order_status === "DELIVERED");
    const cx = R.filter((r: any) => r.order_status === "CANCELLED").length;
    const open = R.length - dl.length - cx;
    const sum = (a: any[]) => a.reduce((x, r) => x + (Number(r.total) || 0), 0);
    const upi = sum(dl.filter((r: any) => r.pay_mode === "upi")), tot = sum(dl);
    const mins = dl.map((r: any) => (new Date(r.delivered_at).getTime() - new Date(r.created_at).getTime()) / 60000).filter((m: number) => m >= 0 && m < 720);
    const avgM = mins.length ? Math.round(mins.reduce((a: number, b: number) => a + b, 0) / mins.length) : 0;
    const body = R.length
      ? `🛒 ${R.length} ஆர்டர் · 🏠 ${dl.length} கொடுத்தது · ₹${rs(tot)}${upi ? ` (📲 UPI ₹${rs(upi)})` : ""}${avgM ? ` · ⏱️ சராசரி ${avgM} நி` : ""}${cx ? ` · ❌ ${cx} ரத்து` : ""}${open ? ` · ⏳ ${open} இன்னும் முடியவில்லை` : ""}`
      : "இன்று ஆர்டர் எதுவும் வரவில்லை";
    const { data: adm } = await sb.from("profiles").select("id").eq("role", "admin").eq("approved", true);
    const ids = (adm ?? []).map((r: { id: string }) => r.id);
    let n = 0;
    if (ids.length) {
      const { data: subs } = await sb.from("push_subscriptions").select("endpoint,user_id,p256dh,auth").in("user_id", ids);
      await Promise.all((subs ?? []).map(async (s: Sub & { user_id: string }) => {
        try {
          await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
            JSON.stringify({ title: "🌙 இன்றைய சுருக்கம்", body, url: "boss.html", tag: "daily-summary" }), { TTL: 6 * 3600, urgency: "normal" });
          n++;
        } catch (e) {
          const code = (e as { statusCode?: number }).statusCode;
          if (code === 404 || code === 410) await sb.from("push_subscriptions").delete().eq("endpoint", s.endpoint).eq("user_id", s.user_id);
        }
      }));
    }
    return json({ ok: true, sent: n, body });
  }
  // 📦 கையிருப்பு (inventory.sql — அலகுக் கணக்கு; கவுண்டர் பில்லிலும் வரும், அதனால் ஆர்டர் இல்லாமல் கடை id மட்டும்)
  if (ev === "low_stock" && sShop) {
    const gone = sQty === 0;
    const { data: ms } = await sb.from("profiles").select("id").eq("role", "merchant").eq("approved", true).eq("shop_id", sShop);
    const ids = (ms ?? []).map((r: { id: string }) => r.id);
    let n = 0;
    if (ids.length) {
      const { data: subs } = await sb.from("push_subscriptions").select("endpoint,user_id,p256dh,auth").in("user_id", ids);
      const m = { title: gone ? `⛔ தீர்ந்துவிட்டது: ${sName}` : `📦 கையிருப்பு குறைவு: ${sName}`,
                  body: gone ? "வாடிக்கையாளர்கள் இனி இதை ஆர்டர் செய்ய முடியாது — சரக்கு வந்ததும் 🧾 பில் & சரக்கு-ல் வரவு போடுங்கள்"
                             : `இன்னும் ${sQty} ${sUnit} மட்டுமே உள்ளது — விரைவில் சரக்கு வாங்குங்கள்`,
                  url: "billing.html", tag: `inv-${sShop}-${sName}` };
      await Promise.all((subs ?? []).map(async (s: Sub & { user_id: string }) => {
        try { await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, JSON.stringify(m), { TTL: 3600, urgency: "high" }); n++; }
        catch (e) { const code = (e as { statusCode?: number }).statusCode; if (code === 404 || code === 410) await sb.from("push_subscriptions").delete().eq("endpoint", s.endpoint).eq("user_id", s.user_id); }
      }));
    }
    return json({ ok: true, sent: n });
  }
  const { data: o } = await sb.from("orders")
    .select("id,order_number,total,shop_id,customer_name,delivery_partner_id,order_status,approved_at,cancel_reason,scheduled_slot")
    .eq("id", orderId).maybeSingle();
  if (!o) return json({ ok: false, msg: "order not found" });
  const { data: shop } = await sb.from("shops").select("name").eq("id", o.shop_id).maybeSingle();
  const shopName = shop?.name ?? "";
  const no = o.order_number ?? "";
  const slot = String(o.scheduled_slot ?? "").trim();
  const sl = slot ? ` · 📅 ${slot}` : "";
  let dName = "";
  if (o.delivery_partner_id) {
    const { data: dp } = await sb.from("profiles").select("full_name").eq("id", o.delivery_partner_id).maybeSingle();
    dName = dp?.full_name ?? "";
  }

  const staff = async (role: string, extra?: (q: any) => any): Promise<string[]> => {
    let q = sb.from("profiles").select("id").eq("role", role).eq("approved", true);
    if (extra) q = extra(q);
    const { data } = await q;
    return (data ?? []).map((r: { id: string }) => r.id);
  };

  // 1) staff (admin / shop / delivery)
  let staffIds: string[] = [];
  let staffMsg: Msg | null = null;
  // 2) customer (phones linked to this order)
  let custMsg: Msg | null = null;
  // 3) மேலும் சில staff குழுக்கள், ஒவ்வொன்றுக்கும் தனிச் செய்தி (ரத்து)
  const extra: { ids: string[]; msg: Msg }[] = [];

  if (ev === "new") {
    staffIds = await staff("admin");
    staffMsg = auto
      ? { title: `⚡ புது ஆர்டர் ${no} — தானாக கடைக்கு அனுப்பப்பட்டது`, body: `🏪 ${shopName} · ₹${rs(o.total)} · ${o.delivery_partner_id ? "🛵 " + (dName || "டெலிவரி நபர்") + " ஒதுக்கப்பட்டார்" : "🛵 Delivery நபரை ஒதுக்குங்கள்"}${sl}`, url: "admin.html", tag: `new-${o.id}`, sticky: !o.delivery_partner_id }
      : { title: `🆕 புது ஆர்டர் ${no}`, body: `🏪 ${shopName} · ₹${rs(o.total)}${sl} — ✅ OK செய்யுங்கள்`, url: "admin.html", tag: `new-${o.id}`, sticky: true };
  } else if (ev === "approved") {
    staffIds = await staff("merchant", (q) => q.eq("shop_id", o.shop_id));
    staffMsg = { title: slot ? `📅 முன்பதிவு ஆர்டர் — ${slot}` : `📦 பார்சல் செய்ய புது ஆர்டர்`, body: `${o.customer_name ?? ""} · ${no}${slot ? " · அந்த நேரத்துக்குத் தயார் செய்யுங்கள்" : ""}`, url: "shop.html", tag: `approved-${o.id}`, sticky: true };
    custMsg = { title: slot ? `✅ உங்கள் முன்பதிவு உறுதி — 📅 ${slot}` : `✅ உங்கள் ஆர்டர் உறுதி செய்யப்பட்டது`, body: slot ? `${shopName} குறித்த நேரத்தில் கொண்டு வரும் · ${no}` : `${shopName} உங்கள் பார்சலைத் தயார் செய்கிறது · ${no}`, url: "./", tag: `c-${o.id}` };
  } else if (ev === "assigned") {
    if (o.delivery_partner_id) staffIds = [o.delivery_partner_id];
    staffMsg = { title: `🛵 உங்களுக்கு புது delivery`, body: `${shopName} → ${o.customer_name ?? ""} · ${no} · ₹${rs(o.total)}${sl}`, url: "delivery.html", tag: `assigned-${o.id}`, sticky: true };
  } else if (ev === "ready") {
    if (o.delivery_partner_id) staffIds = [o.delivery_partner_id];
    staffMsg = { title: `📦 பார்சல் ரெடி — ${shopName}`, body: `${no} · கடையில் வாங்கிக்கொள்ளுங்கள்${sl}`, url: "delivery.html", tag: `ready-${o.id}` };
  } else if (ev === "picked") {
    custMsg = { title: `🛵 உங்கள் ஆர்டர் புறப்பட்டது!`, body: `${dName ? dName + " கொண்டு வருகிறார்" : "Delivery நபர் கொண்டு வருகிறார்"} · ₹${rs(o.total)} தயாராக வைத்திருங்கள் (COD)`, url: "./", tag: `c-${o.id}`, sticky: true };
  } else if (ev === "delivered") {
    custMsg = { title: `🎉 டெலிவரி முடிந்தது`, body: `சிட்டை-யைத் தேர்ந்தெடுத்ததற்கு நன்றி! · ${no}`, url: "./", tag: `c-${o.id}` };
  } else if (ev === "low_stock") { // 📦 கையிருப்பு குறைவு / தீர்ந்தது (stock.sql trigger)
    const gone = sQty === 0;
    extra.push({ ids: await staff("merchant", (q) => q.eq("shop_id", o.shop_id)),
      msg: { title: gone ? `⛔ தீர்ந்துவிட்டது: ${sName} ${sPack}` : `📦 கையிருப்பு குறைவு: ${sName} ${sPack}`,
             body: gone ? "வாடிக்கையாளர்கள் இனி இதை ஆர்டர் செய்ய முடியாது — சரக்கு வந்ததும் கடை app-ல் எண்ணிக்கையைப் புதுப்பியுங்கள்"
                        : `இன்னும் ${sQty} மட்டுமே உள்ளது — விரைவில் சரக்கு வாங்குங்கள்`,
             url: "shop.html", tag: `stock-${o.shop_id}-${sName}-${sPack}` } });
  } else if (ev === "soon") { // 📅 முன்பதிவு நேரம் நெருங்குகிறது (orders_remind, 40 நிமிடம் முன்)
    extra.push({ ids: await staff("merchant", (q) => q.eq("shop_id", o.shop_id)),
      msg: { title: `⏰ 📅 ${slot || "முன்பதிவு"} — ${no}`, body: `${o.customer_name ?? ""} · முன்பதிவு நேரம் நெருங்குகிறது — பார்சலைத் தயார் செய்யுங்கள்`, url: "shop.html", tag: `approved-${o.id}`, sticky: true } });
    if (o.delivery_partner_id) extra.push({ ids: [o.delivery_partner_id],
      msg: { title: `⏰ 📅 ${slot || "முன்பதிவு"} — ${no}`, body: `${shopName} → ${o.customer_name ?? ""} · விரைவில் கடையில் எடுக்க வேண்டும்`, url: "delivery.html", tag: `assigned-${o.id}`, sticky: true } });
  } else if (ev === "cancelled") {
    // by: customer / admin / merchant (பழைய trigger என்றால் காலியாக இருக்கும்) · prev: ரத்துக்கு முந்தைய நிலை
    const why = String(o.cancel_reason ?? "").trim();
    const before = prev || (o.approved_at ? "SHOP_ACCEPTED" : "ORDER_RECEIVED");
    const shopKnew = ["SHOP_ACCEPTED", "PREPARING", "READY_FOR_PICKUP", "DELIVERY_ASSIGNED", "OUT_FOR_DELIVERY"].includes(before);
    const whoTxt = by === "customer" ? "வாடிக்கையாளர் ரத்து செய்தார்" : by === "merchant" ? "கடை நிராகரித்தது" : by === "admin" ? "அட்மின் ரத்து செய்தார்" : "ரத்து செய்யப்பட்டது";
    const whyS = by === "merchant" ? why.replace(/^கடை:\s*/, "") : why;
    const tail = whyS ? ` · ${whyS}` : "";
    if (by !== "customer") {
      custMsg = { title: `❌ உங்கள் ஆர்டர் ரத்து செய்யப்பட்டது`, body: `${no} — ${why ? why + " · " : ""}விவரங்களுக்கு ${shopName || "கடையை"} தொடர்பு கொள்ளுங்கள்`, url: "./", tag: `c-${o.id}` };
    }
    if (shopKnew && by !== "merchant") {
      extra.push({ ids: await staff("merchant", (q) => q.eq("shop_id", o.shop_id)),
        msg: { title: `❌ ஆர்டர் ரத்து — பார்சல் செய்ய வேண்டாம்`, body: `${o.customer_name ?? ""} · ${no} · ${whoTxt}${tail}`, url: "shop.html", tag: `approved-${o.id}`, sticky: true } });
    }
    if (o.delivery_partner_id && by !== "delivery") {
      const onWay = before === "OUT_FOR_DELIVERY";
      extra.push({ ids: [o.delivery_partner_id],
        msg: { title: `❌ Delivery ரத்து — ${no}`, body: onWay ? `பார்சலை ${shopName || "கடை"}-க்கு திருப்பிக் கொடுங்கள் · ${whoTxt}` : `${shopName || "கடை"}-க்குப் போக வேண்டாம் · ${whoTxt}`, url: "delivery.html", tag: `assigned-${o.id}`, sticky: true } });
    }
    if (by !== "admin") {
      extra.push({ ids: await staff("admin"),
        msg: { title: `❌ ஆர்டர் ரத்து ${no}`, body: `🏪 ${shopName} · ₹${rs(o.total)} · ${whoTxt}${tail}`, url: "admin.html", tag: `new-${o.id}` } });
    }
  } else {
    return json({ ok: false, msg: "unknown event" }, 400);
  }

  if (remind) { // ⏰ நினைவூட்டல்: யாரும் இன்னும் கவனிக்கவில்லை
    if (staffMsg) staffMsg = { ...staffMsg, title: "⏰ நினைவூட்டல்: " + staffMsg.title, sticky: true };
    custMsg = null;
  }

  let sent = 0;
  const push = async (s: Sub, m: Msg, onGone: () => Promise<unknown>) => {
    if (s.endpoint.startsWith("fcm:")) { // 📱 Play Store app
      const r = await fcmSend(s.endpoint.slice(4), m, o.id);
      if (r === "ok") sent++;
      else if (r === "gone") await onGone();
      return;
    }
    try {
      await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, JSON.stringify(m), { TTL: 3600, urgency: "high" });
      sent++;
    } catch (e) {
      const code = (e as { statusCode?: number }).statusCode;
      if (code === 404 || code === 410) await onGone(); // phone unsubscribed / app removed → forget it
    }
  };

  const jobs: Promise<unknown>[] = [];
  if (staffMsg && staffIds.length) {
    const { data: subs } = await sb.from("push_subscriptions").select("endpoint,user_id,p256dh,auth").in("user_id", staffIds);
    for (const s of subs ?? []) jobs.push(push(s, staffMsg, () => sb.from("push_subscriptions").delete().eq("endpoint", s.endpoint).eq("user_id", s.user_id)));
  }
  for (const g of extra) {
    if (!g.ids.length) continue;
    const { data: subs } = await sb.from("push_subscriptions").select("endpoint,user_id,p256dh,auth").in("user_id", g.ids);
    for (const s of subs ?? []) jobs.push(push(s, g.msg, () => sb.from("push_subscriptions").delete().eq("endpoint", s.endpoint).eq("user_id", s.user_id)));
  }
  if (custMsg) {
    const { data: subs } = await sb.from("order_push_subscriptions").select("endpoint,p256dh,auth").eq("order_id", o.id);
    for (const s of subs ?? []) jobs.push(push(s, custMsg, () => sb.from("order_push_subscriptions").delete().eq("order_id", o.id).eq("endpoint", s.endpoint)));
  }
  await Promise.all(jobs);
  if (ev === "delivered" || ev === "cancelled") { // order finished: the customer link is no longer needed
    await sb.from("order_push_subscriptions").delete().eq("order_id", o.id);
  }
  return json({ ok: true, sent });
});
