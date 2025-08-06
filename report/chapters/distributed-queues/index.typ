= Distributed MPSC queues <distributed-queues>

#import "@preview/lovelace:0.3.0": *
#import "@preview/lemmify:0.1.7": *
#let (
  definition,
  rules: definition-rules,
) = default-theorems("definition", lang: "en")
#let (
  theorem,
  lemma,
  corollary,
  proof,
  rules: theorem-rules,
) = default-theorems("theorem", lang: "en")

#show: theorem-rules
#show: definition-rules

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

The characteristics of these MPSC queue wrappers are summarized in @summary-of-distributed-mpscs. For benchmarking purposes, we use a baseline distributed SPSC introduced in @distributed-spsc in combination with the MPSC queue wrappers. The characteristics of the resulting MPSC queues are also shown in @summary-of-distributed-mpscs.//, which will be proven in @theoretical-aspects.

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

== A simple baseline distributed SPSC <distributed-spsc>

The two MPSC queue wrapper algorithms we propose in @dLTQueue and @slotqueue both utilize a baseline distributed SPSC data structure, which we will present in this section.

For implementation simplicity, we present a bounded SPSC, effectively make our proposed algorithms support only a bounded number of elements. However, one can trivially substitute another distributed unbounded SPSC to make our proposed algorithms support an unbounded number of elements, as long as this SPSC supports the same interface as ours.

The SPSC queue uses a circular array `Data` with a fixed `Capacity`. It maintains two indices: `First` marks the oldest item not yet removed, and `Last` marks the next available slot for insertion. Both indices use modulo arithmetic (`First % Capacity` and `Last % Capacity`) to wrap around the array.

For performance optimization, each process maintains local cached copies of these indices in `First_buf` and `Last_buf`. All indices start at zero. The memory layout is distributed between processes: the dequeuer hosts the `First` and `Last` indices, while the enqueuer hosts the `Data` array itself.

Placement-wise, all queue data in this SPSC is hosted on the enqueuer while the control variables i.e. `First` and `Last`, are hosted on the dequeuer.

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Shared variables*
      + `Data`: `gptr<data_t>`
      + `First`: `gptr<uint64_t>`
      + `Last`: `gptr<uint64_t>`
  ]
  #colbreak()
  #pseudocode-list(line-numbering: none)[
    + *Enqueuer-local variables*
      + `First_buf`: `uint64_t`
      + `Last_buf`: `uint64_t`
      + `Capacity`: `uint64_t`
    + *Dequeuer-local variables*
      + `First_buf`: `uint64_t`
      + `Last_buf`: `uint64_t`
      + `Capacity`: `uint64_t`
  ]
]

The procedures of the enqueuer are given as follows.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    booktabs: true,
    numbered-title: [`bool spsc_enqueue(data_t v)`],
  )[
    + #line-label(<line-spsc-enqueue-new-last>) `new_last = Last_buf + 1`
    + #line-label(<line-spsc-enqueue-diff-cache-once>) *if* `(new_last - First_buf > Capacity)                                            `
      + #line-label(<line-spsc-enqueue-resync-first>) `read(First, &First_buf)`
      + #line-label(<line-spsc-enqueue-diff-cache-twice>) *if* `(new_last - First_buf > Capacity)`
        + #line-label(<line-spsc-enqueue-full>) *return* `false`
    + #line-label(<line-spsc-enqueue-write>) `write(Data + Last_buf % Capacity, &v)`
    + #line-label(<line-spsc-enqueue-increment-last>) `write(Last, &new_last)`
    + #line-label(<line-spsc-enqueue-update-cache>) `Last_buf = new_last`
    + #line-label(<line-spsc-enqueue-success>) *return* `true`
  ],
) <spsc-enqueue>

`spsc_enqueue` first computes the new `Last` value (@line-spsc-enqueue-new-last). If the queue is full as indicated by the difference the new `Last` value and `First_buf` (@line-spsc-enqueue-diff-cache-once), there can still be the possibility that some elements have been dequeued but `First_buf` has not been synced with `First` yet, therefore, we first refresh the value of `First_buf` by fetching from `First` (@line-spsc-enqueue-resync-first). If the queue is still full (@line-spsc-enqueue-diff-cache-twice), we signal failure (@line-spsc-enqueue-full). Otherwise, we proceed to write the enqueued value to the entry at `Last_buf % Capacity` (@line-spsc-enqueue-write), increment `Last` (@line-spsc-enqueue-increment-last), update the value of `Last_buf` (@line-spsc-enqueue-update-cache) and signal success (@line-spsc-enqueue-success).

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 9,
    booktabs: true,
    numbered-title: [`bool spsc_readFront`#sub(`e`)`(data_t* output)`],
  )[
    + #line-label(<line-spsc-e-readFront-diff-cache-once>) *if* `(First_buf >= Last_buf)                                           `
      + #line-label(<line-spsc-e-readFront-empty-once>) *return* `false`
    + #line-label(<line-spsc-e-readFront-resync-first>) `read(First, &First_buf)`
    + #line-label(<line-spsc-e-readFront-diff-cache-twice>) *if* `(First_buf >= Last_buf)                                           `
      + #line-label(<line-spsc-e-readFront-empty-twice>) *return* `false`
    + #line-label(<line-spsc-e-readFront-read>) `read(Data + First_buf % Capacity, output)`
    + #line-label(<line-spsc-e-readFront-success>) *return* `true`
  ],
) <spsc-enqueue-readFront>

`spsc_readFront`#sub(`e`) first checks if the SPSC is empty based on the difference between `First_buf` and `Last_buf` (@line-spsc-e-readFront-diff-cache-once). Note that if this check fails, we signal failure immediately (@line-spsc-e-readFront-empty-once) without refetching either `First` or `Last`. This suffices because `Last` cannot be out-of-sync with `Last_buf` as we are the enqueuer and `First` can only increase since the last refresh of `First_buf`, therefore, if we refresh `First` and `Last`, the condition on @line-spsc-e-readFront-diff-cache-once would return `false` anyways. If the SPSC is not empty, we refresh `First` and re-perform the empty check (@line-spsc-e-readFront-diff-cache-twice - @line-spsc-e-readFront-empty-twice). If the SPSC is again not empty, we read the queue entry at `First_buf % Capacity` into `output` (@line-spsc-e-readFront-read) and signal success (@line-spsc-e-readFront-success).

The procedures of the dequeuer are given as follows.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 16,
    booktabs: true,
    numbered-title: [`bool spsc_dequeue(data_t* output)`],
  )[
    + #line-label(<line-spsc-dequeue-new-first>) `new_first = First_buf + 1`
    + #line-label(<line-spsc-dequeue-empty-once>) *if* `(new_first > Last_buf)                                            `
      + #line-label(<line-spsc-dequeue-resync-last>) `read(Last, &Last_buf)`
      + #line-label(<line-spsc-dequeue-empty-twice>) *if* `(new_first > Last_buf)`
        + #line-label(<line-spsc-dequeue-empty>) *return* `false`
    + #line-label(<line-spsc-dequeue-read>) `read(Data + First_buf % Capacity, output)`
    + #line-label(<line-spsc-dequeue-swing-first>) `write(First, &new_first)`
    + #line-label(<line-spsc-dequeue-update-cache>) `First_buf = new_first`
    + #line-label(<line-spsc-dequeue-success>) *return* `true`

  ],
) <spsc-dequeue>

`spsc_dequeue` first computes the new `First` value (@line-spsc-dequeue-new-first). If the queue is empty as indicated by the difference the new `First` value and `Last_buf` (@line-spsc-dequeue-empty-once), there can still be the possibility that some elements have been enqueued but `Last_buf` has not been synced with `Last` yet, therefore, we first refresh the value of `Last_buf` by fetching from `Last` (@line-spsc-dequeue-resync-last). If the queue is still empty (@line-spsc-dequeue-empty-twice), we signal failure (@line-spsc-dequeue-empty). Otherwise, we proceed to read the top value at `First_buf % Capacity` (@line-spsc-dequeue-read) into `output`, increment `First` (@line-spsc-dequeue-swing-first) - effectively dequeue the element, update the value of `First_buf` (@line-spsc-dequeue-update-cache) and signal success (@line-spsc-dequeue-success).

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 25,
    booktabs: true,
    numbered-title: [`bool spsc_readFront`#sub(`d`)`(data_t* output)`],
  )[
    + #line-label(<line-spsc-d-readFront-diff-cache-once>) *if* `(First_buf >= Last_buf)                                               `
      + #line-label(<line-spsc-d-readFront-resync-last>) `read(Last, &Last_buf)`
      + #line-label(<line-spsc-d-readFront-diff-cache-twice>) *if* `(First_buf >= Last_buf)`
        + #line-label(<line-spsc-d-readFront-empty>) *return* `false`
    + #line-label(<line-spsc-d-readFront-read>) `read(Data + First_buf % Capacity, output)`
    + #line-label(<line-spsc-d-readFront-success>) *return* `true`
  ],
) <spsc-dequeue-readFront>

`spsc_readFront`#sub(`d`) first checks if the SPSC is empty based on the difference between `First_buf` and `Last_buf` (@line-spsc-d-readFront-diff-cache-once). If this check fails, we refresh `Last_buf` (@line-spsc-d-readFront-resync-last) and recheck (@line-spsc-d-readFront-diff-cache-twice). If the recheck fails, signal failure (@line-spsc-d-readFront-empty). If the SPSC is not empty, we read the queue entry at `First_buf % Capacity` into `output` (@line-spsc-d-readFront-read) and signal success (@line-spsc-d-readFront-success).

== dLTQueue - Straightforward LTQueue adapted for distributed environment <dLTQueue>

This algorithm presents our most straightforward effort to port LTQueue @ltqueue to distributed context. The main challenge is that LTQueue uses LL/SC as the universal atomic instruction and also an ABA solution, but LL/SC is not available in distributed programming environments. We have to replace any usage of LL/SC in the original LTQueue algorithm. We use compare-and-swap and the well-known monotonic timestamp scheme to guard against ABA problem.

=== Overview

The structure of our dLTQueue is shown as in @modified-ltqueue-tree.

We differentiate between 2 types of nodes: _enqueuer nodes_ (represented as the rectangular boxes at the bottom of @modified-ltqueue-tree) and normal _tree nodes_ (represented as the circular boxes in @modified-ltqueue-tree).

Each enqueuer node corresponds to an enqueuer. Each time the local SPSC is enqueued with a value, the enqueuer timestamps the value using a distributed counter shared by all enqueuers. An enqueuer node stores the SPSC local to the corresponding enqueuer and a `min_timestamp` value which is the minimum timestamp inside the local SPSC.

Each tree node stores the rank of an enqueuer process. This rank corresponds to the enqueuer node with the minimum timestamp among the node's children's ranks. The tree node that is attached to an enqueuer node is called a _leaf node_, otherwise, it is called an _internal node_.

Note that if a local SPSC is empty, the `min_timestamp` variable of the corresponding enqueuer node is set to `MAX_TIMESTAMP` and the corresponding leaf node's rank is set to `DUMMY_RANK`.

#place(
  center + top,
  float: true,
  scope: "parent",
  [#figure(
      image("/static/images/modified-ltqueue.png"),
      caption: [dLTQueue's structure.],
    ) <modified-ltqueue-tree>
  ],
)

Placement-wise:
- The enqueuer nodes are hosted at the corresponding enqueuer.
- All the tree nodes are hosted at the dequeuer.
- The distributed counter, which the enqueuers use to timestamp their enqueued value, is hosted at the dequeuer.

=== Data structure

Below is the types utilized in dLTQueue.

#pseudocode-list(line-numbering: none)[
  + *Types*
    + `data_t` = The type of the data to be stored.
    + `spsc_t` = The type of the SPSC, this is assumed to be the distributed SPSC in @distributed-spsc.
    + `rank_t` = The type of the rank of an enqueuer process tagged with a unique timestamp (version) to avoid ABA problem.
      + *struct*
        + `value`: `uint32_t`
        + `version`: `uint32_t`
      + *end*
    + `timestamp_t` = The type of the timestamp tagged with a unique timestamp (version) to avoid ABA problem.
      + *struct*
        + `value`: `uint32_t`
        + `version`: `uint32_t`
      + *end*
    + `node_t` = The type of a tree node.
      + *struct*
        + `rank`: `rank_t`
      + *end*
]

The shared variables in our LTQueue version are as follows.

Note that we have described a very specific and simple way to organize the tree nodes in dLTQueue in a min-heap-like array structure hosted on the sole dequeuer. We will resume our description of the related tree-structure procedures `parent()` (@ltqueue-parent), `children()` (@ltqueue-children), `leafNodeIndex()` (@ltqueue-leaf-node-index) with this representation in mind. However, our algorithm does not strictly require this representation and can be substituted with other more-optimized representations & distributed placements, as long as the similar tree-structure procedures are supported.

#pseudocode-list(line-numbering: none)[
  + *Shared variables*
    + `Counter`: `gptr<uint64_t>`
      + A distributed counter shared by the enqueuers. Hosted at the dequeuer.
    + `Tree_size`: `uint64_t`
      + A read-only variable storing the number of tree nodes present in the dLTQueue.
    + `Nodes`: `gptr<node_t>`
      + An array with `Tree_size` entries storing all the tree nodes present in the dLTQueue shared by all processes.
      + Hosted at the dequeuer.
      + This array is organized in a similar manner as a min-heap: At index `0` is the root node. For every index $i gt 0$, $floor((i - 1) / 2)$ is the index of the parent of node $i$. For every index $i gt 0$, $2i + 1$ and $2i + 2$ are the indices of the children of node $i$.
    + `Dequeuer_rank`: `uint32_t`
      + The rank of the dequeuer process. This is read-only.
    + `Timestamps`: A read-only *array* `[0..size - 1]` of `gptr<timestamp_t>`, with `size` being the number of processes.
      + The entry at index $i$ corresponds to the `Min_timestamp` distributed variable at the process with a rank of $i$.
]

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Enqueuer-local variables*
      + `Process_count`: `uint64_t`
        + The number of processes.
      + `Self_rank`: `uint32_t`
        + The rank of the current enqueuer process.
      + `Min_timestamp`: `gptr<timestamp_t>`
      + `Spsc`: `spsc_t`
        + This SPSC is synchronized with the dequeuer.
  ]

  #colbreak()

  #pseudocode-list(line-numbering: none)[
    + *Dequeuer-local variables*
      + `Process_count`: `uint64_t`
        + The number of processes.
      + `Spscs`: An *array* of `spsc_t` with `Process_count` entries.
        + The entry at index $i$ corresponds to the `Spsc` at the process with a rank of $i$.
  ]
]

Initially, the enqueuers and the dequeuer are initialized as follows:

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Enqueuer initialization*
      + Initialize `Process_count`, `Self_rank` and `Dequeuer_rank`.
      + Initialize `Spsc` to the initial state.
      + Initialize `Min_timestamp` to `timestamp_t {MAX_TIMESTAMP, 0}`.
  ]

  #colbreak()

  #pseudocode-list(line-numbering: none)[
    + *Dequeuer initialization*
      + Initialize `Process_count`, `Self_rank` and `Dequeuer_rank`.
      + Initialize `Counter` to `0`.
      + Initialize `Tree_size` to `Process_count * 2`.
      + Initialize `Nodes` to an array with `Tree_size` entries. Each entry is initialized to `node_t {DUMMY_RANK}`.
      + Initialize `Spscs`, synchronizing each entry with the corresponding enqueuer.
      + Initialize `Timestamps`, synchronizing each entry with the corresponding enqueuer.
  ]
]

=== Algorithm

We first present the tree-structure utility procedures that are shared by both the enqueuer and the dequeuer:

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i,
    booktabs: true,
    numbered-title: [`uint32_t parent(uint32_t index)`],
  )[
    + #line-label(<line-ltqueue-parent>) *return* `(index - 1) / 2                                                   `
  ],
) <ltqueue-parent>

`parent` returns the index of the parent tree node given the node with index `index`. These indices are based on the shared `Nodes` array. Based on how we organize the `Nodes` array, the index of the parent tree node of `index` is `(index - 1) / 2`.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 1,
    booktabs: true,
    numbered-title: [`vector<uint32_t> children(uint32_t index)`],
  )[
    + `left_child = index * 2 + 1                                                  `
    + `right_child = left_child + 1`
    + `res = vector<uint32_t>()`
    + *if* `(left_child >= Tree_size)`
      + *return* `res`
    + `res.push(left_child)`
    + *if* `(right_child >= Tree_size)`
      + *return* `res`
    + `res.push(right_child)`
    + *return* `res`
  ],
) <ltqueue-children>

Similarly, `children` returns all indices of the child tree nodes given the node with index `index`. These indices are based on the shared `Nodes` array. Based on how we organize the `Nodes` array, these indices can be either `index * 2 + 1` or `index * 2 + 2`.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 11,
    booktabs: true,
    numbered-title: [`uint32_t leafNodeIndex(uint32_t enqueuer_rank)`],
  )[
    + *return* `Tree_size + enqueuer_rank                                          `
  ],
) <ltqueue-leaf-node-index>

`leafNodeIndex` returns the index of the leaf node that is logically attached to the enqueuer node with rank `enqueuer_rank` as in @modified-ltqueue-tree.

The followings are the enqueuer procedures.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 12,
    booktabs: true,
    numbered-title: [`bool enqueue(data_t value)`],
  )[
    + #line-label(<line-ltqueue-enqueue-obtain-timestamp>) `timestamp = faa(Counter, 1)                                            `
    + #line-label(<line-ltqueue-enqueue-insert>) *if* `(!spsc_enqueue(&Spsc, (value, timestamp)))`
      + #line-label(<line-ltqueue-enqueue-failure>) *return* `false`
    // + `front = (data_t {}, timestamp_t {})`
    // + `is_empty = !spsc_readFront(Spsc, &front)`
    // + *if* `(!is_empty && front.timestamp.value != timestamp)`
    //  + *return* `true`
    + #line-label(<line-ltqueue-enqueue-propagate>) `propagate`#sub(`e`)`()`
    + #line-label(<line-ltqueue-enqueue-success>) *return* `true`
  ],
) <ltqueue-enqueue>

To enqueue a value, `enqueue` first obtains a count by FAA-ing the distributed counter `Counter` (@line-ltqueue-enqueue-obtain-timestamp). Then, we enqueue the data tagged with the timestamp into the local SPSC (@line-ltqueue-enqueue-insert). Then, `enqueue` propagates the changes by invoking `propagate`#sub(`e`)`()` (@line-ltqueue-enqueue-propagate) and returns `true`.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 17,
    booktabs: true,
    numbered-title: [`void propagate`#sub(`e`)`()`],
  )[
    + #line-label(<line-ltqueue-e-propagate-refresh-ts-once>) *if* `(!refreshTimestamp`#sub(`e`)`())                                                `
      + #line-label(<line-ltqueue-e-propagate-refresh-ts-twice>) `refreshTimestamp`#sub(`e`)`()`
    + #line-label(<line-ltqueue-e-propagate-refresh-leaf-once>) *if* `(!refreshLeaf`#sub(`e`)`())`
      + #line-label(<line-ltqueue-e-propagate-refresh-leaf-twice>) `refreshLeaf`#sub(`e`)`()`
    + #line-label(<line-ltqueue-e-propagate-start-node>) `current_node_index = leafNodeIndex(Self_rank)`
    + #line-label(<line-ltqueue-e-propagate-start-repeat>) *repeat*
      + #line-label(<line-ltqueue-e-propagate-update-current-node>) `current_node_index = parent(current_node_index)`
      + #line-label(<line-ltqueue-e-propagate-refresh-current-node-once>) *if* `(!refresh`#sub(`e`)`(current_node_index))`
        + #line-label(<line-ltqueue-e-propagate-refresh-current-node-twice>) `refresh`#sub(`e`)`(current_node_index)`
    + #line-label(<line-ltqueue-e-propagate-end-repeat>) *until* `current_node_index == 0`
  ],
) <ltqueue-enqueue-propagate>

The `propagate`#sub(`e`) procedure is responsible for propagating SPSC updates up to the root node as a way to notify other processes of the newly enqueued item. It is split into 3 phases: Refreshing of `Min_timestamp` in the enqueuer node (@line-ltqueue-e-propagate-refresh-ts-once - @line-ltqueue-e-propagate-refresh-ts-twice), refreshing of the enqueuer's leaf node (@line-ltqueue-e-propagate-refresh-leaf-once - @line-ltqueue-e-propagate-refresh-leaf-twice), refreshing of internal nodes (@line-ltqueue-e-propagate-start-repeat - @line-ltqueue-e-propagate-end-repeat). On @line-ltqueue-e-propagate-refresh-leaf-once - @line-ltqueue-e-propagate-end-repeat, we refresh every tree node that lies between the enqueuer node and the root node.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 27,
    booktabs: true,
    numbered-title: [`bool refreshTimestamp`#sub(`e`)`()`],
  )[
    + #line-label(<line-ltqueue-e-refresh-timestamp-init-min-timestamp>) `min_timestamp = timestamp_t {}`
    + #line-label(<line-ltqueue-e-refresh-timestamp-read-min-timestamp>) `read(Min_timestamp, &min_timestamp)`
    + #line-label(<line-ltqueue-e-refresh-timestamp-extract-min-timestamp>) `{old_timestamp, old_version} = min_timestamp                                 `
    + #line-label(<line-ltqueue-e-refresh-timestamp-init-front>) `front = (data_t {}, timestamp_t {})`
    + #line-label(<line-ltqueue-e-refresh-timestamp-read-front>) `is_empty = !spsc_readFront(&Spsc, &front)`
    + #line-label(<line-ltqueue-e-refresh-timestamp-empty-check>) *if* `(is_empty)`
      + #line-label(<line-ltqueue-e-refresh-timestamp-CAS-empty>) *return* `cas(Min_timestamp,
timestamp_t {old_timestamp, old_version},
timestamp_t {MAX_TIMESTAMP, old_version + 1})`
    + #line-label(<line-ltqueue-e-refresh-timestamp-not-empty-check>) *else*
      + #line-label(<line-ltqueue-e-refresh-timestamp-CAS-not-empty>) *return* `cas(Min_timestamp,
timestamp_t {old_timestamp, old_version},
timestamp_t {front.timestamp, old_version + 1})`
  ],
) <ltqueue-enqueue-refresh-timestamp>

The `refreshTimestamp`#sub(`e`) procedure is responsible for updating the `Min_timestamp` of the enqueuer node. It simply looks at the front of the local SPSC (@line-ltqueue-e-refresh-timestamp-read-front) and CAS `Min_timestamp` accordingly (@line-ltqueue-e-refresh-timestamp-empty-check - @line-ltqueue-e-refresh-timestamp-CAS-not-empty).

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 36,
    booktabs: true,
    numbered-title: [`bool refreshNode`#sub(`e`)`(uint32_t current_node_index)`],
  )[
    + #line-label(<line-ltqueue-e-refresh-node-init-current>) `current_node = node_t {}                                                      `
    + #line-label(<line-ltqueue-e-refresh-node-read-current-node>) `read(Nodes, current_node_index, &current_node)`
    + #line-label(<line-ltqueue-e-refresh-node-extract-rank>) `{old_rank, old_version} = current_node.rank`
    + #line-label(<line-ltqueue-e-refresh-node-init-min-rank>) `min_rank = DUMMY_RANK`
    + #line-label(<line-ltqueue-e-refresh-node-init-min-timestamp>) `min_timestamp = MAX_TIMESTAMP`
    + #line-label(<line-ltqueue-e-refresh-node-for-loop>) *for* `child_node_index` in `children(current_node)`
      + #line-label(<line-ltqueue-e-refresh-node-init-child>) `child_node = node_t {}`
      + #line-label(<line-ltqueue-e-refresh-node-read-child>) `read(Nodes + child_node_index, &child_node)`
      + #line-label(<line-ltqueue-e-refresh-node-extract-child-rank>) `{child_rank, child_version} = child_node`
      + #line-label(<line-ltqueue-e-refresh-node-check-dummy>) *if* `(child_rank == DUMMY_RANK)` *continue*
      + #line-label(<line-ltqueue-e-refresh-node-init-child-timestamp>) `child_timestamp = timestamp_t {}`
      + #line-label(<line-ltqueue-e-refresh-node-read-timestamp>) `read(Timestamps + child_rank, &child_timestamp)`
      + #line-label(<line-ltqueue-e-refresh-node-check-timestamp>) *if* `(child_timestamp < min_timestamp)`
        + #line-label(<line-ltqueue-e-refresh-node-update-min-timestamp>) `min_timestamp = child_timestamp`
        + #line-label(<line-ltqueue-e-refresh-node-update-min-rank>) `min_rank = child_rank`
    + #line-label(<line-ltqueue-e-refresh-node-cas>) *return* `cas(Nodes + current_node_index,
node_t {rank_t {old_rank, old_version}},
node_t {rank_t {min_rank, old_version + 1}})`
  ],
) <ltqueue-enqueue-refresh-node>

The `refreshNode`#sub(`e`) procedure is responsible for updating the ranks of the internal nodes affected by the enqueue. It loops over the children of the current internal nodes (@line-ltqueue-e-refresh-node-for-loop). For each child node, we read the rank stored in it (@line-ltqueue-e-refresh-node-extract-child-rank), if the rank is not `DUMMY_RANK`, we proceed to read the value of `Min_timestamp` of the enqueuer node with the corresponding rank (@line-ltqueue-e-refresh-node-read-timestamp). At the end of the loop, we obtain the rank stored inside one of the child nodes that has the minimum timestamp stored in its enqueuer node (@line-ltqueue-e-refresh-node-update-min-timestamp - @line-ltqueue-e-refresh-node-update-min-rank). We then try to CAS the rank inside the current internal node to this rank (@line-ltqueue-e-refresh-node-cas).

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 52,
    booktabs: true,
    numbered-title: [`bool refreshLeaf`#sub(`e`)`()`],
  )[
    + #line-label(<line-ltqueue-e-refresh-leaf-index>) `leaf_node_index = leafNodeIndex(Self_rank)             `
    + #line-label(<line-ltqueue-e-refresh-leaf-init>) `leaf_node = node_t {}`
    + #line-label(<line-ltqueue-e-refresh-leaf-read>) `read(Nodes + leaf_node_index, &leaf_node)`
    + #line-label(<line-ltqueue-e-refresh-leaf-extract-rank>) `{old_rank, old_version} = leaf_node.rank`
    + #line-label(<line-ltqueue-e-refresh-leaf-init-timestamp>) `min_timestamp = timestamp_t {}`
    + #line-label(<line-ltqueue-e-refresh-leaf-read-timestamp>) `read(Min_timestamp, &min_timestamp)`
    + #line-label(<line-ltqueue-e-refresh-leaf-extract-timestamp>) `timestamp = min_timestamp.timestamp`
    + #line-label(<line-ltqueue-e-refresh-leaf-cas>) *return* `cas(Nodes + leaf_node_index,
node_t {rank_t {old_rank, old_version}},
node_t {timestamp == MAX ? DUMMY_RANK : Self_rank, old_version + 1})`
  ],
) <ltqueue-enqueue-refresh-leaf>

The `refreshLeaf`#sub(`e`) procedure is responsible for updating the rank of the leaf node affected by the enqueue. It simply reads the value of `Min_timestamp` of the enqueuer node it is logically attached to (@line-ltqueue-e-refresh-leaf-read-timestamp) and CAS the leaf node's rank accordingly (@line-ltqueue-e-refresh-leaf-cas).

The followings are the dequeuer procedures.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 60,
    booktabs: true,
    numbered-title: [`bool dequeue(data_t* output)`],
  )[
    + #line-label(<line-ltqueue-dequeue-init>) `root_node = node_t {}                                                     `
    + #line-label(<line-ltqueue-dequeue-read>) `read(Nodes, &root_node)`
    + #line-label(<line-ltqueue-dequeue-extract-rank>) `{rank, version} = root_node.rank`
    + #line-label(<line-ltqueue-dequeue-check-empty>) *if* `(rank == DUMMY_RANK)` *return* `false`
    + #line-label(<line-ltqueue-dequeue-init-output>) `output_with_timestamp = (data_t {}, timestamp_t {})`
    + #line-label(<line-ltqueue-dequeue-spsc>) *if* `(!spsc_dequeue(&Spscs[rank]),
    &output_with_timestamp))`
      + #line-label(<line-ltqueue-dequeue-fail>) *return* `false`
    + #line-label(<line-ltqueue-dequeue-extract-data>) `*output = output_with_timestamp.data`
    + #line-label(<line-ltqueue-dequeue-propagate>) `propagate`#sub(`d`)`(rank)`
    + #line-label(<line-ltqueue-dequeue-success>) *return* `true`
  ],
) <ltqueue-dequeue>

To dequeue a value, `dequeue` reads the rank stored inside the root node (@line-ltqueue-dequeue-extract-rank). If the rank is `DUMMY_RANK`, the MPSC queue is treated as empty and failure is signaled (@line-ltqueue-dequeue-check-empty). Otherwise, we invoke `spsc_dequeue` on the SPSC of the enqueuer with the obtained rank (@line-ltqueue-dequeue-spsc). We then extract out the real data and set it to `output` (@line-ltqueue-dequeue-extract-data). We finally propagate the dequeue from the enqueuer node that corresponds to the obtained rank (@line-ltqueue-dequeue-propagate) and signal success (@line-ltqueue-dequeue-success).

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 70,
    booktabs: true,
    numbered-title: [`void propagate`#sub(`d`)`(uint32_t enqueuer_rank)`],
  )[
    + #line-label(<line-ltqueue-d-propagate-refresh-timestamp>) *if* `(!refreshTimestamp`#sub(`d`)`(enqueuer_rank))                                              `
      + #line-label(<line-ltqueue-d-propagate-retry-timestamp>) `refreshTimestamp`#sub(`d`)`(enqueuer_rank)`
    + #line-label(<line-ltqueue-d-propagate-refresh-leaf>) *if* `(!refreshLeaf`#sub(`d`)`(enqueuer_rank))`
      + #line-label(<line-ltqueue-d-propagate-retry-leaf>) `refreshLeaf`#sub(`d`)`(enqueuer_rank)`
    + #line-label(<line-ltqueue-d-propagate-init-current>) `current_node_index = leafNodeIndex(enqueuer_rank)`
    + #line-label(<line-ltqueue-d-propagate-repeat>) *repeat*
      + #line-label(<line-ltqueue-d-propagate-get-parent>) `current_node_index = parent(current_node_index)`
      + #line-label(<line-ltqueue-d-propagate-refresh-node>) *if* `(!refresh`#sub(`d`)`(current_node_index))`
        + #line-label(<line-ltqueue-d-propagate-retry-node>) `refresh`#sub(`d`)`(current_node_index)`
    + #line-label(<line-ltqueue-d-propagate-until>) *until* `current_node_index == 0`
  ],
) <ltqueue-dequeue-propagate>

The `propagate`#sub(`d`) procedure is similar to `propagate`#sub(`e`), with appropriate changes to accommodate the dequeuer.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 80,
    booktabs: true,
    numbered-title: [`bool refreshTimestamp`#sub(`d`)`(uint32_t enqueuer_rank)`],
  )[
    + #line-label(<line-ltqueue-d-refresh-timestamp-init>) `min_timestamp = timestamp_t {}`
    + #line-label(<line-ltqueue-d-refresh-timestamp-read>) `read(Timestamps + enqueuer_rank, &min_timestamp)`
    + #line-label(<line-ltqueue-d-refresh-timestamp-extract>) `{old_timestamp, old_version} = min_timestamp                                 `
    + #line-label(<line-ltqueue-d-refresh-timestamp-init-front>) `front = (data_t {}, timestamp_t {})`
    + #line-label(<line-ltqueue-d-refresh-timestamp-read-front>) `is_empty = !spsc_readFront(&Spscs[enqueuer_rank], &front)`
    + #line-label(<line-ltqueue-d-refresh-timestamp-check-empty>) *if* `(is_empty)`
      + #line-label(<line-ltqueue-d-refresh-timestamp-cas-max>) *return* `cas(Timestamps + enqueuer_rank,
timestamp_t {old_timestamp, old_version},
timestamp_t {MAX_TIMESTAMP, old_version + 1})`
    + #line-label(<line-ltqueue-d-refresh-timestamp-else>) *else*
      + #line-label(<line-ltqueue-d-refresh-timestamp-cas-front>) *return* `cas(Timestamps + enqueuer_rank,
timestamp_t {old_timestamp, old_version},
timestamp_t {front.timestamp, old_version + 1})`
  ],
) <ltqueue-dequeue-refresh-timestamp>

The `refreshTimestamp`#sub(`d`) procedure is similar to `refreshTimestamp`#sub(`e`), with appropriate changes to accommodate the dequeuer.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 90,
    booktabs: true,
    numbered-title: [`bool refreshNode`#sub(`d`)`(uint32_t current_node_index)`],
  )[
    + #line-label(<line-ltqueue-d-refresh-node-init-current>) `current_node = node_t {}                                                      `
    + #line-label(<line-ltqueue-d-refresh-node-read-current-node>) `read(Nodes + current_node_index, &current_node)`
    + #line-label(<line-ltqueue-d-refresh-node-extract-rank>) `{old_rank, old_version} = current_node.rank`
    + #line-label(<line-ltqueue-d-refresh-node-init-min-rank>) `min_rank = DUMMY_RANK`
    + #line-label(<line-ltqueue-d-refresh-node-init-min-timestamp>) `min_timestamp = MAX_TIMESTAMP`
    + #line-label(<line-ltqueue-d-refresh-node-for-loop>) *for* `child_node_index` in `children(current_node)`
      + #line-label(<line-ltqueue-d-refresh-node-init-child>) `child_node = node_t {}`
      + #line-label(<line-ltqueue-d-refresh-node-read-child>) `read(Nodes + child_node_index, &child_node)`
      + #line-label(<line-ltqueue-d-refresh-node-extract-child-rank>) `{child_rank, child_version} = child_node`
      + #line-label(<line-ltqueue-d-refresh-node-check-dummy>) *if* `(child_rank == DUMMY_RANK)` *continue*
      + #line-label(<line-ltqueue-d-refresh-node-init-child-timestamp>) `child_timestamp = timestamp_t {}`
      + #line-label(<line-ltqueue-d-refresh-node-read-timestamp>) `read(Timestamps + child_rank, &child_timestamp)`
      + #line-label(<line-ltqueue-d-refresh-node-check-timestamp>) *if* `(child_timestamp < min_timestamp)`
        + #line-label(<line-ltqueue-d-refresh-node-update-min-timestamp>) `min_timestamp = child_timestamp`
        + #line-label(<line-ltqueue-d-refresh-node-update-min-rank>) `min_rank = child_rank`
    + #line-label(<line-ltqueue-d-refresh-node-cas>) *return* `cas(Nodes + current_node_index,
node_t {rank_t {old_rank, old_version}},
node_t {rank_t {min_rank, old_version + 1}})`
  ],
) <ltqueue-dequeue-refresh-node>

The `refreshNode`#sub(`d`) procedure is similar to `refreshNode`#sub(`e`), with appropriate changes to accommodate the dequeuer.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 106,
    booktabs: true,
    numbered-title: [`bool refreshLeaf`#sub(`d`)`(uint32_t enqueuer_rank)`],
  )[
    + #line-label(<line-ltqueue-d-refresh-leaf-index>) `leaf_node_index = leafNodeIndex(enqueuer_rank)             `
    + #line-label(<line-ltqueue-d-refresh-leaf-init>) `leaf_node = node_t {}`
    + #line-label(<line-ltqueue-d-refresh-leaf-read>) `read(Nodes + leaf_node_index, &leaf_node)`
    + #line-label(<line-ltqueue-d-refresh-leaf-extract-rank>) `{old_rank, old_version} = leaf_node.rank`
    + #line-label(<line-ltqueue-d-refresh-leaf-init-timestamp>) `min_timestamp = timestamp_t {}`
    + #line-label(<line-ltqueue-d-refresh-leaf-read-timestamp>) `read(Timestamps + enqueuer_rank, &min_timestamp)`
    + #line-label(<line-ltqueue-d-refresh-leaf-extract-timestamp>) `timestamp = min_timestamp.timestamp`
    + #line-label(<line-ltqueue-d-refresh-leaf-cas>) *return* `cas(Nodes + leaf_node_index,
node_t {rank_t {old_rank, old_version}},
node_t {timestamp == MAX ? DUMMY_RANK : Self_rank, old_version + 1})`
  ],
) <ltqueue-dequeue-refresh-leaf>

The `refreshLeaf`#sub(`d`) procedure is similar to `refreshLeaf`#sub(`e`), with appropriate changes to accommodate the dequeuer.

== Slotqueue - dLTQueue-inspired distributed MPSC queue with all constant-time operations <slotqueue>

The straightforward dLTQueue algorithm we have ported in @dLTQueue pretty much preserves the original algorithm's characteristics, i.e. wait-freedom and time complexity of $Theta(log n)$ for `dequeue` and `enqueue` operations. We note that in shared-memory systems, this logarithmic growth is fine. However, in distributed systems, this increase in remote operations would present a bottleneck in enqueue and dequeue latency. Upon closer inspection, this logarithmic growth is due to the propagation process because it has to traverse every level in the tree. Intuitively, this is the problem of we trying to maintain the tree structure. Therefore, to be more suitable for distributed context, we propose a new algorithm Slotqueue inspired by LTQueue, which uses a slightly different structure. The key point is that both `enqueue` and `dequeue` only perform a constant number of remote operations, at the cost of `dequeue` having to perform $Theta(n)$ local operations, where $n$ is the number of enqueuers. Because remote operations are much more expensive, this might be a worthy tradeoff.

=== Overview

The structure of Slotqueue is shown as in @slotqueue-structure.

Each enqueuer hosts a distributed SPSC as in dLTQueue (@dLTQueue). The enqueuer when enqueues a value to its local SPSC will timestamp the value using a distributed counter hosted at the dequeuer.

Additionally, the dequeuer hosts an array whose entries each corresponds with an enqueuer. Each entry stores the minimum timestamp of the local SPSC of the corresponding enqueuer.

#figure(
  image("/static/images/slotqueue.png"),
  caption: [Basic structure of Slotqueue.],
) <slotqueue-structure>


=== Data structure

We first introduce the types and shared variables utilized in Slotqueue.

#pseudocode-list(line-numbering: none)[
  + *Types*
    + `data_t` = The type of data stored.
    + `timestamp_t` = `uint64_t`
    + `spsc_t` = The type of the SPSC each enqueuer uses, this is assumed to be the distributed SPSC in @distributed-spsc.
]

#pseudocode-list(line-numbering: none)[
  + *Shared variables*
    + `Slots`: `gptr<timestamp_t*>`
      + An array of `timestamp_t` with the number of entries equal to the number of enqueuers.
      + Hosted at the dequeuer.
    + `Counter`: `gptr<uint64_t>`
      + A distributed counter.
      + Hosted at the dequeuer.
]

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Enqueuer-local variables*
      + `Dequeuer_rank`: `uint64_t`
        + The rank of the dequeuer.
      + `Process_count`: `uint64_t`
        + The number of enqueuers.
      + `Self_rank`: `uint32_t`
        + The rank of the current enqueuer process.
      + `Spsc`: `spsc_t`
        + This SPSC is synchronized with the dequeuer.
  ]

  #colbreak()

  #pseudocode-list(line-numbering: none)[
    + *Dequeuer-local variables*
      + `Dequeuer_rank`: `uint64_t`
        + The rank of the dequeuer.
      + `Process_count`: `uint64_t`
        + The number of enqueuers.
      + `Spscs`: An *array* of `spsc_t` with `Process_count` entries.
        + The entry at index $i$ corresponds to the `Spsc` at the process with a rank of $i$.
  ]
]

Initially, the enqueuer and the dequeuer are initialized as follows.

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Enqueuer initialization*
      + Initialize `Dequeuer_rank`.
      + Initialize `Process_count`.
      + Initialize `Self_rank`.
      + Initialize the local `Spsc` to its initial state.
  ]
  #colbreak()
  #pseudocode-list(line-numbering: none)[
    + *Dequeuer initialization*
      + Initialize `Dequeuer_rank`.
      + Initialize `Process_count`.
      + Initialize `Counter` to 0.
      + Initialize the `Slots` array with size equal to the number of enqueuers and every entry is initialized to `MAX_TIMESTAMP`.
      + Initialize the `Spscs` array, the `i`-th entry corresponds to the `Spsc` variable of the process of rank `i`.
  ]
]

=== Algorithm

The enqueuer operations are given as follows.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i,
    booktabs: true,
    numbered-title: [`bool enqueue(data_t v)`],
  )[
    + #line-label(<line-slotqueue-enqueue-obtain-timestamp>) `timestamp = faa(Counter, 1)                                           `
    + #line-label(<line-slotqueue-enqueue-spsc>) *if* `(!spsc_enqueue(&Spsc, (v, timestamp)))` *return* `false`
    + #line-label(<line-slotqueue-enqueue-refresh>) *if* `(!refreshEnqueue(timestamp))`
      + #line-label(<line-slotqueue-enqueue-retry>) `refreshEnqueue(timestamp)`
    + #line-label(<line-slotqueue-enqueue-success>) *return* `true`
  ],
) <slotqueue-enqueue>

To enqueue a value, `enqueue` first obtains a timestamp by FAA-ing the distributed counter (@line-slotqueue-enqueue-obtain-timestamp). It then tries to enqueue the value tagged with the timestamp (@line-slotqueue-enqueue-spsc). At @line-slotqueue-enqueue-refresh - @line-slotqueue-enqueue-retry, the enqueuer tries to refresh its slot's timestamp.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 5,
    booktabs: true,
    numbered-title: [`bool refreshEnqueue(timestamp_t ts)`],
  )[
    + #line-label(<line-slotqueue-refresh-enqueue-init-front>) `front = (data_t {}, timestamp_t {})                                       `
    + #line-label(<line-slotqueue-refresh-enqueue-read-front>) `success = spsc_readFront(&Spsc, &front)`
    + #line-label(<line-slotqueue-refresh-enqueue-calc-timestamp>) `new_timestamp = success ? front.timestamp : MAX_TIMESTAMP`
    + #line-label(<line-slotqueue-refresh-enqueue-check-1>) *if* `(new_timestamp != ts)`
      + #line-label(<line-slotqueue-refresh-enqueue-early-success>) *return* `true`
    + #line-label(<line-slotqueue-refresh-enqueue-init-old_timestamp>) `old_timestamp = timestamp_t {}`
    + #line-label(<line-slotqueue-refresh-enqueue-read-slot>) `read(Slots + Self_rank, &old_timestamp)`
    + #line-label(<line-slotqueue-refresh-enqueue-read-front-2>) `success = spsc_readFront(&Spsc, &front)`
    + #line-label(<line-slotqueue-refresh-enqueue-calc-timestamp-2>) `new_timestamp = success ? front.timestamp : MAX_TIMESTAMP`
    + #line-label(<line-slotqueue-refresh-enqueue-check-2>) *if* `(new_timestamp != ts)`
      + #line-label(<line-slotqueue-refresh-enqueue-mid-success>) *return* `true`
    + #line-label(<line-slotqueue-refresh-enqueue-cas>) *return* `cas(Slots + Self_rank,
    old_timestamp,
    new_timestamp)`
  ],
) <slotqueue-refresh-enqueue>

`refreshEnqueue`'s responsibility is to refresh the timestamp stores in the enqueuer's slot to potentially notify the dequeuer of its newly-enqueued element. It first reads the current front element (@line-slotqueue-refresh-enqueue-read-front). If the SPSC is empty, the new timestamp is set to `MAX_TIMESTAMP`, otherwise, the front element's timestamp (@line-slotqueue-refresh-enqueue-calc-timestamp). If it finds that the front element's timestamp is different from the timestamp `ts` it returns `true` immediately (@line-slotqueue-refresh-enqueue-check-1 - @line-slotqueue-refresh-enqueue-early-success). Otherwise, it reads its slot's old timestamp (@line-slotqueue-refresh-enqueue-read-slot) and re-reads the current front element in the SPSC (@line-slotqueue-refresh-enqueue-read-front-2) to update the new timestamp. Note that similar to @line-slotqueue-refresh-enqueue-early-success, `refreshEnqueue` immediately succeeds if the new timestamp is different from the timestamp `ts` of the element it enqueues (@line-slotqueue-refresh-enqueue-mid-success). Otherwise, it tries to CAS its slot's timestamp with the new timestamp (@line-slotqueue-refresh-enqueue-cas).

The dequeuer operations are given as follows.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 18,
    booktabs: true,
    numbered-title: [`bool dequeue(data_t* output)`],
  )[
    + #line-label(<line-slotqueue-dequeue-read-rank>) `rank = readMinimumRank()                                                    `
    + #line-label(<line-slotqueue-dequeue-check-empty>) *if* `(rank == DUMMY_RANK)`
      + #line-label(<line-slotqueue-dequeue-fail>) *return* `false`
    + #line-label(<line-slotqueue-dequeue-init-output>) `output_with_timestamp = (data_t {}, timestamp_t {})`
    + #line-label(<line-slotqueue-dequeue-spsc>) *if* `(!spsc_dequeue(&Spscs[rank], &output_with_timestamp))`
      + #line-label(<line-slotqueue-dequeue-spsc-fail>) *return* `false`
    + #line-label(<line-slotqueue-dequeue-extract-data>) `*output = output_with_timestamp.data`
    + #line-label(<line-slotqueue-dequeue-refresh>) *if* `(!refreshDequeue(rank))`
      + #line-label(<line-slotqueue-dequeue-retry>) `refreshDequeue(rank)`
    + #line-label(<line-slotqueue-dequeue-success>) *return* `true`
  ],
) <slotqueue-dequeue>

To dequeue a value, `dequeue` first reads the rank of the enqueuer whose slot currently stores the minimum timestamp (@line-slotqueue-dequeue-read-rank). If the obtained rank is `DUMMY_RANK`, failure is signaled (@line-slotqueue-dequeue-check-empty - @line-slotqueue-dequeue-fail). Otherwise, it tries to dequeue the SPSC of the corresponding enqueuer (@line-slotqueue-dequeue-spsc). It then tries to refresh the enqueuer's slot's timestamp to potentially notify the enqueuer of the dequeue (@line-slotqueue-dequeue-refresh - @line-slotqueue-dequeue-retry). It then signals success (@line-slotqueue-dequeue-success).

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 28,
    booktabs: true,
    numbered-title: [`uint64_t readMinimumRank()`],
  )[
    + #line-label(<line-slotqueue-read-min-rank-init-buffer>) `buffered_slots = timestamp_t[Process_count] {}                       `
    + #line-label(<line-slotqueue-read-min-rank-scan1-loop>) *for* `index` *in* `0..Process_count`
      + #line-label(<line-slotqueue-read-min-rank-scan1-read>) `read(Slots + index, &bufferred_slots[index])`
    + #line-label(<line-slotqueue-read-min-rank-check-empty>) *if* every entry in `bufferred_slots` is `MAX_TIMESTAMP`
      + #line-label(<line-slotqueue-read-min-rank-return-empty>) *return* `DUMMY_RANK`
    + #line-label(<line-slotqueue-read-min-rank-find-min>) *let* `rank` be the index of the first slot that contains the minimum timestamp among `bufferred_slots`
    + #line-label(<line-slotqueue-read-min-rank-scan2-loop>) *for* `index` *in* `0..rank`
      + #line-label(<line-slotqueue-read-min-rank-scan2-read>) `read(Slots + index, &bufferred_slots[index])`
    + #line-label(<line-slotqueue-read-min-rank-init-min>) `min_timestamp = MAX_TIMESTAMP`
    + #line-label(<line-slotqueue-read-min-rank-check-loop>) *for* `index` *in* `0..rank`
      + #line-label(<line-slotqueue-read-min-rank-get-timestamp>) `timestamp = buffered_slots[index]`
      + #line-label(<line-slotqueue-read-min-rank-compare>) *if* `(min_timestamp < timestamp)`
        + #line-label(<line-slotqueue-read-min-rank-update-rank>) `min_rank = index`
        + #line-label(<line-slotqueue-read-min-rank-update-timestamp>) `min_timestamp = timestamp`
    + #line-label(<line-slotqueue-read-min-rank-return>) *return* `min_rank`
  ],
) <slotqueue-read-minimum-rank>

`readMinimumRank`'s main responsibility is to return the rank of the enqueuer from which we can safely dequeue next. It first creates a local buffer to store the value read from `Slots` (@line-slotqueue-read-min-rank-init-buffer). It then performs 2 scans of `Slots` and read every entry into `buffered_slots` (@line-slotqueue-read-min-rank-scan1-loop - @line-slotqueue-read-min-rank-scan2-read). If the first scan finds only `MAX_TIMESTAMP`s, `DUMMY_RANK` is returned (@line-slotqueue-read-min-rank-return-empty). From there, based on `bufferred_slots`, it returns the rank of the enqueuer whose bufferred slot stores the minimum timestamp (@line-slotqueue-read-min-rank-check-loop - @line-slotqueue-read-min-rank-return).

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 45,
    booktabs: true,
    numbered-title: [`refreshDequeue(rank: int)` *returns* `bool`],
  )[
    + #line-label(<line-slotqueue-refresh-dequeue-init-timestamp>) `old_timestamp = timestamp_t {}                                       `
    + #line-label(<line-slotqueue-refresh-dequeue-read-slot>) `read(Slots + rank, &old_timestamp)`
    + #line-label(<line-slotqueue-refresh-dequeue-init-front>) `front = (data_t {}, timestamp_t {})`
    + #line-label(<line-slotqueue-refresh-dequeue-read-front>) `success = spsc_readFront(&Spscs[rank], &front)`
    + #line-label(<line-slotqueue-refresh-dequeue-calc-timestamp>) `new_timestamp = success ? front.timestamp : MAX_TIMESTAMP`
    + #line-label(<line-slotqueue-refresh-dequeue-cas>) *return* `cas(Slots + rank,
    old_timestamp,
    new_timestamp)`
  ],
) <slotqueue-refresh-dequeue>

`refreshDequeue`'s responsibility is to refresh the timestamp of the just-dequeued enqueuer to notify the enqueuer of the dequeue. It first reads the old timestamp of the slot (@line-slotqueue-refresh-dequeue-read-slot) and the front element (@line-slotqueue-refresh-dequeue-read-front). If the SPSC is empty, the new timestamp is set to `MAX_TIMESTAMP`, otherwise, it is the front element's timestamp (@line-slotqueue-refresh-dequeue-calc-timestamp). It finally tries to CAS the slot with the new timestamp (@line-slotqueue-refresh-dequeue-cas).
