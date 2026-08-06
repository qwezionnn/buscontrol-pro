begin;

grant usage on schema public to authenticated;

grant select, insert, update, delete on table
  public.profiles,
  public.user_settings,
  public.vehicles,
  public.trips,
  public.trip_payouts,
  public.orders,
  public.order_payments,
  public.fuel_logs,
  public.expenses,
  public.daily_logs,
  public.maintenance_items,
  public.credits,
  public.credit_payments
to authenticated;

commit;
