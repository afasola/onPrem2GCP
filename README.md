# Solution Design Task - Data migration from On-Prem to GCP
This repository contains the proposed high-level solution to migrate data from an existing On-Premise Hadoop Cluster to a new GCP Analytics platform.


# High-Level Solution

## Key principles

1. **"Lift and shift" data migration**
2. **Cloud Storage as a data lake**
3. **Data is pulled from On-Prem by an ephemeral cluster in GCP**
4. **Data migration per Service and in stages** 
5. **Build new data ingestion pipelines into GCP**
6. **Ad interim new data ingestion**

### 1. "Lift and shift" data migration
Data is migrated *AS-IS* from the On-Prem Hadoop cluster to an equivalent representation in GCS (Google Cloud Storage).

This approach has several benefits:
- it simplifies the migration strategy: for each main folder in HDFS there will be an equivalent bucket in GCS
- it ensures consistency between source data and migrated data. Moving from one environment/technology to another implies risks. A 1-2-1 migration reduces the risk to lose or alter the semantic of the data, e.g.: if data was organized in a certain folder structure and hierarchy that will be preserved
- the subsequent migration of the jobs will be very simple: jobs will have to be adjusted to point the resource used from hdfs://... to gs://...
- with this approach, the migration of the first service (or a similar test executed in preproduction) will help to determine with high precision the time required for the full migration

### 2. Cloud Storage as a data lake
GCS is well suited to serve as the central storage repository for many reasons. (Source: [Cloud Storage as a data lake](https://cloud.google.com/solutions/build-a-data-lake-on-gcp))

- Performance and durability: can store from few files to exabyte volumes with 11 Nines of durability.
- Strong consistency: almost all operations on data and metadata have strong consistency which means that the result of the operation produces an immediate effect after a success response from the platform. Access revocation instead can take up to one minute. Cache-control can have some discrepancies if not properly handled. [More details](https://cloud.google.com/storage/docs/consistency)
- Cost efficiency: several storage classes for several purposes (depending on the access frequency and the location/availability) together with lifecycle policies, allow controlling the storage costs. 
- Flexible processing: it's fully integrated with many GCP services simplifying the adoption of them
- Central repository: data is in one place only!
- Security: access control and encryption are built-in
  
*Disclaimer*: BigQuery is a service well suited for storing data too. For example, raw data could be stored in BigQuery. However, there shall be a consideration made around the data itself: BigQuery stores data in a denormalized form, meaning that if one raw data is normalized and gets loaded in BigQuery, BigQuery will create as many table raws as required to fully represent the original data. For example:

this JSON 

```
{
  "field1": "value1",
  "field2": "value2",
  "field3": "value3",
  "nested": {
    "nested1": "n_value1",
    "nested2": "n_value2",
    "nested3": "n_value3"
  }
}
```
once loaded in BigQuery will be represented as

```
--------------------------------------
| field1 | field2 | field3 | nested  |
--------------------------------------
| value1 | value2 | value3 | nested1 |
| value1 | value2 | value3 | nested2 |
| value1 | value2 | value3 | nested3 |
| value1 | value2 | value3 | nested4 |
--------------------------------------
```
with a clear increase in space allocation to store the object. Of course, the more normalized and complex the data the higher the space required to represent and store it in a denormalized form.

1.2PB of data costs ~ 30.000EURO a month to be stored in GCS. The "same amount" in BigQuery costs ~25.000EURO. It's apparently cheaper. However, once the data will be loaded in BigQuery and it will be denormalized, in case of complex data, the required space could multiply for a factor of 2, or 3 or even much more. The related cost for storage will follow this trend. 

This does not mean that BigQuery is not a valuable service for storing data. Actually, it provides extremely powerful features that are not possible in GCS and enables access to data in a much simpler way.

My final consideration is: BigQuery can be used as well, as long as it's clear the type of data that are going to be loaded in there and related consequences in terms of costs. Also, BigQuery can read data from GCS without the need for loading the data itself. Performance can be affected as a consequence, but it could be a good trade-off in certain cases where speed is not a requirement. 

Having the data migrated from On-Prem to GCS enables us to explore this option later.
  
### 3. Data is pulled from On-Prem by an ephemeral cluster in GCP
Ephemeral Pull Dataproc Clusters will pull data from the OnPrem Hadoop Cluster (Source: [Migrating HDFS Data from On-Premises to Google Cloud Platform](https://cloud.google.com/solutions/migration/hadoop/hadoop-gcp-migration-data))

The official documentation describes and explains two approaches to copy data from HDFS to GCP (GCS): push model vs pull model. Both based on the usage of the DistCp command provided by Hadoop. The slightly bigger complexity to implement the pull model is paid back with a lot of advantages: 

* Impact on the source cluster's CPU and RAM resources is minimized because the source nodes are used only for serving blocks out of the cluster. You can also fine-tune the specifications of the pull cluster's resources on GCP to handle the copy jobs, and tear down the pull cluster when the migration is complete.
* Traffic on the source cluster's network is reduced, which allows for higher outbound bandwidths and faster transfers.
* There is no need to install the Cloud Storage connector on the source cluster as the ephemeral Cloud Dataproc cluster, which already has the connector installed, handles the data transfer to Cloud Storage.

To me, the biggest advantage is the following: migration to the cloud requires and enables a paradigm shift. We no longer need a monolithic Hadoop cluster running 24/7 and shared across all the services and propositions, with all the complexity that arises from that. We can instead spin up a dedicated cluster for each job that needs to be executed. A cluster fully tailored for the specific job that runs only for the duration of the job and it gets automatically destroyed after completion. The advantages are many, in terms of costs, maintenance and availability. Starting this paradigm shift and learning how to do it during the data migration phase put the right bases and builds the right knowledge to use it later for the BAU activities. 


### 4. Data migration per Service and in stages
Data should be migrated on a per Service base. And for each service, starting with the less important data and learning the process to do it.

Once data is migrated, a 1-2-1 migration of the related job can happen and whenever possible, using ephemeral clusters for their execution. This offers also a good opportunity to prove the consistency of the new results in the new environment.


### 5. Build new data ingestion pipelines into GCP
Possibly not in scope for this exercise but for sure required in the real scenario. 

New data ingestion pipelines have to be built to allow the migration to GCP. The TO-BE scenario assumes that new data will be ingested directly into GCP and having them implemented in parallel while migrating the data is one enabler that supports the last principle.


### 6. Ad interim new data ingestion
This approach ensures the Analytics Service continuity while building the foundation for a seamless transition.

The idea is that already during the migration, data ingestion happens in both environments. The benefits are:

- possibly fewer data to be migrated. If the new ingestion pipelines work properly there is no need to transfer new data from On-Prem. In the worst-case instead, they will be available in the old environment and migrated when needed.
- all data is always available on-prem. This ensures service continuity
- when all the service data is migrated and the new ingestion pipelines are proved to work properly the legacy ingestion pipeline can be closed.


# High-level solution (DEMO) overview

This demo project uses Terraform to automate the creation od two environments in GCP, respectively the On-Prem environment (source of data) and the new GCP Analytics Platform (target destination). 

## On-Prem environment
When created it's composed by:

- VPC (Virtual Private Cloud) in the europe-west3 region
- a subnetwork for the Hadoop Cluster in the europe-west3 region 
- a VPC Peering with the target environment
- a firewall rule which allows TCP outgoing traffic to the target cloud
- a firewall rule which allows SSH to machines in the cluster subnetwork
- a Hadoop Cluster with one master in the europe-west3 region
- a regional support bucket containing some sample data to be loaded in the On-Prem Hadoop cluster together with a script to load in Hadoop

## GCP target environment
When created it's composed by:

- VPC (Virtual Private Cloud) in the europe-west3 region
- a subnetwork for the Hadoop Cluster in the europe-west3 region 
- a VPC Peering with the target environment
- a support bucket containing import jobs required by the ephemeral pull cluster
- Dataproc Workflow Template used to generate the ephemeral pull cluster on job submission
- a GCS bucket where data will be migrated to




![Subscriber](img/hl-solution.png)


## Network TO BE

![Subscriber](img/nw-topology-2be.png)


## Network Demo

![Subscriber](img/nw-topology-demo.png)

*Disclaimer:* for the sake of the demo, a VPC Peering between the two VPC has been implemented. 

## Demo

### Preconditions

- Terraform is installed
- there is an active service account with privilegies to create and destroy resources
- the related service account key is dowloaded and copied the ./demo folder
- the Cloud Store service account is authorised to use the provided encryption key (in this case the service-x-crypto-key in the gcp-target-key-ring-3 key ring)

```
gsutil kms authorize -p onprem2gcp -k projects/onprem2gcp/locations/europe-west3/keyRings/gcp-target-key-ring-3/cryptoKeys/service-x-crypto-key
```

### Step 1
This is the preparation of the environments.

From folder "./demo/step1-create-environments" run 

```
terraform init
terraform apply
```

Verify that:
- on-prem and the target VPC have been created. [Verify](https://console.cloud.google.com/networking/networks/list?project=onprem2gcp)
- the related subnetrowks exist in their respective VPCs
- there is peering betweenn the VPCs. [Verify](https://console.cloud.google.com/networking/peering/list?project=onprem2gcp&peeringTablesize=50)
- there are two firewall rules. One to allo SSH on the Cluster and one to allow traffic from On-Prem to GCP. [Verify](https://console.cloud.google.com/networking/firewalls/list?project=onprem2gcp&firewallTablesize=50)
- there a Hadoop Cluster in the On-Prem subnetwork. [Verify](https://console.cloud.google.com/dataproc/clusters?project=onprem2gcp)
- there is a support bucket containig data which have been loaded in the On-Prem Hadoop Cluster. [Verify](https://console.cloud.google.com/storage/browser?project=onprem2gcp)
- verity that data is in Hadoop as described below

Connect to the Hadoop Cluster machine in ssh:

```
gcloud beta compute --project "onprem2gcp" ssh --zone "europe-west3-b" "on-prem-cluster-m" 
```

Once connected, run a few Hadoop commands. Eg:

```
hadoop fs -ls hdfs://on-prem-cluster-m/service-x/ 

or 

hadoop fs -cat hdfs://on-prem-cluster-m/service-x/raw/service-x-raw.json
```

We are now ready to import the data!

### Step 2

From folder "./demo/step2-create-pull-cluster-and-import" run 

```
terraform init
terraform apply
```


Verify that:

- there is a new bucket where data will be imported and it's empty. [Verify](https://console.cloud.google.com/storage/browser?project=onprem2gcp)
- there is a new Workflow Template. [Verify](https://console.cloud.google.com/dataproc/workflows/templates?project=onprem2gcp)
- a new ephemeral pull Hadoop Cluster is being created. [Verify](https://console.cloud.google.com/dataproc/clusters?project=onprem2gcp)
- there is a new Workflow Instance being executed. [Verify](https://console.cloud.google.com/dataproc/workflows/instances?project=onprem2gcp)

Once the job is completed, verify that:

- the ephemeral pull cluster has been deleted. [Verify](https://console.cloud.google.com/dataproc/clusters?project=onprem2gcp)
- data has been imported in the target bucket. [Verify](https://console.cloud.google.com/storage/browser/onprem2gcp-migrated-data-service-x?project=onprem2gcp)




# Answers to your questions

- **Your vision for the data analytics at GCP**
  * **Answer**: TODO
- **The GCP target architecture and the GCP technologies you have chosen**
    - Considering the storage technology on GCP and suggest which solution to use for raw and aggregated data and why?
    - Draft a data architecture for storage layer with considering cost and performance aspects
      - Aggregation? Retention? Data classification?
      - Best practices & recommendation to use data for Analytics?
    - How do you implement data governance and security on GCP?
      - Control mechanism of granting access to data
        - Who access when & which data?
      - How to secure data due to GDPR compliance requirements?
        - Encryption solution? (Encryption on-fly in data stream <-> Encryption on persisted data
    * **Answer**: TODO
- **Specific tasks and processes that benefit from the chosen GCP technologies**
    * **Answer**: TODO
- **Migration strategy**
  - How to automate data transfer of existing data on Hadoop to GCP?
  - What should be considered for the transit? (secure transit communication, file format?)
  * **Answer**: TODO
- **Brief indication of milestones and timelines**
  * **Answer**: TODO
- **Any special considerations for rolling out the proposed initiative**
  * **Answer**: TODO
- **Criteria by which success will be determined**
  * **Answer**: TODO
- **Plans for extending the GCP roadmap to our advantage in the future**
  * **Answer**: TODO


