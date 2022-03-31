FROM ubuntu:20.04

RUN apt-get update && apt-get install curl unzip zip vim git traceroute postgresql-client fish -y

RUN curl -s "https://get.sdkman.io" | bash

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

RUN chmod a+x "$HOME/.sdkman/bin/sdkman-init.sh"

RUN source "$HOME/.sdkman/bin/sdkman-init.sh" && \
  sdk install java 8.0.302-open  && \
  sdk install tomcat 8.5.73 && \
  sdk install maven 3.8.4

ENV PATH=/root/.sdkman/candidates/java/current/bin:$PATH

ENV PATH=/root/.sdkman/candidates/tomcat/current/bin:$PATH
ENV PATH=/root/.sdkman/candidates/maven/current/bin:$PATH

RUN java -version

RUN chmod +x /root/.sdkman/candidates/tomcat/current/bin/*.sh


ADD docker-settings.xml /root/.m2/settings.xml

ADD run_the_liquibase_scripts.sh /run_the_liquibase_scripts.sh

ADD truncate_localizer.sh /truncate_localizer.sh

ADD truncate.sql /truncate.sql

ADD truncate_index.sql /truncate_index.sql

ADD setenv.sh /root/.sdkman/candidates/tomcat/current/bin/setenv.sh

ADD tomcat-users.xml /root/.sdkman/candidates/tomcat/current/conf/tomcat-users.xml

#ADD context.xml /root/.sdkman/candidates/tomcat/current/conf/context.xml
ADD context.xml /root/.sdkman/candidates/tomcat/current/webapps/manager/META-INF/context.xml

#RUN git clone https://bitbucket.tomtomgroup.com/scm/cdb/coredb-services-devel.git /coredb-services-devel

#RUN cd /coredb-services-devel && mvn clean install -DskipTests
#
#RUN git clone https://bitbucket.tomtomgroup.com/scm/cdb/handler-plugins.git  /handler-plugins
#
#RUN cd /handler-plugins && mvn clean install -DskipTests

ENTRYPOINT sleep infinity
#ENTRYPOINT cd coredb-services-devel && ./docker_start.sh
