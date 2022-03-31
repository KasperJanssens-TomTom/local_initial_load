export JAVA_OPTS="$JAVA_OPTS -Xmx6G -Xms4G -Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"
export CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=8081 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false -Djava.rmi.server.hostname=coredb-source -Xdebug"
echo custom java opts $JAVA_OPTS
echo custom catalina opts $CATALINA_OPTS
