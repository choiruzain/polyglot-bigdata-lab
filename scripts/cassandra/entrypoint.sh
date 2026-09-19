#!/bin/bash
set -e
# Enable password authentication and role-based authorization (works for both yaml styles).
sed -i 's/AllowAllAuthenticator/PasswordAuthenticator/; s/AllowAllAuthorizer/CassandraAuthorizer/' /etc/cassandra/cassandra.yaml
exec docker-entrypoint.sh cassandra -f
