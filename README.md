# onPrem2GCP
Demo - migration from on premises to GCP


1. create source cluster
2. create local file
3. copy data into hadoop with command "hadoop distcp file:///home/andrea_fasola/ciccio.txt /test/ciccio"
4. show the file has been loaded with command "hadoop fs -cat /test/ciccio"


connect to the onPrem Hadoop Cluster: gcloud beta compute --project "onprem2gcp" ssh --zone "europe-west3-b" "on-prem-cluster-m" 
connect to the Pull Hadoop Cluster: gcloud beta compute --project "onprem2gcp" ssh --zone "europe-west3-b" "gcp-pull-cluster-m"

https://www.terraform.io/docs/providers/google/r/compute_ha_vpn_gateway.html


gcloud dataproc workflow-templates create pull-cluster-template   --region europe-west3 

gcloud dataproc workflow-templates set-managed-cluster pull-cluster-template \
  --region europe-west3 \
  --subnet gcp-target-hadoop-cluster-nw \
  --zone "" \
  --single-node \
  --master-machine-type n1-standard-4 \
  --master-boot-disk-size 500 \
  --image-version 1.3-deb9 \
  --project onprem2gcp \
  --initialization-actions 'gs://onprem2gcp-gcp-target-data/import.sh'

gcloud dataproc workflow-templates add-job pyspark gs://onprem2gcp-gcp-target-data/do_nothing.py --step-id empty --workflow-template pull-cluster-template --region europe-west3


gcloud dataproc workflow-templates instantiate pull-cluster-template --region europe-west3

gcloud dataproc workflow-templates delete pull-cluster-template --region europe-west3


topology https://cloud.google.com/vpn/docs/concepts/topologies#2-gcp-gateways