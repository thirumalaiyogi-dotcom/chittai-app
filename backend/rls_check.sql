-- Crispy — RLS சரிபார்ப்பு (படிக்க மட்டும் — எதையும் மாற்றாது)
-- Supabase → SQL Editor → ஒவ்வொரு பகுதியையும் தனித்தனியாக run செய்து, முடிவை (screenshot / text) அனுப்புங்கள்.

-- ① எந்த table-க்கு RLS இல்லை? (rls_on = false என்றால் ஆபத்து; கடைசியில் வரும் வரிகளை கவனிக்கவும்)
select c.relname as tbl, c.relrowsecurity as rls_on
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
order by c.relrowsecurity, c.relname;

-- ② anon (app பயன்படுத்தும் key) நேரடியாக என்ன செய்ய முடியும்? (table வாரியாக)
select table_name,
       string_agg(privilege_type, ', ' order by privilege_type) as anon_can
from information_schema.role_table_grants
where table_schema = 'public' and grantee = 'anon'
group by table_name
order by table_name;

-- ③ ஒவ்வொரு table-ன் policy-கள் (anon / public-க்கு யார் எதைப் பார்க்கலாம்)
select tablename, policyname, cmd, roles, qual as using_expr, with_check
from pg_policies
where schemaname = 'public'
order by tablename, cmd, policyname;

-- ④ anon அழைக்கக்கூடிய functions (RPC) — security definer = அனுமதிகளைத் தாண்டி இயங்கும்
select p.proname as fn,
       case when p.prosecdef then 'SECURITY DEFINER' else 'invoker' end as mode,
       has_function_privilege('anon', p.oid, 'execute') as anon_can_execute
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by p.prosecdef desc, p.proname;
