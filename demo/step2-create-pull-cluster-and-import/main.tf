provider "google" {
  credentials = file("../demo-onprem2gcp-serviceAccount.json")

  project = "onprem2gcp"
  region  = "europe-west3"
  zone    = "europe-west3-a"
}

#creates data migration bucket
resource "google_storage_bucket" "service-x-bucket" {
  name                = "onprem2gcp-migrated-data-service-x"
  location            = "europe-west3"
  force_destroy       = "false"
  storage_class       = "REGIONAL"
  bucket_policy_only  = false
  encryption {
    default_kms_key_name = "projects/onprem2gcp/locations/europe-west3/keyRings/gcp-target-key-ring-3/cryptoKeys/service-x-crypto-key"
  }  
  labels              = {
    service = "service-x"
  }

  provisioner "local-exec" {
    command = "echo hadoop distcp hdfs://10.156.0.2/service-x/ gs://onprem2gcp-migrated-data-service-x/ > ./data/import.sh"
  }
}

#creates support bucket
resource "google_storage_bucket" "support-bucket" {
  name          = "onprem2gcp-gcp-target-data"
  location      = "EU"
  depends_on = [
        google_storage_bucket.service-x-bucket,
  ]
}

#uploads data import script in the support bucket
resource "google_storage_bucket_object" "import-script" {
  name   = "pull.sh"
  source = "./data/pull.sh"
  bucket = "onprem2gcp-gcp-target-data"
  depends_on = [
        google_storage_bucket.support-bucket,
  ]
}

#uploads empty job in the support bucket
resource "google_storage_bucket_object" "job" {
  name   = "empty.py"
  source = "./data/empty.py"
  bucket = "onprem2gcp-gcp-target-data"
  depends_on = [
        google_storage_bucket.support-bucket,
  ]
}

#Local executor that creates workflow and cluster templates for later execution
resource "null_resource" "create-template-and-cluster" {
  provisioner "local-exec" {
    command = "./data/createWFTandEC.sh"
  }
}

#Local executor that destroys workflow and cluster templates
resource "null_resource" "delete-template" {
  provisioner "local-exec" {
    when    = "destroy"
    command = "gcloud dataproc workflow-templates delete pull-cluster-template --region europe-west3"
  }
}

#SPIN UP THE EPHEMERAL CLUSTER ONCE THE MIGRATION BUCKET IS CREATED
#THE CLUSTER WILL BE AUTOMATICALLY DELETED ONCE THE DATA PULL IS COMPLETED
resource "null_resource" "pull" {
  provisioner "local-exec" {
    command = "./data/executeJob.sh"
  }
  depends_on = [
        google_storage_bucket_object.job,
  ]
}

#Key rings and keys 
/*resource "google_kms_key_ring" "gcp-target-key-ring-3" {
  name     = "gcp-target-key-ring-3"
  location = "europe-west3"
}

resource "google_kms_crypto_key" "service-x-crypto-key" {
  name     = "service-x-crypto-key"
  key_ring = "projects/onprem2gcp/locations/europe-west3/keyRings/gcp-target-key-ring-3/cryptoKeys/service-x-crypto-key"
}*/
