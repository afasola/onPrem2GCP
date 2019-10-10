gcloud dataproc workflow-templates create pull-cluster-template --region europe-west3
gcloud dataproc workflow-templates set-managed-cluster pull-cluster-template --region europe-west3 --subnet gcp-target-hadoop-cluster-nw --zone "" --single-node --master-machine-type n1-standard-4 --master-boot-disk-size 500 --image-version 1.3-deb9 --project onprem2gcp --initialization-actions 'gs://onprem2gcp-gcp-target-data/pull.sh'
gcloud dataproc workflow-templates add-job pyspark gs://onprem2gcp-gcp-target-data/empty.py --step-id empty --workflow-template pull-cluster-template --region europe-west3