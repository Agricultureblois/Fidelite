create or replace function protect_member_points()
returns trigger
language plpgsql
as E'
begin
  if current_user in (''anon'', ''authenticated'') then
    if tg_op = ''INSERT'' then
      new.points := 0;
    elsif tg_op = ''UPDATE'' and new.points <> old.points then
      new.points := old.points;
    end if;
  end if;

  return new;
end;
';

drop trigger if exists protect_member_points_trigger on members;

create trigger protect_member_points_trigger
before insert or update on members
for each row
execute function protect_member_points();

drop policy if exists "members_public_select" on members;
drop policy if exists "members_public_insert" on members;
drop policy if exists "members_public_update_profile" on members;

create policy "members_public_select"
on members for select
using (true);

create policy "members_public_insert"
on members for insert
with check (true);

create policy "members_public_update_profile"
on members for update
using (true)
with check (true);

select 'OK inscription client debloquee' as resultat;
