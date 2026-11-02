-- scripts/lab5/15-reto-alerta.sql — reto de la Parte P: consultas que solo devuelven fila cuando hay que despertar a alguien
-- SQLcl · C##OPS_RO · servicio FREE. Uso: bash scripts/ops/ro.sh scripts/lab5/15-reto-alerta.sql
-- Un sistema de alertas ejecuta cada consulta cada pocos minutos: 0 filas = todo bien, 1 fila = aviso.
@scripts/ops/marca
SPOOL docs/bitacora/lab5/evidencia/spool/&marca._15-reto-alerta.spool.log
SET SQLFORMAT DEFAULT
SET LINESIZE 160 PAGESIZE 50 FEEDBACK ON VERIFY OFF
COLUMN alerta FORMAT A90
PROMPT == 1. FRA por encima del umbral (sección 3 del healthcheck). Umbral real: 85 % ==
DEFINE umbral = 85
SELECT 'ALERTA: FRA al ' || ROUND(100 * (space_used - space_reclaimable) / space_limit, 1) || ' % (umbral &umbral %)' AS alerta
  FROM v$recovery_file_dest
 WHERE space_limit > 0 AND 100 * (space_used - space_reclaimable) / space_limit > &umbral;
PROMPT == 1b. La misma consulta con umbral 0 %, solo para comprobar que dispara ==
DEFINE umbral = 0
SELECT 'ALERTA: FRA al ' || ROUND(100 * (space_used - space_reclaimable) / space_limit, 1) || ' % (umbral &umbral %)' AS alerta
  FROM v$recovery_file_dest
 WHERE space_limit > 0 AND 100 * (space_used - space_reclaimable) / space_limit > &umbral;
PROMPT == 2. Ninguna copia RMAN completada en las últimas 24 horas ==
SELECT 'ALERTA: ninguna copia RMAN completada desde ' || TO_CHAR(SYSDATE - 1, 'YYYY-MM-DD HH24:MI') AS alerta
  FROM dual
 WHERE NOT EXISTS (SELECT 1 FROM v$rman_backup_job_details WHERE status = 'COMPLETED' AND end_time > SYSDATE - 1);
SPOOL OFF
