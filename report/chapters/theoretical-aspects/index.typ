= Theoretical aspects <theoretical-aspects>

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

This section discusses the correctness and progress guarantee properties of the distributed MPSC queue algorithms introduced in @distributed-queues[]. We also provide a theoretical performance model of these algorithms to predict how well they scale to multiple nodes.

== Preliminaries

In this section, we formalize the notion of harmless ABA problem (@ABA-safety) and correct concurrent algorithms (@linearizability). Verifying the correctness of concurrent queues involves us giving a sequential queue specification based on the Larch interface specification @guttag1985family (@larch), the Owicki-Gries formal method for reasoning about concurrent algorithms @owicki (@owicki-gries), Herlihy and Wing's method for verifying linearizability @herlihy-axioms (@linearizability-verification).

We will base our proofs on these formalisms to prove the algorithms' correctness.

=== ABA-safety <ABA-safety>

=== Linearizability <linearizability>

=== Larch interface specification of queues <larch>

=== The Owicki-Gries method <owicki-gries>

=== Verifying linearizability <linearizability-verification>

== Theoretical proofs of the distributed SPSC

This section establishes the correctness and fault-tolerance of our simple distributed SPSC introduced in @distributed-spsc. Specifically, @spsc-correctness proves there's no ABA problem and unsafe memory reclamation in our SPSC queue and it is linearizable; @spsc-progress-guarantee proves that our SPSC queue is wait-free; @spsc-performance discusses the overhead involved in each SPSC operation.

=== Correctness <spsc-correctness>

First, we prove that there's no ABA problem in our SPSC queue in @spsc-aba-problem. Second, we prove that there's no potential memory errors when executing our SPSC queue in @spsc-safe-memory. Finally and most importantly, we prove that our SPSC queue is linearizable in @spsc-linearizable.

==== ABA problem <spsc-aba-problem>

There's no CAS instruction in our simple distributed SPSC, so there's no potential for ABA problem.

==== Memory reclamation <spsc-safe-memory>

There's no dynamic memory allocation and deallocation in our simple distributed SPSC, so it is memory-safe.

==== Linearizability <spsc-linearizable>

=== Progress guarantee <spsc-progress-guarantee>

Our simple distributed SPSC is wait-free:
- `spsc_dequeue` (@spsc-dequeue) does not execute any loops or wait for any other method calls.
- `spsc_enqueue` (@spsc-enqueue) does not execute any loops or wait for any other method calls.
- `spsc_readFront`#sub(`e`) (@spsc-enqueue-readFront) does not execute any loops or wait for any other method calls.
- `spsc_readFront`#sub(`d`) (@spsc-dequeue-readFront) does not execute any loops or wait for any other method calls.

=== Theoretical performance <spsc-performance>

A summary of the theoretical performance of our simple SPSC is provided in @theo-perf-spsc. In the following discussion, $R$ means remote operations and $L$ means local operations.

#figure(
  kind: "table",
  supplement: "Table",
  caption: [Theoretical performance summary of our simple distributed SPSC. $R$ means remote operations and $L$ means local operations.],
  table(
    columns: (1fr, 1.5fr),
    table.header(
      [*Operations*],
      [*Time-complexity*],
    ),

    [`spsc_enqueue`], [$R+L$],
    [`spsc_dequeue`], [$R+L$],
    [`spsc_readFront`#sub(`e`)], [$R+L$],
    [`spsc_readFront`#sub(`d`)], [$R$],
  ),
) <theo-perf-spsc>

For `spsc_enqueue`, we consider the procedure @spsc-enqueue. In the usual case, the remote operation on @line-spsc-enqueue-resync-first is skipped and so only 2 remote puts are performed on @line-spsc-enqueue-write and @line-spsc-enqueue-increment-last. The Data array on @line-spsc-enqueue-write is hosted on the enqueuer, so this is actually a local operation, while the control variable is hosted on the dequeuer, so @line-spsc-enqueue-increment-last is truly a remote operation. Therefore, theoretically, it's one remote operation plus a local one.

For `spsc_dequeue`, we consider the procedure @spsc-dequeue. Similarly, in the usual case, the remote operation on @line-spsc-dequeue-resync-last is skipped and only the 2 lines @line-spsc-dequeue-read and @line-spsc-dequeue-swing-first are executed always. Here, it's the other way around, the access to the `Data` array on @line-spsc-dequeue-read is a truly remote operation while the access to the First control variable is a local one. Therefore, theoretically, it's one remote operation plus a local one.

For `spsc_readFront`#sub(`e`), we consider the procedure @spsc-enqueue-readFront. The operation on @line-spsc-e-readFront-resync-first is a truly remote operation, as the `First` control variable is hosted on the dequeuer. The operation on @line-spsc-e-readFront-read is a remote operation, as the `Data` array is hosted on the enqueuer. This means, theoretically, it also takes one remote operation plus a local one.

For `spsc_readFront`#sub(`d`), we consider the procedure @spsc-dequeue-readFront. Only the operation on @line-spsc-d-readFront-read is executed always, which results in a truly remote operation as the Data array is hosted on the enqueuer. Therefore, it only takes one remote operation.


== Theoretical proofs of dLTQueue

=== Proof-specific notations

The structure of dLTQueue is presented again in @remind-modified-ltqueue-tree.

As a reminder, the bottom rectangular nodes are called the *enqueuer nodes* and the circular node are called the *tree nodes*. Tree nodes that are attached to an enqueuer node are called *leaf nodes*, otherwise, they are called *internal nodes*. Each *enqueuer node* is hosted on the enqueuer that corresponds to it. The enqueuer nodes accomodate an instance of our distributed SPSC in @distributed-spsc and a `Min_timestamp` variable representing the minimum timestamp inside the SPSC. Each *tree node* stores a rank of a enqueuer that's attached to the subtree which roots at the *tree node*.

#place(
  center + top,
  float: true,
  scope: "parent",
  [#figure(
      image("/static/images/modified-ltqueue.png"),
      caption: [dLTQueue's structure.],
    ) <remind-modified-ltqueue-tree>
  ],
)

We will refer `propagate`#sub(`e`) and `propagate`#sub(`d`) as `propagate` if there's no need for discrimination. Similarly, we will sometimes refer to `refreshNode`#sub(`e`) and `refreshNode`#sub(`d`) as `refreshNode`, `refreshLeaf`#sub(`e`) and `refreshLeaf`#sub(`d`) as `refreshLeaf`, `refreshTimestamp`#sub(`e`) and `refreshTimestamp`#sub(`d`) as `refreshTimestamp`.

#definition[For a tree node $n$, the rank stored in $n$ at time $t$ is denoted as $r a n k(n, t)$.]

#definition[For an enqueue or a dequeue $op$, the rank of the enqueuer it affects is denoted as $r a n k(op)$.]

#definition[For an enqueuer whose rank is $r$, the `Min_timestamp` value stored in its enqueuer node at time $t$ is denoted as $m i n \- t s(r, t)$. If $r$ is `DUMMY_RANK`, $m i n \- t s(r, t)$ is `MAX_TIMESTAMP`.]

#definition[For an enqueuer with rank $r$, the minimum timestamp among the elements between `First` and `Last` in its SPSC at time $t$ is denoted as $m i n \- s p s c \- t s(r, t)$. If $r$ is dummy, $m i n \- s p s c \- t s(r, t)$ is `MAX`.]

#definition[For an enqueue or a dequeue $op$, the set of nodes that it calls `refreshNode` (@ltqueue-enqueue-refresh-node or @ltqueue-dequeue-refresh-node) or `refreshLeaf` (@ltqueue-enqueue-refresh-leaf or @ltqueue-dequeue-refresh-leaf) on is denoted as $p a t h(op)$.]

#definition[For an enqueue or a dequeue, *timestamp-refresh phase* refer to its execution of @line-ltqueue-e-propagate-refresh-ts-once - @line-ltqueue-e-propagate-refresh-ts-twice in `propagate`#sub(`e`) (@ltqueue-enqueue-propagate) or @line-ltqueue-d-propagate-refresh-timestamp - @line-ltqueue-d-propagate-retry-timestamp in `propagate`#sub(`d`) (@ltqueue-dequeue-propagate).]

#definition[For an enqueue $op$, and a node $n in p a t h(op)$, *node-$n$-refresh phase* refer to its execution of:
  - @line-ltqueue-e-propagate-refresh-leaf-once - @line-ltqueue-e-propagate-refresh-leaf-twice of `propagate`#sub(`e`) (@ltqueue-enqueue-propagate) if $n$ is a leaf node.
  - @line-ltqueue-e-propagate-refresh-current-node-once - @line-ltqueue-e-propagate-refresh-current-node-twice of `propagate`#sub(`e`) (@ltqueue-enqueue-propagate) to refresh $n$'s rank if $n$ is a non-leaf node.
]

#definition[For a dequeue $op$, and a node $n in p a t h(op)$, *node-$n$-refresh phase* refer to its execution of:
  - @line-ltqueue-d-propagate-refresh-leaf - @line-ltqueue-d-propagate-retry-leaf of `propagate`#sub(`d`) (@ltqueue-dequeue-propagate) if $n$ is a leaf node.
  - @line-ltqueue-d-propagate-refresh-node - @line-ltqueue-d-propagate-retry-node of `propagate`#sub(`d`) (@ltqueue-dequeue-propagate) to refresh $n$'s rank if $n$ is a non-leaf node.
]

#definition[`refreshTimestamp`#sub(`e`) (@ltqueue-enqueue-refresh-timestamp) is said to start its *CAS-sequence* if it finishes @line-ltqueue-e-refresh-timestamp-read-min-timestamp. `refreshTimestamp`#sub(`e`) is said to end its *CAS-sequence* if it finishes @line-ltqueue-e-refresh-timestamp-CAS-empty or @line-ltqueue-e-refresh-timestamp-CAS-not-empty.]

#definition[`refreshTimestamp`#sub(`d`) (@ltqueue-dequeue-refresh-timestamp) is said to start its *CAS-sequence* if it finishes @line-ltqueue-d-refresh-timestamp-read. `refreshTimestamp`#sub(`d`) is said to end its *CAS-sequence* if it finishes @line-ltqueue-d-refresh-timestamp-cas-max or @line-ltqueue-d-refresh-timestamp-cas-front.]

#definition[`refreshNode`#sub(`e`) (@ltqueue-enqueue-refresh-node) is said to start its *CAS-sequence* if it finishes @line-ltqueue-e-refresh-node-read-current-node. `refreshNode`#sub(`e`) is said to end its *CAS-sequence* if it finishes @line-ltqueue-e-refresh-node-cas.]

#definition[`refreshNode`#sub(`d`) (@ltqueue-dequeue-refresh-node) is said to start its *CAS-sequence* if it finishes @line-ltqueue-d-refresh-node-read-current-node. `refreshNode`#sub(`d`) is said to end its *CAS-sequence* if it finishes @line-ltqueue-d-refresh-node-cas.]

#definition[`refreshLeaf`#sub(`e`) (@ltqueue-enqueue-refresh-leaf) is said to start its *CAS-sequence* if it finishes @line-ltqueue-e-refresh-leaf-read. `refreshLeaf`#sub(`e`) is said to end its *CAS-sequence* if it finishes @line-ltqueue-e-refresh-leaf-cas.]

#definition[`refreshLeaf`#sub(`d`) (@ltqueue-dequeue-refresh-leaf) is said to start its *CAS-sequence* if it finishes @line-ltqueue-d-refresh-leaf-read. `refreshLeaf`#sub(`d`) is said to end its *CAS-sequence* if it finishes @line-ltqueue-d-refresh-leaf-cas.]

=== Correctness

==== ABA problem

We use CAS instructions on:
- @line-ltqueue-e-refresh-timestamp-CAS-empty and @line-ltqueue-e-refresh-timestamp-CAS-not-empty of `refreshTimestamp`#sub(`e`) (@ltqueue-enqueue-refresh-timestamp).
- @line-ltqueue-e-refresh-node-cas of `refreshNode`#sub(`e`) (@ltqueue-enqueue-refresh-node).
- @line-ltqueue-e-refresh-leaf-cas of `refreshLeaf`#sub(`e`) (@ltqueue-enqueue-refresh-leaf).
- @line-ltqueue-d-refresh-timestamp-cas-max and @line-ltqueue-d-refresh-timestamp-cas-front of `refreshTimestamp`#sub(`d`) (@ltqueue-dequeue-refresh-timestamp).
- @line-ltqueue-d-refresh-node-cas of `refreshNode`#sub(`d`) (@ltqueue-dequeue-refresh-node).
- @line-ltqueue-d-refresh-leaf-cas of `refreshLeaf`#sub(`d`) (@ltqueue-dequeue-refresh-leaf).

Notice that at these locations, we increase the associated version tags of the CAS-ed values. These version tags are 32-bit in size, therefore, practically, ABA problem can't virtually occur. It's safe to assume that there's no ABA problem in dLTQueue.

==== Memory reclamation

Notice that dLTQueue pushes the memory reclamation problem to the underlying SPSC. If the underlying SPSC is memory-safe, dLTQueue is also memory-safe.

==== Linearizability

=== Progress guarantee

Notice that every loop in dLTQueue is bounded, and no method have to wait for another. Therefore, dLTQueue is wait-free.

=== Theoretical performance

A summary of the theoretical performance of dLTQueue is provided in @theo-perf-dltqueue, which is already shown in @summary-of-distributed-mpscs. In the following discussion, $R$ means remote operations and $L$ means local operations.

#figure(
  kind: "table",
  supplement: "Table",
  caption: [Theoretical performance summary of dLTQueue. $R$ means remote operations and $L$ means local operations.],
  table(
    columns: (1fr, 1.5fr),
    table.header(
      [*Operations*],
      [*Time-complexity*],
    ),

    [`enqueue`], [$6log_2(n)R + 4log_2(n)L$],
    [`dequeue`], [$4log_2(n)R + 6log_2(n)L$],
  ),
) <theo-perf-dltqueue>

For `enqueue`, we consider the procedure @ltqueue-enqueue. We consider the propagation process, which causes most of the remote operations, while @line-ltqueue-enqueue-obtain-timestamp and @line-ltqueue-enqueue-insert are negligible. Notice that the number of node refreshes are proportional to the number of the level of the trees, which is $O(n)$ for $n$ being the number of processes. Each level of the tree in the worst case needs 2 retries, each retry would have to:
- Read the current node (which is a truly remote operation for `enqueue`).
- Read the two child nodes (which is 2 truly remote operations for `enqueue`).
- Read the two `min-timestamp` variables in the two child nodes (which is 2 truly local operations for `enqueue`).
- Compare-and-swap the current node (which is a truly remote opoeration for `enqueue`).
In total, each level requires 6 remote operations and 4 local operations. Therefore, `enqueue` requires about $6log_2(n)R + 4log_2(n)L$ operations.

For `dequeue`, it's similar to `enqueue` but the other way around, what makes for a remote operation in `enqueue` is a local operation in `dequeue` and otherwise. Therefore, `dequeue` requires about $4log_2(n)R + 6log_2(n)L$ operations.

== Theoretical proofs of Slotqueue

=== Proof-specific notations

As a refresher, @remind-slotqueue-structure shows the structure of Slotqueue.

#figure(
  image("/static/images/slotqueue.png"),
  caption: [Basic structure of Slotqueue.],
) <remind-slotqueue-structure>

Each enqueuer hosts an SPSC that can only accessed by itself and the dequeuer. The dequeuer hosts an array of slots, each slot corresponds to an enqueuer, containing its SPSC's minimum timestamp.

We apply some domain knowledge of Slotqueue algorithm to the definitions introduced in @ABA-safety.

#definition[A *CAS-sequence* on a slot `s` of an enqueue that affects `s` is the sequence of instructions from @line-slotqueue-refresh-enqueue-read-slot to @line-slotqueue-refresh-enqueue-cas of its `refreshEnqueue` (@slotqueue-refresh-enqueue).]

#definition[A *slot-modification instruction* on a slot `s` of an enqueue that affects `s` is @line-slotqueue-refresh-enqueue-cas of `refreshEnqueue` (@slotqueue-refresh-enqueue).]

#definition[A *CAS-sequence* on a slot `s` of a dequeue that affects `s` is the sequence of instructions from @line-slotqueue-refresh-dequeue-read-slot to @line-slotqueue-refresh-dequeue-cas of its `refreshDequeue` (@slotqueue-refresh-dequeue).]

#definition[A *slot-modification instruction* on a slot `s` of a dequeue that affects `s` is @line-slotqueue-refresh-dequeue-cas of `refreshDequeue` (@slotqueue-refresh-dequeue).]

#definition[A *CAS-sequence* of a dequeue/enqueue is said to *observe a slot value of $s_0$* if it loads $s_0$ at @line-slotqueue-refresh-enqueue-read-slot of `refreshEnqueue` or @line-slotqueue-refresh-dequeue-read-slot of `refreshDequeue`.]

The followings are some other definitions that will be used throughout our proof.

#definition[For an enqueue or dequeue $o p$, $r a n k(o p)$ is the rank of the enqueuer whose local SPSC is affected by $o p$.]

#definition[For an enqueuer whose rank is $r$, the value stored in its corresponding slot at time $t$ is denoted as $s l o t(r, t)$.]

#definition[For an enqueuer with rank $r$, the minimum timestamp among the elements between `First` and `Last` in its local SPSC at time $t$ is denoted as $m i n \- s p s c \- t s(r, t)$.]

#definition[For an enqueue, *slot-refresh phase* refer to its execution of @line-slotqueue-enqueue-refresh - @line-slotqueue-enqueue-retry of @slotqueue-enqueue.]

#definition[For a dequeue, *slot-refresh phase* refer to its execution of @line-slotqueue-dequeue-refresh - @line-slotqueue-dequeue-retry of @slotqueue-dequeue.]

#definition[For a dequeue, *slot-scan phase* refer to its execution of @line-slotqueue-read-min-rank-init-buffer - @line-slotqueue-read-min-rank-return of @slotqueue-read-minimum-rank.]

=== Correctness

==== ABA problem

==== Memory reclamation

Notice that Slotqueue pushes the memory reclamation problem to the underlying SPSC. If the underlying SPSC is memory-safe, Slotqueue is also memory-safe.

==== Linearizability

=== Progress guarantee

Notice that every loop in Slotqueue is bounded, and no method have to wait for another. Therefore, Slotqueue is wait-free.

=== Theoretical performance

A summary of the theoretical performance of Slotqueue is provided in @theo-perf-slotqueue, which is already shown in @summary-of-distributed-mpscs. By $R$, we mean remote operations and by $L$ we mean local operations.

#figure(
  kind: "table",
  supplement: "Table",
  caption: [Theoretical performance summary of Slotqueue. $R$ means remote operations and $L$ means local operations.],
  table(
    columns: (1fr, 1.5fr),
    table.header(
      [*Operations*],
      [*Time-complexity*],
    ),

    [`enqueue`], [$4R + 3L$],
    [`dequeue`], [$3R + 2n L$],
  ),
) <theo-perf-slotqueue>

For `enqueue`, we consider @slotqueue-enqueue. @line-slotqueue-enqueue-obtain-timestamp causes 1 truly remote operation, as the distributed counter is hosted on the dequeuer. @line-slotqueue-enqueue-spsc, as discussed in the theoretical performance of SPSC, causes $R + L$ operations. In the worst case, two `refreshEnqueue` calls are executed. We then consider each `refreshEnqueue` call. @line-slotqueue-refresh-enqueue-read-front causes $R + L$ operations. Most of the time, @line-slotqueue-refresh-enqueue-read-slot - @line-slotqueue-refresh-enqueue-cas are not executed. Therefore, the two `refreshEnqueue` calls cause at most $2R$ operations. So in total, $4R + 3L$ operations are required.

For `dequeue`, we consider @slotqueue-dequeue. @line-slotqueue-dequeue-read-rank causes most of the remote operations: The double scan of the `Slots` array causes about $2n L$ operations. We consider the truly remote operations. @line-slotqueue-dequeue-spsc causes $R + L$ operations. The double retry on @line-slotqueue-dequeue-refresh - @line-slotqueue-dequeue-retry each causes $L$ operation (@line-slotqueue-refresh-dequeue-read-slot) and $R$ operation. So in total, $3R + 2n L$ operations are required.
