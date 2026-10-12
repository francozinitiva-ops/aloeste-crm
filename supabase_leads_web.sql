-- ═══════════════════════════════════════════════════════════════════
-- OCRE · CRM — las consultas del formulario de la web entran solas
-- como leads del CRM.
-- Cada fila nueva en public.leads (la tabla de la web) crea un lead
-- en crm_leads con el siguiente número LEA-xxxx, etapa «Nuevo»,
-- canal «Web» y seguimiento para hoy. El CRM lo muestra en el momento.
-- Se puede volver a correr sin duplicar nada.
-- ═══════════════════════════════════════════════════════════════════

create or replace function public.crm_lead_desde_web()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  n        int;
  nuevo_id text;
  hoy      text := to_char((now() at time zone 'America/Argentina/San_Juan')::date, 'YYYY-MM-DD');
  norm_exp text := lower(translate(coalesce(new.experiencia_de_interes,''), 'ÁÉÍÓÚÜáéíóúü', 'AEIOUUaeiouu'));
  dest     text;
begin
  -- ya importado (por ejemplo, si se vuelve a correr la carga inicial)
  if exists (select 1 from crm_leads where data->>'webLeadId' = new.id::text) then
    return new;
  end if;

  -- un número por vez, aunque entren dos consultas juntas
  perform pg_advisory_xact_lock(hashtext('crm_numeracion_LEA'));
  select greatest(
           coalesce((select (data->>'LEA')::int from crm_meta where clave = 'cont'), 0),
           coalesce((select max(substring(id from 5)::int) from crm_leads where id ~ '^LEA-[0-9]+$'), 0)
         ) + 1 into n;
  nuevo_id := 'LEA-' || lpad(n::text, 4, '0');

  -- destino: el del catálogo cuyo nombre aparezca en la experiencia elegida (el más largo)
  if norm_exp <> '' then
    select id into dest from crm_destinos
     where length(data->>'nombre') >= 4
       and norm_exp like '%' || lower(translate(data->>'nombre', 'ÁÉÍÓÚÜáéíóúü', 'AEIOUUaeiouu')) || '%'
     order by length(data->>'nombre') desc
     limit 1;
  end if;

  insert into crm_leads (id, data) values (nuevo_id, jsonb_build_object(
    'id', nuevo_id,
    'nombre', coalesce(nullif(btrim(new.nombre), ''), '(sin nombre)'),
    'telefono', coalesce(new.telefono, ''),
    'email', coalesce(new.email, ''),
    'localidad', '',
    'canal', 'Web',
    'referidoPor', '',
    'destinoId', coalesce(dest, ''),
    'interes', coalesce(new.experiencia_de_interes, ''),
    'fechaViaje', '',
    'pax', '',
    'presupuesto', '',
    'etapa', 'Nuevo',
    'proxSeg', hoy,
    'motivoPerdida', '',
    'notas', coalesce(new.mensaje, ''),
    'alta', hoy,
    'historial', jsonb_build_array(jsonb_build_object(
        'fecha', hoy, 'auto', 1,
        'texto', 'Consulta recibida desde el formulario de la web.')),
    'webLeadId', new.id::text
  ));

  -- el contador del CRM nunca queda por debajo del número usado
  insert into crm_meta (clave, data) values ('cont', jsonb_build_object('LEA', n))
  on conflict (clave) do update
    set data = jsonb_set(crm_meta.data, '{LEA}',
                 to_jsonb(greatest(n, coalesce((crm_meta.data->>'LEA')::int, 0))));
  return new;
exception when others then
  -- si algo falla, la consulta de la web se guarda igual; el aviso queda en los logs
  raise warning 'crm_lead_desde_web: % (lead web %)', sqlerrm, new.id;
  return new;
end;
$$;
revoke all on function public.crm_lead_desde_web() from public, anon, authenticated;

drop trigger if exists crm_lead_desde_web on public.leads;
create trigger crm_lead_desde_web
  after insert on public.leads
  for each row execute function public.crm_lead_desde_web();
