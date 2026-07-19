# Supabase deployment notes

Apply migrations with the Supabase CLI against a disposable development project before any shared environment. The first migration creates the RLS-protected Wake9u domain, generated GraphQL-readable views, and narrow `SECURITY DEFINER` mutation functions. Client code must use the views/functions and must not receive table write privileges.

The minute-level scheduler should invoke `public.mark_overdue_occurrences()` using a service-only scheduler role. Occurrence horizon generation is deliberately not placed in this initial migration: local-day/DST resolution must be implemented and fixture-tested as a versioned server function before it is enabled in production.

Before deployment, configure an Auth hook or confirm the `auth.users` profile trigger has been approved for the target Supabase project. Seed a published remote configuration with at least `{"thresholds":{"phoneSteps":10}}` before arming any schedule.
