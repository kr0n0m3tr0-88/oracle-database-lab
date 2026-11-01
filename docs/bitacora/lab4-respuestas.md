# Lab 4 · Respuestas

Las evidencias están en `docs/bitacora/lab4/evidencia/` (carpetas `script/`, `spool/` y `config/`).
Cito cada una por su número y su nombre, por ejemplo `script/..._03-prueba-persistencia`.

## Preguntas de comprobación

### Respaldo y diagnóstico (A)

**1. ¿Por qué la copia de la Parte A es consistente? ¿Qué pasaría si se tomara con la base abierta?**

Porque `backup-estado.sh` hace `SHUTDOWN IMMEDIATE` y `docker stop` antes de copiar (sección 4 de `script/20261101T222221Z_00-backup-lab3`). Con SHUTDOWN IMMEDIATE se deshacen las transacciones abiertas, se hace un checkpoint y se cierran los archivos, así que todos los datafiles quedan con el mismo SCN y no hay nada a medias. El manifiesto lo deja escrito: `tipo=copia en frio consistente (SHUTDOWN IMMEDIATE)`. Si se copiara con la base abierta, cada archivo se copiaría en un momento distinto mientras DBWn sigue escribiendo: cabeceras con SCN distintos y bloques a medio escribir. Esa copia no se podría abrir tal cual, necesitaría recuperación con redo, y sin los archivados de ese intervalo no serviría.

**2. ¿Para qué sirven manifiesto.txt y SHA256SUMS? ¿Qué comprueba restaurar-estado.sh antes de tocar nada?**

`manifiesto.txt` dice qué es la copia: etiqueta `lab3-final`, fecha `20261101T222415Z`, contenedor, volumen, imagen, el commit de Git del momento (`4c48c52`) y `archivos_fuera_del_volumen=0`. `SHA256SUMS` guarda la huella de cada archivo de la copia (sobre todo `volumen.tar.gz`, 516 079 649 bytes) para saber si se ha corrompido o alguien la ha tocado. `restaurar-estado.sh`, antes de borrar nada, comprueba que Docker responde, que la carpeta existe, que `sha256sum --check` da todo correcto y pide confirmación (`--si` o escribir el nombre del volumen). Solo después para la base y sustituye el volumen.

**3. Define RPO y RTO con los datos de tu propia copia.**

El RPO es cuántos datos acepto perder: si hoy restauro `lab3-final`, vuelvo al estado de las 22:24 UTC (SCN 3131053 en el inventario) y pierdo todo lo del Lab 4 que vino después. Con una copia por laboratorio, mi RPO es una sesión de trabajo entera. El RTO es cuánto tardo en volver a dar servicio: la copia completa tardó unos 2 minutos (de las 22:22:21 a las 22:24:15 más 10 s hasta `healthy`), y la restauración hace casi lo mismo al revés (comprobar SHA-256, parar, descomprimir 492 MB que vuelven a ser 4752 MB, arrancar), así que calculo entre 2 y 3 minutos.

### Correcciones del Lab 3 (C, D)

**4. ¿Dónde creó Oracle los datafiles de V000 y por qué? ¿Qué parámetro habría evitado el problema?**

En `/opt/oracle/product/26ai/dbhomeFree/dbs/` (evidencia 01). V000 ponía `DATAFILE 'academia01.dbf'` sin ruta y, como `db_create_file_dest` estaba vacío, Oracle resolvió el nombre relativo contra `$ORACLE_HOME/dbs`. En mi imagen esa carpeta es un enlace simbólico a `/opt/oracle/oradata/dbconfig/FREE/dbs`, así que los archivos sí estaban dentro del volumen, pero en una carpeta rara y dependiendo de un enlace que la imagen puede cambiar. El parámetro es `DB_CREATE_FILE_DEST`: con OMF basta con no escribir ruta y el archivo se crea en el destino configurado. Lo apliqué en el reto de la Parte C.

**5. ¿Por qué ALTER TABLESPACE ... RENAME DATAFILE no basta para mover un archivo?**

Porque solo cambia la ruta que guarda el control file, no mueve nada en el disco. Si no copias antes el archivo al destino, al poner el tablespace ONLINE Oracle va a la ruta nueva y no encuentra nada. Por eso `03-reubicar-datafiles.sh` hace OFFLINE, `cp -p`, RENAME, ONLINE y solo al final borra el original (`script/..._03-reubicar-datafiles`).

**6. ¿Por qué no se edita V000 y se crea V003? ¿Por qué invalidar una contraseña es mejor que borrarla del archivo?**

Una migración aplicada ya forma parte de la historia de todos los entornos donde se ejecutó. Si la edito, mi repositorio deja de describir lo que pasó y otro entorno que la aplique de cero acabaría distinto; los cambios nuevos van en un archivo nuevo. Y borrar la contraseña del archivo no sirve porque sigue en el historial de Git y en cualquier clon. Lo que protege de verdad es que deje de funcionar: con V003 las cuentas `ADMIN_*` quedan en `NO AUTHENTICATION` y la contraseña de V000 da `ORA-01017` (`spool/..._04-V003__cuentas_esquema_sin_password` y la prueba con SQLcl de la D.1).

**7. ¿Qué demuestra la prueba de persistencia y por qué se ejecuta después de reubicar?**

Demuestra que todo el estado de la base vive en el volumen: borré el contenedor, lo recreé con la 05 v2 y salieron los mismos 5 tablespaces y las mismas tablas por esquema (3, 3, 2, 3 y 3) antes y después (`script/20261101T223033Z_03-prueba-persistencia`). Se hace después de reubicar porque, si algún datafile estuviera fuera del volumen, el `docker rm` lo borraría para siempre. Por eso también va después de la copia de la Parte A.

### Instancia, arranque y parámetros (E, F)

**8. Con tus evidencias: tres datos que pertenecen a la instancia y tres que pertenecen a la base de datos.**

De la instancia (`spool/..._05-instancia-y-base` y `script/..._06-arranque-por-etapas`): el `HOST_NAME` 299d6830019c, que cambió al recrear el contenedor; la hora de arranque 2026-11-01 22:30:41, que vuelve a cambiar con cada STARTUP; y la SGA de 1 603 398 928 bytes que reserva STARTUP NOMOUNT. De la base: el `DBID` 1509902213, la fecha de creación 2026-07-05 y el `LOG_MODE` ARCHIVELOG, junto con sus 16 datafiles (3954 MB). Los tres primeros desaparecen al parar; los otros siguen en el disco.

**9. ¿Qué lee Oracle en NOMOUNT, en MOUNT y en OPEN? Relaciónalo con ORA-01507 y ORA-01219.**

En NOMOUNT lee el SPFILE, reserva la SGA y arranca los procesos: `v$parameter` ya responde, pero `v$database` da `ORA-01507` porque todavía no ha abierto el control file. En MOUNT abre los control files: ya conoce los 16 datafiles y responde `v$database` (`MOUNTED`, `ARCHIVELOG`), pero `dba_tables` da `ORA-01219` porque el diccionario está en SYSTEM, que es un datafile todavía cerrado. En OPEN abre datafiles y redo online y, si hiciera falta, hace la recuperación de instancia. Todo está en `script/..._06-arranque-por-etapas`.

**10. Diferencia entre v$parameter y v$spparameter con el ejemplo de db_files de tu evidencia.**

`v$parameter` es el valor en memoria de la instancia y `v$spparameter` lo que está escrito en el SPFILE para el próximo arranque. Con `db_files = 300 SCOPE = SPFILE`, `v$parameter` seguía diciendo 200 y `v$spparameter` 300: el cambio quedaba pendiente. Después del `RESET`, `v$spparameter` volvió a "(no especificado)" (`script/..._07-parametros-cambios`, bloque 3).

**11. ¿Por qué PROCESSES rechaza el cambio en memoria aunque v$parameter lo marque IMMEDIATE?**

Porque PROCESSES dimensiona estructuras de la SGA que se reservan al arrancar (los huecos para procesos y, de rebote, para sesiones). Aunque la metadata diga IMMEDIATE, en Free el cambio en memoria falla con `ORA-02097` y `ORA-02095` (bloque 4 de la evidencia 07). En la práctica es estático: se cambia con `SCOPE = SPFILE` y reinicio.

### Memoria y procesos (G, H)

**12. ¿Qué modelo de gestión de memoria usa tu instancia? Justifícalo con tres parámetros.**

ASMM. `memory_target` y `memory_size` valen 0, así que no hay AMM; `sga_target` vale 1536M, y con eso Oracle reparte la SGA solo; `db_cache_size` y `shared_pool_size` están a 0, es decir, sin mínimos fijados. La PGA va aparte con `pga_aggregate_target` 512M (`spool/..._08-memoria`). En `v$sga_dynamic_components` la caché tiene 1008 MB y la shared pool 400 MB con `FIJADO_MB` 0: el reparto lo ha decidido ASMM.

**13. Explica las cifras de tu experimento de caché: lecturas lógicas, físicas y tasa de acierto.**

ACA_ESTUDIANTES ocupa 244 bloques. Con la caché recién vaciada, la ronda 1 hizo 359 lecturas lógicas y 261 físicas: casi cada bloque tuvo que venir del disco, y la tasa de acierto fue (359 - 261) / 359, un 27 %. En la ronda 2 hizo 247 lógicas y 0 físicas: acierto del 100 %. Las 247 son prácticamente los 244 bloques bajo la HWM más la cabecera del segmento. Las lecturas lógicas de más de la ronda 1 creo que son de las consultas recursivas al diccionario, porque el FLUSH también vació sus bloques. Al final `v$bh` mostraba 245 bloques de la tabla en la caché (`script/..._08-experimento-cache`).

**14. Compara literales y variables de enlace con tus cifras de análisis y de V$SQL.**

Con literales: 1076 análisis, 1008 duros y 810 ms de CPU de análisis para 1000 consultas. Con `:id`: 1 análisis, 1 duro y 0 ms. En V$SQL la versión con variable es un solo cursor con 1000 ejecuciones y 39 KB de shared pool; la de literales dejó 406 cursores con 14 388 KB, y no salen 1000 porque la shared pool ya había expulsado los más viejos (`script/..._08-parse-y-pga`). Mi consulta del reto encuentra justo esa sentencia por su `force_matching_signature` (1863221789280198928, 406 cursores).

**15. Relaciona el SPID de LGWR de v$process con el PID de /proc. ¿Por qué docker top muestra otro número?**

`09-procesos.sql` dio LGWR con SPID 986 y `09-procesos-so.sh 986` encontró en `/proc` del contenedor el proceso 986 `db_lgwr_FREE`: es el mismo número porque los dos lo miran desde dentro del contenedor. `docker top` enseña el PID del anfitrión, que es otro espacio de nombres de PID; en la evidencia 05 los procesos salían con PID de 87xx y 88xx (por ejemplo PMON 8774, antes del reinicio de la E.3) mientras que dentro el PMON actual es el 934.

### Contenedores (I)

**16. Explica con tu evidencia por qué SYS ve 16 datafiles desde la raíz y 9 desde FREEPDB1.**

Desde CDB$ROOT las vistas V$ enseñan toda la CDB: 4 datafiles de la raíz (CON_ID 1), 3 de PDB$SEED (2) y 9 de FREEPDB1 (3), en total 16. Al hacer `ALTER SESSION SET CONTAINER = FREEPDB1` las mismas vistas se filtran al contenedor actual y solo queda la fila de CON_ID 3 con 9 (`script/..._10-que-ve-cada-usuario`, bloques 1 y 2).

**17. ¿Por qué LAB4_ANALISTA recibe ORA-00942 y no "privilegios insuficientes" al consultar DBA_TABLES?**

Porque Oracle no te dice que existe algo que no puedes ver. Sin `SELECT_CATALOG_ROLE` ni nada parecido, para ese usuario `SYS.DBA_TABLES` no existe y el error es `ORA-00942: table or view "SYS"."DBA_TABLES" does not exist`. Si respondiera "privilegios insuficientes" estaría confirmando que el objeto está ahí, y eso ya es información para un atacante.

**18. ¿Qué diferencia hay entre C##LAB4_AUDITOR y C##OPS_RO? ¿Qué sentencia los igualaría?**

Los dos son comunes, pero C##OPS_RO tiene el atributo `CONTAINER_DATA = ALL` (DEFAULT_ATTR Y, ALL_CONTAINERS Y) y C##LAB4_AUDITOR no. Por eso el auditor, desde la raíz, solo ve sus 5 tablespaces y las sesiones de CON_ID 0 y 1 (89 y 1), nada de FREEPDB1; para mirar la PDB tiene que entrar en ella con SET CONTAINER. Los igualaría `ALTER USER c##lab4_auditor SET CONTAINER_DATA = ALL CONTAINER = CURRENT;` ejecutado en la raíz.

**19. ¿Qué ventaja tiene GRANT READ ANY TABLE ON SCHEMA frente a conceder tabla por tabla? ¿Y qué riesgo?**

La ventaja es que con una sola sentencia el usuario lee todas las tablas del esquema, incluidas las que se creen después, y no se te olvida ninguna. En la evidencia 10 LAB4_ANALISTA pasó a ver las 3 tablas de ADMIN_ACADEMIA y los 20000 estudiantes, sin poder tocar ADMIN_CLINICA (`ORA-00942`) ni hacer UPDATE (`ORA-41900`). El riesgo es justo lo de "las que se creen después": si mañana alguien crea en ese esquema una tabla con datos sensibles, el usuario la puede leer sin que nadie lo haya decidido.

**20. ¿Qué valor tiene COMMON_USER_PREFIX en tu base y qué consecuencia tuvo en el bloque 3a de 10-ciclo-vida-pdb?**

Vale `C##`. Por eso en el bloque 3a `CREATE USER lab4_local` en la raíz falló con `ORA-65096: common user or role name must start with prefix C##`, que era lo esperado; el usuario no llegó a crearse y la rama que lo borraba no hizo nada (`script/..._10-ciclo-vida-pdb`).

### Archivos (J)

**21. Clasifica los archivos de tu evidencia 11 en "son la base de datos" y "relacionados". ¿Dónde va el password file y por qué?**

Son la base: los 16 datafiles (3954 MB), los 2 control files (36 MB), los 3 redo online (600 MB) y los 3 tempfiles (60 MB), aunque estos últimos no se copian porque se recrean. Relacionados: el SPFILE, el password file `orapwFREE`, el redo archivado (1 archivo, 66 MB en ese momento), el ADR con el alert log y las trazas, y los `listener.ora`, `sqlnet.ora` y `tnsnames.ora` de `dbconfig/FREE`. El password file está en `$ORACLE_HOME/dbs/orapwFREE`, que en esta imagen es `dbconfig/FREE/dbs` dentro del volumen. Tiene que estar fuera de la base porque sirve para autenticar a SYSDBA cuando la base no está abierta (por ejemplo para arrancarla en remoto) y en ese momento el diccionario no se puede consultar.

Nota: la sección 2 de `11-archivos-so.sh` me salió vacía. El motivo es que `$ORACLE_HOME/dbs` entero es un enlace simbólico y `ls -l` sobre el enlace sin barra final muestra el enlace y no lo que hay dentro. Con `ls -l $ORACLE_HOME/dbs/` sí aparecen `spfileFREE.ora` (3584 bytes), `orapwFREE` (2048 bytes), el archivado `arch1_1_1237845575.dbf` y las autocopias del control file `c-1509902213-20261101-00` y `-01`.

**22. Explica por qué academia01.dbf mide 104 865 792 bytes en Linux si v$datafile dice 100 MB.**

104 865 792 - 104 857 600 = 8192, exactamente un bloque. Oracle cuenta en `v$datafile` los 12 800 bloques del archivo (100 MB), pero en el disco hay uno más al principio, el bloque 0, una cabecera para el sistema operativo que `v$datafile` no incluye.

**23. ¿Qué dos puntos únicos de fallo ves en los control files y en el redo de tu base?**

Los dos control files (`control01.ctl` y `control02.ctl`) están en la misma carpeta `/opt/oracle/oradata/FREE` del mismo volumen: están duplicados, pero un fallo de ese disco se lleva los dos. Y cada grupo de redo (`redo01.log` a `redo03.log`) tiene un solo miembro: si se corrompe el miembro del grupo CURRENT no hay otra copia y se pierden transacciones confirmadas.

**24. ¿Por qué el ADR fuera del volumen es un problema operativo aunque la base no pierda datos?**

Porque el alert log y las trazas son lo primero que miras en un incidente, y viven en la capa del contenedor (sección 4 de `script/..._11-archivos-so`: "NO: /opt/oracle/diag vive en la capa del contenedor"). Cada vez que se recrea el contenedor, por ejemplo al actualizar la imagen, se pierde el historial: mi alert log ya no tiene nada anterior a las 22:30 de hoy salvo lo que traía la imagen de julio. Los datos están bien, pero no podría explicar qué pasó antes de esa hora.

### Bloque y fila (K)

**25. Descompón el ROWID de tu estudiante 101 en objeto, bloque y fila, y comprueba cada trozo con DBMS_ROWID.**

El ROWID es `AAAR2kAAAAAAAMMAAF` (`script/..._12-bloque`, bloque 4) y va en base 64 con el alfabeto A-Z, a-z, 0-9, +, /:

- `AAAR2k` es el objeto: R=17, 2=54, k=36, así que 17·64² + 54·64 + 36 = 69632 + 3456 + 36 = 73124, que es el `DATA_OBJECT_ID` de ACA_ESTUDIANTES.
- `AAAAAAAMM` es el bloque. TBS_ACADEMIA es BIGFILE y por eso no hay número de archivo relativo separado: los nueve caracteres son el bloque, M=12, 12·64 + 12 = 780.
- `AAF` es la fila: F=5.

DBMS_ROWID devuelve lo mismo: objeto 73124, bloque 780 (con `'BIGFILE'`), fila 5 y archivo absoluto 16 con `ROWID_TO_ABSOLUTE_FNO`, que es `academia01.dbf` con `RELATIVE_FNO` 1024.

**26. Del volcado: ¿qué significan nrow, fsbo, fseo y avsp? Demuestra que avsp = fseo - fsbo con tus números.**

`nrow` es el número de filas del bloque (90). `fsbo` es donde empieza el hueco libre, justo después del directorio de filas (0xc6 = 198). `fseo` es donde acaba el hueco libre, donde empiezan los datos de las filas, que se escriben desde el final del bloque hacia atrás (0x427 = 1063). `avsp` es el espacio disponible: 0x361 = 865. Y 1063 - 198 = 865, así que `avsp = fseo - fsbo`. `tosp` también vale 0x361 porque no hay filas borradas cuyo hueco se pueda recuperar.

**27. Explica la línea de la ITL con Lck = 90 y Flag --U-. ¿Qué es la limpieza diferida de bloques?**

La entrada 0x01 de la ITL tiene la Xid `0x000a.00f.00000226`, que es la transacción de V002 que insertó las filas. `--U-` quiere decir que está confirmada, pero con un SCN "cota superior" (upper bound), no el exacto. `Lck 90` quiere decir que las 90 filas del bloque todavía tienen el byte de bloqueo apuntando a esa entrada (`lb: 0x1` en la fila). La limpieza diferida es eso: al hacer COMMIT, Oracle no vuelve a todos los bloques que tocó la transacción para borrar las marcas, porque costaría mucho; la limpieza la hace después la siguiente sesión que lee o modifica el bloque. En el reto, el bloque del estudiante 19500 tiene la misma Xid con `--U-` y `Lck 85`, o sea que también está pendiente de limpiar.

**28. Calcula los 78 bytes de la fila 101 a partir de cabecera, bytes de longitud y datos.**

En el volcado la fila tiene `tl: 78` y `cc: 7`. La cuenta es 3 bytes de cabecera de fila (flag, byte de bloqueo y número de columnas) + 7 bytes de longitud, uno por columna + 68 bytes de datos. Los 68 son 3 (ID) + 9 (DNI) + 9 (NOMBRES) + 11 (APELLIDOS) + 19 (EMAIL) + 6 (ESTADO) + 11 (FECHA_REGISTRO), y coinciden con la suma de `VSIZE` que da el script. 3 + 7 + 68 = 78. A eso hay que sumarle 2 bytes del directorio de filas, por eso en el bloque cada fila ocupa unos 80.

### Capacidad y coste (L)

**29. Calcula bfr y b de ACA_ESTUDIANTES con la fórmula de la Unidad 3 y explica por qué la tabla real tiene 244 bloques.**

bfr = floor((8192 - 96) · (1 - 0,10) / 76) = floor(7286,4 / 76) = 95 filas por bloque, y b = ceil(20000 / 95) = 211 bloques. La versión de Oracle, con cabecera de 122 bytes y R + 2 por el directorio, da 93 y 216 bloques. En la realidad (`script/..._13-capacidad`) hay 231 bloques con filas, con entre 68 y 95 filas cada uno y una media de 86,6, porque las filas reales miden 78-80 bytes en el bloque y no 76. A eso se suman los 13 bloques casi vacíos del final que vimos con DBMS_SPACE en la K (FS4), y salen los 244 bloques bajo la HWM. El segmento tiene 256 porque el espacio se reserva por extensiones.

**30. Con tus cifras de 5a, 5b y 5c, ¿cuánto cuesta una lectura lógica, una física aleatoria y un bloque secuencial?**

Lectura lógica: 1160 ms de CPU para 400 000 lecturas, unos 2,9 µs. Física aleatoria: 56,6 ms para 5464 lecturas de un bloque, unos 10,4 µs. Secuencial: 4595 bloques en unos 28 ms (53 peticiones, 36 de ellas multibloque de unos 87 bloques), unos 6 µs por bloque, que es un ancho de banda de 1302 MB/s.

**31. Recalcula el umbral de rentabilidad de la sección 5d suponiendo un HDD (Bw = 150 MB/s, lat = 5 ms).**

Un bloque secuencial cuesta 8192 B / 150 MB/s, unos 52 µs. Uno aleatorio, 5 ms = 5000 µs. El cociente c_sec / c_aleat es 52 / 5000 = 0,0104. Con mi bfr medido de 86, el umbral es 0,0104 / 86 = 0,00012, un 0,012 % de las filas. En la tabla de 400 000 filas eso son unas 48 filas: por encima de eso, en un HDD sale más barato el recorrido completo. En el contenedor me salía un 0,67 %.

**32. ¿Por qué la "lectura física" sale en microsegundos en el contenedor? ¿Invalida eso el método?**

Porque `FLUSH BUFFER_CACHE` vacía la caché de Oracle pero no la caché de páginas de Linux: muchas lecturas que Oracle cuenta como físicas en realidad salen de la RAM del sistema operativo. No invalida el método: las fórmulas son las mismas y lo único que cambia es el valor de la latencia y del ancho de banda que metes. Con almacenamiento real se mide igual y salen 0,1-10 ms, y la decisión cambia (como se ve en la pregunta 31).

### Filas migradas y encadenadas (M)

**33. Diferencia migración y encadenamiento: causa, cómo se detecta y cómo se cura.**

La migración pasa cuando una fila que cabía en su bloque crece con un UPDATE y ya no cabe: Oracle la muda entera a otro bloque y deja en el original solo la cabeza con la dirección nueva (`nrid`), para que el ROWID no cambie. El encadenamiento pasa cuando la fila no cabe en ningún bloque (mi fila de unos 12 000 bytes en bloques de 8 KB) y se trocea entre varios. Las dos se detectan con `ANALYZE ... LIST CHAINED ROWS` (o `CHAIN_CNT` tras ANALYZE), con la estadística `table fetch continued row` y en el volcado (`fb: --H-----` y `nrid`). La migración se cura reorganizando con más PCTFREE (`ALTER TABLE ... MOVE`, a poder ser ONLINE); el encadenamiento no se cura así, hace falta un bloque mayor o cambiar el diseño de la tabla.

**34. Explica el 3,2 de lecturas lógicas por búsqueda de la sección 4 a partir del 20 % de filas migradas.**

Una búsqueda por clave normal cuesta 3 lecturas lógicas en esta tabla: raíz y hoja del índice y el bloque de la tabla. Si la fila está migrada hay que leer además el bloque donde vive ahora, 4 lecturas. Con un 20 % de filas migradas, en 1000 búsquedas 200 hacen la lectura extra: 1000 · 3 + 200 = 3200, es decir 3,2 por búsqueda, y la estadística `table fetch continued row` sale justo 200 (`script/..._14-filas-migradas`).

**35. ¿Por qué ALTER TABLE ... MOVE deja el índice UNUSABLE? ¿Qué harías en producción?**

Porque MOVE reescribe las filas en bloques nuevos y les cambia el ROWID, y el índice sigue apuntando a los ROWID viejos. En mi evidencia `PK_MIGRA` pasó a UNUSABLE y volvió a VALID con el REBUILD. En producción usaría `ALTER TABLE ... MOVE ONLINE`, que mantiene los índices válidos y no bloquea el DML. Si no se pudiera, MOVE más `ALTER INDEX ... REBUILD ONLINE` en una ventana de mantenimiento, y luego estadísticas.

### Autopsia y trabajo profesional (N, O)

**36. Elige tres hallazgos de tu autopsia (15) y escribe para cada uno riesgo, acción y prioridad.**

Están completos en `docs/bitacora/lab4-autopsia.md`. Los tres más importantes:

- ARCHIVELOG con FORCE LOGGING pero sin FRA (`db_recovery_file_dest` vacío) y 259 MB de redo archivado en `$ORACLE_HOME/dbs`. Riesgo: los archivados crecen sin límite y, si se llena el disco, la base se para; además sin copias RMAN no sirven para recuperar. Acción: FRA con tamaño, copias RMAN y retención. Prioridad alta.
- Los dos control files en la misma carpeta y un solo miembro por grupo de redo. Riesgo: punto único de fallo. Acción: multiplexar en otro volumen. Prioridad alta.
- Cuatro esquemas de negocio sin estadísticas (ALTURA_MAX vacía). Riesgo: planes a ciegas cuando tengan datos. Acción: `DBMS_STATS.GATHER_SCHEMA_STATS` tras cargar datos. Prioridad media.

**37. ¿Por qué C##OPS_RO y no SYSTEM para observar? ¿Qué no puede hacer C##OPS_RO?**

Por mínimo privilegio. SYSTEM tiene el rol DBA: un despiste o un script equivocado puede borrar o cambiar cualquier cosa, y si se filtra su contraseña desde la herramienta de monitorización el atacante se lleva la base entera. C##OPS_RO solo tiene `CREATE SESSION`, `SET CONTAINER`, `SELECT_CATALOG_ROLE`, el atributo `CONTAINER_DATA` y el SELECT sobre `V_$DIAG_ALERT_EXT`. No puede crear, modificar ni borrar objetos, no puede leer los datos de las tablas de negocio, no puede cambiar parámetros ni parar o arrancar la base. La verificación final lo comprueba: "C##OPS_RO sin privilegios ANY de escritura (0)".

**38. ¿Qué dos vías de exposición de contraseñas corrige este laboratorio respecto al Lab 3?**

Una, las contraseñas literales de V000 que estaban en Git: V003 las invalida con `NO AUTHENTICATION`. Dos, el `sys/<contraseña>@...` que el 08 del Lab 3 pasaba en la línea de comandos y se podía ver con `ps` y en los eventos de Docker: el 08 v2 usa `/ as sysdba`. De paso también se quitó `ORACLE_PWD` del `docker run` al reutilizar el volumen (05 v2), y ro.sh pasa la contraseña de C##OPS_RO por la entrada estándar.

## Preguntas tipo examen

**P1.** A y D. Con SHUTDOWN IMMEDIATE la copia es consistente: no necesita redo y se abre directamente con STARTUP, que es justo lo que hace mi `backup-estado.sh`.

**P2.** B. En Standard Edition no hay MOVE DATAFILE online (en Free da ORA-00439), así que es OFFLINE, copiar, RENAME y ONLINE, como en `03-reubicar-datafiles.sh`.

**P-D1.** C. `NO AUTHENTICATION` deja la cuenta sin ninguna forma de iniciar sesión; es lo que hace V003 y la contraseña vieja da ORA-01017.

**P3.** A y C. STARTUP_TIME es de la instancia y cambia en cada arranque (22:30 y luego 22:36 en mis evidencias); CREATED es de la base (2026-07-05) y el DBID no cambió al recrear el contenedor.

**P4.** A y C. En NOMOUNT ya responde `v$parameter` (lo vi en la E.3) y es la etapa para recrear el control file; `dba_users` necesita la base abierta.

**P5.** B. ARCHIVELOG se activa con la base montada y sin abrir, porque cambia el control file.

**P6.** B. Si la instancia arrancó con SPFILE, el SCOPE por defecto es BOTH.

**P7.** C. PROCESSES no es modificable a nivel de PDB y desde FREEPDB1 da ORA-65040, como en mi bloque 5 de la evidencia 07.

**P8.** A y C. Se arranca con un PFILE bueno y luego se rehace el SPFILE desde ese PFILE.

**P9.** B. Con SGA_TARGET fijado manda ASMM y DB_CACHE_SIZE pasa a ser el mínimo que no baja.

**P10.** A y D. El área de ordenación y la memoria de sesión en servidor dedicado están en la PGA; shared pool, log buffer y buffer cache son SGA.

**P-G1.** B. La solución de verdad es usar variables de enlace; mis cifras lo muestran: 1008 análisis duros frente a 1.

**P-G2.** B. 6 PASSES es que el área de trabajo no cupo y se releyó seis veces desde TEMP; me salió igual con 64 KB (3072 KB en TEMP).

**P11.** C. El COMMIT espera a que LGWR escriba el redo en disco; los bloques de datos los escribe DBWn más tarde.

**P12.** B y D. PMON y SMON están en cualquier instancia; ARCn solo en ARCHIVELOG y CJQ0 depende de los jobs.

**P13.** B. Desde la PDB, V$DATAFILE solo devuelve sus filas: a mí me salió solo CON_ID 3 con 9.

**P14.** B. Lo que falta es el atributo CONTAINER_DATA; es la diferencia entre C##LAB4_AUDITOR y C##OPS_RO.

**P15.** A y D. El privilegio de esquema cubre también las tablas futuras de HR y no da acceso a otros esquemas (ADMIN_CLINICA dio ORA-00942).

**P16.** B y D. Control files y redo online son parte de la base; el password file y el SPFILE son relacionados y el alert log es diagnóstico.

**P17.** C. En NOARCHIVELOG, perdido todo el disco, solo queda volver a la última copia completa y se pierde lo posterior.

**P18.** B. DBMS_ROWID supone SMALLFILE si no le pasas `'BIGFILE'`; en mi script hubo que pasarlo para obtener el bloque 780.

**P19.** A y B. PCTFREE marca cuándo el bloque deja de aceptar INSERT y ese hueco se guarda para que crezcan las filas con UPDATE.

**P20.** B. bfr = floor((8192 - 96) · 0,9 / 180) = floor(40,48) = 40 y 2 000 000 / 40 = 50 000 bloques.

**P21.** B. "db file scattered read" son lecturas multibloque a la buffer cache, las de un recorrido completo.

**P22.** A y C. LIST CHAINED ROWS identifica las filas y MOVE ONLINE con más PCTFREE las cura; DBMS_STATS no rellena CHAIN_CNT.

**P23.** B. 12 000 bytes no caben en ningún bloque de 8 KB: la fila está encadenada y MOVE no lo arregla (mi tabla ANCHA siguió con CHAIN_CNT 1).

**P24.** B. Usuario común de solo lectura con CONTAINER_DATA y el GRANT puntual de V_$DIAG_ALERT_EXT, que es C##OPS_RO.

**P25.** B. PDB$SEED es la plantilla de solo lectura; de ella creé PDB_LAB4.

**P26.** C. Desde una PDB no se puede crear un usuario con C##: ORA-65094, como en mi bloque 3b.

**P27.** B. Con la PDB abierta el DROP da ORA-65025; primero CLOSE IMMEDIATE y luego DROP INCLUDING DATAFILES.

**P28.** A y C. V$DATAFILE y V$LOG salen del control file y responden en MOUNT; las DBA_ y CDB_ necesitan OPEN.

**P29.** A. KCC es la capa del control file: V$LOG lee `x$kccle` y `x$kccrt`, como vi en la evidencia 10.

**P30.** B. Las CDB_ existen en la raíz y en cada PDB; desde una PDB solo devuelven sus filas (10 tablespaces en FREEPDB1).

**P31.** B. Los tempfiles no se respaldan, se recrean.

**P32.** B. La instancia ya leyó el SPFILE al arrancar y sigue funcionando; se recrea con `CREATE SPFILE FROM MEMORY`.

**P33.** B. V$PWFILE_USERS; en mi base sale SYS con SYSDBA y SYSOPER.

**P34.** A y B. La cabecera lleva la ITL y el directorio de filas, como se ve en el volcado.

**P35.** B. Con AUTOALLOCATE salen primero extensiones de 64 KB (8 bloques) y luego de 1 MB: ACA_ESTUDIANTES tiene 16 de 64 KB y una de 1 MB.

**P36.** B. ASSM gestiona el espacio libre de los bloques con mapas de bits.

**P37.** B. Desde 23ai el tipo por defecto es BIGFILE gestionado localmente; mis TBS_* lo son.

**P38.** A. Cuatro lecturas lógicas y ninguna física: todo estaba en la buffer cache.

**P39.** A y B. Más PCTFREE deja menos sitio útil y filas más grandes caben menos por bloque.

**P40.** B. Vaciar la caché hace que todas las sesiones vuelvan a leer de disco hasta que se recalienta.

**P41.** B. La migrada cabía y se mudó al crecer; la encadenada no cabe en ningún bloque.

**P42.** A. REBUILD del índice, o haber usado MOVE ONLINE.

**P43.** A. V$DIAG_ALERT_EXT; con el GRANT de la Parte J, C##OPS_RO la lee.

**P44.** A y B. Ampliar el espacio y averiguar qué segmento crece y por qué.

**P45.** A y B. La SGA, los procesos y el redo online son de la instancia y los comparten todas las PDB; el undo es local por PDB desde 12.2.

**P46.** B. ORA-01031: un usuario local sin SET CONTAINER no puede saltar a la raíz (lo vi con LAB4_ANALISTA en el bloque 3c).

## Retos de práctica profesional

### Parte A · Mi primer informe de diagnóstico

1. Contraseñas expuestas: las de V000 en Git y la de SYS en la línea de comandos del 08 (riesgo alto). Las corregiría las primeras porque cualquiera con el repositorio o un `ps` puede entrar.
2. No había ninguna copia de seguridad antes de tocar nada (alto). La resolví en la A.3, antes de cualquier cambio, porque todo lo demás implica modificar la base.
3. ARCHIVELOG activo sin FRA y con los archivados en `dbs/` (medio, sube a alto cuando crezca): necesita FRA, copias RMAN y retención.
4. Datafiles de negocio con ruta relativa en `$ORACLE_HOME/dbs`, que aquí es un enlace dentro del volumen (medio: no se pierden con `docker rm`, pero dependen del enlace). Los moví en la C.
5. Puerto 8181 publicado sin nadie escuchando (bajo). Lo último: no rompe nada, solo es superficie de ataque.

### Parte B · Mínimo privilegio, de verdad

Riesgos de dar el rol DBA a C##OPS_RO: primero, la contraseña de una cuenta de monitorización suele acabar guardada en la configuración de una herramienta; si se filtra, con DBA el atacante puede leer todos los datos de negocio (SELECT ANY TABLE), crear usuarios y darse más privilegios. Segundo, cualquier consulta equivocada de la herramienta o de quien la usa puede modificar o borrar objetos (DROP ANY, ALTER SYSTEM), y lo que era "mirar" se convierte en una incidencia. Para leer el alert log le daría solo `GRANT SELECT ON sys.v_$diag_alert_ext TO c##ops_ro CONTAINER = ALL;`, que es lo que hace `11-ampliar-ops-ro.sql`, y la verificación final comprueba que sigue sin privilegios ANY de escritura.

### Parte C · Que no vuelva a pasar

Comando, en CDB$ROOT: `ALTER SYSTEM SET db_create_file_dest = '/opt/oracle/oradata' SCOPE = BOTH;` (`scripts/lab4/03-reto-omf.sql`, evidencia `script/..._03-reto-omf`, commit propio). SCOPE = BOTH porque el parámetro es dinámico (IMMEDIATE): se aplica ya y queda en el SPFILE para los siguientes arranques; FREEPDB1 lo hereda porque no tiene valor propio. Antes, `CREATE TABLESPACE tbs_x;` sin DATAFILE habría fallado con ORA-02199 por falta de la cláusula; con OMF se creó `/opt/oracle/oradata/FREE/55E54F210F100828E0630B00580ADFD0/datafile/o1_mf_tbs_x_oghhkj58_.dbf`, de 100 MB y autoextensible, dentro del volumen. Después lo borré para no dejar restos. Ojo: si alguien escribe a propósito una ruta relativa, Oracle la sigue resolviendo contra `$ORACLE_HOME/dbs`; OMF evita el problema cuando no se pone ruta, así que la norma para las migraciones es no escribir rutas relativas nunca.

### Parte E · El parte del reinicio

Según el alert log, el último reinicio (el de la E.3) fue así, en hora UTC:

- 22:36:06 se pide la parada: `Shutting down ORACLE instance (immediate)`.
- 22:36:14 `Instance shutdown complete`: unos 8 segundos para parar.
- 22:36:14 arranca la instancia, a las 22:36:18 termina el MOUNT y a las 22:36:20 `Completed: ALTER DATABASE OPEN` con FREEPDB1 abierta en lectura y escritura.

En total, unos 14 segundos desde que se pide la parada hasta que la base está abierta, y unos 6 de arranque. No hubo recuperación de instancia: solo aparecen las líneas `Crash Recovery excluding pdb 2/3 which was cleanly closed`, que indican que las PDB se cerraron bien. Errores: `ORA-00800 [Set Priority Failed]` para VKTM y LGWR, conocido (el contenedor no deja subir la prioridad de esos procesos). Más arriba en el log hay ORA-27167 a ORA-27303 y ORA-07427 (`spstp: cannot change directory to dbs`), pero son del 2026-07-05, de cuando se construyó la imagen, no de este reinicio. Ninguno a investigar.

### Parte F · Petición de cambio para open_cursors

- Valor actual: 300. Está escrito en el SPFILE (`v$spparameter`), lo heredan las PDB y es dinámico (IMMEDIATE) y modificable por PDB (evidencia 07).
- Antes de tocarlo: ORA-01000 suele ser una aplicación que no cierra cursores. Pediría la sesión que falla y miraría `v$open_cursor` y la estadística `opened cursors current` por sesión. Si una sola sesión va subiendo sin parar, hay que arreglar la aplicación, y subir el límite solo lo retrasa.
- Valor propuesto, solo si el uso es legítimo: 1000, pero solo en la PDB de la aplicación (FREEPDB1), no en toda la CDB: `ALTER SYSTEM SET open_cursors = 1000 COMMENT = 'CR-xxx ORA-01000 app' SCOPE = BOTH;` dentro de FREEPDB1. BOTH porque es dinámico y queremos que dure tras un reinicio.
- Prueba: primero en el laboratorio (como en la evidencia 07, donde SCOPE = BOTH funcionó y se deshizo), y luego comprobar en producción que la aplicación deja de dar ORA-01000 y que el máximo de cursores abiertos por sesión se estabiliza.
- Vuelta atrás: `ALTER SYSTEM RESET open_cursors SCOPE = BOTH;` en FREEPDB1, que vuelve a heredar los 300 de la raíz.
- Evidencia: spool de `v$parameter` y `v$spparameter` antes y después, el PFILE nuevo comparado con `initFREE_lab4.ora` en Git y las cifras de cursores por sesión antes y después.

### Parte G · Encontrar a los culpables

Está en `scripts/lab4/08-reto-literales.sql` y su salida en `spool/20261101T223839Z_08-reto-literales`. Agrupa V$SQL por `con_id` y `force_matching_signature` y se queda con las firmas de más de 50 cursores distintos. Ejecutada justo después de `08-parse-y-pga.sql` sale una sola firma: 1863221789280198928, en CON_ID 3, con 406 cursores, 406 ejecuciones y 14,1 MB de shared pool, y el ejemplo es `SELECT /* lab4_literal */ COUNT(*) FROM admin_academia.aca_estudiantes WHERE ...`.

### Parte H · La sesión que más consume

En una sesión SYSDBA dentro de FREEPDB1 lancé `SELECT COUNT(*) FROM admin_academia.aca_matriculas a, admin_academia.aca_matriculas b WHERE a.matricula_id < 3000;` (179 940 000 filas en 6,05 s) y, mientras corría, como C##OPS_RO desde la raíz:

```sql
SELECT s.con_id, s.sid, s.serial#, s.username, s.sql_id, p.spid,
       ROUND(p.pga_used_mem / 1048576, 1)  AS pga_usada_mb,
       ROUND(p.pga_alloc_mem / 1048576, 1) AS pga_asignada_mb,
       s.last_call_et AS seg_activa
  FROM v$session s JOIN v$process p ON p.addr = s.paddr
 WHERE s.type = 'USER' AND s.status = 'ACTIVE'
   AND s.sid <> SYS_CONTEXT('USERENV', 'SID')
 ORDER BY p.pga_alloc_mem DESC;
```

Valores: SID 63 (SERIAL# 56833, usuario SYS en CON_ID 3, sql_id f3t2mvta30bt1), SPID 1922 en Linux y 4,1 MB de PGA usada (4,6 MB asignada).

### Parte I · Acceso de un auditor externo (diseño, no ejecutado)

```sql
-- en FREEPDB1, no en la raíz
CREATE USER auditora_ext IDENTIFIED BY "<contraseña robusta>" PASSWORD EXPIRE;
GRANT CREATE SESSION TO auditora_ext;
GRANT READ ANY TABLE ON SCHEMA admin_clinica TO auditora_ext;
-- el último día
REVOKE READ ANY TABLE ON SCHEMA admin_clinica FROM auditora_ext;
DROP USER auditora_ext;
```

Usuario local porque solo necesita una PDB: en la I.2 vi que un local no puede saltar a la raíz (ORA-01031) ni ver otros contenedores, y un usuario común le abriría la puerta de todas las PDB. Privilegio de esquema porque cubre las tablas de ADMIN_CLINICA y nada más: LAB4_ANALISTA, con el de ADMIN_ACADEMIA, recibía ORA-00942 en otro esquema y ORA-41900 al intentar UPDATE. Pongo READ y no SELECT para que no pueda hacer `SELECT ... FOR UPDATE` y bloquear filas. `PASSWORD EXPIRE` para que la cambie al entrar y no quede la que le mandemos. Al acabar la semana revoco y borro el usuario; para no depender de acordarme, se puede programar con DBMS_SCHEDULER.

### Parte J · Plan de copia a partir del inventario

Copia en frío completa con los tamaños exactos de Linux (`script/..._11-archivos-so` y `ls -l $ORACLE_HOME/dbs/`): datafiles 4 146 200 576 bytes + control files 37 584 896 + redo online 629 145 216 + SPFILE 3584 + password file 2048 = 4 812 935 872 bytes, unos 4590 MB. Los tempfiles (60 MB) no hacen falta porque se recrean. Con RMAN sobrarían el redo online (600 MB: RMAN nunca lo copia), la segunda copia del control file (RMAN guarda una sola, con el SPFILE, en la autocopia) y los tempfiles; además RMAN solo copia bloques usados, así que los datafiles ocuparían menos. El password file RMAN no lo copia, hay que guardarlo aparte. Y como la base está en ARCHIVELOG, con RMAN añadiría los redo archivados (`BACKUP DATABASE PLUS ARCHIVELOG`).

### Parte K · Abre otro bloque

Elegí el estudiante 19500 (`scripts/lab4/12-reto-otro-bloque.sql`, evidencia `script/..._12-reto-otro-bloque` y traza `config/20261101T224655Z_12-reto-volcado-bloque.trc.txt`). Está en el bloque 1165, fila 77. Comparado con el bloque 780 de la fila 101: `nrow` 85 frente a 90, `avsp` 0x33a (826 bytes) frente a 0x361 (865), y la fila mide `tl: 84` frente a 78 porque sus valores son más largos (19500, Nombre19500, est19500@...), así que caben menos filas por bloque. La ITL tiene la misma Xid `0x000a.00f.00000226` con `--U-` y `Lck 85`: sí, también tiene la limpieza diferida pendiente, como todos los bloques que cargó V002.

### Parte L · Dimensiona ACA_MATRICULAS

Predicción antes de mirar, con R = 30 bytes: bfr = floor(7286,4 / 30) = 242 y b = ceil(60000 / 242) = 248 bloques (con la versión de Oracle, floor(7263 / 32) = 226 y 266 bloques). Lo real en DBA_TABLES: AVG_ROW_LEN 30, BLOCKS 370 bajo la HWM y 384 asignados (3 MB). Contando filas por bloque con DBMS_ROWID salen 301 bloques con filas, de 159 a 210 filas, media 199. La diferencia es mucho mayor que en ACA_ESTUDIANTES (211 frente a 244) por dos motivos. Las filas son pequeñas, así que lo fijo por fila (3 bytes de cabecera, 5 de longitudes y 2 del directorio) pesa casi un 30 %, cuando en ACA_ESTUDIANTES era un 15 %: con 26,3 bytes de datos reales la fila ocupa unos 36 en el bloque, y 7263 / 36 da unas 201 filas, que es justo lo medido. Y además hay 69 bloques bajo la HWM sin filas. Un recorrido completo en un HDD a 150 MB/s: 370 · 8 KB = 3 031 040 bytes, unos 20 ms de transferencia, y contando una búsqueda de 5 ms por cada una de las ~5 peticiones multibloque, unos 45 ms.
