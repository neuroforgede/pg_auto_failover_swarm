rm -r monitor
rm -r postgres
rm -r admin

bash gen_server_cert.sh root_ca monitor/postgres_server monitor unused
bash gen_server_cert.sh root_ca postgres/postgres_server postgres unused
# cert is named "postgres_server", but works
bash gen_server_cert.sh root_ca admin/postgres_server postgres unused
