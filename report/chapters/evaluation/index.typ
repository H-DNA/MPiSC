= Evaluation <result>

This section introduces our benchmarking process, including our setup, environment, and our microbenchmark program. Most importantly, we showcase the results on how well our algorithms perform, especially Slotqueue. We conclude this section with a discussion about the implications of these results.

== Benchmarking baselines

We use three MPSC queue algorithms as benchmarking baselines:

- dLTQueue + our custom SPSC: Our most optimized version of LTQueue while still keeping the core algorithm intact.
- Slotqueue + our custom SPSC: Our modification to dLTQueue to obtain a more optimized distributed version of LTQueue.
- AMQueue @amqueue: A hosted bounded MPSC queue algorithm, already detailed in @dmpsc-related-works.

== Microbenchmark program

Our microbenchmark is as follows:

- All processes share a single MPSC; one of the processes is a dequeuer, and the rest are enqueuers.
- The enqueuers enqueue a total of $10^4$ elements.
- The dequeuer dequeues $10^4$ elements.
- The MPSC is warmed up before the dequeuer starts.

We measure the latency and throughput of the enqueue and dequeue operations. This microbenchmark is repeated 5 times for each algorithm, and we take the mean of the results.

== Benchmarking setup

The experiments are carried out on a four-node cluster residing in the HPC Lab at Ho Chi Minh University of Technology. Each node is an Intel Xeon CPU E5-2680 v3, which has 8 cores and 16 GB RAM. The interconnect used is Ethernet and, thus, does not support true one-sided communication.

The operating system used is Ubuntu 22.04.5. The MPI implementation used is MPICH version 4.0, released on January 21, 2022.

== Benchmarking results

#import "@preview/subpar:0.2.2"

@enqueue-benchmark, @dequeue-benchmark, and @total-benchmark showcase our benchmarking results, with the y-axis drawn in log scale.

#subpar.grid(
  figure(
    image("../../static/images/enqueue_latency_comparison.png"),
    caption: [Enqueue latency benchmark results.],
  ),
  <enqueue-latency-benchmark>,
  figure(
    image("../../static/images/enqueue_throughput_comparison.png"),
    caption: [Enqueue throughput benchmark results],
  ),
  <enqueue-throughput-benchmark>,
  columns: (1fr, 1fr),
  caption: [Microbenchmark results for enqueue operation.],
  label: <enqueue-benchmark>,
)

#subpar.grid(
  figure(
    image("../../static/images/dequeue_latency_comparison.png"),
    caption: [Dequeue latency benchmark results.],
  ),
  <dequeue-latency-benchmark>,
  figure(
    image("../../static/images/dequeue_throughput_comparison.png"),
    caption: [Dequeue throughput benchmark results],
  ),
  <dequeue-throughput-benchmark>,
  columns: (1fr, 1fr),
  caption: [Microbenchmark results for dequeue operation.],
  label: <dequeue-benchmark>,
)

#figure(
  image("../../static/images/total_throughput_comparison.png"),
  caption: [Microbenchmark results for total throughput.],
) <total-benchmark>

The most evident thing is that @total-benchmark and @dequeue-throughput-benchmark are almost identical. This supports our claim that in an MPSC queue, the performance is bottlenecked by the dequeuer.

For enqueue latency and throughput, Slotqueue performs far better than dLTQueue while being slightly better than AMQueue. This is in line with our theoretical projection in @summary-of-distributed-mpscs. One concerning trend is that Slotqueue's enqueue throughput seems to degrade with the number of nodes, which signals a potential scalability problem. This is further problematic in that our theoretical model suggests that the cost of enqueue is always fixed. This is to be investigated further in the future.

For dequeue latency and throughput, Slotqueue and AMQueue are quite closely matched, while being better than dLTQueue. This is expected, agreeing with our projection of dequeue wrapping overhead in @summary-of-distributed-mpscs. Furthermore, Slotqueue is conceived as a more dequeuer-optimized version of dLTQueue. Based on this empirical result, it is reasonable to believe this to be the case. Unlike enqueue, the dequeue latency of Slotqueue seems to be quite stable, increasing very slowly. Because the dequeuer is the bottleneck of an MPSC, this is a good sign for the scalability of Slotqueue.

In conclusion, based on @total-benchmark, Slotqueue seems to perform better than dLTQueue and AMQueue in terms of both enqueue and dequeue operations, both latency-wise and throughput-wise. The overhead of a logarithmic-order number of remote operations in dLTQueue seems to be costly, adversely affecting its performance when the number of nodes increases. Additionally, compared to AMQueue, dLTQueue and Slotqueue also have the advantage of fault tolerance, which, due to the blocking nature of AMQueue, cannot be promised.
