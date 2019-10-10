provider "google" {
  credentials = file("../demo-onprem2gcp-serviceAccount.json")

  project = "onprem2gcp"
  region  = "europe-west3"
  zone    = "europe-west3-a"
}

######### ON PREM ENVIRONMENT ###########


#On Prem VPC
resource "google_compute_network" "onprem-vpc" {
  name                      = "onprem-vpc"
  routing_mode              = "REGIONAL"
  auto_create_subnetworks   = false
}

#Hadoop cluster subnetwork
resource "google_compute_subnetwork" "onprem-hadoop-cluster-nw" {
  name          = "onprem-hadoop-cluster-nw"
  ip_cidr_range = "10.156.0.0/20"
  region        = "europe-west3"
  network       = "${google_compute_network.onprem-vpc.self_link}"
}

#allow ssh firewall rule (needed only for the demo only)
resource "google_compute_firewall" "allow-ssh-onprem-hadoop-cluster" {
  name    = "allow-ssh-onprem-hadoop-cluster"
  network = "${google_compute_network.onprem-vpc.name}"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["176.198.122.79"]
}

#support bucket (it contains data to be loaded in the On Prem Hadoop cluster + related import script)
resource "google_storage_bucket" "support-bucket" {
  name          = "onprem2gcp-onprem-data"
  location      = "EU"
}

#uploads raw data in the support bucket
resource "google_storage_bucket_object" "data-service-x-raw" {
  name   = "service-x/raw/service-x-raw.json"
  source = "./data/service-x/raw/service-x-raw.json"
  bucket = "onprem2gcp-onprem-data"
  depends_on = [
        google_storage_bucket.support-bucket,
  ]
}

resource "google_storage_bucket_object" "data-service-x-aggregated" {
  name   = "service-x/aggregated/service-x-aggregated.json"
  source = "./data/service-x/aggregated/service-x-aggregated.json"
  bucket = "onprem2gcp-onprem-data"
  depends_on = [
        google_storage_bucket.support-bucket,
  ]
}

resource "google_storage_bucket_object" "data-service-y-raw" {
  name   = "service-y/raw/service-y-raw.json"
  source = "./data/service-y/raw/service-y-raw.json"
  bucket = "onprem2gcp-onprem-data"
  depends_on = [
        google_storage_bucket.support-bucket,
  ]
}

resource "google_storage_bucket_object" "data-service-y-aggregated" {
  name   = "service-y/aggregated/service-y-aggregated.json"
  source = "./data/service-y/aggregated/service-y-aggregated.json"
  bucket = "onprem2gcp-onprem-data"
  depends_on = [
        google_storage_bucket.support-bucket,
  ]
}

#data import script in the support bucket
resource "google_storage_bucket_object" "data-import-script" {
  name   = "load.sh"
  source = "./data/load.sh"
  bucket = "onprem2gcp-onprem-data"
  depends_on = [
        google_storage_bucket.support-bucket,
  ]
}

#On Prem Hadoop cluster + sample data import
resource "google_dataproc_cluster" "on-prem-cluster" {
    name       = "on-prem-cluster"
    region     = "europe-west3"
    labels = {
        foo = "onprem"
    }

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
            subnetwork = "${google_compute_subnetwork.onprem-hadoop-cluster-nw.name}"
        }

        software_config {
            image_version       = "1.3.7-deb9"
            override_properties = {
                "dataproc:dataproc.allow.zero.workers" = "true"
            }
        }
        initialization_action {
            script      = "gs://onprem2gcp-onprem-data/load.sh"
            timeout_sec = 500
        }
    }

    depends_on = [
        google_storage_bucket_object.data-import-script,
    ]
}


######### GCP TARGET ##########

#GCP VPC
resource "google_compute_network" "gcp-target-vpc" {
  name                      = "gcp-target-vpc"
  routing_mode              = "REGIONAL"
  auto_create_subnetworks   = false
}

#Ephemeral Hadoop cluster subnetwork
resource "google_compute_subnetwork" "gcp-target-hadoop-cluster-nw" {
  name          = "gcp-target-hadoop-cluster-nw"
  ip_cidr_range = "10.154.0.0/20"
  region        = "europe-west3"
  network       = "${google_compute_network.gcp-target-vpc.self_link}"
}

#VPC Peering On Prem to GCP
resource "google_compute_network_peering" "onprem-to-gcp-target-peering" {
  name = "onprem-to-gcp-target-peering"
  network = "${google_compute_network.onprem-vpc.self_link}"
  peer_network = "${google_compute_network.gcp-target-vpc.self_link}"
}

#VPC Peering GCP to On Prem
resource "google_compute_network_peering" "gcp-target-to-onprem-peering" {
  name = "gcp-target-to-onprem-peering"
  network = "${google_compute_network.gcp-target-vpc.self_link}"
  peer_network = "${google_compute_network.onprem-vpc.self_link}"
}

#Allow traffic from On Prem to GCP for data pulling
resource "google_compute_firewall" "allow-tcp-from-gcp-target" {
  name    = "allow-tcp-from-gcp-target"
  network = "${google_compute_network.onprem-vpc.name}"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  source_ranges = ["${google_compute_subnetwork.gcp-target-hadoop-cluster-nw.ip_cidr_range}"]
}

########### VPN ###########

/*resource "google_compute_ha_vpn_gateway" "ha-gateway-onprem" {
  provider = "google-beta"
  region   = "europe-west3"
  name     = "ha-vpn-onprem"
  network  = "${google_compute_network.onprem-vpc.self_link}"
}

resource "google_compute_ha_vpn_gateway" "ha-gateway-gcp-target" {
  provider = "google-beta"
  region   = "europe-west3"
  name     = "ha-vpn-gcp-target"
  network  = "${google_compute_network.gcp-target-vpc.self_link}"
}

#creates the on prem vpn router
resource "google_compute_router" "onprem-vpn-router" {
  provider = "google-beta"
  name    = "onprem-vpn-router"
  network = "${google_compute_network.onprem-vpc.name}"
  bgp {
    asn               = 64514
  }
}

#creates the on gcp target vpn router
resource "google_compute_router" "gcp-target-vpn-router" {
  provider = "google-beta"
  name    = "gcp-target-vpn-router"
  network = "${google_compute_network.gcp-target-vpc.name}"
  bgp {
    asn               = 64515
  }
}

resource "google_compute_vpn_tunnel" "tunnel-onprem-2-gcp-target" {
  provider         = "google-beta"
  name             = "ha-vpn-tunnel-onprem-2-gcp-target"
  region           = "europe-west3"
  vpn_gateway      = "${google_compute_ha_vpn_gateway.ha-gateway-onprem.self_link}"
  peer_gcp_gateway = "${google_compute_ha_vpn_gateway.ha-gateway-gcp-target.self_link}"
  shared_secret    = "a secret message"
  router           = "${google_compute_router.onprem-vpn-router.self_link}"
  vpn_gateway_interface = 0
}


resource "google_compute_vpn_tunnel" "tunnel-gcp-target-2-onprem" {
  provider         = "google-beta"
  name             = "ha-tunnel-gcp-target-2-onprem"
  region           = "europe-west3"
  vpn_gateway      = "${google_compute_ha_vpn_gateway.ha-gateway-gcp-target.self_link}"
  peer_gcp_gateway = "${google_compute_ha_vpn_gateway.ha-gateway-onprem.self_link}"
  shared_secret    = "a secret message"
  router           = "${google_compute_router.gcp-target-vpn-router.self_link}"
  vpn_gateway_interface = 0
}


resource "google_compute_router_interface" "router-onprem-if1" {
  provider = "google-beta"
  name       = "router-onprem-if1"
  router     = "${google_compute_router.onprem-vpn-router.name}"
  region     = "europe-west3"
  ip_range   = "169.254.0.1/30"
  vpn_tunnel = "${google_compute_vpn_tunnel.tunnel-onprem-2-gcp-target.name}"
}

resource "google_compute_router_peer" "router-onprem-peer" {
  provider = "google-beta"
  name                      = "router-onprem-peer"
  router                    = "${google_compute_router.onprem-vpn-router.name}"
  region                    = "europe-west3"
  peer_ip_address           = "169.254.0.2"
  peer_asn                  = 64515
  advertised_route_priority = 100
  interface                 = "${google_compute_router_interface.router-onprem-if1.name}"
}


resource "google_compute_router_interface" "router-gcp-target-if1" {
  provider = "google-beta"
  name       = "router-gcp-target-if1"
  router     = "${google_compute_router.gcp-target-vpn-router.name}"
  region     = "europe-west3"
  ip_range   = "169.254.0.1/30"
  vpn_tunnel = "${google_compute_vpn_tunnel.tunnel-gcp-target-2-onprem.name}"
}

resource "google_compute_router_peer" "router-gcp-target-peer" {
  provider                  = "google-beta"
  name                      = "router-gcp-target-peer"
  router                    = "${google_compute_router.gcp-target-vpn-router.name}"
  region                    = "europe-west3"
  peer_ip_address           = "169.254.0.2"
  peer_asn                  = 64514
  advertised_route_priority = 100
  interface                 = "${google_compute_router_interface.router-gcp-target-if1.name}"
}*/