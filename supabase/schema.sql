-- Open Chat database setup. Run the full script in Supabase SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.chat_messages (
 id uuid primary key default gen_random_uuid(),
 room_id text not null,
 sender_id uuid not null references auth.users(id) on delete cascade,
 sender_name text not null check (char_length(sender_name) between 1 and 32),
 body text not null check (char_length(body) between 1 and 12000),
 created_at timestamptz not null default now()
);
create index if not exists chat_messages_room_created_idx on public.chat_messages(room_id,created_at desc);
alter table public.chat_messages enable row level security;
drop policy if exists "Chat users can read messages" on public.chat_messages;
drop policy if exists "Users can send messages as themselves" on public.chat_messages;
drop policy if exists "Open Chat read messages" on public.chat_messages;
drop policy if exists "Open Chat send messages" on public.chat_messages;
create policy "Open Chat read messages" on public.chat_messages for select to authenticated using (true);
create policy "Open Chat send messages" on public.chat_messages for insert to authenticated with check (auth.uid()=sender_id);
grant select,insert on public.chat_messages to authenticated;

create table if not exists public.dm_conversations (
 id uuid primary key default gen_random_uuid(),
 user1 uuid not null references auth.users(id) on delete cascade,
 user2 uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 constraint dm_distinct_users check(user1<>user2),
 constraint dm_sorted_users check(user1<user2),
 constraint dm_unique_pair unique(user1,user2)
);
alter table public.dm_conversations enable row level security;
drop policy if exists "DM members can read conversations" on public.dm_conversations;
drop policy if exists "DM members can create conversations" on public.dm_conversations;
create policy "DM members can read conversations" on public.dm_conversations for select to authenticated using(auth.uid()=user1 or auth.uid()=user2);
create policy "DM members can create conversations" on public.dm_conversations for insert to authenticated with check(user1<user2 and auth.uid() in (user1,user2));
grant select,insert on public.dm_conversations to authenticated;

create table if not exists public.dm_messages (
 id uuid primary key default gen_random_uuid(),
 conversation_id uuid not null references public.dm_conversations(id) on delete cascade,
 sender_id uuid not null references auth.users(id) on delete cascade,
 sender_name text not null check(char_length(sender_name) between 1 and 32),
 body text not null check(char_length(body) between 1 and 12000),
 created_at timestamptz not null default now()
);
create index if not exists dm_messages_conversation_created_idx on public.dm_messages(conversation_id,created_at);
alter table public.dm_messages enable row level security;
drop policy if exists "DM members can read messages" on public.dm_messages;
drop policy if exists "DM members can send messages" on public.dm_messages;
create policy "DM members can read messages" on public.dm_messages for select to authenticated using(exists(select 1 from public.dm_conversations c where c.id=conversation_id and auth.uid() in(c.user1,c.user2)));
create policy "DM members can send messages" on public.dm_messages for insert to authenticated with check(auth.uid()=sender_id and exists(select 1 from public.dm_conversations c where c.id=conversation_id and auth.uid() in(c.user1,c.user2)));
grant select,insert on public.dm_messages to authenticated;
do $$ begin alter publication supabase_realtime add table public.chat_messages; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.dm_messages; exception when duplicate_object then null; end $$;
-- Private media bucket. Direct-message objects are readable only by conversation members.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('chat-media','chat-media',false,26214400,array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm','video/quicktime'])
on conflict(id) do update set public=false,file_size_limit=26214400,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists "Open Chat media read" on storage.objects;
drop policy if exists "Open Chat media upload" on storage.objects;
create policy "Open Chat media read" on storage.objects for select to authenticated
using(bucket_id='chat-media' and (
 (storage.foldername(name))[1]='public'
 or (storage.foldername(name))[1]='room'
 or ((storage.foldername(name))[1]='dm' and exists(
   select 1 from public.dm_conversations c
   where c.id::text=(storage.foldername(name))[2] and auth.uid() in(c.user1,c.user2)
 ))
));
create policy "Open Chat media upload" on storage.objects for insert to authenticated
with check(bucket_id='chat-media' and (
 (storage.foldername(name))[1] in ('public','room')
 or ((storage.foldername(name))[1]='dm' and exists(
   select 1 from public.dm_conversations c
   where c.id::text=(storage.foldername(name))[2] and auth.uid() in(c.user1,c.user2)
 ))
));
