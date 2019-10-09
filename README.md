# Solution Design Task - Data migration from On Prem to GCP
This repository contains the proposed high level solution to migrate data from an existing On Premise Hadoop Cluster to a new GCP Analytics platform.


# High Level Solution

## Key principles

1. **"Lift and shift" data migration** : data is migrated AS IS from the On Prem Hadoop cluster to an equivalent representation in GCS
2. **Cloud Storage as a data lake** : GCS is well suited to serve as the central storage repository for many reasons (Source: [Cloud Storage as a data lake](https://cloud.google.com/solutions/build-a-data-lake-on-gcp))
3. **Existing Data is pulled from GCP** : Ephemeral Pull Dataproc Clusters will pull data from the On Prem Hadoop Cluster (Source: [Migrating HDFS Data from On-Premises to Google Cloud Platform](https://cloud.google.com/solutions/migration/hadoop/hadoop-gcp-migration-data))
4. **Data migration in stages** : Data is migrated on a per Service base. 
5. **Build new data ingestion pipelines into GCP**: needed for the targert solution and to support the point below. 
6. **New data for a given Service *should* be ingested in both environments untill Service data migration is fully completed** : this approach ensures Analytics Service continuity.


![Subscriber](img/hl-solution.png)




### Push vs Pull?

**The pull model** has been selected. The only disadvantage is the slighlty bigger complexity to implement it while the advantages are:

* Impact on the source cluster's CPU and RAM resources is minimized, because the source nodes are used only for serving blocks out of the cluster. You can also fine-tune the specifications of the pull cluster's resources on GCP to handle the copy jobs, and tear down the pull cluster when the migration is complete.
* Traffic on the source cluster's network is reduced, which allows for higher outbound bandwidths and faster transfers.
* There is no need to install the Cloud Storage connector on the source cluster as the ephemeral Cloud Dataproc cluster, which already has the connector installed, handles the data transfer to Cloud Storage.



### Answers to your questions

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



## Network TO BE

![Subscriber](img/nw-topology-2be.png)


## Network Demo

![Subscriber](img/nw-topology-demo.png)

*Disclaimer:* for the sake of the demo, a VPC Peering between the two VPC has been implemented. 

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

gcloud dataproc workflow-templates add-job pyspark gs://onprem2gcp-gcp-target-data/empty.py --step-id empty --workflow-template pull-cluster-template --region europe-west3


gcloud dataproc workflow-templates instantiate pull-cluster-template --region europe-west3

gcloud dataproc workflow-templates delete pull-cluster-template --region europe-west3


topology https://cloud.google.com/vpn/docs/concepts/topologies#2-gcp-gateways