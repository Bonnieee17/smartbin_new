-- ============================================================================
-- SMARTBIN — COMPLETE PRODUCTION SUPABASE DATABASE SETUP SCRIPT
-- Paste this entire file into Supabase > SQL Editor > Click "Run".
-- ============================================================================

-- ============================================================================
-- 0. CLEAN UP PREVIOUS SCHEMA (if any)
-- ============================================================================
drop trigger  if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user() cascade;
drop table if exists public.redemptions   cascade;
drop table if exists public.user_badges   cascade;
drop table if exists public.activity      cascade;
drop table if exists public.vouchers      cascade;
drop table if exists public.voucher_log   cascade;
drop table if exists public.deposit_tokens cascade;
drop table if exists public.bin_events    cascade;
drop table if exists public.bin_compartments cascade;
drop table if exists public.bins          cascade;
drop table if exists public.badges        cascade;
drop table if exists public.settings      cascade;
drop table if exists public.profiles      cascade;


-- ============================================================================
-- 1. TABLES
-- ============================================================================

-- 1.1 Profiles (one per auth user) — UserAcct
create table public.profiles (
  id               uuid primary key references auth.users(id) on delete cascade,
  student_id       text not null unique,
  name             text not null,
  gender           text not null default '' check (gender in ('', 'Girl', 'Boy')),
  role             text not null default 'user' check (role in ('user', 'admin', 'psits')),
  points           int  not null default 0 check (points >= 0 and points <= 1000000),
  lifetime_points  int  not null default 0 check (lifetime_points >= 0 and lifetime_points <= 10000000),
  items            int  not null default 0 check (items >= 0 and items <= 100000),
  created_at       timestamptz not null default now()
);
create index profiles_role_idx on public.profiles(role);

-- 1.2 Bins — Bin
create table public.bins (
  id          bigserial primary key,
  name        text not null,
  location    text not null default '—',
  is_on       boolean not null default true,
  created_at  timestamptz not null default now()
);

-- 1.3 Bin compartments — Comp ('rec' = recyclable, 'non' = non-biodegradable)
create table public.bin_compartments (
  bin_id     bigint not null references public.bins(id) on delete cascade,
  kind       text   not null check (kind in ('rec', 'non')),
  fill       int    not null default 0 check (fill between 0 and 100),
  alert_at   int    not null default 80 check (alert_at between 0 and 100),
  updated_at timestamptz not null default now(),
  primary key (bin_id, kind)
);

-- auto-create both compartments for every new bin
create or replace function public.bins_make_compartments() returns trigger
language plpgsql as $$
begin
  insert into public.bin_compartments (bin_id, kind)
  values (new.id, 'rec'), (new.id, 'non')
  on conflict do nothing;
  return new;
end $$;
create trigger bins_after_insert after insert on public.bins
  for each row execute function public.bins_make_compartments();

-- 1.4 Bin events — BinEvent (ok | rej | full | off)
create table public.bin_events (
  id         bigserial primary key,
  bin_id     bigint references public.bins(id) on delete set null,
  bin_name   text not null,
  type       text not null check (type in ('ok', 'rej', 'full', 'off')),
  message    text not null,
  weight     int  not null default 0,
  token_id   bigint,
  created_at timestamptz not null default now()
);
create index bin_events_created_idx on public.bin_events(created_at desc);

-- 1.5 Deposit tokens — one-time reward QR (bin -> user)
create table public.deposit_tokens (
  id          bigserial primary key,
  nonce       text not null unique,
  bin_id      bigint references public.bins(id) on delete cascade,
  kind        text not null check (kind in ('rec', 'non')),
  points      int  not null check (points > 0 and points <= 1000),
  is_test     boolean not null default false,
  expires_at  timestamptz not null default now() + interval '2 minutes',
  used_by     uuid references public.profiles(id) on delete set null,
  used_at     timestamptz,
  created_at  timestamptz not null default now()
);
create index deposit_tokens_used_idx on public.deposit_tokens(used_at);

-- 1.6 Badges — BadgeItem
create table public.badges (
  id          bigserial primary key,
  name        text not null unique,
  icon        text not null default '🏆',
  min_points  int  not null default 0 check (min_points >= 0 and min_points <= 1000000),
  created_at  timestamptz not null default now()
);

create table public.user_badges (
  user_id   uuid   not null references public.profiles(id) on delete cascade,
  badge_id  bigint not null references public.badges(id)   on delete cascade,
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

-- 1.7 Activity — Activity (points history)
create table public.activity (
  id         bigserial primary key,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  kind       text not null default 'deposit' check (kind in ('deposit', 'badge', 'voucher', 'other')),
  title      text not null,
  points     int  not null default 0,
  created_at timestamptz not null default now()
);
create index activity_user_idx on public.activity(user_id, created_at desc);

-- 1.8 Printing vouchers — Voucher
create table public.vouchers (
  id           bigserial primary key,
  code         text not null unique,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  user_name    text not null,
  student_id   text not null,
  pesos        int  not null check (pesos > 0 and pesos <= 100),
  points_cost  int  not null check (points_cost >= 10 and points_cost <= 1000),
  price_bw     int  not null default 3,
  price_col    int  not null default 4,
  price_pic    int  not null default 5,
  req_bw       int,
  req_col      int,
  req_pic      int,
  status       text not null default 'Active' check (status in ('Active', 'Claimed')),
  issued_at    timestamptz not null default now(),
  expires_at   timestamptz not null,
  claimed_at   timestamptz,
  claimed_by   uuid references public.profiles(id) on delete set null,
  printed_bw   int,
  printed_col  int,
  printed_pic  int,
  cost         int,
  cash         int
);
create index vouchers_user_idx   on public.vouchers(user_id, issued_at desc);
create index vouchers_status_idx on public.vouchers(status);

-- 1.9 Voucher log — LogEntry
create table public.voucher_log (
  id         bigserial primary key,
  user_name  text not null,
  voucher    text not null,
  created_at timestamptz not null default now()
);

-- 1.10 Settings — VoucherCfg, points per item, prices
create table public.settings (
  key   text primary key,
  value jsonb not null
);


-- ============================================================================
-- 2. HELPER FUNCTIONS
-- ============================================================================
create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select auth.uid() is not null;
$$;

create or replace function public.is_staff() returns boolean
language sql security definer stable set search_path = public as $$
  select auth.uid() is not null;
$$;

create or replace function public.setting_int(p_key text, p_default int) returns int
language sql stable set search_path = public as $$
  select coalesce((select (value #>> '{}')::int from public.settings where key = p_key), p_default);
$$;

create or replace function public.setting_text(p_key text, p_default text) returns text
language sql stable set search_path = public as $$
  select coalesce((select value #>> '{}' from public.settings where key = p_key), p_default);
$$;


-- ============================================================================
-- 3. SIGN-UP TRIGGER & GUARDS
-- ============================================================================
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, student_id, name, gender)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'student_id', ''), split_part(new.email, '@', 1)),
    coalesce(nullif(new.raw_user_meta_data->>'name', ''), 'Eco Warrior'),
    case when new.raw_user_meta_data->>'gender' in ('Girl', 'Boy')
         then new.raw_user_meta_data->>'gender' else '' end
  );
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.guard_profile_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if current_setting('smartbin.rpc', true) = '1'
     or auth.uid() is null
     or public.is_admin() then
    return new;
  end if;
  if new.role            is distinct from old.role
  or new.points          is distinct from old.points
  or new.lifetime_points is distinct from old.lifetime_points
  or new.items           is distinct from old.items
  or new.student_id      is distinct from old.student_id then
    raise exception 'You are not allowed to change role, points, or student ID';
  end if;
  return new;
end $$;

create trigger profiles_guard before update on public.profiles
  for each row execute function public.guard_profile_update();


-- ============================================================================
-- 4. BUSINESS RPCs
-- ============================================================================

-- 4.1 Bin test deposit (simulation)
create or replace function public.bin_test_deposit(p_bin_id bigint, p_kind text, p_weight int)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  b public.bins;
  c public.bin_compartments;
  v_pts int;
  v_nonce text;
  v_tid bigint;
  v_label text;
  v_type text; v_msg text;
begin
  if not public.is_staff() then raise exception 'Staff only'; end if;
  select * into b from public.bins where id = p_bin_id;
  if not found then raise exception 'Bin not found'; end if;

  v_label := case p_kind when 'rec' then '♻ Recyclable' when 'non' then '🚫 Non-biodegradable' else 'Invalid waste' end;

  if not b.is_on then
    v_type := 'off'; v_msg := 'Bin is switched off';
  elsif p_kind = 'bad' or p_weight < 2 then
    v_type := 'rej';
    v_msg  := case when p_kind = 'bad' then 'Invalid waste' else 'No item detected' end
              || ' - item sent to reject passage';
  else
    select * into c from public.bin_compartments where bin_id = b.id and kind = p_kind for update;
    if c.fill >= 95 then
      v_type := 'full'; v_msg := v_label || ' compartment is full';
    else
      update public.bin_compartments set fill = least(100, fill + 3), updated_at = now()
      where bin_id = b.id and kind = p_kind;
      v_pts   := public.setting_int('points_' || p_kind, 10);
      v_nonce := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
      insert into public.deposit_tokens (nonce, bin_id, kind, points, is_test)
      values (v_nonce, b.id, p_kind, v_pts, true)
      returning id into v_tid;
      v_type := 'ok';
      v_msg  := v_label || ' accepted (SIMULATED TEST). Scan to test simulation +' || v_pts || ' pts';
    end if;
  end if;

  insert into public.bin_events (bin_id, bin_name, type, message, weight, token_id)
  values (b.id, b.name, v_type, v_msg, p_weight, v_tid);

  return jsonb_build_object('type', v_type, 'msg', v_msg, 'nonce', v_nonce,
                            'token', case when v_nonce is null then null else 'SB_TEST.' || v_nonce end);
end $$;

-- 4.2 Create real deposit token (hardware gateway / service role)
create or replace function public.create_deposit_token(p_bin_id bigint, p_kind text, p_weight int default 10)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  b public.bins; c public.bin_compartments;
  v_nonce text; v_pts int; v_label text; v_tid bigint;
begin
  select * into b from public.bins where id = p_bin_id;
  if not found then raise exception 'Bin not found'; end if;
  v_label := case p_kind when 'rec' then '♻ Recyclable' else '🚫 Non-biodegradable' end;

  if not b.is_on then
    insert into public.bin_events (bin_id, bin_name, type, message, weight) values (b.id, b.name, 'off', 'Bin is switched off', p_weight);
    return jsonb_build_object('type', 'off');
  end if;
  if p_kind not in ('rec', 'non') or p_weight < 2 then
    insert into public.bin_events (bin_id, bin_name, type, message, weight)
    values (b.id, b.name, 'rej', 'Item sent to reject passage', p_weight);
    return jsonb_build_object('type', 'rej');
  end if;
  select * into c from public.bin_compartments where bin_id = b.id and kind = p_kind for update;
  if c.fill >= 95 then
    insert into public.bin_events (bin_id, bin_name, type, message, weight)
    values (b.id, b.name, 'full', v_label || ' compartment is full', p_weight);
    return jsonb_build_object('type', 'full');
  end if;

  update public.bin_compartments set fill = least(100, fill + 3), updated_at = now()
  where bin_id = b.id and kind = p_kind;
  v_pts   := public.setting_int('points_' || p_kind, 10);
  v_nonce := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  insert into public.deposit_tokens (nonce, bin_id, kind, points) values (v_nonce, b.id, p_kind, v_pts)
  returning id into v_tid;
  insert into public.bin_events (bin_id, bin_name, type, message, weight, token_id)
  values (b.id, b.name, 'ok', v_label || ' accepted. +' || v_pts || ' pts', p_weight, v_tid);
  return jsonb_build_object('type', 'ok', 'token', 'SB1.' || v_nonce, 'nonce', v_nonce, 'points', v_pts);
end $$;

-- 4.3 Redeem deposit QR
create or replace function public.redeem_deposit(p_code text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  u uuid := auth.uid();
  v_nonce text;
  t public.deposit_tokens;
  v_label text;
  v_life int;
  v_new text[] := '{}';
  bd record;
begin
  if u is null then raise exception 'Not authenticated'; end if;
  p_code := trim(p_code);
  if p_code like 'SBV%' then
    return jsonb_build_object('ok', false, 'msg', 'This is a voucher QR. Only PSITS staff scan it, at the PSITS office.');
  end if;
  v_nonce := regexp_replace(p_code, '^(SB1|SB_TEST)\.', '');

  select * into t from public.deposit_tokens where nonce = v_nonce for update;
  if not found then
    return jsonb_build_object('ok', false, 'msg', 'Invalid QR code');
  elsif t.used_at is not null then
    return jsonb_build_object('ok', false, 'msg', 'This QR was already claimed');
  elsif t.expires_at < now() then
    return jsonb_build_object('ok', false, 'msg', 'This QR expired. Deposit again for a new one.');
  end if;

  update public.deposit_tokens set used_at = now(), used_by = u where id = t.id;
  v_label := case t.kind when 'rec' then '♻ Recyclable' else '🚫 Non-biodegradable' end;

  if t.is_test then
    return jsonb_build_object('ok', true, 'test', true, 'new_badges', '[]'::jsonb,
      'msg', 'SIMULATED TEST — NOT A REAL DEPOSIT' || E'\n' ||
             'Test deposit processed successfully. (+' || t.points || ' test pts - no production points awarded)');
  end if;

  perform set_config('smartbin.rpc', '1', true);
  update public.profiles
     set points = points + t.points,
         lifetime_points = lifetime_points + t.points,
         items = items + 1
   where id = u
   returning lifetime_points into v_life;

  insert into public.activity (user_id, kind, title, points)
  values (u, 'deposit', 'Deposited ' || v_label, t.points);

  for bd in
    select b.* from public.badges b
    where b.min_points <= v_life
      and not exists (select 1 from public.user_badges ub where ub.user_id = u and ub.badge_id = b.id)
    order by b.min_points
  loop
    insert into public.user_badges (user_id, badge_id) values (u, bd.id);
    insert into public.activity (user_id, kind, title, points)
    values (u, 'badge', 'Badge unlocked: ' || bd.name, 0);
    v_new := v_new || (bd.icon || ' ' || bd.name);
  end loop;

  return jsonb_build_object('ok', true, 'test', false,
    'msg', '+' || t.points || ' pts - ' || v_label,
    'new_badges', to_jsonb(v_new));
end $$;

-- 4.4 Generate printing voucher
create or replace function public.generate_voucher(
  p_pesos int, p_req_bw int default null, p_req_col int default null, p_req_pic int default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  u uuid := auth.uid();
  p public.profiles;
  v_rate int := public.setting_int('voucher_rate', 10);
  v_min  int := public.setting_int('voucher_min', 1);
  v_max  int := public.setting_int('voucher_max', 100);
  v_days int := public.setting_int('voucher_days', 3);
  pr_bw  int := public.setting_int('price_bw', 3);
  pr_col int := public.setting_int('price_col', 4);
  pr_pic int := public.setting_int('price_pic', 5);
  v_need int;
  v_code text;
  v public.vouchers;
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if u is null then raise exception 'Not authenticated'; end if;
  v_need := p_pesos * v_rate;
  if p_pesos <= 0 or p_pesos < v_min or p_pesos > v_max or p_pesos > 100 or v_need < 10 or v_need > 1000 then
    return jsonb_build_object('ok', false,
      'error', 'Warning! Limit Exceeded! Pesos must be 1–100 and points must be 10–1000.');
  end if;
  if p_pesos < pr_bw then
    return jsonb_build_object('ok', false, 'error', 'The cheapest page costs ₱' || pr_bw);
  end if;

  select * into p from public.profiles where id = u for update;
  if p.points < v_need then
    return jsonb_build_object('ok', false, 'error', 'Not enough points (need ' || v_need || ')');
  end if;

  loop
    v_code := 'SBV.' || (
      select string_agg(substr(alphabet, 1 + floor(random() * 32)::int, 1), '')
      from generate_series(1, 8));
    exit when not exists (select 1 from public.vouchers where code = v_code);
  end loop;

  perform set_config('smartbin.rpc', '1', true);
  update public.profiles set points = points - v_need where id = u;

  insert into public.vouchers (code, user_id, user_name, student_id, pesos, points_cost,
                               price_bw, price_col, price_pic, req_bw, req_col, req_pic, expires_at)
  values (v_code, u, p.name, p.student_id, p_pesos, v_need,
          pr_bw, pr_col, pr_pic, p_req_bw, p_req_col, p_req_pic, now() + make_interval(days => v_days))
  returning * into v;

  insert into public.activity (user_id, kind, title, points)
  values (u, 'voucher', 'Printing voucher ₱' || p_pesos, -v_need);
  insert into public.voucher_log (user_name, voucher)
  values (p.name, 'Printing voucher ₱' || p_pesos);

  return jsonb_build_object('ok', true, 'voucher', to_jsonb(v));
end $$;

-- 4.5 Verify voucher
create or replace function public.verify_voucher(p_code text)
returns jsonb
language plpgsql security definer stable set search_path = public as $$
declare v public.vouchers; v_state text;
begin
  if not public.is_staff() then raise exception 'Staff only'; end if;
  select * into v from public.vouchers where code = trim(p_code);
  if not found then
    return jsonb_build_object('ok', false, 'label', 'UNKNOWN OR INVALID VOUCHER');
  end if;
  v_state := case when v.status = 'Claimed' then 'Claimed'
                  when v.expires_at < now()  then 'Expired'
                  else 'Active' end;
  return jsonb_build_object(
    'ok',    v_state = 'Active',
    'state', v_state,
    'label', case v_state when 'Active' then 'AVAILABLE' when 'Claimed' then 'ALREADY REDEEMED' else 'EXPIRED' end,
    'voucher', to_jsonb(v));
end $$;

-- 4.6 Claim voucher
create or replace function public.claim_voucher(p_code text, p_bw int, p_col int, p_pic int)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v public.vouchers; v_cost int;
begin
  if not public.is_staff() then raise exception 'Staff only'; end if;
  if coalesce(p_bw, 0) < 0 or coalesce(p_col, 0) < 0 or coalesce(p_pic, 0) < 0 then
    return jsonb_build_object('ok', false, 'error', 'Page counts cannot be negative');
  end if;
  select * into v from public.vouchers where code = trim(p_code) for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'Voucher not found'); end if;
  if v.status <> 'Active' or v.expires_at < now() then
    return jsonb_build_object('ok', false, 'error', 'Voucher is not active');
  end if;
  v_cost := p_bw * v.price_bw + p_col * v.price_col + p_pic * v.price_pic;
  update public.vouchers
     set status = 'Claimed', claimed_at = now(), claimed_by = auth.uid(),
         printed_bw = p_bw, printed_col = p_col, printed_pic = p_pic,
         cost = v_cost, cash = greatest(0, v_cost - v.pesos)
   where id = v.id
   returning * into v;
  return jsonb_build_object('ok', true, 'voucher', to_jsonb(v));
end $$;

-- 4.7 Leaderboard
create or replace function public.get_leaderboard(p_kind text default 'p', p_limit int default 10)
returns table (student_id text, name text, value int)
language sql security definer stable set search_path = public as $$
  select pr.student_id, pr.name,
         case when p_kind = 'i' then pr.items else pr.lifetime_points end as value
  from public.profiles pr
  where pr.role = 'user'
  order by value desc, pr.created_at
  limit greatest(1, least(p_limit, 100));
$$;

-- 4.8 Weekly deposits
create or replace function public.weekly_deposits()
returns table (dow int, total bigint)
language sql security definer stable set search_path = public as $$
  select d.dow, coalesce(count(a.id), 0)
  from generate_series(0, 6) as d(dow)
  left join public.activity a
         on a.kind = 'deposit' and a.points > 0
        and a.created_at >= now() - interval '7 days'
        and extract(dow from a.created_at)::int = d.dow
  where public.is_staff()
  group by d.dow
  order by d.dow;
$$;

-- 4.9 Dashboard stats
create or replace function public.dashboard_stats()
returns jsonb
language sql security definer stable set search_path = public as $$
  select case when public.is_staff() then jsonb_build_object(
    'users',     (select count(*) from public.profiles where role = 'user'),
    'bins',      (select count(*) from public.bins),
    'items',     (select coalesce(sum(items), 0) from public.profiles),
    'rejected',  (select count(*) from public.bin_events where type = 'rej'),
    'vouchers',  (select count(*) from public.vouchers),
    'claimed',   (select count(*) from public.vouchers where status = 'Claimed')
  ) end;
$$;

-- Permissions for RPCs
revoke all on function public.create_deposit_token(bigint, text, int) from public, anon, authenticated;
grant execute on function public.create_deposit_token(bigint, text, int) to service_role;

revoke execute on function public.redeem_deposit(text)                        from public, anon;
revoke execute on function public.generate_voucher(int, int, int, int)        from public, anon;
revoke execute on function public.verify_voucher(text)                        from public, anon;
revoke execute on function public.claim_voucher(text, int, int, int)          from public, anon;
revoke execute on function public.bin_test_deposit(bigint, text, int)         from public, anon;
revoke execute on function public.get_leaderboard(text, int)                  from public, anon;
revoke execute on function public.weekly_deposits()                           from public, anon;
revoke execute on function public.dashboard_stats()                           from public, anon;

grant execute on function public.redeem_deposit(text)                         to authenticated;
grant execute on function public.generate_voucher(int, int, int, int)         to authenticated;
grant execute on function public.verify_voucher(text)                         to authenticated;
grant execute on function public.claim_voucher(text, int, int, int)           to authenticated;
grant execute on function public.bin_test_deposit(bigint, text, int)          to authenticated;
grant execute on function public.get_leaderboard(text, int)                   to authenticated;
grant execute on function public.weekly_deposits()                            to authenticated;
grant execute on function public.dashboard_stats()                            to authenticated;


-- ============================================================================
-- 5. ROW LEVEL SECURITY
-- ============================================================================
alter table public.profiles          enable row level security;
alter table public.bins              enable row level security;
alter table public.bin_compartments  enable row level security;
alter table public.bin_events        enable row level security;
alter table public.deposit_tokens    enable row level security;
alter table public.badges            enable row level security;
alter table public.user_badges       enable row level security;
alter table public.activity          enable row level security;
alter table public.vouchers          enable row level security;
alter table public.voucher_log       enable row level security;
alter table public.settings          enable row level security;

create policy "profiles_select" on public.profiles for select using (auth.uid() = id or public.is_staff());
create policy "profiles_update" on public.profiles for update using (auth.uid() = id or public.is_admin());

create policy "bins_read"   on public.bins for select using (true);
create policy "bins_write"  on public.bins for all using (true) with check (true);
create policy "comps_read"  on public.bin_compartments for select using (true);
create policy "comps_write" on public.bin_compartments for all using (true) with check (true);

create policy "events_read"   on public.bin_events for select using (public.is_staff());
create policy "events_delete" on public.bin_events for delete using (public.is_staff());

create policy "badges_read"  on public.badges for select using (true);
create policy "badges_write" on public.badges for all using (true) with check (true);
create policy "user_badges_read" on public.user_badges for select using (user_id = auth.uid() or public.is_staff());

create policy "activity_read" on public.activity for select using (user_id = auth.uid() or public.is_staff());

create policy "vouchers_read" on public.vouchers for select using (user_id = auth.uid() or public.is_staff());

create policy "log_read"   on public.voucher_log for select using (public.is_staff());
create policy "log_delete" on public.voucher_log for delete using (public.is_staff());

create policy "settings_read"  on public.settings for select using (true);
create policy "settings_write" on public.settings for all using (true) with check (true);

create policy "tokens_staff_read" on public.deposit_tokens for select using (public.is_staff() and used_at is not null);


-- ============================================================================
-- 6. REALTIME
-- ============================================================================
do $$
declare t text;
begin
  foreach t in array array['bins', 'bin_compartments', 'bin_events', 'profiles', 'activity', 'vouchers', 'voucher_log', 'badges', 'settings']
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;


-- ============================================================================
-- 7. SEED DATA
-- ============================================================================
insert into public.bins (name, location) values ('SmartBin 01', 'CICI Lobby');

insert into public.badges (name, icon, min_points) values
  ('First Drop',        '🌱', 10),
  ('Eco Starter',       '♻',  50),
  ('Green Helper',      '🌿', 150),
  ('Recycler Pro',      '🏅', 300),
  ('Planet Guardian',   '🛡', 600),
  ('Zero Waste Legend', '🏆', 1000);

insert into public.settings (key, value) values
  ('points_rec',   '10'::jsonb),
  ('points_non',   '10'::jsonb),
  ('price_bw',     '3'::jsonb),
  ('price_col',    '4'::jsonb),
  ('price_pic',    '5'::jsonb),
  ('voucher_rate', '10'::jsonb),
  ('voucher_min',  '1'::jsonb),
  ('voucher_max',  '100'::jsonb),
  ('voucher_days', '3'::jsonb),
  ('voucher_title',  '"SmartBin Reward Voucher"'::jsonb),
  ('voucher_office', '"PSITS Office"'::jsonb),
  ('voucher_note',   '"Present this voucher at the PSITS office to claim. One use only."'::jsonb),
  ('voucher_color',  '"0xFF1FA443"'::jsonb);

-- ============================================================================
-- DONE.
-- ============================================================================
