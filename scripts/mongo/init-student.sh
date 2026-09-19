#!/bin/bash
mongosh --quiet -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin <<JS
use shop
db.createUser({user: "student", pwd: "$MONGO_STUDENT_PASSWORD", roles: [{role: "readWrite", db: "shop"}]})
JS
