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
