= Evaluation <result>

This section introduces our benchmarking process, including the benchmarking baselines (@benchmark-baseline), the benchmarking environment (@benchmark-environment) and the microbenchmark program (@microbenchmark). Most importantly, we showcase the results on how well our algorithms perform and conclude with a discussion about the implications of these results in @benchmark-result.

== Benchmarking baselines <benchmark-baseline>

We use three MPSC queue algorithms as benchmarking baselines:

- dLTQueueV2 + our custom SPSC: Our most optimized version of LTQueue while still keeping the core algorithm intact.
- Slotqueue + our custom SPSC: Our modification to dLTQueue to obtain a more optimized distributed version of LTQueue.
- AMQueue @amqueue: A hosted bounded MPSC queue algorithm, already detailed in @dmpsc-related-works.

== Benchmarking environment <benchmark-environment>

We conduct all benchmark evaluations using computing resources at the Leibniz Supercomputing Center#footnote[https://www.lrz.de/], specifically leveraging both the SuperMUC-NG#footnote[https://doku.lrz.de/supermuc-ng-10745965.html] and CoolMUC-4#footnote[https://doku.lrz.de/coolmuc-4-1082337877.html] systems.

SuperMUC-NG provides extensive computational capacity through its configuration of over 6,000 compute nodes. Each node features 48 processing cores powered by Intel Xeon Platinum 8174 processors and is equipped with a minimum of 96GB of memory. Inter-node communication is facilitated by a high-performance OmniPath network delivering 100GBit/s bandwidth. The platform operates on SUSE Linux Enterprise Server 15.3 and employs Intel MPI Version 2019 Update 12 Build 20210429 for parallel processing coordination.

For additional computational resources, we utilize the CoolMUC-4 infrastructure, which comprises over 100 compute nodes totaling approximately 12,000 processing cores. These nodes are powered by Intel Xeon Platinum 8480+ processors, with each node providing 112 cores of processing capability. Node-to-node connectivity is established through an Infiniband network architecture. The system environment consists of SUSE Linux Enterprise Server 15.6 with Intel MPI Version 2021.12 Build 20240213 handling message passing operations.

== Microbenchmark program <microbenchmark>

Our microbenchmark is as follows:

- All processes share a single MPSC; one of the processes is a dequeuer, and the rest are enqueuers.
- The enqueuers enqueue a total of $10^4$ elements.
- The dequeuer dequeues $10^4$ elements.
- The MPSC is warmed up before the dequeuer starts.

We measure the latency and throughput of the enqueue and dequeue operations. This microbenchmark is repeated 5 times for each algorithm, and we take the mean of the results.

== Benchmarking results <benchmark-result>

#import "@preview/subpar:0.2.2"

@enqueue-benchmark, @dequeue-benchmark, and @total-benchmark showcase our benchmarking results, with the y-axis drawn in log scale.

#subpar.grid(
  figure(
    image("../../static/images/cm4/enqueue_latency_comparison.png"),
    caption: [Enqueue latency benchmark results on CoolMUC-4.],
  ),
  <cm4-enqueue-latency-benchmark>,
  figure(
    image("../../static/images/cm4/enqueue_throughput_comparison.png"),
    caption: [Enqueue throughput benchmark results on CoolMUC-4.],
  ),
  <cm4-enqueue-throughput-benchmark>,
  figure(
    image("../../static/images/sm/enqueue_latency_comparison.png"),
    caption: [Enqueue latency benchmark results on SuperMUC.],
  ),
  <sm-enqueue-latency-benchmark>,
  figure(
    image("../../static/images/sm/enqueue_throughput_comparison.png"),
    caption: [Enqueue throughput benchmark results on SuperMUC.],
  ),
  <sm-enqueue-throughput-benchmark>,
  columns: (1fr, 1fr),
  caption: [Microbenchmark results for the enqueue operation.],
  label: <enqueue-benchmark>,
)

#subpar.grid(
  figure(
    image("../../static/images/cm4/dequeue_latency_comparison.png"),
    caption: [Dequeue latency benchmark results on CoolMUC-4.],
  ),
  <cm4-dequeue-latency-benchmark>,
  figure(
    image("../../static/images/cm4/dequeue_throughput_comparison.png"),
    caption: [Dequeue throughput benchmark results on CoolMUC-4.],
  ),
  <cm4-dequeue-throughput-benchmark>,
  figure(
    image("../../static/images/sm/dequeue_latency_comparison.png"),
    caption: [Dequeue latency benchmark results on SuperMUC.],
  ),
  <cm4-dequeue-latency-benchmark>,
  figure(
    image("../../static/images/sm/dequeue_throughput_comparison.png"),
    caption: [Dequeue throughput benchmark results on SuperMUC.],
  ),
  <cm4-dequeue-throughput-benchmark>,

  columns: (1fr, 1fr),
  caption: [Microbenchmark results for the dequeue operation.],
  label: <dequeue-benchmark>,
)

#subpar.grid(
  figure(
    image("../../static/images/cm4/total_throughput_comparison.png"),
    caption: [Total throughput benchmark results on CoolMUC-4.],
  ),
  <cm4-total-throughput-benchmark>,
  figure(
    image("../../static/images/sm/total_throughput_comparison.png"),
    caption: [Total throughput benchmark results on SuperMUC.],
  ),
  <sm-total-throughput-benchmark>,
  columns: (1fr, 1fr),
  caption: [Microbenchmark results for the total throughput.],
  label: <total-benchmark>,
)

The most evident thing is that the trends in total throughput and dequeue throughput are almost identical. This supports our claim that in an MPSC queue, the performance is bottlenecked by the dequeuer.

Slotqueue demonstrates superior enqueue performance compared to AMQueue on both CoolMUC-4 and SuperMUC-NG systems, achieving roughly double the throughput. Meanwhile, dLTQueueV2 performs the worst enqueue-wise. The performance advantage of Slotqueue results from reduced contention between concurrent enqueuers and minimal interference between enqueue and dequeue operations in Slotqueue's architecture, unlike AMQueue's design. However, despite Slotqueue and dLTQueueV2's theoretical guarantee of constant-time enqueue operations, practical measurements reveal declining enqueue throughput as cluster size increases. This performance degradation occurs due to heightened competition for the shared counter resource among multiple enqueuers, which eventually overwhelms the interconnect infrastructure's capacity.

In contrast, Slotqueue and dLTqueue's dequeue performance significantly lags behind AMQueue, showing 10-fold slower performance on CoolMUC-4 and 3-fold slower performance on SuperMUC-NG. While Slotqueue and dLTQueueV2 execute only a limited number of remote operations per dequeue compared to AMQueue's potentially unlimited remote operations, AMQueue's batch processing capability dramatically enhances its dequeue throughput. Additionally, AMQueue's architecture stores all data locally on the dequeuer node, eliminating remote operations during dequeue processes entirely. Consequently, Slotqueue and dLTQueueV2's benefits become less pronounced when measured against AMQueue's optimized approach. Similar to enqueue operations, dequeue throughput also declines with increasing node count, as more processes competing for access to the dequeuer node intensify contention at that critical bottleneck.

While Slotqueue and dLTQueueV2 offer superior fault tolerance compared to AMQueue and maintains competitive performance across both evaluated systems, it faces challenges under high-contention scenarios. In large-scale cluster deployments, the dequeuer node becomes overwhelmed by numerous remote memory access requests. Therefore, Slotqueue and dLTQueueV2 would benefit from additional optimizations focused on alleviating contention pressure at the dequeuer node to realize its full potential in distributed environments.

