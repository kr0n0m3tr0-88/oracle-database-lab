-- scripts/lab4/08-reto-literales.sql — reto de la Parte G: sentencias que la aplicación ejecuta con literales (SQLcl · C##OPS_RO)
-- force_matching_signature es la misma para dos sentencias que solo se diferencian en los literales.
-- Muchos cursores con la misma firma = un hard parse por cada valor distinto.
@scripts/ops/marca
SPOOL docs/bitacora/lab4/evidencia/spool/&marca._08-reto-literales.spool.log
SET SQLFORMAT DEFAULT
SET LINESIZE 180 PAGESIZE 100 FEEDBACK OFF
COLUMN firma FORMAT 99999999999999999999
COLUMN ejemplo FORMAT A80
PROMPT == Firmas con más de 50 cursores distintos (candidatas a variables de enlace) ==
SELECT con_id,
       force_matching_signature AS firma,
       COUNT(DISTINCT sql_id) AS cursores,
       SUM(executions) AS ejecuciones,
       ROUND(SUM(sharable_mem) / 1048576, 1) AS memoria_mb,
       MIN(SUBSTR(sql_text, 1, 80)) AS ejemplo
  FROM v$sql
 WHERE force_matching_signature > 0
 GROUP BY con_id, force_matching_signature
HAVING COUNT(DISTINCT sql_id) > 50
 ORDER BY cursores DESC;
SPOOL OFF
