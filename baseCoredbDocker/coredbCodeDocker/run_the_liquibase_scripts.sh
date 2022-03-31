#!/bin/bash
set -x

sleep 15s

/root/.sdkman/candidates/tomcat/current/bin/startup.sh

git clone --depth 1 https://bitbucket.tomtomgroup.com/scm/cdb/coredb-services-devel.git

pushd coredb-services-devel || exit

mvn -T 1C clean install -Pdev,full,deploy-with-ttom,dev-toggles -Dmaven.test.skip -Dmaven.javadoc.skip tomcat7:deploy-only -Dalt.resources.dir="./dev-resources" -Ddb.host=test-postgres -Ddb.prefix=coredb -DvalidateInterface.skip=ALL || true

popd || exit

./truncate_localizer.sh
