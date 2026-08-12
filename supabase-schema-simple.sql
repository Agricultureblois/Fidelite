-- VERSION SIMPLE SANS FONCTIONS $$
-- À lancer dans Supabase SQL Editor en une seule fois.
-- Cette version évite les erreurs de dollar-quoted string.

create extension if not exists pgcrypto with schema extensions;

create table if not exists members (
  id uuid primary key default gen_random_uuid(),
  first_name text not null,
  last_name text,
  phone text not null unique,
  code text not null unique,
  points integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table members add column if not exists last_name text;

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
  pin text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table members enable row level security;
alter table visits enable row level security;
alter table ranks enable row level security;
alter table daily_menu enable row level security;
alter table admin_users enable row level security;

drop policy if exists "members_all" on members;
drop policy if exists "visits_all" on visits;
drop policy if exists "ranks_read" on ranks;
drop policy if exists "menu_read" on daily_menu;
drop policy if exists "admins_read" on admin_users;

create policy "members_all" on members for all using (true) with check (true);
create policy "visits_all" on visits for all using (true) with check (true);
create policy "ranks_read" on ranks for all using (true) with check (true);
create policy "menu_read" on daily_menu for all using (true) with check (true);
create policy "admins_read" on admin_users for all using (true) with check (true);

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

insert into admin_users (name, pin)
select 'Admin principal', '1900'
where not exists (select 1 from admin_users);
