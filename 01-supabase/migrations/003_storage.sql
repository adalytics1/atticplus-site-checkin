-- 003_storage.sql
-- Private photo bucket. Installers can upload into their own folder and
-- nothing else — no listing, no reading other people's photos, no deleting.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'site-photos',
  'site-photos',
  false,                      -- private. n8n mints long-lived signed URLs for GHL.
  1048576,                    -- 1 MB hard ceiling. Compressed photos target 250 KB;
                              -- anything near this ceiling means compression is broken.
  array['image/jpeg']
)
on conflict (id) do nothing;

-- Path convention: {installer_id}/{visit_id}/{clockin|clockout}.jpg
-- The first path segment is the installer's own id, which is what these
-- policies key on.

create policy site_photos_insert_own
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'site-photos'
    and (storage.foldername(name))[1] = public.current_installer_id()::text
  );

create policy site_photos_select_own
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'site-photos'
    and (storage.foldername(name))[1] = public.current_installer_id()::text
  );

-- Deliberately no update or delete policy. A photo is evidence; once uploaded
-- an installer cannot replace or remove it. Pruning at 12 months is done by
-- n8n with the service role — see 03-n8n/workflows/03-prune-old-photos.json.
