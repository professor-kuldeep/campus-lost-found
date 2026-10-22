-- Run once in Supabase Dashboard > SQL Editor, on a NEW project.
-- Do not put service-role keys into your Next.js client.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '',
 role text not null default 'student' check(role in ('student','admin')),
 created_at timestamptz not null default now()
);
create table if not exists public.items (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 title text not null check(char_length(title) between 2 and 150),
 item_type text not null check(item_type in ('lost','found')),
 category text not null,
 description text not null check(char_length(description) between 5 and 2000),
 location text not null,
 incident_date date not null check(incident_date <= current_date),
 image_path text,
 status text not null check(status in ('lost','found','claim_pending','returned','closed')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint initial_item_status check ((item_type='lost' and status in ('lost','closed')) or item_type='found')
);
create index if not exists idx_items_date on public.items(created_at desc);
create index if not exists idx_items_filter on public.items(item_type,category,status);
create table if not exists public.claims (
 id uuid primary key default gen_random_uuid(),
 item_id uuid not null references public.items(id) on delete cascade,
 claimant_id uuid not null references public.profiles(id) on delete cascade,
 proof_description text not null check(char_length(proof_description) between 15 and 1000),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 reviewed_by uuid references public.profiles(id),
 created_at timestamptz not null default now(),
 reviewed_at timestamptz,
 unique(item_id,claimant_id)
);
create table if not exists public.status_history (
 id uuid primary key default gen_random_uuid(),
 item_id uuid not null references public.items(id) on delete cascade,
 changed_by uuid not null references public.profiles(id),
 old_status text,
 new_status text not null,
 changed_at timestamptz not null default now()
);
create table if not exists public.admin_logs (
 id uuid primary key default gen_random_uuid(),
 admin_id uuid not null references public.profiles(id),
 action text not null,
 created_at timestamptz not null default now()
);

-- Add profiles for newly authenticated students (server-side trigger).
create or replace function public.create_student_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.profiles(id,full_name,role)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),'student')
 on conflict(id) do nothing;
 return new;
end; $$;
drop trigger if exists auth_new_user_profile on auth.users;
create trigger auth_new_user_profile after insert on auth.users
for each row execute procedure public.create_student_profile();
-- Ensure profiles exist if auth users were registered before running this migration.
insert into public.profiles(id,full_name,role)
select id,coalesce(raw_user_meta_data->>'full_name',''),'student' from auth.users
on conflict(id) do nothing;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles where id=(select auth.uid()) and role='admin');
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

alter table public.profiles enable row level security;
alter table public.items enable row level security;
alter table public.claims enable row level security;
alter table public.status_history enable row level security;
alter table public.admin_logs enable row level security;

create policy "profiles self or admin read" on public.profiles for select to authenticated using(id=(select auth.uid()) or public.is_admin());
-- No client policies to update role or insert profiles; trigger and admin SQL are authoritative.
create policy "items browse" on public.items for select to anon,authenticated using(true);
create policy "items own insert" on public.items for insert to authenticated with check(user_id=(select auth.uid()) and status=item_type and image_path is null or user_id=(select auth.uid()) and status=item_type and image_path like (select auth.uid())::text || '/%');
-- Status modifications happen only via trusted review function.
create policy "claims own or admin read" on public.claims for select to authenticated using(claimant_id=(select auth.uid()) or public.is_admin());
create policy "claims claimant insert" on public.claims for insert to authenticated with check(
 claimant_id=(select auth.uid()) and status='pending' and reviewed_by is null and reviewed_at is null
 and exists(select 1 from public.items i where i.id=item_id and i.item_type='found' and i.status in('found','claim_pending') and i.user_id <> (select auth.uid()))
);
create policy "history own or admin read" on public.status_history for select to authenticated using(public.is_admin() or exists(select 1 from public.items i where i.id=item_id and i.user_id=(select auth.uid())));
create policy "logs admins read" on public.admin_logs for select to authenticated using(public.is_admin());

-- Atomic administrator-only review; no direct claim/item update policies are granted.
create or replace function public.review_ownership_claim(p_claim_id uuid,p_decision text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_claim public.claims%rowtype; v_item public.items%rowtype; v_new text;
begin
 if (select auth.uid()) is null or not public.is_admin() then raise exception 'Not authorized'; end if;
 if p_decision not in ('approved','rejected') then raise exception 'Invalid decision'; end if;
 select * into v_claim from public.claims where id=p_claim_id for update;
 if not found then raise exception 'Claim not found'; end if;
 if v_claim.status<>'pending' then raise exception 'This claim was already reviewed'; end if;
 select * into v_item from public.items where id=v_claim.item_id for update;
 if v_item.status='returned' or v_item.item_type<>'found' then raise exception 'Item not eligible'; end if;
 update public.claims set status=p_decision,reviewed_by=(select auth.uid()),reviewed_at=now() where id=p_claim_id;
 if p_decision='approved' then
   update public.claims set status='rejected',reviewed_by=(select auth.uid()),reviewed_at=now() where item_id=v_item.id and id<>p_claim_id and status='pending';
   v_new:='returned';
 else
   v_new:=case when exists(select 1 from public.claims where item_id=v_item.id and status='pending') then 'claim_pending' else 'found' end;
 end if;
 update public.items set status=v_new, updated_at=now() where id=v_item.id;
 insert into public.status_history(item_id,changed_by,old_status,new_status) values(v_item.id,(select auth.uid()),v_item.status,v_new);
 insert into public.admin_logs(admin_id,action) values((select auth.uid()),'Reviewed claim '||p_claim_id||' as '||p_decision);
end;$$;
revoke all on function public.review_ownership_claim(uuid,text) from public;
grant execute on function public.review_ownership_claim(uuid,text) to authenticated;

-- Automatically mark found items claim_pending upon first claim.
create or replace function public.mark_claim_pending()
returns trigger language plpgsql security definer set search_path='' as $$
declare previous text;
begin
 select status into previous from public.items where id=new.item_id for update;
 if previous='found' then
 update public.items set status='claim_pending' where id=new.item_id;
 insert into public.status_history(item_id,changed_by,old_status,new_status)
 values(new.item_id,new.claimant_id,'found','claim_pending');
 end if;
 return new;
end;$$;
drop trigger if exists new_claim_pending on public.claims;
create trigger new_claim_pending after insert on public.claims
for each row execute procedure public.mark_claim_pending();

-- Public photos: don't upload sensitive identification photos.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('item-images','item-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
create policy "own photo upload" on storage.objects for insert to authenticated
with check(bucket_id='item-images' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "own photo cleanup" on storage.objects for delete to authenticated
using(bucket_id='item-images' and (storage.foldername(name))[1]=(select auth.uid())::text
and not exists(select 1 from public.items where image_path=storage.objects.name));
