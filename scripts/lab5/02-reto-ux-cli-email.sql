-- scripts/lab5/02-reto-ux-cli-email.sql — reto de la Parte C: comprobar la altura calculada a mano de UX_CLI_EMAIL
-- Se ejecuta como SYSDBA: bash scripts/ops/sysdba.sh <este archivo> <evidencia>
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 170 PAGESIZE 50 FEEDBACK OFF
COLUMN name FORMAT A14
ALTER SESSION SET CONTAINER = FREEPDB1;
PROMPT == UX_CLI_EMAIL frente a PK_CLIENTE: las dos tienen 100 000 entradas ==
ANALYZE INDEX tiendasur.ux_cli_email VALIDATE STRUCTURE;
SELECT name, height, lf_rows, lf_blks, br_rows, br_blks,
       ROUND(lf_rows_len / lf_rows, 1) AS bytes_entrada_hoja,
       ROUND(br_rows_len / NULLIF(br_rows, 0), 1) AS bytes_entrada_rama,
       ROUND(lf_rows / lf_blks) AS entradas_por_hoja, pct_used
  FROM index_stats;
ANALYZE INDEX tiendasur.pk_cliente VALIDATE STRUCTURE;
SELECT name, height, lf_rows, lf_blks, br_rows, br_blks,
       ROUND(lf_rows_len / lf_rows, 1) AS bytes_entrada_hoja,
       ROUND(br_rows_len / NULLIF(br_rows, 0), 1) AS bytes_entrada_rama,
       ROUND(lf_rows / lf_blks) AS entradas_por_hoja, pct_used
  FROM index_stats;
PROMPT == ¿En qué orden llegaron las claves? Primeros clientes por id y su email ==
SELECT id_cliente, email FROM tiendasur.cliente WHERE id_cliente <= 5 ORDER BY id_cliente;
EXIT
