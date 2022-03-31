FROM mdillon/postgis:11
MAINTAINER Kasper Janssens <kasper.janssens@tomtom.com>
COPY data /var/lib/postgresql/data
CMD ["postgres", "-c", "fsync=off", "-c", "max_connections=300", "-c", "max_prepared_transactions=300"]
