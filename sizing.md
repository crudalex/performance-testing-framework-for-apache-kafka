# Targeted Cluster Throughput 
| MB/s (1 kb msg)                                | 488.28 |
| ---------------------------------------------- | ------ |
| MB/s Provisioned for AZ failure (MB/s \* 1.33) | 650.88 |


# Recommended Sizing (Plan 13)
| Sizing Parameters                                       | Value            |
| --------------------------------------------------------| -----------------|
| instance type                                           | kafka.m5.2xlarge |
| #brokers                                                | 9                |
| replication factor                                      | 3                |
| #consumer groups                                        | 4                |
| instance usd/monthly                                    | 832              |
| tEC2network                                             | 640              |
| max(tEC2network)                                        | 512              |
| max(tEC2network) \* #brokers/(#consumer groups + r-1)   | 768              |
| tstorage                                                | 288              |
| max(tstorage)                                           | 230              |
| IO Bound?                                               | 1                |
| provisioning throughput                                 | 0                |
| provisioned throughput usd/monthly                      |                - |
| max(tstorage) \* #brokers/r                             | 690              |
| max(tcluster)                                           | 690              |
| cluster usd/monthly                                     | 7,484            |

# Assumptions
* average message size of 1KB, sustained throughput = 500k / 1024 = 488.28 MB/s
* Not considering non-ebs-optimized instances. They are not cost efficient. 
* Consumer groups of 4, as there are 4 topics
* Provisioned for a single az faillure in a 3 az in a region. ap-east-1a/b/c
* Burst performance not considered. 
* Replication factor of 3, best practise of Kafka. 
* Latency not a concern, as the cluster serves analytical workload
* Not considering serverless msk
* T3 instance not considered, due to limitation with provisioned throughput. 
* No auto scaling, assuming a 24x7 constant workload. 

# Conclusion
The recommended setup (refer to plan 13 in the appendix) provide sustained throughput of 690 MB/s at the monthly cost of 7,484 USD. 

The ultimate goal of any Kafka setup is to turn a pool of virtual machines into packet pushers, where storage and network throughput are maximized and compute utilization minimized. Therefore, it is crucial to ensure the disk and network throughput are at the same level and that the level matches the cluster throughput objective. Theoretically, we may achieve a low-cost cluster by using provisioned storage throughput so that 1. storage throughput matches network throughput, and 2. given network throughput alone fulfills the cluster throughput objective. 


However, achieving low-cost clusters with provisioned throughput performance is only sometimes possible. As indicated in sizing plans 1-13 (except 11), clusters of smaller instance types are all storage throughput bound. However, provisioned throughput is only available for instance type higher or equal to Kafka.m5.4xlarge. There is no room for small instances to take advantage of provisioned throughput. On the contrary, when a  cluster uses m4.4xlarge or above, the cluster is no more extended storage bound but network bound. Provisioned throughput provides little cost benefit as any scale-out requires increasing nodes. 

However, should lower-cost instances support provisioned storage throughput in the future, we could use low-cost instances and provisioned throughput to achieve a low-cost cluster. An example is to take a nine-node Kafka.t3.small and a provisioned throughput of 613 MB/s to achieve a cluster throughput of 768 MB/s and a monthly cost of $996 (Plan 3). 

I did not go into details of resource creation and performance testing as my original intention was to borrow the work of [2] but failed when I find was unfamiliar with CDK and had to give up due to time constraints. However, a similar setup can be created with relatively ease with [4] and performance testing conducted based on kafka-cli [5]. 

The key metric to observe would be the aggregated throughput from the producer and consumer. I would argue latency, specifically p99 latency, is of secondary concern as we are serving an analytical workload, not transactional. Finally, monitoring the consumption of the burst tokens, such as BurstBalance, CPUCreditBalance, and TrafficShaping, may be used as an early indicator of increased traffic and an evidence to justify a pre-emptive scale-out. 

# Reference
1. [Best practices for right-sizing your Apache Kafka clusters to optimize performance and cost
](https://aws.amazon.com/blogs/big-data/best-practices-for-right-sizing-your-apache-kafka-clusters-to-optimize-performance-and-cost/)
2. [aws-samples/performance-testing-framework-for-apache-kafka](https://github.com/aws-samples/performance-testing-framework-for-apache-kafka)
3. [t3small-perf-test-27-t3small-5334-f-280](https://ap-east-1.console.aws.amazon.com/cloudformation/home?region=ap-east-1#/stacks/stackinfo?filteringText=&filteringStatus=active&viewNested=true&stackId=arn%3Aaws%3Acloudformation%3Aap-east-1%3A341249726843%3Astack%2Ft3small-perf-test-27-t3small-5334-f-280%2F3007c780-c07b-11ed-8a8b-0eee8c07edc8)
4. https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/msk_cluster
5. https://github.com/crudalex/performance-testing-framework-for-apache-kafka/blob/main/cdk/docker/run-kafka-command.sh

# Appendix

## Cluster Sizing Calculation
| id  | instance type     | #brokers | r   | #consumer groups | instance usd/monthly | tEC2network | max(tEC2network) | max(tEC2network) \* #brokers/(#consumer groups + r-1) | tstorage | max(tstorage) | IO Bound? | provisioning throughput | provisioned throughput usd/monthly | max(tstorage) \* #brokers/r | max(tcluster) | cluster usd/monthly |
| --- | ----------------- | -------- | --- | ---------------- | -------------------- | ----------- | ---------------- | ----------------------------------------------------- | -------- | ------------- | --------- | ----------------------- | ---------------------------------- | --------------------------- | ------------- | ------------------- |
| 1   | kafka.t3.small    | 3        | 3   | 4                | 46                   | 640         | 512              | 256                                                   | 22       | 17            | 1         | 613                     | 65                                 | 630                         | 256           | 332                 |
| 2   | kafka.t3.small    | 6        | 3   | 4                | 46                   | 640         | 512              | 512                                                   | 22       | 17            | 1         | 613                     | 65                                 | 1260                        | 512           | 664                 |
| **3**   | kafka.t3.small    | 9        | 3   | 4                | 46                   | 640         | 512              | 768                                                   | 22       | 17            | 1         | 613                     | 65                                 | 1891                        | 768           | 996                 |
| 4   | kafka.m5.large    | 3        | 3   | 4                | 208                  | 640         | 512              | 256                                                   | 81       | 65            | 1         | 538                     | 57                                 | 603                         | 256           | 795                 |
| 5   | kafka.m5.xlarge   | 3        | 3   | 4                | 416                  | 640         | 512              | 256                                                   | 144      | 115           | 1         | 460                     | 49                                 | 575                         | 256           | 1,394               |
| 6   | kafka.m5.large    | 6        | 3   | 4                | 208                  | 640         | 512              | 512                                                   | 81       | 65            | 1         | 538                     | 57                                 | 1207                        | 512           | 1,590               |
| 7   | kafka.m5.large    | 9        | 3   | 4                | 208                  | 640         | 512              | 768                                                   | 81       | 65            | 1         | 538                     | 57                                 | 1810                        | 768           | 2,384               |
| 8   | kafka.m5.2xlarge  | 3        | 3   | 4                | 832                  | 640         | 512              | 256                                                   | 288      | 230           | 1         | 281                     | 30                                 | 511                         | 256           | 2,584               |
| 9   | kafka.m5.xlarge   | 6        | 3   | 4                | 416                  | 640         | 512              | 512                                                   | 144      | 115           | 1         | 460                     | 49                                 | 1151                        | 512           | 2,789               |
| 10  | kafka.m5.xlarge   | 9        | 3   | 4                | 416                  | 640         | 512              | 768                                                   | 144      | 115           | 1         | 460                     | 49                                 | 1726                        | 768           | 4,183               |
| 11  | kafka.m5.4xlarge  | 3        | 3   | 4                | 1,663                | 640         | 512              | 256                                                   | 18750    | 15000         | 0         | 0                       | -                                  | 15000                       | 256           | 4,990               |
| 12  | kafka.m5.2xlarge  | 6        | 3   | 4                | 832                  | 640         | 512              | 512                                                   | 288      | 230           | 1         | 281                     | 30                                 | 1021                        | 512           | 5,167               |
| 13  | kafka.m5.2xlarge  | 9        | 3   | 4                | 832                  | 640         | 512              | 768                                                   | 288      | 230           | 1         | 281                     | 30                                 | 1532                        | 768           | 7,751               |
| 14  | kafka.m5.4xlarge  | 6        | 3   | 4                | 1,663                | 640         | 512              | 512                                                   | 18750    | 15000         | 0         | 0                       | -                                  | 30000                       | 512           | 9,979               |
| 15  | kafka.m5.8xlarge  | 3        | 3   | 4                | 3,334                | 1280        | 1024             | 512                                                   | 30000    | 24000         | 0         | 0                       | -                                  | 24000                       | 512           | 10,001              |
| 16  | kafka.m5.12xlarge | 3        | 3   | 4                | 4,990                | 1536        | 1229             | 614                                                   | 40000    | 32000         | 0         | 0                       | -                                  | 32000                       | 614           | 14,969              |
| 17  | kafka.m5.4xlarge  | 9        | 3   | 4                | 1,663                | 640         | 512              | 768                                                   | 18750    | 15000         | 0         | 0                       | -                                  | 45000                       | 768           | 14,969              |
| 18  | kafka.m5.16xlarge | 3        | 3   | 4                | 6,660                | 2560        | 2048             | 1024                                                  | 60000    | 48000         | 0         | 0                       | -                                  | 48000                       | 1024          | 19,980              |
| 19  | kafka.m5.8xlarge  | 6        | 3   | 4                | 3,334                | 1280        | 1024             | 1024                                                  | 30000    | 24000         | 0         | 0                       | -                                  | 48000                       | 1024          | 20,002              |
| 20  | kafka.m5.12xlarge | 6        | 3   | 4                | 4,990                | 1536        | 1229             | 1229                                                  | 40000    | 32000         | 0         | 0                       | -                                  | 64000                       | 1229          | 29,938              |
| 21  | kafka.m5.24xlarge | 3        | 3   | 4                | 9,979                | 3200        | 2560             | 1280                                                  | 80000    | 64000         | 0         | 0                       | -                                  | 64000                       | 1280          | 29,938              |
| 22  | kafka.m5.8xlarge  | 9        | 3   | 4                | 3,334                | 1280        | 1024             | 1536                                                  | 30000    | 24000         | 0         | 0                       | -                                  | 72000                       | 1536          | 30,002              |
| 23  | kafka.m5.16xlarge | 6        | 3   | 4                | 6,660                | 2560        | 2048             | 2048                                                  | 60000    | 48000         | 0         | 0                       | -                                  | 96000                       | 2048          | 39,960              |
| 24  | kafka.m5.12xlarge | 9        | 3   | 4                | 4,990                | 1536        | 1229             | 1843                                                  | 40000    | 32000         | 0         | 0                       | -                                  | 96000                       | 1843          | 44,906              |
| 25  | kafka.m5.24xlarge | 6        | 3   | 4                | 9,979                | 3200        | 2560             | 2560                                                  | 80000    | 64000         | 0         | 0                       | -                                  | 128000                      | 2560          | 59,875              |
| 26  | kafka.m5.16xlarge | 9        | 3   | 4                | 6,660                | 2560        | 2048             | 3072                                                  | 60000    | 48000         | 0         | 0                       | -                                  | 144000                      | 3072          | 59,940              |
| 27  | kafka.m5.24xlarge | 9        | 3   | 4                | 9,979                | 3200        | 2560             | 3840                                                  | 80000    | 64000         | 0         | 0                       | -                                  | 192000                      | 3840          | 89,813              |


## EC2 Capacity Specifications
| Broker            | Broker2     | vCPU | Memory | Price  | tEBSnetwork MB/s | tEC2network Gb/s | tEC2network MB/s |
| ----------------- | ----------- | ---- | ------ | ------ | ---------------- | ---------------- | ---------------- |
| kafka.t3.small    | t3.small    | 2    | 2      | 0.0639 | 21.75            | 5                | 640              |
| kafka.m5.large    | m5.large    | 2    | 8      | 0.289  | 81.25            | 5                | 640              |
| kafka.m5.xlarge   | m5.xlarge   | 4    | 16     | 0.578  | 143.75           | 5                | 640              |
| kafka.m5.2xlarge  | m5.2xlarge  | 8    | 32     | 1.155  | 287.5            | 5                | 640              |
| kafka.m5.4xlarge  | m5.4xlarge  | 16   | 64     | 2.31   | 18750            | 5                | 640              |
| kafka.m5.8xlarge  | m5.8xlarge  | 32   | 128    | 4.63   | 30000            | 10               | 1280             |
| kafka.m5.12xlarge | m5.12xlarge | 48   | 192    | 6.93   | 40000            | 12               | 1536             |
| kafka.m5.16xlarge | m5.16xlarge | 64   | 256    | 9.25   | 60000            | 20               | 2560             |
| kafka.m5.24xlarge | m5.24xlarge | 96   | 384    | 13.86  | 80000            | 25               | 3200             |
