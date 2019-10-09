gcloud dataproc workflow-templates add-job pyspark gs://onprem2gcp-gcp-target-data/empty.py --step-id empty --workflow-template pull-cluster-template --region europe-west3
gcloud dataproc workflow-templates instantiate pull-cluster-template --region europe-west3
