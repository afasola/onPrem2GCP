provider "google" {
  credentials = file("../demo-onprem2gcp-serviceAccount.json")

  project = "onprem2gcp"
  region  = "europe-west3"
  zone    = "europe-west3-a"
}

#creates data migration bucket
resource "google_storage_bucket" "service-x-bucket" {
  name          = "onprem2gcp-migrated-data-service-x"
  location      = "EU"

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
  name   = "import.sh"
  source = "./data/import.sh"
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

resource "null_resource" "import" {
  provisioner "local-exec" {
    command = "./data/executeJob.sh"
  }
  depends_on = [
        google_storage_bucket_object.job,
  ]
}
