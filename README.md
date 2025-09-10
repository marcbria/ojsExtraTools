# ojsExtraTools
Some bashscripts helpers created to upgrade and maintain OJS

These tools have been developed during the process of updating or maintaining OJS.
Although they were created for internal use, they have been generalised so that they can be used in more generic contexts.

## Scripts included

- **mergeUserList**: Starting from an external file that includes a list of usernames of known spam or fake users, the script goes through that list and merges against the user of your choice. Useful for journals that have suffered an attack and too many spam users to manage manually. It assumes that ojs is installed in /var/www/html, but you can change that path if you wish.

- **dockgradeMe**: the script takes advantage of the power of containers to automate the upgrade of an OJS instance. Starting from a dockerised installation, the application loads the DB, public and private files and performs different upgrades following the indicated upgrade path. Multiple pauses are incorporated in the execution to confirm that the process has been carried out correctly in the intermediate steps. It is assumed that docker has been dockerised following the directory structure of [easy-ojs](https://github.com/pkp/containers/blob/main/docs/easyOJS.md)).


## Usage

### MergeUserList

0. Create a ‘spamuser’ (Reader role) that is going to be the recipient of the ‘merge’ of all spam users.
1. Visit the root directory of your ojs installation.
2. wget https://github.com/marcbria/ojsExtraTools/raw/refs/heads/main/mergeUsersList.sh && chmod +x mergeUsersList.sh
3. Create a file with all the usernames you want to merge (e.g. spammerList.txt). One username each line.
4. Run the script with: `./mergeUsersList.sh spamuser spammerList.txt`.


### DockgradeMe

1. **Clone containers repo**  
   ```bash
   git clone https://github.com/pkp/containers.git
   ```
2. **Prepare the volumes**
Copy the following items into the corresponding subdirectories inside volumes/:
- Database dump file (dump.sql) into volumes/db-import (sometimes dump or migration)
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
