= Distributed MPSC queues <distributed-queues>

Based on the MPSC queue algorithms we have surveyed in @related-works[], we propose three wait-free distributed MPSC queue algorithms:
- dLTQueue (@dLTQueue) is a direct modification of the original LTQueue @ltqueue without any usage of LL/SC, adapted for distributed environment.
- Slotqueue (@slotqueue) is inspired by the timestamp-refreshing idea of dLTQueue @ltqueue and repeated-rescan of Jiffy @jiffy. Although it still bears some resemblance to LTQueue, we believe that it is more optimized for distributed context.
- dLTQueueV2 (@dLTQueue-v2) introduces some lightweight optimization upon dLTQueue. Therefore, dLTQueueV2 does not deviate much from dLTQueue. However, theory-wise, dLTQueueV2 has the best performance characteristics.

The characteristics of these algorithms are discussed in @summary-of-distributed-mpscs.

#figure(
  kind: "table",
  supplement: "Table",
  caption: [Characteristic summary of our proposed distributed MPSC queues. #linebreak() (1) $n$ is the number of processes. #linebreak() (2) $R$ stands for *remote operation* and $L$ stands for *local operation*.],
  table(
    columns: (2fr, 1.5fr, 1.5fr, 1.5fr),
    table.header(
      [*MPSC queues*],
      [*dLTQueue*],
      [*Slotqueue*],
      [*dLTQueueV2*],
    ),

    [Correctness], [Linearizable], [Linearizable], [Linearizable],
    [Progress guarantee of dequeue], [Wait-free], [Wait-free], [Wait-free],
    [Progress guarantee of enqueue], [Wait-free], [Wait-free], [Wait-free],
    [Dequeue #linebreak() time-complexity],
    [$4 log_2(n) R + 6 log_2(n) L$],
    [$3R + 2n L$],
    [$3R + 10 log(n)L$],

    [Enqueue #linebreak() time-complexity],
    [$6 log_2(n) R + 4 log_2(n) L$],
    [$4R + 3L$],
    [$4R + 4L$],

    [ABA solution],
    [Unique #linebreak() timestamp],
    [No hazardous ABA problem],
    [Unique #linebreak() timestamp],

    [Safe memory #linebreak() reclamation],
    [No #linebreak() dynamic #linebreak() memory #linebreak() allocation],
    [No #linebreak() dynamic #linebreak() memory #linebreak() allocation],
    [No #linebreak() dynamic #linebreak() memory #linebreak() allocation],
  ),
) <summary-of-distributed-mpscs>


The rest of this chapter is organized as follows. @distributed-spsc describes a simple baseline distributed SPSC that is utilized as the underlying SPSC in our MPSC queues. @dLTQueue, @slotqueue and @dLTQueue-v2 introduces three wait-free MPSC queues: dLTQueue, Slotqueue and dLTQueueV2, respectively.

In these next few descriptions, we assume that each process in our program is assigned a unique number as an identifier, which is termed as its *rank*. The numbers are taken from the range of `[0, size - 1]`, with `size` being the number of processes in our program.

#include "spsc.typ"
#include "dltqueue.typ"
#include "slotqueue.typ"
#include "dltqueue-v2.typ"
