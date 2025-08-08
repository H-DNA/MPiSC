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

This section discusses the correctness and progress guarantee properties of the distributed MPSC queue algorithms introduced in @distributed-queues[]. We also provide a theoretical performance model of these algorithms to predict how well they scale to multiple nodes. For preparation, first, we provide some preliminaries for understanding the details of this section in @preliminaries. We can then proceed to reason about our simple distributed SPSC queue (@spsc-proof), dLTQueue (@dltqueue-proof) and Slotqueue (@slotqueue-proof).

== Preliminaries <preliminaries>

In this section, we will formalize some ideas so that we can reason about them. Specifically, we specifies the notion of correct concurrent algorithms in @linearizability. Verifying the correctness of concurrent queues involves us giving two sequential queue specifications in @sequential-specification. We then give an MPSC queue theorem for establish the linearizability of dLTQueue and Slotqueue. Finally, we formulate the definition of harmless ABA problem in @ABA-safety. We will base our proofs on these formalisms to prove the algorithms' correctness.

Our system consists of a set of sequential processes that communicate through a collection of shared objects. Processes are asynchronous, so that each process may run at their own pace. Each object has a type, defining a set of possible values and operations that manipulate that object.

=== Linearizability <linearizability>

This section provides the formal definition of linearizability, which was not given in @correctness-condition. Our formalism is based on Herlihy and Wing's notion introduced in @herlihy-linearizability and @herlihy-axioms. To prove that our queues are linearizable, we have to provide a sequential specification, which will be given in the next section (@sequential-specification).

An execution of a concurrent system is modeled by a history, which is a finite sequence of operation _invocation_ and _response events_ @herlihy-axioms:
- An invocation is of the form $x" "o p(a r g s^*) A$ where $x$ is the object name, $o p$ is the operation name, $a r g^*$ is the list of arguments and $A$ is the name of a process.
- A response is of the form $x" "t e r m(r e s^*) A$ where $x$ is the object name, $t e r m$ is the termination status (which is assumed to be $O k$ in this thesis for normal termination), $r e s^*$ is the list of results and $A$ is the name of a process.
A response event _matches_ an invocation event if their object names and process names are the same. If there is no matching response event for an invocation event, the invocation event is said to be _pending_. $C o m p l e t e(H)$ is a history obtained from a history $H$ by removing all pending events in it.

A history is _sequential_ when it begins with an invocation event, and every invocation event is paired with a corresponding response event that follows it (with the exception that the final invocation may not yet have its response).

Given a history H, we can extract two types of subsequences:
- A _process subhistory_ $H|P$ contains only those events from $H$ where the process name matches $P$.
- An _object subhistory_ $H∣x$ contains only those events from $H$ where the object name matches $x$.

Two histories $H$ and $H'$ are considered equivalent when their process subhistories are identical for every process $P$.

We assume all histories to be _well-formed_, that is the history $H$ such that $H|P$ is sequential for every $P$.

An _operation_ $e$ within a history is defined as a pair composed of an invocation $i n v (e)$ and the subsequent matching response $r e s(e)$. Operation $e_0$ _lies within_ operation $e_1$ in history $H$ if $e_1$'s invocation comes first, then $e_0$'s invocation, then $e_0$'s response, and finally $e_1$'s response. Operation $e_0$ _precedes_ operation $e_1$ if $e_0$'s response comes before $e_1$'s invocation. A history $H$ induces a precedence strict partial order $arrow^(p r)_(H)$ on operations. That is, $e_0 arrow^(p r)_(H) e_1$ iff $e_0$ precedes $e_1$. When the context is clear, we write $arrow^(p r)$ instead of $arrow^(p r)_(H)$ for brevity.

A sequential specification is a function that dictates whether a sequential history is legal. Given an sequential specification of a sequential data structure, it is easy to verify the legality of a sequential history. However, sequential specifications can not be used alone to verify non-sequential histories. Therefore, the notion of linearizability is introduced.

#definition(
  name: [Linearizability @herlihy-axioms],
)[A history $H$ is _linearizable_ if it can be extended (by appending zero or more events) to some history $H'$ such that:
  - $C o m p l e t e(H')$ is equivalent to some legal sequential history $S$.
  - $arrow^(p r)_H subset.eq arrow^(p r)_S$.
  In this case $S$ is called a _linearization_ of $H$.
]

=== Sequential specification of queues <sequential-specification>

This section gives two sequential specifications of queues, one for our simple SPSC queue and one for dLTQueue and Slotqueue. Even though our SPSC queue and MPSC queues are both FIFO queues so that a single sequential specification may seem suffice, the situation when an enqueue fails differ between the two cases. The difference will be clear in a moment.

==== Sequential specification of the SPSC queue

Let the abstract state $sigma$ have the form of $[v_0, v_1, dots]$, where $v_0$, $v_1$, $dots$ are the values currently in the queue. Let $l e n(sigma)$ represent the queue's length. Let $dot$ represent concatenation.

We define the SPSC queue methods as abstract operations on the abstract state. Assume that $C a p a c i t y$ is a constant known in advance.
- $E n q u e u e(e)$: If $l e n(sigma)=C a p a c i t y$ then $sigma' = sigma$ else $sigma = sigma' dot e$. Update $sigma$ to $sigma'$.
- $D e q u e u e()$: If $sigma = []$ then return $N U L L$. Otherwise, $sigma = e dot sigma'$. Update $sigma$ to $sigma'$ and return $e$.

==== Sequential specification of dLTQueue and Slotqueue

Let the abstract state $sigma$ have the form of $[(v_0, t_0), (v_1, t_1), dots]$, where $v_0$, $v_1$, $dots$ are the values currently in the queue and $t_0$, $t_1$, $dots$ are process identifiers. Let $l e n_i (sigma)$ represent the queue's length after filtering out tuples with process identifier equal $i$. Let $dot$ represent concatenation.

We define the queue methods as abstract operations on the abstract state. Assume that $C a p a c i t y$ is a constant known in advance.
- $E n q u e u e_i (e)$: If $l e n_i (sigma)=C a p a c i t y$ then $sigma' = sigma$ else $sigma = sigma' dot e$. Update $sigma$ to $sigma'$.
- $D e q u e u e()$: If $sigma = []$ then return $N U L L$. Otherwise, $sigma = e dot sigma'$. Update $sigma$ to $sigma'$ and return $e$.

The most noticeable difference from the sequential specification of the SPSC queue is that $E n q u e u e$ and $l e n$ are now defined on a per-process basis. This is due to the fact that dLTQueue and Slotqueue keeps a bounded SPSC queue in each process.

=== MPSC queue theorem

In this section, we specify and prove a theorem for establishing dLTQueue and Slotqueue's correctness. Our theorem draws inspiration from @aspect-proof and @tss, in that we specify some properties that is sufficient for a linearizable history. However, @tss provided a theorem for stacks while @aspect-proof could only work with unbounded queues. Therefore, we provide a similar set of properties that work with bounded queues that maintain local buffers.

We consider a history $H$. We append to $H$ a large enough number of dequeues so that any successfully-enqueued values should have been dequeued out. If we can prove that this extended history $H'$ is linearizable, then we can also prove that $H$ is linearizable.

Denote:
- $M$ as the set of operations in $H'$.
- For $m in M$, $D e q(m)$ as the statement that $m$ is a dequeue and similarly for $E n q(m)$.
- $E m p(d)$ as a statement that $d$ is a dequeue that returns $N U L L$.
- $F a i l e d(e)$ as the statement that $e$ is a failed enqueue.
- $t a r g e t(m)$ as the target SPSC queue that the method $m$ affects.
- $c$ as the capacity of the local SPSC queues.

In addition to the precedence partial order $->^(p r)$, there is also a relation $->^(v a l)$ on $M$ where $e ->^(v a l) d$ if $e$ is an enqueue, $d$ is a dequeue and $d$ dequeues $e$'s value.

For simplicity, we assume every enqueue enqueues a unique value.

Consider the following properties that the history $H'$ can possess. The $=>$ is taken to mean the $->$ connective, and $<=>$ is taken to mean the $<->$ connective in propositional logic so as not to confuse with $->^(p r)$ and $->^(v a l)$.
+ Every successful enqueue is matched by a dequeue: $forall e in M. E n q (e) and not F a i l e d(e) <=> E n q(e) and  exists d in M. e ->^(v a l) d$.
+ A failed enqueue cannot be matched: $forall e, d in M. F a i l e d(e) => e arrow.not^(v a l) d$.
+ A dequeue can not dequeue a value out of nowhere: $forall d in M. D e q(d) and not E m p(d) <=> D e q(d) and exists e in M. e->^(v a l) d$.
+ A dequeue can not dequeue a future value: $forall e,d in M.e->^(v a l) d => d arrow.not^(p r)e$.
+ An enqueue can only be matched once by a dequeue: $forall e,d_1,d_2 in M.e ->^(v a l) d_1 and e ->^(v a l) d_2 =>d_1 = d_2$.
+ A dequeue can only be matched once by an enqueue: $forall e_1,e_2,d in M.e_1 ->^(v a l) d and e_2 ->^(v a l) d =>e_1 = e_2$.
+ Enqueued values are dequeued in order: $forall e_1, e_2, d_1, d_2 in M. e_1 ->^(p r) e_2 and e_2 ->^(v a l) d_2 and  e_1 ->^(v a l) d_1 => d_1 arrow^(p r) d_2$.
+ A dequeue cannot return $N U L L$ when the queue is not empty: $forall d in M. D e q(d) and (exists e, d' in M. e ->^(p r) d and e ->^(v a l) d' and d ->^(p r) d') => not E m p(d)$.
+ An enqueue cannot fail when the local SPSC queue is not full: $forall e in M$, if there are fewer than $c$ enqueues $e_i in M$ such that $not F a i l e d(e_i) and t a r g e t(e_i) = t a r g e t(e) and e_i ->^(p r) e and forall d_i. (e_i ->^(v a l) d_i => d_i arrow.not^(p r) e)$ then $not F a i l e d(e)$.
+ An enqueue fails when the local SPSC queue is full: $forall e in M$, if there are at least $c$ enqueues $e_i in M$ such that $not F a i l e d(e_i) and t a r g e t(e_i) = t a r g e t(e) and e_i ->^(p r) e and forall d_i. (e_i ->^(v a l) d_i => e arrow^(p r) d_i)$ then $F a i l e d(e)$.

We prove the following theorem.

#theorem[
  If all complete histories (after appending a large enough number of dequeues) produced by a wait-free MPSC queue satisfy the 10 properties above, the queue is linearizable.
]

#proof[
  Consider any history $H$ produced by the wait-free MPSC queue. If we can prove that $H$ is linearizable, then the queue is linearizable. Because the queue is wait-free, we can assume that there is no pending method call in the history. We then append to $H$ a large enough number of dequeues so that there shall be no unmatched enqueues and obtain $H'$. If we can prove that $H'$ is linearizable, then $H$ is also linearizable. Due to the assumption in the theorem, $H'$ satisfy the 10 properties above.

  We consider a relation $prec$ on $M$ constructed as follows.
  + If $X ->^(p r) Y$ then $X prec Y$.
  + If $e ->^(v a l) d$ then $e prec d$.
  + If $e_1 ->^(v a l) d_1$ and $e_2 ->^(v a l) d_2$ and $d_1 ->^(p r) d_2$ then $e_1 prec e_2$.
  + If $E m p(d)$ and $d ->^(p r) d'$ and $e->^(v a l) d'$ then $d prec e$.
  + If $F a i l e d (e)$ and $e arrow.not^(p r) d$ and $d arrow.not^(p r)e$ then $e prec d$.

  (\*) We will prove that the transitive closure of $prec$, $->^(a u x)$, is a strict partial order.

  By definition, $->^(a u x)$ is transitive.

  We prove that $->^(a u x)$ is irreflexive. Suppose the contrary, this must be caused by a cycle in $prec$. Suppose the shortest cycle is $m_0 prec dots prec m_k prec m_0$.

  We can easily prove that the cycle cannot have length 1 or 2. Suppose the cycle has length at least 3.

  If there are at least two dequeues in the cycle $d_0$ and $d_1$, because our history is an MPSC queue, $d_0$ and $d_1$ must be related by $->^(p r)$, suppose $d_0 ->^(p r) d_1$. If these two dequeues are not adjacent, we can create a smaller cycle by removing the operations between $d_0$ and $d_1$ in the old cycle. This means there are at most two dequeues in the cycle, and these two dequeues must be adjacent.

  If there is no dequeue in the cycle, the cycle consists of only enqueues. Note that two enqueues can only be related via rule 1 or rule 3.
  - If rule 1 was applied, or $m_i ->^(p r) m_(i+1)$, by property 7, $m_i ->^(v a l) d_i$ and $m_(i+1) ->^(v a l) d_(i+1)$ and $d_i ->^(p r) d_(i+1)$.
  - If rule 3 was applied, then by the assumption, $m_i ->^(v a l) d_i$ and $m_(i+1) ->^(v a l) d_(i+1)$ and $d_i ->^(p r) d_(i+1)$.
  Therefore, $d_i ->^(p r) d_(i+1)$. This means $d_0 ->^(p r) d_1 ->^(p r) dots ->^(p r) d_k ->^(p r) d_0$, which is a contradiction.

  (\*\*)
]

=== ABA-safety <ABA-safety>

== Theoretical proofs of the distributed SPSC <spsc-proof>

This section establishes the correctness and fault-tolerance of our simple distributed SPSC queue introduced in @distributed-spsc. Specifically, @spsc-correctness proves there is no ABA problem and unsafe memory reclamation in our SPSC queue and it is linearizable; @spsc-progress-guarantee proves that our SPSC queue is wait-free; @spsc-performance discusses the overhead involved in each SPSC queue's operation.

=== Correctness <spsc-correctness>

First, we prove that there is no ABA problem in our SPSC queue in @spsc-aba-problem. Second, we prove that there is no potential memory errors when executing our SPSC queue in @spsc-safe-memory. Finally and most importantly, we prove that our SPSC queue is linearizable in @spsc-linearizable.

==== ABA problem <spsc-aba-problem>

There is no CAS instruction in our simple distributed SPSC, so there is no potential for ABA problem.

==== Memory reclamation <spsc-safe-memory>

There is no dynamic memory allocation and deallocation in our simple distributed SPSC, so it is memory-safe.

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

For `spsc_enqueue`, we consider the procedure @spsc-enqueue. In the usual case, the remote operation on @line-spsc-enqueue-resync-first is skipped and so only 2 remote puts are performed on @line-spsc-enqueue-write and @line-spsc-enqueue-increment-last. The Data array on @line-spsc-enqueue-write is hosted on the enqueuer, so this is actually a local operation, while the control variable is hosted on the dequeuer, so @line-spsc-enqueue-increment-last is truly a remote operation. Therefore, theoretically, it is one remote operation plus a local one.

For `spsc_dequeue`, we consider the procedure @spsc-dequeue. Similarly, in the usual case, the remote operation on @line-spsc-dequeue-resync-last is skipped and only the 2 lines @line-spsc-dequeue-read and @line-spsc-dequeue-swing-first are executed always. Here, it is the other way around, the access to the `Data` array on @line-spsc-dequeue-read is a truly remote operation while the access to the First control variable is a local one. Therefore, theoretically, it is one remote operation plus a local one.

For `spsc_readFront`#sub(`e`), we consider the procedure @spsc-enqueue-readFront. The operation on @line-spsc-e-readFront-resync-first is a truly remote operation, as the `First` control variable is hosted on the dequeuer. The operation on @line-spsc-e-readFront-read is a remote operation, as the `Data` array is hosted on the enqueuer. This means, theoretically, it also takes one remote operation plus a local one.

For `spsc_readFront`#sub(`d`), we consider the procedure @spsc-dequeue-readFront. Only the operation on @line-spsc-d-readFront-read is executed always, which results in a truly remote operation as the Data array is hosted on the enqueuer. Therefore, it only takes one remote operation.


== Theoretical proofs of dLTQueue <dltqueue-proof>

=== Proof-specific notations

The structure of dLTQueue is presented again in @remind-modified-ltqueue-tree.

As a reminder, the bottom rectangular nodes are called the *enqueuer nodes* and the circular node are called the *tree nodes*. Tree nodes that are attached to an enqueuer node are called *leaf nodes*, otherwise, they are called *internal nodes*. Each *enqueuer node* is hosted on the enqueuer that corresponds to it. The enqueuer nodes accomodate an instance of our distributed SPSC in @distributed-spsc and a `Min_timestamp` variable representing the minimum timestamp inside the SPSC. Each *tree node* stores a rank of a enqueuer that is attached to the subtree which roots at the *tree node*.

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

We will refer `propagate`#sub(`e`) and `propagate`#sub(`d`) as `propagate` if there is no need for discrimination. Similarly, we will sometimes refer to `refreshNode`#sub(`e`) and `refreshNode`#sub(`d`) as `refreshNode`, `refreshLeaf`#sub(`e`) and `refreshLeaf`#sub(`d`) as `refreshLeaf`, `refreshTimestamp`#sub(`e`) and `refreshTimestamp`#sub(`d`) as `refreshTimestamp`.

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

Notice that at these locations, we increase the associated version tags of the CAS-ed values. These version tags are 32-bit in size, therefore, practically, ABA problem can't virtually occur. It is safe to assume that there is no ABA problem in dLTQueue.

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

For `dequeue`, it is similar to `enqueue` but the other way around, what makes for a remote operation in `enqueue` is a local operation in `dequeue` and otherwise. Therefore, `dequeue` requires about $4log_2(n)R + 6log_2(n)L$ operations.

== Theoretical proofs of Slotqueue <slotqueue-proof>

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

Noticeably, we use no scheme to avoid ABA problem in Slotqueue. In actuality, ABA problem does not adversely affect our algorithm's correctness, except in the extreme case that the 64-bit distributed counter overflows, which is unlikely.

We will prove that Slotqueue is ABA-safe, as introduced in @ABA-safety.

Notice that we only use `CAS`es on:
- @line-slotqueue-refresh-enqueue-cas of `refreshEnqueue` (@slotqueue-refresh-enqueue), which is part of an enqueue.
- @line-slotqueue-refresh-dequeue-cas of `refreshDequeue` (@slotqueue-refresh-dequeue), which is part of a dequeue.

Both `CAS`es target some slot in the `Slots` array.

#theorem(name: "Concurrent accesses on an SPSC and a slot")[
  Only one dequeuer and one enqueuer can concurrently modify an SPSC and a slot in the `Slots` array.
] <slotqueue-one-enqueuer-one-dequeuer-theorem>

#proof[
  This is trivial to prove based on the algorithm's definition.
]

#theorem(name: "Monotonicity of SPSC timestamps")[
  Each SPSC in Slotqueue contains elements with increasing timestamps.
] <slotqueue-spsc-timestamp-monotonicity-theorem>

#proof[
  Each enqueue would `FAA` the distributed counter (@line-slotqueue-enqueue-obtain-timestamp in @slotqueue-enqueue) and enqueue into the local SPSC an item with the timestamp obtained from the counter. Applying @slotqueue-one-enqueuer-one-dequeuer-theorem, we know that items are enqueued one at a time into the SPSC. Therefore, later items are enqueued by later enqueues, which obtain increasing values by `FAA`-ing the shared counter. The theorem holds.
]

#theorem[A `refreshEnqueue` (@slotqueue-refresh-enqueue) can only change a slot to a value other than `MAX_TIMESTAMP`.] <slotqueue-refresh-enqueue-CAS-to-non-MAX-theorem>

#proof[
  For `refreshEnqueue` to change the slot's value, the condition on @line-slotqueue-refresh-enqueue-check-2 must be `false`. Then, `new_timestamp` must equal to `ts`, which is not `MAX_TIMESTAMP`. It's obvious that the `CAS` on @line-slotqueue-refresh-enqueue-cas changes the slot to a value other than `MAX_TIMESTAMP`.
]

#theorem(
  name: [ABA safety of dequeue],
)[Assume that the 64-bit distributed counter never overflows, dequeue (@slotqueue-dequeue) is ABA-safe.] <slotqueue-aba-safe-dequeue-theorem>

#proof[
  Consider a *successful CAS-sequence* on slot `s` by a dequeue $d$. Denote $t_d$ as the value this CAS-sequence observes.

  If there's no *successful slot-modification instruction* on slot `s` by an enqueue $e$ within $d$'s *successful CAS-sequence*, then this dequeue is ABA-safe.

  Suppose the enqueue $e$ executes the _last_ *successful slot-modification instruction* on slot `s` within $d$'s *successful CAS-sequence*. Denote $t_e$ to be the value that $e$ sets `s` $(*)$.

  If $t_e != t_d$, this CAS-sequence of $d$ cannot be successful, which is a contradiction. Therefore, $t_e = t_d$.

  Note that $e$ can only set `s` to the timestamp of the item it enqueues. That means, $e$ must have enqueued a value with timestamp $t_d$. However, by definition $(*)$, $t_d$ is read before $e$ executes the CAS, so $d$ cannot observe $t_d$ because $e$ has CAS-ed slot `s`. This means another process (dequeuer/enqueuer) has seen the value $e$ enqueued and CAS `s` for $e$ before $t_d$. By @slotqueue-one-enqueuer-one-dequeuer-theorem, this "another process" must be another dequeuer $d'$ that precedes $d$ because it overlaps with $e$.

  Because $d'$ and $d$ cannot overlap, while $e$ overlaps with both $d'$ and $d$, $e$ must be the _first_ enqueue on `s` that overlaps with $d$. Combining with @slotqueue-one-enqueuer-one-dequeuer-theorem and the fact that $e$ executes the _last_ *successful slot-modification instruction* on slot `s` within $d$'s *successful CAS-sequence*, $e$ must be the only enqueue that executes a *successful slot-modification instruction* on `s` within $d$'s *successful CAS-sequence*.

  During the start of $d$'s successful CAS-sequence till the end of $e$, `spsc_readFront` on the local SPSC must return the same element, because:
  - There's no other dequeue running during this time.
  - There's no enqueue other than $e$ running.
  - The `spsc_enqueue` of $e$ must have completed before the start of $d$'s successful CAS sequence, because a previous dequeuer $d'$ can see its effect.
  Therefore, if we were to move the starting time of $d$'s successful CAS-sequence right after $e$ has ended, we still retain the output of the program because:
  - The CAS sequence only reads two shared values: the `rank`th entry of `Slots` and `spsc_readFront()`, but we have proven that these two values remain the same if we were to move the starting time of $d$'s successful CAS-sequence this way.
  - The CAS sequence does not modify any values except for the last CAS instruction, and the ending time of the CAS sequence is still the same.
  - The CAS sequence modifies the `rank`th entry of `Slots` at the CAS but the target value is the same because inputs and shared values are the same in both cases.

  We have proved that if we move $d$'s successful CAS-sequence to start after the _last_ *successful slot-modification instruction* on slot `s` within $d$'s *successful CAS-sequence*, we still retain the program's output.

  If we apply the reordering for every dequeue, the theorem directly follows.
]

#theorem(
  name: [ABA safety of enqueue],
)[Assume that the 64-bit distributed counter never overflows, enqueue (@slotqueue-enqueue) is ABA-safe.] <slotqueue-aba-safe-enqueue-theorem>

#proof[
  Consider a *successful CAS-sequence* on slot `s` by an enqueue $e$. Denote $t_e$ as the value this CAS-sequence observes.

  If there's no *successful slot-modification instruction* on slot `s` by a dequeue $d$ within $e$'s *successful CAS-sequence*, then this enqueue is ABA-safe.

  Suppose the dequeue $d$ executes the _last_ *successful slot-modification instruction* on slot `s` within $e$'s *successful CAS-sequence*. Denote $t_d$ to be the value that $d$ sets `s`. If $t_d != t_e$, this CAS-sequence of $e$ cannot be successful, which is a contradiction $(*)$.

  Therefore, $t_d = t_e$.

  If $t_d = t_e =$ `MAX_TIMESTAMP`, this means $e$ observes a value of `MAX_TIMESTAMP` before $d$ even sets `s` to `MAX_TIMESTAMP` due to $(*)$. If this `MAX_TIMESTAMP` value is the initialized value of `s`, it's a contradiction, as `s` must be non-`MAX_TIMESTAMP` at some point for a dequeue such as $d$ to enter its CAS sequence. If this `MAX_TIMESTAMP` value is set by an enqueue, it's also a contradiction, as `refreshEnqueue` cannot set a slot to `MAX_TIMESTAMP`. Therefore, this `MAX_TIMESTAMP` value is set by a dequeue $d'$. If $d' != d$ then it's a contradiction, because between $d'$ and $d$, `s` must be set to be a non-`MAX_TIMESTAMP` value before $d$ can be run, thus, $e$ cannot have observed a value set by $d'$. Therefore, $d' = d$. But, this means $e$ observes a value set by $d$, which violates our assumption $(*)$.

  Therefore $t_d = t_e = t' !=$ `MAX_TIMESTAMP`. $e$ cannot observe the value $t'$ set by $d$ due to our assumption $(*)$. Suppose $e$ observes the value $t'$ from `s` set by another enqueue/dequeue call other than $d$.

  If this "another call" is a dequeue $d'$ other than $d$, $d'$ precedes $d$. By @slotqueue-spsc-timestamp-monotonicity-theorem, after each dequeue, the front element's timestamp will be increasing, therefore, $d'$ must have set `s` to a timestamp smaller than $t_d$. However, $e$ observes $t_e = t_d$. This is a contradiction.

  Therefore, this "another call" is an enqueue $e'$ other than $e$ and $e'$ precedes $e$. We know that an enqueue only sets `s` to the timestamp it obtains.

  Suppose $e'$ does not overlap with $d$, then $e$ precedes $d$. $e'$ can only set `s` to $t'$ if $e'$ sees that the local SPSC has the front element as the element it enqueues. Due to @slotqueue-one-enqueuer-one-dequeuer-theorem, this means $e'$ must observe a local SPSC with only the element it enqueues. Then, when $d$ executes `readFront`, the item $e'$ enqueues must have been dequeued out already, thus, $d$ cannot set `s` to $t'$. This is a contradiction.

  Therefore, $e'$ overlaps with $d$.

  Because $e'$ and $e$ cannot overlap, while $d$ overlaps with both $e'$ and $e$, $d$ must be the _first_ dequeue on `s` that overlaps with $e$. Combining with @slotqueue-one-enqueuer-one-dequeuer-theorem and the fact that $d$ executes the _last_ *successful slot-modification instruction* on slot `s` within $e$'s *successful CAS-sequence*, $d$ must be the only dequeue that executes a *successful slot-modification instruction* within $e$'s *successful CAS-sequence*.

  During the start of $e$'s successful CAS-sequence till the end of $d$, `spsc_readFront` on the local SPSC must return the same element, because:
  - There's no other enqueue running during this time.
  - There's no dequeue other than $d$ running.
  - The `spsc_dequeue` of $d$ must have completed before the start of $e$'s successful CAS sequence, because a previous enqueuer $e'$ can see its effect.
  Therefore, if we were to move the starting time of $e$'s successful CAS-sequence right after $d$ has ended, we still retain the output of the program because:
  - The CAS sequence only reads two shared values: the `rank`th entry of `Slots` and `spsc_readFront()`, but we have proven that these two values remain the same if we were to move the starting time of $e$'s successful CAS-sequence this way.
  - The CAS sequence does not modify any values except for the last CAS/store instruction, and the ending time of the CAS sequence is still the same.
  - The CAS sequence modifies the `rank`th entry of `Slots` at the CAS but the target value is the same because inputs and shared values are the same in both cases.

  We have proved that if we move $e$'s successful CAS-sequence to start after the _last_ *successful slot-modification instruction* on slot `s` within $e$'s *successful CAS-sequence*, we still retain the program's output.

  If we apply the reordering for every enqueue, the theorem directly follows.
]

#theorem(
  name: "ABA safety",
)[Assume that the 64-bit distributed counter never overflows, Slotqueue is ABA-safe.] <aba-safe-slotqueue-theorem>

#proof[
  This follows from @slotqueue-aba-safe-enqueue-theorem and @slotqueue-aba-safe-dequeue-theorem.
]

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
