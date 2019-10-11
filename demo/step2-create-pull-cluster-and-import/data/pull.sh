hadoop distcp -Dmapreduce.map.memory.mb=4096 -Dyarn.app.mapreduce.am.resource.mb=4096 -prb -bandwidth 50 -m 16 -strategy dynamic hdfs://10.156.0.2/service-x/ gs://onprem2gcp-migrated-data-service-x/
