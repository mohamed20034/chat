-- Open Chat database setup
-- Run this entire script once in Supabase Dashboard > SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  room_id text not null,
  sender_id uuid not null references auth.users(id) on delete cascade,
  sender_name text not null check (char_length(sender_name) between 1 and 32),
  body text not null check (char_length(body) between 1 and 12000),
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_room_created_idx
  on public.chat_messages (room_id, created_at desc);

alter table public.chat_messages enable row level security;

-- Private-room bodies are encrypted in the browser before storage.
drop policy if exists "Chat users can read messages" on public.chat_messages;
create policy "Chat users can read messages"
  on public.chat_messages for select
  to authenticated
  using (true);

drop policy if exists "Users can send messages as themselves" on public.chat_messages;
create policy "Users can send messages as themselves"
  on public.chat_messages for insert
  to authenticated
  with check (auth.uid() = sender_id);

-- Enable Realtime events for new messages.
do $$
begin
  alter publication supabase_realtime add table public.chat_messages;
exception
  when duplicate_object then null;
end;
$$;
