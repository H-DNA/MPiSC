= Introduction <introduction>

#import "@preview/subpar:0.2.2"

This chapter details the motivation for our research topic: "Studying and developing non-blocking distributed MPSC queues" (@motivation), based on which the objectives (@objective) and scope (@scope) of this study are set out. To summarize, we then come to the formulation of the research question (@research-question) and the overall contributions of the thesis are listed in @contributions. This chapter is ended with a brief description of the structure of the rest of this document.

== Motivation <motivation>

The demand for computation power has been increasing relentlessly. Increasingly complex computation problems arise and accordingly more computation power is required to solve them. Much engineering effort has been put forth toward obtaining more computation power. A popular topic in this regard is distributed computing: The combined power of clusters of commodity hardware can surpass that of a single powerful machine @commodity-supercomputer.

To harness the power of distributed systems, specialized algorithms and data structures need to be devised. Two especially important properties of distributed systems are performance and fault tolerance @favorable-characteristics-of-distributed-systems. Therefore, the algorithms and data structures running on distributed systems need to be highly efficient and fault tolerant. Regarding efficiency, we are concerned with the algorithms' throughput and latency, which are the two main metrics to measure performance. Considering fault tolerance, we are especially interested in the progress guarantee @art-of-multiprocessor-programming characteristic of the algorithms. The progress guarantee criterion divides the algorithms into two groups: blocking and non-blocking. Blocking algorithms allow one faulty process to delay the other processes forever, which is not fault tolerant @nature-of-progress. Non-blocking algorithms are safeguarded against this problem, exhibiting a higher degree of fault tolerance @concurrent-ds.

One of the algorithms that has seen applications in the distributed domain is the multi-producer, single-consumer (MPSC) queue algorithm @amqueue. Furthermore, there are applications and programming patterns in the shared-memory domain that can potentially see similar usage in the distributed domain, such as the actor model @actor-model-paper or the fan-out fan-in pattern @fan-out-fan-in-paper. Although the more general multi-producer, multi-consumer (MPMC) queues suffice for the MPSC workloads, they are typically too expensive for these use cases @wrlqueue @dqueue. Therefore, supporting a specialized non-blocking distributed MPSC queue is still valuable.

However, currently in the literature, there is only one distributed MPSC queue, AMQueue @amqueue. Moreover, even though the author claims that AMQueue is non-blocking, we found that AMQueue is actually blocking (@dmpsc-related-works). This is unlike the shared-memory domain, where there are a lot more research on non-blocking MPSC queues @dqueue @ltqueue @wrlqueue @jiffy. This apparent gap between the two domains have been bridged by some recent research to adapt non-blocking shared-memory algorithms to distributed environments @bcl @bclx @hcl @atomic-objects.
The work by @atomic-objects introduces a method for creating non-blocking distributed data structures within the partitioned global address space (PGAS) framework, particularly targeting the Chapel programming language. However, their methodology faces a significant limitation: it relies on double-word compare-and-swap (DCAS) or 128-bit compare-and-swap (CAS) operations to prevent ABA problems, which lack support from most remote direct memory access (RDMA) hardware systems @atomic-objects.
The HCL framework @hcl provides a distributed data structure library built on RPC over RDMA technology. While functional, this approach demands specialized hardware capabilities from contemporary network interface cards, limiting its portability @bclx. BCL Core @bcl presents a highly portable solution capable of interfacing with multiple distributed programming backends including MPI, SHMEM, and GASNet-EX. However, BCL Core's architecture incorporates 128-bit pointers, creating the same RDMA hardware compatibility issues as @atomic-objects.
For our research, we have selected BCL CoreX @bclx and adopted its design philosophy to adapt existing shared-memory MPSC queues for distributed computing environments. BCL CoreX @bclx extends the original BCL @bcl framework with enhanced features that simplify the development of non-blocking distributed data structures. A key innovation in their approach is the implementation of 64-bit pointers, which are compatible with virtually all large-scale computing clusters and supported by most RDMA hardware configurations. To address ABA problems without relying on specialized instructions like DCAS, they have developed a distributed hazard pointer mechanism. This generic solution provides sufficient portability and flexibility to accommodate the adaptation of most existing non-blocking shared-memory data structures to distributed environments.

In summary, we focus on the design of efficient non-blocking distributed MPSC queues using the BCL CoreX library as the main implementation framework. The next few sections will list the objectives in more details and sum them up in a research question.

== Objective <objective>

Based on what we have listed out in @motivation, we aim to:
- Investigate the principles underpinning the design of fault-tolerant and performant shared-memory algorithms.
- Investigate state-of-the-art shared-memory MPSC queue algorithms as case studies to support our design of distributed MPSC queue algorithms.
- Investigate existing distributed MPSC algorithms to serve as a comparison baseline.
- Model and design distributed MPSC queue algorithms using techniques from the shared-memory literature, specifically the BCL CoreX library.
- Utilize the shared-memory programming model to evaluate various theoretical aspects of distributed MPSC queue algorithms: correctness and progress guarantee.
- Model the theoretical performance of distributed MPSC queue algorithms that are designed using techniques from the shared-memory literature.
- Collect empirical results on distributed MPSC queue algorithms and discuss important factors that affect these results.

== Scope <scope>

The following narrows down what we are going to investigate in the shared-memory literature and which theoretical and empirical aspects we are interested in for our distributed algorithms:
- Regarding the investigation of the design principles in the shared-memory literature, we focus on fault-tolerant and performant concurrent algorithm design using atomic operations and common problems that often arise in this area, namely, ABA problem and safe memory reclamation problem.
- Regarding the investigation of shared-memory MPSC queues currently in the literature, we focus on linearizable MPSC queues that follow strict FIFO semantics and support at least lock-free `enqueue` and `dequeue` operations.
- Regarding correctness, we concern ourselves with the linearizability correctness condition.
- Regarding fault tolerance, we concern ourselves with the concept of progress guarantee, that is, the ability of the system to continue to make forward progress despite the failure of one or more components of the system.
- Regarding algorithm prototyping, benchmarking and optimizations, we assume an MPI-3 setting.
- Regarding empirical results, we focus on performance-related metrics, e.g. throughput and latency.

== Research question <research-question>

Any research effort in this thesis revolves around this research question:

#quote()[How to utilize shared-memory programming principles to model and design distributed MPSC queue algorithms in a correct, fault-tolerant and performant manner?]

This question is further decomposed into smaller subquestions:
+ How to model the correctness of a distributed MPSC queue algorithm?
+ Which factors contribute to the fault tolerance and performance of distributed MPSC queue algorithms?
+ Which shared-memory programming principles are relevant in modeling and designing distributed MPSC queue algorithms in a fault-tolerant and performant manner?
+ Which shared-memory programming principles need to be modified to more effectively model and design distributed MPSC queue algorithms in a fault-tolerant and performant manner?

== Contributions <contributions>

This research makes two primary contributions to the field of distributed programming:
- An application of a novel design technique for non-blocking distributed data structures - via adaptation of non-blocking shared-memory data structures. The thesis demonstrates the feasibility of this approach in designing new non-blocking distributed data structures.
- Three novel wait-free distributed MPSC queues: dLTQueue, Slotqueue and dLTQueueV2, which are all fault-tolerant. Slotqueue and dLTQueueV2 are especially optimized for performance.

In conclusion, this work establishes a foundation for future research in fault-tolerant distributed data structures while providing immediately usable implementations for practitioners.

== Structure <structure>

The rest of this report is structured as follows:

@background[] discusses the theoretical foundation this thesis is based on. As mentioned, this thesis investigates the principles of shared-memory programming and the existing state-of-the-art shared-memory MPSC queues. We then explore the utilities offered by MPI-3 and BCL CoreX to implement distributed algorithms modeled by shared-memory programming techniques.

@related-works[] surveys the shared-memory literature for state-of-the-art queue algorithms, specifically MPSC queues. We specifically focus on non-blocking shared-memory algorithms that have the potential to be adapted efficiently for distributed environments. This chapter additionally surveys existing distributed MPSC algorithms to serve as a comparison baseline for our novel distributed MPSC queue algorithms.

@distributed-queues[] introduces our novel distributed MPSC queue algorithms, designed using shared-memory programming techniques and inspired by the selected shared-memory MPSC queue algorithms surveyed in @related-works[]. It specifically presents our adaptation efforts of existing algorithms in the shared-memory literature to make their distributed implementations feasible and efficient.

@result[] details our benchmarking metrics and elaborates on our benchmarking setup. We aim to demonstrate results on how well our novel MPSC queue algorithms perform, additionally compared to existing distributed MPSC queues. Finally, we discuss important factors that affect the runtime properties of distributed MPSC queue algorithms.

@conclusion[] concludes what we have accomplished in this thesis and considers future possible improvements to our research.
