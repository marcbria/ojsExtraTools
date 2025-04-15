# ojsExtraTools
Some bashscripts helpers created to upgrade and maintain OJS

Estas herramientas se han desarrollado durante el proceso de actualización o mantenimiento de OJS.
Aunque fueron creadas para uso interno, se han generalizado para que puedan usarse en contextos más genéricos.

## Scripts incluidos

- mergeUserList.sh: Partiendo de un fichero externo que incluye una lista de usernames de usuarios spammers, el script recorre dicha lista y hace un merge contra el usuario de su elección. Útil con revistas que han sufrido algún ataque i demasiados usuarios spam como para gestionarlos manualmente. Se asume que ojs està instalado en /var/www/html, pero se puede canviar ese path si se desea.

- dockgradeMe: el script aprovecha la potencia de los contenedores para automatizar la actualización de una instancia de OJS. Partiendo de una instalación dockerizada, la aplicación carga la BD, los ficheros públicos y privados y realiza distintos upgrades siguiendo el path de actualización indicado. Se incorporan múltiples pausas en la ejecución para confirmar que el proceso se ha realizado correctamente en los pasos intermedios. Se asume asume que se ha dockerizado docker siguiendo la estructura de directorios de [easy-ojs](https://github.com/pkp/docker-ojs)).

## Forma de uso

### MergeUserList

0. Crear un usuario "spamuser" (rol Lector) que va a ser receptor del "merge" de todos los usuarios spam.
1. Visitar el directorio raiz de tu instalación ojs.
2. wget https://github.com/marcbria/ojsExtraTools/raw/refs/heads/main/mergeUsersList.sh && chmod +x mergeUsersList.sh
3. Crear un archivo con todos los usuarios que desea hacer "merge" (pej. spammerList.txt).
4. Ejecutar el script con: `./mergeUsersList.sh spamuser spammerList.txt`

### DockgradeMe


1. **Clone easyOJS**  
   ```bash
   git clone https://github.com/marcbria/easyOJS.git
   ```

2. **Prepare the volumes**
Copy the following items into the corresponding subdirectories inside volumes/:
- Database dump file (dump.sql) into volumes/dump (sometimes dbimport)
- public/ directory into volumes/public/
- private/ (also known as "files") directory into volumes/private

3. **Download the update script**
In the directory where your docker-compose.yml is located, download the script:
   ```bash
    wget https://raw.githubusercontent.com/marcbria/ojsExtraTools/main/dockgradeMe.sh`
   ```

4. **Edit the script according to your needs**
Modify dockgradeMe.sh to adjust:
- The upgrade path
- The path to the config.inc.php file
- ...

5. **Give execution permissions and run the script**

   ```bash 
   chmod +x dockgradeMe.sh
   ./dockgradeMe.sh
   ```

6. **Answer the script's questions**
Provide the requested information during the interactive execution of the script.

7. **Test the installation**
Access the updated OJS instance at: http://localhost:8080
And verify that the migration was successful.
