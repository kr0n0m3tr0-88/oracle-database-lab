#!/usr/bin/env bash
# scripts/lab5/12-reto-fra.sh — reto de la Parte M: cuánto crece la FRA con una ejecución más de 12-undo-y-redo.sql
# Antes de medir se archiva el log actual para que el archivado final contenga solo el redo de esta ejecución.
# Uso: bash scripts/lab5/12-reto-fra.sh | tee "$EVID_LAB5/script/$(ts)_12-reto-fra.script.log"
set -euo pipefail
source scripts/deployment/env/00-config.sh
sql() { docker exec -i "$CONT_NAME" sqlplus -s -L / as sysdba; }
fra() { printf "SET HEADING OFF FEEDBACK OFF PAGESIZE 0\nSELECT space_used FROM v\$recovery_file_dest;\nEXIT\n" | sql | xargs; }
printf "ALTER SYSTEM ARCHIVE LOG CURRENT;\nEXIT\n" | sql > /dev/null
ANTES=$(fra)
echo "== 1. FRA usada antes: $ANTES bytes =="
echo "== 2. 12-undo-y-redo.sql una vez más =="
bash scripts/ops/sysdba.sh scripts/lab5/12-undo-y-redo.sql
echo "== 3. ALTER SYSTEM ARCHIVE LOG CURRENT y FRA después =="
printf "ALTER SYSTEM ARCHIVE LOG CURRENT;\nEXIT\n" | sql > /dev/null
DESPUES=$(fra)
echo "FRA usada después: $DESPUES bytes"
echo "Crecimiento: $(( (DESPUES - ANTES) / 1024 )) KB"
sql <<'SQL'
SET LINESIZE 150 PAGESIZE 50 FEEDBACK OFF
COLUMN archivo FORMAT A40
SELECT sequence#, REGEXP_SUBSTR(name, '[^/]+$') AS archivo, ROUND(blocks * block_size / 1024) AS kb
  FROM v$archived_log WHERE name LIKE '%/fra/%' ORDER BY sequence# DESC FETCH FIRST 2 ROWS ONLY;
EXIT
SQL
