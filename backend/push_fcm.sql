-- ═══════════════════════════════════════════════════════════════
-- சிட்டை — push_fcm.sql  📱 Play Store app-க்கு notification
-- புதிதாக ஒரு function மட்டும் சேர்க்கிறது. எந்த table-ம், எந்த பழைய function-ம் மாறாது.
--   save_order_fcm(ஆர்டர் id, அதே mobile எண், Firebase token)
--   → order_push_subscriptions-ல் endpoint = 'fcm:<token>' என்று ஒரு வரி (web push வரிகளைப் போலவே)
--   → ஆர்டர் முடிந்ததும் notify தானாக அந்த வரியை நீக்கும் (முன்பு போலவே)
-- Supabase → SQL Editor → முழுவதும் paste செய்து Run. மீண்டும் run செய்தாலும் பாதிப்பில்லை.
-- ═══════════════════════════════════════════════════════════════

create or replace function public.save_order_fcm(p_order_id uuid, p_phone text, p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_ph text; v_st text; v_ep text;
begin
  if p_token is null or length(p_token) < 20 or length(p_token) > 4096 or p_token !~ '^[A-Za-z0-9:_\-]+$' then
    return jsonb_build_object('ok', false, 'msg', 'token தவறு');
  end if;
  select customer_phone, order_status into v_ph, v_st from public.orders where id = p_order_id;
  if not found then return jsonb_build_object('ok', false, 'msg', 'ஆர்டர் கிடைக்கவில்லை'); end if;
  -- அதே mobile எண் இருந்தால் மட்டும் (ஆர்டர் id மட்டும் போதாது)
  if right(regexp_replace(coalesce(v_ph, ''), '\D', '', 'g'), 10) <> right(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'), 10) then
    return jsonb_build_object('ok', false, 'msg', 'எண் பொருந்தவில்லை');
  end if;
  if v_st in ('DELIVERED', 'CANCELLED') then return jsonb_build_object('ok', false, 'msg', 'ஆர்டர் முடிந்துவிட்டது'); end if;
  v_ep := 'fcm:' || p_token;
  insert into public.order_push_subscriptions (order_id, endpoint, p256dh, auth)
  select p_order_id, v_ep, 'fcm', 'fcm'
  where not exists (select 1 from public.order_push_subscriptions where order_id = p_order_id and endpoint = v_ep);
  return jsonb_build_object('ok', true);
end $$;

revoke all on function public.save_order_fcm(uuid, text, text) from public;
grant execute on function public.save_order_fcm(uuid, text, text) to anon, authenticated;

-- சரிபார்ப்பு: fn_ok = true என்று வர வேண்டும்
select exists(select 1 from pg_proc where proname = 'save_order_fcm') as fn_ok;
