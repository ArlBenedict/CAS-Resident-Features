create or replace function public.estimate_utility_recipients(
  p_utility text,
  p_city text,
  p_area_labels text[]
)
returns table (
  email_recipients bigint,
  sms_recipients bigint,
  total_resident_accounts bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'admin'
      and utility = p_utility
  ) then
    raise exception 'A matching utility administrator must sign in.'
      using errcode = '42501';
  end if;

  return query
  select
    count(*) filter (where nullif(trim(profiles.email), '') is not null),
    count(*),
    count(*)
  from public.profiles as profiles
  join public.puroks as puroks on puroks.id = profiles.purok_id
  join public.barangays as barangays on barangays.id = profiles.barangay_id
  where profiles.role = 'resident'
    and barangays.city = p_city
    and barangays.name || ' · ' || puroks.name = any(coalesce(p_area_labels, array[]::text[]));
end;
$$;

revoke all on function public.estimate_utility_recipients(text, text, text[]) from public;
revoke all on function public.estimate_utility_recipients(text, text, text[]) from anon;
grant execute on function public.estimate_utility_recipients(text, text, text[]) to authenticated;
