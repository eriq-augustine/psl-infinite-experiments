#!/bin/bash

echo "Clearing Postgres-related caches (for BSOE servers)."

# Do an extra restart so we can guarentee all connections are closed.
bsoe_postgres_stop
bsoe_postgres_start

dropdb -U psl psl
bsoe_postgres_stop

# Page cache, dentries, and inodes.
bsoe_cache_reset

bsoe_postgres_start
createdb -U psl psl

wait
