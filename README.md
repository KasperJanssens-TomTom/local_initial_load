* Creating a postgres coredb database from a postgis image

First of all, we will have to create the docker that will host the coredb source code. THe code for this can be found inside baseCoredbDocker/coredbCodeDocker. You can find a build script there that will prep this dockerfile.
Next, run the docker compose inside baseCoredbDocker. This will bring up two dockers, a postgis docker and the coredb code docker, on a network. The coredb postgres docker can be found as test-postgres, which is the main reason for this as the liquibase scripts write the name of the server inside the coredb data and if that is just localhost or something, it won't work well in the test layers set up that comes after this.

Anyway, docker exec -it <containername> /bin/bash into the code docker (likely called basecoredbdocker_coredb-source_1)  and run the run_the_liquibase_script.sh inside /coredb-service-devel.

At the end, stop the compose, and find the data folder under baseCoredbDocker. Execute the builder-coredb-docker.sh script inside that folder, passing user:group to it for chowning the data folder correctly, something like janssenk:janssenk for instance for me.
