# Roll your own empty and preloaded coredb osm docker
We want to write integration tests and performance tests by leaning on dockerized infrastructure.
This has advantages and disadvantages.

The main advantages are that we can be as close to production as we want without having to actually depend on production servers like we do currently. 

The disadvantages are of course the time it takes to write and maintain this repo as well as the fact that this type of tests tend to be on the slow side, booting up dockers and the like is slow-ish. Next to that it is not so easy to load up fake data as it could be when fully mocking these dependencies in code.  

# Caveat
This script is mainly intended to run on Linux. MacOs should be possible too, but not all tools on mac os are gnu tools so no guarantees that the options are the same. In fact, guarantees that with the default mac toolchain it won't work.

## Goals
* Have an empty coredb docker build from master
* Have a coredb docker with an initial load performed

### Create an empty coredb 
There is a script in the repository that will create and empty coredb and tag it. The script is called build_empty_layer.sh.

* It will first build a docker that can compile the coredb code. This part is inside the directory [coredbCodeDocker](./baseCoredbDocker/coredbCodeDocker).
  * To achieve this it will load up config for a tomcat inside that docker and settings to be able to clone the coredb repository
  * It will also provide the [run_the_liquibase_scripts.sh](./baseCoredbDocker/coredbCodeDocker/run_the_liquibase_scripts.sh) inside that docker
* Next, it will boot up a docker-compose as described in the directory [baseCoredbDocker](baseCoredbDocker). That compose will start the coredb source code docker we just created as well as a postgis docker.
* After this is done, the build script will start the [run_the_liquibase_scripts.sh](./baseCoredbDocker/coredbCodeDocker/run_the_liquibase_scripts.sh) script which will execute all liquibase scripts.
  * At the end we will clean certain tables that contain localizer code
* Lastly, the build script will copy the data folder which has been populated by the execution of these scripts inside a postgis docker and tag it as `cppspdocker.azurecr.io/coredb`, with the version hard coded in the script, currently.
* No pushes are done, need to be done manually

The reason why this needs to be executed inside a docker compose is that it is important for the liquibase scripts to be able to connect to a server called `test-postgres`. This server name will be present inside tables that are created and this server name needs to be used in the test layers code or any other code that starts this empty coredb docker.
So, **important**, this docker will only function if it can be called as if it is on a server called `test-postgres`.

### Create an initial loaded coredb
**CAVEAT** need to be able to read from s3. Saml log on is necessary. There is a script inside that performs the log in but only in case you have created your profile. The script is called `log_on_through_saml.sh`. To create profile, check [this confluence page](https://confluence.tomtomgroup.com/display/OSM/Logging+into+an+AWS+account)
To avoid annoying bug-hunts, this script is called by default during a run for now, this unfortunately means that the script is not fully unattended. Also, the script assumes that saml2aws is installed in a specific folder. If you want to skip this check because you want to install it elsewhere and call manually, you can add the --skip-saml flag.

There is a script that will create a coredb with an initial load performed. It is called [build_osm_hkm_layer.sh](./build_osm_hkm_layer.sh)

* This script will perform all the same steps for creating an empty coredb but will not perform the last step, creating the empty docker. Instead, it will run the [load_into_postgres_new.sh](osmCoredbDocker/load_into_postgres_new.sh) script that will clone an s3 folder containing an initial load and load these dumped csv files.
  * Note, there is a version that handles the old style of dumps, called [load_into_fresh_postgres.sh](osmCoredbDocker/load_into_postgres.sh). This is currently no longer used but is just present in case somebody encounters a dump in the old style. The difference between both is not totally clear to me but if you get errors concerning the directory layout of the dump you're trying to load you are or not authorized to download the dump or the dump is in the other format than the one you selected.
  * This script will first of all create the structure, by using the [configuration_scripts](osmCoredbDocker/configuration_scripts) folder. Not all scripts in there are currently used, anyd it might not be the best idea to check them in in this repo and not point to them online, but it seemed that there was not really a master version of these scripts.
  * The next part will be using the azure tool to download the csv files that make up the direct load locally.
  * As soon as that is done, these csv files will be loaded up through psql
* The next part is creating the localizer and idindex. The scripts for this can be found in the [idindex](osmCoredbDocker/idindex) folder, I will go a bit deeper into it later in the readme as it is interesting.
* In the end it will create a loaded docker and tag it, through the [build_coredb_osm_hkm_docker.sh](baseCoredbDocker/build_coredb_osm_hkm_docker.sh) script. It will create a docker with this name `cppspdocker.azurecr.io/coredb-osm-hkm`, and a version currently hard coded inside the script.
* No pushes are done, need to be done manually

The reason why we need two different scripts is that before copying the data folder locally to the new docker, we need to chown that folder so our current user can read it. However, that means we cannot make changes to it anymore. We could try to find a way around it, chown it back or just make it readable for everybody, that will likely be enough, but this is the easy, brute-force approach for now.

### The Dockerfile
There is a [Dockerfile](baseCoredbDocker/Dockerfile) that is used to build both the empty layer and the direct loaded layer. It is a bit confusing but due to the limits of Docker mounting paths there was not much alternative. Both times it will mount the contents of baseCoredbDocker/data inside a docker. 
When running the empty layer build, the only data there will be the scripts that have been run for creating an empty coredb layer.
When running the osm layer build, the data folder will contain also the direct load files. It is a bit annoying that this data folder and Dockerfile are both in the baseCoredbDocker folder even if they can contain data that is more than just the baseCoredbDocker, but the alternative involved too much duplication.

### Troubleshooting: 
* If you get a message about not being able to clone or not finding test-postgres during the loading of the liquibase scripts, chances are you activated or deactivated your vpn without cleaning up the docker compose network. In fact most network issues can be traced back to this. Simple perform a `docker-compose down --remove-orphans` or prune the docker network manually yourself.

### Usage of the built dockers
So, now we have two coredb dockers, an empty one and a filled one. But what can we do with this then? Well, the best way to use this, currently, is using the [test-layers](ssh://git@bitbucket.tomtomgroup.com:7999/cdb/test-layers.git) project.

There is an example-test in there, called OsmHkmLayerWithKongTest, but in case it would be gone by the time you read this, the important part is in the start of the layer.
```java
        osmHkmLayer = new OsmHkmLayer()
            .withConsulKV("service-config/coredb-main-ws/test-env/test/feature-flipper.simplified.idindex.on.toggle", "dHJ1ZQ==")
            .withConsulKV("service-config/coredb-main-ws/test-env/test/feature-flipper.storage.mds.attributes.newModelDetector.enabled", "dHJ1ZQ==")
            .withDefaultKongKonfig();
```
The consul key values are important in the start. First, currently the values need to be base64 encoded. This example could have been done a lot better of course, but `dHJ1ZQ==` is `true` in base 64.
This code sets those two properties to true. What do those mean then? The first key sets the usage of the simplified index. The simplified index is the new way of creating the index, and is also the way the
index is created by the scripts in the [idindex](osmCoredbDocker/idindex) folder.

### The index, the localizer
What this dump basically loads up is an `smds`, a snapshot mds. Normally, coredb uses a combination of `vmds`, or versioned mds and smds to retrieve a feature.
The smds is the baseline, the vmds are the potential deltas on top of this baseline. The complete state of a feature can only be found by retrieving the snapshot version of a feature from the smds and adding the deltas found on top of it.
For this to be possible, the vmds needs to be found. The approach is that the coredb postgres database contains a table refering other coredb postgres databases where the vmds data can be found.
However, here, the vmds can be found in our own database so we need to make sure to point to our own database.

The full retrieval of these vmds is slightly more complicated. This is because there are multiple smds's and we need to find the correct smds. This is done through the use of the id-index.

The full process is (bear in mind that this is only the case when the simplified.idindex.on.toggle is set) that coredb checks a feature's vmds by first looking for the location of its index (note, not immediately reading its index but the location of its index).
```roomsql
coredb=# select * from localizer.idindex_connection_settings;
 id | version |              connectionstring               |           dbschema           |                branch                |   engine   
----+---------+---------------------------------------------+------------------------------+--------------------------------------+------------
  8 |       0 | jdbc:postgresql://test-postgres:5432/coredb | id_index_simplified_000000_0 | 00000000-0000-0000-0000-000000000000 | POSTGRESQL
(1 row)
```

You can see that it always starts off in the localizer schema, the idindex_connection_settings table. This points to a schema per branch/version combination. So a feature id only makes sense withint the context of a branch/version id.

The next part is checking the id_index_simplified schema, for the table index_key.
```roomsql
coredb=# select * from id_index_simplified_000000_0.index_key limit 10;
               entityid               | datasetname 
--------------------------------------+-------------
 4593a96a-5d21-4a59-a2f7-222d91841d08 | GLB
 c3c2184f-0dfb-4b01-8c11-aeb493aec125 | GLB
 51d7e62e-e5a5-43fa-852f-26e272beb055 | GLB
 10d674bf-daae-44b4-8306-6b38ee827b43 | GLB
 935530ab-bcf8-4fcf-a0e2-6767296f7bbf | GLB
 edd50984-dbd6-4015-8c1e-09d1ccea3e2b | GLB
 c888f9fe-8955-484e-86e9-ca22464a511e | GLB
 363eb3bb-f460-4027-aa39-cd477b5755c9 | GLB
 7ee983cb-fe69-4d40-8d9b-7167382b354d | GLB
 85472292-7602-463d-8965-0747bcff67a1 | GLB
```

Index key is a mapping from id to dataset name. This dataset name is then used eventually in the localizer schema, again, more specifically the db_connection_settings. ( I have no idea what the boundary id should mean or come from, just invented one)

```roomsql
coredb=# select * from localizer.db_connection_settings;
 id | datasetname | version |             connectionstring              |  dbschema  | comment | boundary_id | dpuid |       creation_date        | ascii_creation_date | ascii_version |             branch_uuid              
----+-------------+---------+-------------------------------------------+------------+---------+-------------+-------+----------------------------+---------------------+---------------+--------------------------------------
  1 | GLB         |       0 | jdbc:postgresql://test-postgres:5432/coredb | mds_schema |         |        7460 | GLB   | 2022-04-11 07:43:06.722717 |                     | 0             | 00000000-0000-0000-0000-000000000000
(1 row)
```
This is then the pointer to the smds. The smds as configured here is in our own database (remember the remark about the usage of test-postgres, this here is the main reason for this naming convention), more specifically in the `mds_schema`.

The reason for the dataset name is a bit murky. It seems that every feature starts with 10 hex numbers, which potentially from 5 ASCII characters. The majority of the time the first four hex/first two ascii characters are 0 and are not taken into account.
The next three form the ascii tokens of the datasetname. So 0000474c42 is a feature that is linked to GLB (47 -> G, 4C -> L, 42 -> B as can be looked up in the [asciitable](https://www.asciitable.com/).
It seems that, if you are looking up a feature that is linked to GLB, but the datasetname in the id_index_simplified or db_connection_settings does not correspond to GLB, it will silentyl fail. So bottom line, if instead of GLB in these requests, we would have filled out BE2 and then expected to be able to look up a feature id starting with 0000474c42, it would have silently failed

