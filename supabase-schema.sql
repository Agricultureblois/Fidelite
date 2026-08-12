create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- Fonctions supprimées avant recréation, utile si une ancienne tentative a échoué à moitié.
drop function if exists admin_dashboard(text);
drop function if exists admin_replace_ranks(text, jsonb);
drop function if exists admin_create_admin(text, text, text);
drop function if exists admin_update_menu(text, text, text, text, text);
drop function if exists admin_add_visit(text, text, integer);
drop function if exists admin_check_pin(text);
drop function if exists get_member_by_code(text);
drop function if exists register_member(text, text);
drop function if exists member_json(members);
drop function if exists public_menu();
drop function if exists public_ranks();
drop function if exists private_admin_ok(text);

create table if not exists members (
  id uuid primary key default gen_random_uuid(),
  first_name text not null,
  phone text not null unique,
  code text not null unique,
  points integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists visits (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references members(id) on delete cascade,
  amount integer not null,
  points integer not null,
  created_at timestamptz not null default now()
);

create table if not exists ranks (
  id bigserial primary key,
  name text not null,
  points_required integer not null,
  reward text not null,
  sort_order integer not null
);

create table if not exists daily_menu (
  id integer primary key default 1,
  starter text not null,
  main text not null,
  dessert text not null,
  price text not null,
  updated_at timestamptz not null default now(),
  constraint one_menu check (id = 1)
);

create table if not exists admin_users (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  pin_hash text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table members enable row level security;
alter table visits enable row level security;
alter table ranks enable row level security;
alter table daily_menu enable row level security;
alter table admin_users enable row level security;

delete from ranks;

insert into ranks (name, points_required, reward, sort_order) values
('Stagiaire',0,'Carte créée : café offert après la première visite créditée',1),
('Apprenti',100,'Un café ou un thé offert, environ après 5 menus du jour',2),
('Plongeur',250,'Un verre de vin de Loire ou un soft maison offert',3),
('Commis de cuisine',450,'Dessert du jour offert sur un menu entrée-plat-dessert',4),
('Serveur',700,'Apéritif maison offert pour deux personnes',5),
('Chef de rang',1000,'10 EUR de remise sur l''addition',6),
('Sous-chef',1400,'Un menu du jour à 19,90 EUR offert',7),
('Chef de cuisine',1900,'Deux menus du jour à -50%',8),
('Directeur du restaurant',2500,'Table privilégiée : deux coupes offertes et menu du jour offert pour deux',9);

insert into daily_menu (id, starter, main, dessert, price) values
(1,'Velouté de saison, éclats de noisette','Suprême de volaille, jus corsé et pommes fondantes','Tarte fine aux pommes, crème légère','19,90 EUR')
on conflict (id) do update set
  starter = excluded.starter,
  main = excluded.main,
  dessert = excluded.dessert,
  price = excluded.price,
  updated_at = now();

insert into admin_users (name, pin_hash)
select 'Admin principal', extensions.crypt('1900', extensions.gen_salt('bf'))
where not exists (select 1 from admin_users);

create or replace function private_admin_ok(p_pin text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists(select 1 from admin_users where active = true and pin_hash = extensions.crypt(p_pin, pin_hash));
$$;

create or replace function public_ranks()
returns table(name text, points_required integer, reward text, sort_order integer)
language sql
security definer
set search_path = public
as $$
  select name, points_required, reward, sort_order from ranks order by sort_order;
$$;

create or replace function public_menu()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select to_jsonb(daily_menu) from daily_menu where id = 1;
$$;

create or replace function member_json(m members)
returns jsonb
language sql
security definer
set search_path = public
as $$
select jsonb_build_object(
  'id', m.id,
  'first_name', m.first_name,
  'phone', m.phone,
  'code', m.code,
  'points', m.points,
  'visits', coalesce((select jsonb_agg(to_jsonb(v) order by v.created_at) from visits v where v.member_id = m.id), '[]'::jsonb)
);
$$;

create or replace function register_member(p_first_name text, p_phone text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare m members; clean_phone text; new_code text;
begin
  clean_phone := regexp_replace(coalesce(p_phone,''), '[^0-9+]', '', 'g');
  if length(clean_phone) < 8 then raise exception 'Téléphone invalide'; end if;
  new_code := 'AGRI-' || regexp_replace(clean_phone, '[^0-9]', '', 'g');
  insert into members(first_name, phone, code)
  values (trim(p_first_name), clean_phone, new_code)
  on conflict (phone) do update set first_name = excluded.first_name, updated_at = now()
  returning * into m;
  return member_json(m);
end;
$$;

create or replace function get_member_by_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare m members;
begin
  select * into m from members where code = upper(trim(p_code));
  if not found then return null; end if;
  return member_json(m);
end;
$$;

create or replace function admin_check_pin(p_pin text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select private_admin_ok(p_pin);
$$;

create or replace function admin_add_visit(p_pin text, p_code text, p_amount integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare m members; pts integer;
begin
  if not private_admin_ok(p_pin) then raise exception 'Accès admin refusé'; end if;
  pts := greatest(0, round(p_amount)::integer);
  select * into m from members where code = upper(trim(p_code));
  if not found then raise exception 'Client introuvable'; end if;
  insert into visits(member_id, amount, points) values (m.id, pts, pts);
  update members set points = points + pts, updated_at = now() where id = m.id returning * into m;
  return member_json(m);
end;
$$;

create or replace function admin_update_menu(p_pin text, p_starter text, p_main text, p_dessert text, p_price text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not private_admin_ok(p_pin) then raise exception 'Accès admin refusé'; end if;
  update daily_menu set starter=p_starter, main=p_main, dessert=p_dessert, price=p_price, updated_at=now() where id=1;
  return public_menu();
end;
$$;

create or replace function admin_create_admin(p_pin text, p_name text, p_new_pin text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not private_admin_ok(p_pin) then raise exception 'Accès admin refusé'; end if;
  if length(coalesce(p_new_pin,'')) < 4 then raise exception 'PIN trop court'; end if;
  insert into admin_users(name, pin_hash) values (coalesce(nullif(trim(p_name),''),'Admin'), extensions.crypt(p_new_pin, extensions.gen_salt('bf')));
  return true;
end;
$$;

create or replace function admin_replace_ranks(p_pin text, p_ranks jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not private_admin_ok(p_pin) then raise exception 'Accès admin refusé'; end if;
  delete from ranks;
  insert into ranks(name, points_required, reward, sort_order)
  select r->>'name', (r->>'points_required')::integer, r->>'reward', row_number() over ()
  from jsonb_array_elements(p_ranks) r;
  return true;
end;
$$;

create or replace function admin_dashboard(p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not private_admin_ok(p_pin) then raise exception 'Accès admin refusé'; end if;
  return jsonb_build_object(
    'clients', (select count(*) from members),
    'points', (select coalesce(sum(points),0) from members),
    'visits', (select count(*) from visits),
    'admins', (select coalesce(jsonb_agg(jsonb_build_object('name', name)), '[]'::jsonb) from admin_users where active=true),
    'members', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'first_name', m.first_name,
        'phone', m.phone,
        'code', m.code,
        'points', m.points,
        'rank', coalesce((select r.name from ranks r where r.points_required <= m.points order by r.points_required desc limit 1), 'Stagiaire')
      ) order by m.points desc), '[]'::jsonb)
      from members m
    )
  );
end;
$$;

grant execute on all functions in schema public to anon, authenticated;
