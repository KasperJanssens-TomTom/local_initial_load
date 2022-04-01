# Roll your own empty and preloaded coredb osm docker
We want to write integration tests and performance tests by leaning on dockerized infrastructure.
This has advantages and disadvantages.

The main advantages are that we can be as close to production as we want without having to actually depend on production servers like we do currently. 

The disadvantages are of course the time it takes to write and maintain this repo as well as the fact that this type of tests tend to be on the slow side, booting up dockers and the like is slow-ish. Next to that it is not so easy to load up fake data as it could be when fully mocking these dependencies in code.  

## Goals
* Have an empty coredb docker build from master
* Have a coredb docker with an initial load performed

### Create an empty coredb 
There is a script in the repository that will create and empty coredb and tag it. The script is called build_empty_layer.sh.

* It will first build a docker that can compile the coredb code. This part is inside baseCoredbDocker/coredbCodeDocker.
  * To achieve this it will load up config for a tomcat inside that docker and settings to be able to clone the coredb repository
  * It will also provide the run_the_liquibase_scripts.sh inside that docker
* Next, it will boot up a docker-compose as described in baseCoredbDocker. That compose will start the coredb source code docker we just created as well as a postgis docker.
* After this is done, the build script will start the run_the_liquibase_script.sh script which will execute all liquibase scripts.
  * At the end we will clean certain tables that contain localizer code
* Lastly, the build script will copy the data folder which has been populated by the execution of these scripts inside a postgis docker and tag it as cppspdocker.azurecr.io/coredb
* No pushes are done, need to be done manually

The reason why this needs to be executed inside a docker compose is that it is important for the liquibase scripts to be able to connect to a server called test-postgres. This server name will be present inside tables that are created and this server name needs to be used in the test layers code or any other code that starts this empty coredb docker.

### Create an initial loaded coredb

There is a script that will create a coredb with an initial load performed. It is called build_osm_hkm_layer.sh

* This script will perform all the steps for creating an empty coredb but will not perform the last step, creating the empty docker. Instead, it will run the load_it_to_fresh_postgres.sh script that will clone an s3 folder containing an initial load and load these dumped csv files.
* In the end it will create a loaded docker and tag it, through the build_coredb_osm_hkm_docker.sh script. It will call this docker cppspdocker.azurecr.io/coredb-osm-hkm.
* No pushes are done, need to be done manually

The reason why we need two different scipts is that before copying the data folder locally to the new docker, we need to chown that folder so our current user can read it. However, that means we cannot make changes to it anymore. We could try to find a way around it, chown it back or just make it readable for everybody, that will likely be enough, but this is the easy, brute-force approach for now.