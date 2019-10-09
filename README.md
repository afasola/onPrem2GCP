# onPrem2GCP
Demo - migration from on premises to GCP


# High Level solution

![Subscriber](img/hl-solution.png)

## Source: https://cloud.google.com/solutions/migration/hadoop/hadoop-gcp-migration-data

### Push vs Pull




- Your vision for the data analytics at GCP
- The GCP target architecture and the GCP technologies you have chosen
    - Considering the storage technology on GCP and suggest which solution to use for raw and aggregated data and why?
    - Draft a data architecture for storage layer with considering cost and performance aspects
      - Aggregation? Retention? Data classification?
      - Best practices & recommendation to use data for Analytics?
    - How do you implement data governance and security on GCP?
      - Control mechanism of granting access to data
        - Who access when & which data?
      - How to secure data due to GDPR compliance requirements?
        - Encryption solution? (Encryption on-fly in data stream <-> Encryption on persisted data
- Specific tasks and processes that benefit from the chosen GCP technologies
- Migration strategy
  - How to automate data transfer of existing data on Hadoop to GCP?
  - What should be considered for the transit? (secure transit communication, file format?)

- Brief indication of milestones and timelines
- Any special considerations for rolling out the proposed initiative
- Criteria by which success will be determined
- Plans for extending the GCP roadmap to our advantage in the future









Network TO BE

![Subscriber](img/nw-topology-2be.png)


Network Demo

![Subscriber](img/nw-topology-demo.png)



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