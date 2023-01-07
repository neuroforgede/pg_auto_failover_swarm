rm -r monitor
rm -r postgres

bash gen_server_cert.sh root_ca monitor/postgres_server monitor unused
bash gen_server_cert.sh root_ca postgres/postgres_server postgres unused
