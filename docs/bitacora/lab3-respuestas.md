# Lab 3 · Respuestas de comprobación

## Docker

**1. ¿Qué diferencia hay entre una imagen y un contenedor?**

La imagen es la plantilla de solo lectura y el contenedor es la instancia que se crea y se arranca a partir de ella. En el G2, `docker run hello-world` cogió la imagen `hello-world`, creó un contenedor (Docker le puso de nombre `distracted_carson`), imprimió el mensaje y terminó: en `docker ps -a` se veía como `Exited (0)`. En el G4 creé el contenedor `prueba` a partir de `alpine:3.20`. Con esa misma imagen podría crear todos los contenedores que quisiera y la imagen no cambiaría.

**2. En el G5 el archivo nota.txt desapareció y en el G6 no. ¿Por qué?**

En el G5 escribí `/tmp/nota.txt` en el sistema de archivos del propio contenedor `prueba`. Al hacer `docker rm prueba` ese sistema de archivos se borró con él, y `prueba2` arrancó otra vez desde la imagen limpia, por eso salió `can't open '/tmp/nota.txt': No such file or directory`. En el G6 escribí en `/datos`, que era el volumen `datos-prueba` montado desde fuera. `--rm` borra el contenedor pero no el volumen, así que el segundo contenedor encontró "dato importante".

**3. ¿Qué diferencia hay entre docker ps y docker ps -a, y qué significa STATUS = Exited (0)?**

`docker ps` solo lista los contenedores que están en marcha y `docker ps -a` lista todos, también los parados. `Exited (0)` quiere decir que el proceso principal del contenedor terminó y lo hizo bien (código de salida 0). Con un código distinto de 0 habría terminado con error.

**4. En -p 8181:8181, ¿qué número corresponde a tu equipo y cuál al contenedor? ¿Qué pasaría con -p 80:8080 en el ejercicio de nginx?**

El primero es el puerto de mi equipo y el segundo el del contenedor (primero lo mío, luego lo del contenedor). Con `-p 80:8080` publicaría mi puerto 80 hacia el 8080 del contenedor, pero nginx escucha en el 80 dentro del contenedor, así que la página no cargaría. En el G7 usé `-p 8080:80` y `docker port web` mostró `80/tcp -> 0.0.0.0:8080`, y en el navegador salió "Welcome to nginx!".

**5. ¿Por qué un contenedor de Oracle se queda en marcha y el de hello-world termina solo?**

Un contenedor vive lo que vive su proceso principal. El de hello-world solo imprime un texto y acaba, así que el contenedor pasa a `Exited`. En `oralab-26ai` el proceso principal arranca el listener y la instancia y se queda vigilando la base, no termina, por eso sigue `Up (healthy)` (bloque 3 de la evidencia 13).

**6. ¿Qué es el digest de una imagen y por qué lo registramos si ya sabemos que usamos :latest?**

Es la huella sha256 del contenido exacto de la imagen. `:latest` es una etiqueta que se mueve y dentro de unos meses puede apuntar a otra versión, el digest no. En la evidencia 04 quedó `sha256:f988b0c04c4c386cd306a2a914c0d7a9702d83acc31b064a28ad8eb6278a8fba`, que corresponde a Oracle AI Database 26ai Free 23.26.3.0.0 (evidencia 07), así que se sabe qué versión instalé aunque `:latest` cambie.

**7. ¿Qué comando borraría realmente los datos de Oracle? ¿Por qué docker rm oralab-26ai no lo hace?**

`docker volume rm oralab-26ai-data` (o un `docker system prune -a --volumes` con el contenedor parado). `docker rm` solo borra el contenedor, y los archivos de la base están en el volumen montado en `/opt/oracle/oradata`, que sobrevive y se puede montar en un contenedor nuevo con el script 05. Ojo con una cosa que vi al revisar: los datafiles de los TBS_* de V000 se crearon sin ruta y Oracle los dejó en `/opt/oracle/product/26ai/dbhomeFree/dbs/`. En esta imagen esa carpeta es un enlace simbólico a `/opt/oracle/oradata/dbconfig/FREE/dbs`, así que físicamente están dentro del volumen y sobreviven a un `docker rm`, pero en una carpeta que no es la normal (el resto de la PDB está en `FREE/FREEPDB1`). Lo comprobé en el diagnóstico del Lab 4 y allí se mueven a su sitio.

## Git, organización y evidencia

**8. ¿Por qué este laboratorio se hace dentro del repositorio oracle-database-lab, con Issue, branch y Pull Request, en vez de en una carpeta aparte?**

Porque montar el entorno es un cambio de infraestructura como otro cualquiera: el issue dice qué se va a hacer, la rama lo separa de main, los commits por Parte cuentan cómo se hizo con su evidencia y el PR deja que otra persona lo revise. Además es reproducible: si cambio de equipo (me ha pasado con este laboratorio) vuelvo a lanzar los scripts y tengo el mismo entorno. En una carpeta aparte todo eso quedaría solo en mi máquina.

**9. ¿Qué diferencia hay entre source 00-config.sh y bash 00-config.sh? ¿Por qué usamos source?**

`bash 00-config.sh` lo ejecuta en una shell hija que desaparece al terminar y las variables se van con ella. `source` lo ejecuta en mi propia terminal, así que `CONT_NAME`, `EVID`, la función `ts`, etc. quedan disponibles para lo que lance después. Si abro otra terminal hay que repetir el `source`.

**10. Explica cada parte del nombre 20260915T091230Z_02-docker.script.log.**

`20260915T091230Z` es la fecha y hora en UTC en formato ISO 8601 compacto (15/09/2026 a las 09:12:30; la Z es UTC). `02` es el número del paso que la generó (Parte F, `02-verificar-docker.sh`). `docker` es la descripción en kebab-case y `.script.log` dice que es una salida de terminal (las de SQL son `.spool.log` y las capturas `.png`).

**11. ¿Para qué sirve .gitattributes y qué error evita?**

Hace que Git guarde los `.sh`, `.sql` y `.md` con finales de línea LF aunque se editen en Windows. Evita el típico `$'\r': command not found` al ejecutar en Linux o dentro del contenedor un script con CRLF, y que los diffs se llenen de cambios invisibles.

**12. ¿Por qué en este Pull Request elegimos Create a merge commit en lugar de Squash and merge?**

Porque aquí cada commit es una Parte con su evidencia y tiene valor por sí mismo: se ve cuándo y cómo se verificó cada herramienta. Con squash todo quedaría en un solo commit en main y se perdería ese historial paso a paso.

## Seguridad

**13. Describe las cuatro capas de la estrategia de contraseñas (Parte D) y qué pasaría si te saltas la primera.**

1) Añadir `config/.env` y `backups/` al `.gitignore` antes de crear nada con contraseñas. 2) Una plantilla versionada, `config/.env.example`, sin valores reales. 3) El archivo real `config/.env`, que solo existe en mi equipo. 4) Cargar las contraseñas con `set -a; source config/.env; set +a` y usar `"$ORACLE_PWD"` en los comandos en lugar de escribirlas. Si me salto la primera, `config/.env` aparece en `git status` y basta un `git add .` para subir la contraseña, que se quedaría en el historial.

**14. ¿Por qué no escribimos la contraseña directamente en el comando docker run, aunque el script no se suba a Git?**

Porque todo lo que se teclea queda en `~/.bash_history` en texto plano. Con `"$ORACLE_PWD"` en el historial solo queda el nombre de la variable. Además una contraseña escrita a mano acaba fácilmente en una grabación con `script` o en una captura.

**15. Si descubres tu contraseña en un commit ya publicado, ¿basta con borrarla en un commit nuevo? ¿Qué debes hacer?**

No, el commit anterior sigue en el historial y cualquiera puede recuperarla. Hay que darla por comprometida y rotarla (contraseña nueva en `config/.env` y recrear el contenedor), avisar al docente para limpiar la rama y no volver a hacer push hasta que el control de la O.2 dé 0.

## Oracle y herramientas

**16. ¿Por qué no usamos SPOOL ni @archivo.sql con sqlplus dentro del contenedor, y qué hicimos en su lugar?**

Porque ese sqlplus corre dentro del contenedor: el SPOOL escribiría en el sistema de archivos del contenedor y no en el repo, y `@archivo.sql` buscaría el archivo dentro del contenedor, donde no está (SP2-0310). Lo que hicimos fue pasar el `.sql` con la redirección `<` y guardar la salida con `tee` desde mi equipo (evidencias 07 y 08). Con SQLcl, que corre en Ubuntu, el SPOOL sí escribe en el repo (evidencia 10).

**17. ¿Qué hace WHENEVER SQLERROR EXIT SQL.SQLCODE al inicio de V000 y V001, y qué pasaría sin esa línea?**

Si falla cualquier sentencia, sqlplus termina en ese punto devolviendo el código del error. Así `08-aplicar-migraciones.sh` se entera del fallo y no lanza V001 sobre un V000 a medias. Sin esa línea sqlplus seguiría ejecutando el resto y la base podría quedar a medio crear sin que el script avisara.

**18. ¿Qué es una migración y por qué V000 y V001 no se deben editar una vez aplicadas?**

Es un script SQL numerado que lleva la base de un estado al siguiente: V000 crea los tablespaces y usuarios, V001 las tablas. Una vez aplicada ya forma parte del estado de la base, mío y de los compañeros; si la editara, dos bases "con V000" serían distintas y nadie sabría cuál se aplicó. Si hay que cambiar algo se crea una migración nueva.

**19. ¿Por qué en SQL Developer se usa el servicio FREEPDB1 y no FREE ni un SID?**

FREEPDB1 es el servicio de la PDB donde están los cinco esquemas de negocio. FREE es el servicio del contenedor raíz y el SID identifica la instancia, no la PDB, así que con cualquiera de los dos acabaría conectado al contenedor raíz. En la captura 11 se ve la conexión con "Nombre del Servicio" FREEPDB1.

**20. ¿Qué aporta SQLcl frente a SQL*Plus, y por qué un DBA debe dominar ambas?**

SQLcl se instala en mi equipo y trae autocompletado, historial, formato automático (`SET SQLFORMAT ansiconsole`), conexiones guardadas (`CONNECT -save oralab26-system`, que guardó la conexión sin la contraseña) e integración con Liquibase. SQL*Plus está en cualquier servidor Oracle, también dentro del contenedor, y cuando solo tienes una terminal en el servidor es lo único que hay. Por eso conviene manejar las dos.

## Entorno de trabajo

**21. ¿Por qué el curso pasa de Git Bash a Ubuntu en WSL 2? Da al menos dos problemas concretos de Git Bash que desaparecen en Ubuntu.**

Git Bash es una emulación. Convierte las rutas tipo `/opt/...` en rutas de Windows y rompe argumentos de Docker, y `docker run -it` falla con "not a TTY" (había que tirar de winpty o de PowerShell). Además no trae `free`, `ss` ni `htop`, y las herramientas Java dan problemas al pedir contraseñas. En WSL 2 no hay emulación: es un Ubuntu real, como los servidores y los propios contenedores.

**22. ¿Por qué clonamos el repositorio en ~/oracle-database-lab y no trabajamos sobre la carpeta de Windows (/mnt/c/...)? ¿Y por qué recomendamos bash frente a zsh para los scripts del curso?**

En `/mnt/c` cada operación cruza entre dos sistemas de archivos, así que Git y Docker van mucho más lentos, se pierden los permisos de Linux (como el de ejecución) y vuelven los problemas de finales de línea. En `/home` el repo está en el disco de Linux. Y los scripts van en bash porque es la shell que hay en todos los servidores (Ubuntu, Red Hat, Oracle Linux); zsh es más cómoda para el día a día, pero tiene diferencias con arrays, globbing y expansión de variables, y en un servidor recién instalado normalmente no está.
