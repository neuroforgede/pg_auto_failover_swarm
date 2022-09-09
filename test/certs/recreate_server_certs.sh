rm -r monitor
rm -r node_1
rm -r node_2

bash gen_server_cert.sh root_ca monitor/postgres_server monitor.local unused
bash gen_server_cert.sh root_ca node_1/postgres_server node1.local unused
bash gen_server_cert.sh root_ca node_2/postgres_server node2.local unused
