= Distributed MPSC queues <distributed-queues>

Based on the MPSC queue algorithms we have surveyed in @related-works[], we propose two wait-free distributed MPSC queue algorithms:
- dLTQueue (@dLTQueue) is a direct modification of the original LTQueue @ltqueue without any usage of LL/SC, adapted for distributed environment.
- Slotqueue (@slotqueue) is inspired by the timestamp-refreshing idea of dLTQueue @ltqueue and repeated-rescan of Jiffy @jiffy. Although it still bears some resemblance to LTQueue, we believe that it is more optimized for distributed context.

In actuality, dLTQueue and Slotqueue are more than simple MPSC algorithms. They are _MPSC queue wrappers_, that is, given an SPSC queue implementation, they yield an MPSC implementation. There is one additional constraint: The SPSC interface must support an additional `readFront` operation, which returns the first data item currently in the SPSC queue.

This fact has an important implication: when we are talking about the characteristics (correctness, progress guarantee, performance model, ABA solution and safe memory reclamation scheme) of an MPSC queue wrapper, we are talking about the correctness, progress guarantee, performance model, ABA solution and safe memory reclamation scheme of the wrapper that turns an SPSC queue to an MPSC queue:
- If the underlying SPSC queue is linearizable, the resulting MPSC queue is linearizable.
- The resulting MPSC queue's progress guarantee is the weaker guarantee between the wrapper's and the underlying SPSC's.
- If the underlying SPSC queue is safe against ABA problem and memory reclamation, the resulting MPSC queue is also safe against these problems.
- If the underlying SPSC queue is unbounded, the resulting MPSC queue is also unbounded.
- The theoretical performance of dLTQueue and Slotqueue has to be coupled with the theoretical performance of the underlying SPSC.

The characteristics of these MPSC queue wrappers are summarized in @summary-of-distributed-mpscs. For benchmarking purposes, we use a baseline distributed SPSC introduced in @distributed-spsc in combination with the MPSC queue wrappers. The characteristics of the resulting MPSC queues are also shown in @summary-of-distributed-mpscs, which will be proven in @theoretical-aspects.

#figure(
  kind: "table",
  supplement: "Table",
  caption: [Characteristic summary of our proposed distributed MPSC queues. #linebreak() (1) $n$ is the number of enqueuers. #linebreak() (2) $R$ stands for *remote operation* and $L$ stands for *local operation*. #linebreak() (\*) The underlying SPSC is assumed to be our simple distributed SPSC in @distributed-spsc.],
  table(
    columns: (1fr, 1.5fr, 1.5fr),
    table.header(
      [*MPSC queues*],
      [*dLTQueue*],
      [*Slotqueue*],
    ),

    [Correctness], [Linearizable], [Linearizable],
    [Progress guarantee of dequeue], [Wait-free], [Wait-free],
    [Progress guarantee of enqueue], [Wait-free], [Wait-free],
    [Dequeue time-complexity (\*)],
    [$4 log_2(n) R + 6 log_2(n) L$],
    [$3R + 2n L$],

    [Enqueue time-complexity (\*)],
    [$6 log_2(n) R + 4 log_2(n) L$],
    [$4R + 3L$],

    [ABA solution], [Unique timestamp], [No hazardous ABA problem],
    [Safe memory #linebreak() reclamation],
    [No dynamic memory allocation],
    [No dynamic memory allocation],
  ),
) <summary-of-distributed-mpscs>


The rest of this chapter is organized as follows. @distributed-spsc describes a simple baseline distributed SPSC that is utilized as the underlying SPSC in our MPSC queues. @dLTQueue and @slotqueue introduce dLTQueue and Slotqueue, our two wait-free MPSC queues that are our main contributions in this thesis.

In these next few descriptions, we assume that each process in our program is assigned a unique number as an identifier, which is termed as its *rank*. The numbers are taken from the range of `[0, size - 1]`, with `size` being the number of processes in our program.

#include "spsc.typ"
#include "dltqueue.typ"
#include "slotqueue.typ"
