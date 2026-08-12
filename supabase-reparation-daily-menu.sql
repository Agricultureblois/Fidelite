-- Réparation rapide si Supabase dit : relation "daily_menu" n'existe pas
create table if not exists daily_menu (
  id integer primary key default 1,
  starter text not null,
  main text not null,
  dessert text not null,
  price text not null,
  updated_at timestamptz not null default now(),
  constraint one_menu check (id = 1)
);

alter table daily_menu enable row level security;

insert into daily_menu (id, starter, main, dessert, price) values
(1, 'Velouté de saison, éclats de noisette', 'Suprême de volaille, jus corsé et pommes fondantes', 'Tarte fine aux pommes, crème légère', '19,90 EUR')
on conflict (id) do nothing;
