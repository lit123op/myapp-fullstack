#!/bin/bash
# Ipagsabihin sa bash na itigil kaagad ang script kapag may error --
# parehong safety practice gaya ng replica-init.sh
set -e

# Ito ay isang script na AWTOMATIKONG tatakbo ni Postgres sa UNANG
# beses lang na mag-initialize ang primary database (nasa loob ng
# /docker-entrypoint-initdb.d/ folder ang script na 'to, at ganito
# talaga gumagana ang official postgres Docker image -- kahit anong
# .sh o .sql file doon, isasagawa niya ito automatic sa unang startup).

# Gumawa tayo ng bagong PostgreSQL user na tinatawag na "repl_user" --
# ito ang gagamitin ng replica para kumonekta at humingi ng data mula
# sa primary. Ang "REPLICATION" keyword dito ang nagbibigay sa kanya ng
# SPESYAL na pahintulot -- hindi normal na login, kundi partikular na
# para sa streaming replication lang.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER repl_user WITH REPLICATION ENCRYPTED PASSWORD '$POSTGRES_PASSWORD';
EOSQL

# Idinadagdag natin ang isang linya sa "pg_hba.conf" file (ang file na
# kumokontrol kung sino ang pinapayagang kumonekta sa database, at
# saan sila galing). Ang linyang ito ay nagsasabing:
#   "payagan ang koneksyon PARA SA REPLICATION PURPOSES,
#    galing kahit saang IP address sa loob ng Docker network natin
#    (0.0.0.0/0), gamit ang password authentication (md5)"
# Kailangan itong idagdag dahil by default, TINATANGGIHAN ni Postgres
# ang kahit anong koneksyon mula sa labas maliban sa localhost.
echo "host replication all 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf

# Kailangan i-reload ni Postgres ang config file para maapply ang
# bagong linya na idinagdag natin sa itaas
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT pg_reload_conf();
EOSQL