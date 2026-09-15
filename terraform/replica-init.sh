#!/bin/bash
# Ipagsabihin sa bash na itigil kaagad ang script kapag may error sa
# kahit anong command -- para hindi tuloy-tuloy kung may nabigong step
set -e

# Hinihintay muna natin na "ready" (tumatanggap ng connections) ang
# primary database bago tayo tumuloy. Kung agad tayong susubok mag-
# connect nang wala pa itong tapos mag-start, mabibigo ang buong script.
# Ang "repl_user" dito ay yung replication user na tinukoy natin sa
# environment variables ng primary container.
until pg_isready -h tf-db-primary -p 5432 -U repl_user; do
  echo "Naghihintay sa primary database..."
  sleep 2
done

# Tinatanggal natin ang laman ng data directory ng replica bago mag-sync.
# Kailangan itong blangko muna, dahil ang "pg_basebackup" sa susunod na
# linya ang bahalang magpuno nito ng kopya ng data mula sa primary --
# kung may laman na, mag-e-error ito.
rm -rf /var/lib/postgresql/data/*

# Ito ang pangunahing hakbang ng replication setup:
# "pg_basebackup" ay isang built-in PostgreSQL tool na kumukuha ng
# kumpletong "physical copy" ng buong database mula sa primary server.
#   -h tf-db-primary  = kunin mula sa container na ito (via network natin)
#   -D ...             = ilagay ang kinopya sa data directory ng replica
#   -U repl_user       = gamitin ang replication user (hindi regular user)
#   -Fp                = i-format bilang "plain" (regular files, hindi tar)
#   -Xs                = i-stream din ang mga transaction logs habang
#                        kinokopya, para walang mawalang data
#   -R                 = AWTOMATIKONG gumawa ng config file na magsasabi
#                        sa replica na "sundan mo ang primary papuntang
#                        hinaharap" (continuous streaming replication)
PGPASSWORD=$POSTGRES_REPLICATION_PASSWORD pg_basebackup \
  -h tf-db-primary -D /var/lib/postgresql/data -U repl_user -Fp -Xs -R

# Kapag tapos na ang unang pagkopya (Step sa itaas), ipinapasa na natin
# ang control papunta sa normal na PostgreSQL startup script. Dahil
# nandoon na yung "-R" config mula kanina, awtomatiko na itong
# magsisimulang mag-"replay" ng mga bagong pagbabago mula sa primary
# nang walang hinto (real-time replication).
echo "Replica setup complete, starting Postgres..."
exec docker-entrypoint.sh postgres