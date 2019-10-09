provider "google" {
  credentials = file("../demo-onprem2gcp-serviceAccount.json")

  project = "onprem2gcp"
  region  = "europe-west3"
  zone    = "europe-west3-a"
}

provider "google-beta" {
  credentials = file("../demo-onprem2gcp-serviceAccount.json")

  project = "onprem2gcp"
  region  = "europe-west3"
  zone    = "europe-west3-a"
}

#creates support bucket
resource "google_storage_bucket" "support-bucket" {
  name          = "onprem2gcp-gcp-target-data"
  location      = "EU"
}


#uploads data import script in the support bucket
resource "google_storage_bucket_object" "data-import-script" {
  name   = "import.sh"
  source = "./data/import.sh"
  bucket = "onprem2gcp-gcp-target-data"
  depends_on = [
        google_storage_bucket.support-bucket,
  ]
}

#creates the demo on prem cluster loading sample data
/*resource "google_dataproc_cluster" "gcp-pull-cluster" {
    name       = "gcp-pull-cluster"
    region     = "europe-west3"

    cluster_config {
        master_config {
            num_instances     = 1
            machine_type      = "n1-standard-1"
            disk_config {
                boot_disk_type = "pd-ssd"
                boot_disk_size_gb = 15
            }
        }

        gce_cluster_config {
            subnetwork = "gcp-target-hadoop-cluster-nw"
        }

        software_config {
            image_version       = "1.3.7-deb9"
            override_properties = {
                "dataproc:dataproc.allow.zero.workers" = "true"
            }
        }

        initialization_action {
            script      = "gs://onprem2gcp-gcp-target-data/import.sh"
            timeout_sec = 500
        }
    }
    depends_on = [
        google_storage_bucket_object.data-import-script,
    ]

}*/

#creates support bucket
resource "google_storage_bucket" "service-x" {
  name          = "onprem2gcp-migrated-data-service-x"
  location      = "EU"
}