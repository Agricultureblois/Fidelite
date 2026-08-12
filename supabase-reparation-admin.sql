-- REPARATION ADMIN - ne supprime aucun client, ne touche pas aux points.
-- Remplace 4937 par ton code si tu veux un autre PIN.

insert into admin_users (name, pin, active)
select 'Admin principal', '4937', true
where not exists (select 1 from admin_users where active = true);

update admin_users
set pin = '4937',
    active = true
where active = true;

select admin_ok('4937') as code_admin_ok;
select admin_dashboard('4937') is not null as tableau_admin_ok;
