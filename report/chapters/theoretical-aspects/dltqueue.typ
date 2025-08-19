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

== Theoretical proofs of dLTQueue

In this section, we provide proofs covering all of our interested theoretical aspects in dLTQueue.

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

This section establishes the correctness of dLTQueue introduced in @dLTQueue.

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

We assume all enqueues succeed in this section. Note that a failed enqueue only causes the counter to increment, and does not change the queue state in any other ways.

#theorem[In dLTQueue, an enqueue can only match at most one dequeue.] <ltqueue-unique-match-enqueue>

#proof[A dequeue indirectly performs a value dequeue through `spsc_dequeue`. Because `spsc_dequeue` can only match one `spsc_enqueue` by another enqueue, the theorem holds.]

#theorem[In dLTQueue, a dequeue can only match at most one enqueue.] <ltqueue-unique-match-dequeue>

#proof[This is trivial as a dequeue can only read out at most one value, so it can only match at most one enqueue.]

#theorem[Only the dequeuer and one enqueuer can operate on an enqueuer node.]

#proof[This is trivial based on how the algorithm is defined.]

We immediately obtain the following result.

#corollary[Only one dequeue operation and one enqueue operation can operate concurrently on an enqueuer node.] <ltqueue-one-dequeue-one-enqueue-corollary>

#theorem[The SPSC at an enqueuer node contains items with increasing timestamps.] <ltqueue-increasing-timestamp-theorem>

#proof[
  Each enqueue would `FAA` the distributed counter (@line-ltqueue-enqueue-obtain-timestamp in @ltqueue-enqueue) and enqueue into the SPSC an item with the timestamp obtained from that counter. Applying @ltqueue-one-dequeue-one-enqueue-corollary, we know that items are enqueued one at a time into the SPSC. Therefore, later items are enqueued by later enqueues, which obtain increasing values by `FAA`-ing the shared counter. The theorem holds.
]

#theorem[For an enqueue or a dequeue $op$, if $op$ modifies an enqueuer node and this enqueuer node is attached to a leaf node $l$, then $p a t h(op)$ is the set of nodes lying on the path from $l$ to the root node.]

#proof[This is trivial considering how `propagate`#sub(`e`) (@ltqueue-enqueue-propagate) and `propagate`#sub(`d`) (@ltqueue-dequeue-propagate) work.]

#theorem[For any time $t$ and a node $n$, $r a n k(n, t)$ can only be `DUMMY_RANK` or the rank of an enqueuer that is attached to the subtree rooted at $n$.] <ltqueue-possible-ranks-theorem>

#proof[This is trivial considering how `refreshNode`#sub(`e`), `refreshNode`#sub(`d`) and `refreshLeaf`#sub(`e`), `refreshLeaf`#sub(`d`) works.]

#theorem[If an enqueue or a dequeue $op$ begins its *timestamp-refresh phase* at $t_0$ and finishes at time $t_1$, there's always at least one successful call to `refreshTimestamp`#sub(`e`) (@ltqueue-enqueue-refresh-timestamp) or `refreshTimestamp`#sub(`d`) (@ltqueue-dequeue-refresh-timestamp) that affects the enqueuer node corresponding to $r a n k(op)$ and this successful call starts and ends its *CAS-sequence* between $t_0$ and $t_1$.] <ltqueue-refresh-timestamp-theorem>

#proof[
  Suppose the interested *timestamp-refresh phase* affects the enqueuer node $n$.

  Notice that the *timestamp-refresh phase* of both enqueue and dequeue consists of at most 2 `refreshTimestamp` calls affecting $n$.

  If one of the two `refreshTimestamp`s of the *timestamp-refresh phase* succeeds, then the theorem obviously holds.

  Consider the case where both fail.

  The first `refreshTimestamp` fails because there's another `refreshTimestamp` on $n$ ending its *CAS-sequence* successfully after $t_0$ but before the end of the first `refreshTimestamp`'s *CAS-sequence*.

  The second `refreshTimestamp` fails because there's another `refreshTimestamp` on $n$ ending its *CAS-sequence* successfully after $t_0$ but before the end of the second `refreshTimestamp`'s *CAS-sequence*. This another `refreshTimestamp` must start its *CAS-sequence* after the end of the first successful `refreshTimestamp`, otherwise, it would overlap with the *CAS-sequence* of the first successful `refreshTimestamp`, but successful *CAS-sequences* on the same enqueuer node cannot overlap as ABA problem does not occur. In other words, this another `refreshTimestamp` starts and successfully ends its *CAS-sequence* between $t_0$ and $t_1$.

  We have proved the theorem.
]

#theorem[If an enqueue or a dequeue begins its *node-$n$-refresh phase* at $t_0$ and finishes at $t_1$, there's always at least one successful `refreshNode` or `refreshLeaf` calls affecting $n$ and this successful call starts and ends its *CAS-sequence* between $t_0$ and $t_1$.] <ltqueue-refresh-node-theorem>

#proof[This is similar to the above proof.]

#theorem[Consider a node $n$. If within $t_0$ and $t_1$, any dequeue $d$ where $n in p a t h(d)$ has finished its *node-$n$-refresh phase*, then $m i n \- t s(r a n k(n, t_x), t_y)$ is monotonically decreasing for $t_x, t_y in [t_0, t_1]$ .] <ltqueue-monotonic-theorem>

#proof[
  We have the assumption that within $t_0$ and $t_1$, all dequeue where $n in p a t h(d)$ has finished its *node-$n$-refresh phase*. Notice that if $n$ satisfies this assumption, any child of $n$ also satisfies this assumption.

  We will prove a stronger version of this theorem: Given a node $n$, time $t_0$ and $t_1$ such that within $[t_0, t_1]$, any dequeue $d$ where $n in p a t h(d)$ has finished its *node-$n$-refresh phase*. Consider the last dequeue's *node-$n$-refresh phase* before $t_0$ (there maybe none). Take $t_s (n)$ and $t_e (n)$ to be the starting and ending time of the CAS-sequence of the last successful *$n$-refresh call* during this phase, or if there is none, $t_s (n) = t_e (n) = 0$. Then, $m i n \- t s(r a n k(n, t_x), t_y)$ is monotonically decreasing for $t_x, t_y in [t_e (n), t_1]$.

  Consider any enqueuer node of rank $r$ that is attached to a satisfied leaf node. For any $n'$ that is a descendant of $n$, during $t_s (n')$ and $t_1$, there's no call to `spsc_dequeue`. Because:
  - If an `spsc_dequeue` starts between $t_0$ and $t_1$, the dequeue that calls it hasn't finished its *node-$n'$-refresh phase*.
  - If an `spsc_dequeue` starts between $t_s (n')$ and $t_0$, then a dequeue's *node-$n'$-refresh phase* must start after $t_s (n')$ and before $t_0$, but this violates our assumption of $t_s (n')$.
  Therefore, there can only be calls to `spsc_enqueue` during $t_s (n')$ and $t_1$. Thus, $m i n \- s p s c \- t s(r, t_x)$ can only decrease from `MAX_TIMESTAMP` to some timestamp and remain constant for $t_x in [t_s (n'), t_1]$. $(1)$

  Similarly, there can be no dequeue that hasn't finished its *timestamp-refresh phase* during $t_s (n')$ and $t_1$. Therefore, $m i n \- t s (r, t_x)$ can only decrease from `MAX_TIMESTAMP` to some timestamp and remain constant for $t_x in [t_s (n'), t_1]$. $(2)$

  Consider any satisfied leaf node $n_0$. There can't be any dequeue that hasn't finished its *node-$n_0$-refresh phase* during $t_e (n_0)$ and $t_1$. Therefore, any successful `refreshLeaf` affecting $n_0$ during $[t_e (n_0), t_1]$ must be called by an enqueue. Because there's no `spsc_dequeue`, this `refreshLeaf` can only set $r a n k(n_0, t_x)$ from `DUMMY_RANK` to $r$ and this remains $r$ until $t_1$, which is the rank of the enqueuer whose node it is attached to. Therefore, combining with $(1)$, $m i n \- t s(r a n k(n_0, t_x), t_y)$ is monotonically decreasing for $t_x, t_y in [t_e (n_0), t_1]$. $(3)$

  Consider any satisfied non-leaf node $n'$ that is a descendant of $n$. Suppose during $[t_e (n'), t_1]$, we have a sequence of successful *$n'$-refresh calls* that start their CAS-sequences at $t_(s t a r t \- 0) lt t_(s t a r t \- 1) lt t_(s t a r t \- 2) lt ... lt t_(s t a r t \- k)$ and end them at $t_(e n d \- 0) lt t_(e n d \- 1) lt t_(e n d\- 2) lt ... lt t_(e n d \- k)$. By definition, $t_(e n d \- 0) = t_e (n')$ and $t_(s t a r t \- 0) = t_s (n')$. We can prove that $t_(e n d \- i) < t_(s t a r t \- (i+1))$ because successful CAS-sequences cannot overlap.

  Due to how `refreshNode` (@ltqueue-enqueue-refresh-node and @ltqueue-dequeue-refresh-node) is defined, for any $k gt.eq i gt.eq 1$:
  - Suppose $t_(r a n k\-i)(c)$ is the time `refreshNode` reads the rank stored in the child node $c$, so $t_(s t a r t \- i) lt.eq t_(r a n k\-i)(c) lt.eq t_(e n d \- i)$.
  - Suppose $t_(t s\-i)(c)$ is the time `refreshNode` reads the timestamp stored in the enqueuer with the rank read previously, so $t_(s t a r t \- i) lt.eq t_(t s\-i)(c) lt.eq t_(e n d \- i)$.
  - There exists a child $c_i$ such that $r a n k(n', t_(e n d \- i)) = r a n k(c_i, t_(r a n k\-i)(c_i))$. $(4)$
  - For every child $c$ of $n'$, #linebreak() $m i n \- t s(r a n k(n', t_(e n d \- i)), t_(t s\-i)(c_i))$ #linebreak() $lt.eq m i n \- t s (r a n k(c, t_(r a n k\-i)(c)), t_(t s\-i)(c))$. $(5)$

  Suppose the stronger theorem already holds for every child $c$ of $n'$. $(6)$

  For any $i gt.eq 1$, we have $t_e (c) lt.eq t_s (n') lt.eq t_(s t a r t \-(i-1)) lt.eq t_(r a n k\-(i-1))(c) lt.eq t_(e n d \-(i-1)) lt.eq t_(s t a r t \-i) lt.eq t_(r a n k \- i)(c) lt.eq t_1$. Combining with $(5)$, $(6)$, we have for any $k gt.eq i gt.eq 1$, #linebreak() $m i n \- t s(r a n k(n', t_(e n d \- i)), t_(t s\-i)(c_i))$ #linebreak() $lt.eq m i n \- t s (r a n k(c, t_(r a n k\-i)(c)), t_(t s\-i)(c))$ #linebreak() $lt.eq m i n \- t s (r a n k(c, t_(r a n k\-(i-1))(c)), t_(t s\-i)(c))$.

  Choose $c = c_(i-1)$ as in $(4)$. We have for any $k gt.eq i gt.eq 1$, #linebreak() $m i n \- t s(r a n k(n', t_(e n d \- i)), t_(t s\-i)(c_i))$ #linebreak() $lt.eq m i n \- t s (r a n k(c_(i-1), t_(r a n k\-(i-1))(c_(i-1))),$$t_(t s\-i)(c_(i-1)))$ #linebreak() $= m i n\- t s(r a n k(n', t_(e n d \- (i-1))), t_(t s \-i)(c_(i-1))$.

  Because $t_(t s \-i)(c_i) lt.eq t_(e n d \- i)$ and $t_(t s \-i)(c_(i-1)) gt.eq t_(e n d \- (i-1))$ and $(2)$, we have for any $k gt.eq i gt.eq 1$, #linebreak() $m i n \- t s(r a n k(n', t_(e n d \- i)), t_(e n d\-i))$ #linebreak() $lt.eq m i n \- t s (r a n k(n', t_(e n d \- (i-1))), t_(e n d \- (i-1)))$. $(*)$

  $r a n k(n', t_x)$ can only change after each successful `refreshNode`, therefore, the sequence of its value is $r a n k(n', t_(e n d \- 0))$, $r a n k(n', t_(e n d \- 1))$, ..., $r a n k(n', t_(e n d \- k))$. $(**)$

  Note that if `refreshNode` observes that an enqueuer has a `Min_timestamp` of `MAX_TIMESTAMP`, it would never try to CAS $n'$'s rank to the rank of that enqueuer (@line-ltqueue-e-refresh-node-check-dummy of @ltqueue-enqueue-refresh-node and @line-ltqueue-d-refresh-node-check-dummy of @ltqueue-dequeue-refresh-node). So, if `refreshNode` actually sets the rank of $n'$ to some non-`DUMMY_RANK` value, the corresponding enqueuer must actually has a non-`MAX_TIMESTAMP` `Min-timestamp` _at some point_. Due to $(2)$, this is constant up until $t_1$. Therefore, $m i n \- t s(r a n k(n', t_(e n d \- i)), t))$ is constant for any $t gt.eq t_(e n d \- i)$ and $k gt.eq i gt.eq 1$. $m i n \- t s(r a n k(n', t_(e n d \- 0)), t))$ is constant for any $t gt.eq t_(e n d \- 0)$ if there's a `refreshNode` before $t_0$. If there's no `refreshNode` before $t_0$, it is constantly `MAX_TIMESTAMP`. So, $m i n \- t s(r a n k(n', t_(e n d \- i)), t))$ is constant for any $t gt.eq t_(e n d \- i)$ and $k gt.eq i gt.eq 0$. $(***)$

  Combining $(*)$, $(**)$, $(***)$, we obtain the stronger version of the theorem.
]

#theorem[If an enqueue $e$ obtains a timestamp $c$, finishes at time $t_0$ and is still *unmatched* at time $t_1$, then for any subrange $T$ of $[t_0, t_1]$ that does not overlap with a dequeue, $m i n \- t s(r a n k(r o o t, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.] <ltqueue-unmatched-enqueue-theorem>

#proof[
  We will prove a stronger version of this theorem: Suppose an enqueue $e$ obtains a timestamp $c$, finishes at time $t_0$ and is still *unmatched* at time $t_1$. For every $n_i in p a t h(e)$, $n_0$ is the leaf node and $n_i$ is the parent of $n_(i-1)$, $i gt.eq 1$. If $e$ starts and finishes its *node-$n_i$-refresh phase* at $t_(s t a r t\-i)$ and $t_(e n d\-i)$ then for any subrange $T$ of $[t_(e n d\-i), t_1]$ that does not overlap with a dequeue $d$ where $n_i in p a t h(d)$ and $d$ hasn't finished its *node $n_i$ refresh phase*, $m i n \- t s(r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.

  If $t_1 lt t_0$ then the theorem holds.

  Take $r_e$ to be the rank of the enqueuer that performs $e$.

  Suppose $e$ enqueues an item with the timestamp $c$ into the local SPSC at time $t_(e n q u e u e)$. Because it is still unmatched up until $t_1$, $c$ is always in the local SPSC during $t_(e n q u e u e)$ to $t_1$. Therefore, $m i n \- s p s c \- t s(r_e, t) lt.eq c$ for any $t in [t_(e n q u e u e), t_1]$. $(1)$

  Suppose $e$ finishes its *timestamp refresh phase* at $t_(r\-t s)$. Because $t_(r\-t s) gt.eq t_(e n q u e u e)$, due to $(1)$, $m i n \- t s(r_e, t) lt.eq c$ for every $t in [t_(r\-t s),t_1]$. $(2)$

  Consider the leaf node $n_0 in p a t h (e)$. Due to $(2)$, $r a n k(n_0, t)$ is always $r_e$ for any $t in [t_(e n d\-0), t_1]$. Also due to $(2)$, $m i n \- t s(r a n k(n_0, t_r), t_s) lt.eq c$ for any $t_r, t_s in [t_(e n d\-0), t_1]$.

  Consider any non-leaf node $n_i in p a t h(e)$. We can extend any subrange $T$ to the left until we either:
  - Reach a dequeue $d$ such that $n_i in p a t h (d)$ and $d$ has just finished its *node-$n_i$-refresh phase*.
  - Reach $t_(e n d \- i)$.
  Consider one such subrange $T_i$.

  Notice that $T_i$ always starts right after a *node-$n_i$-refresh phase*. Due to @ltqueue-refresh-node-theorem, there's always at least one successful `refreshNode` in this *node-$n_i$-refresh phase*.

  Suppose the stronger version of the theorem already holds for $n_(i-1)$. That is, if $e$ starts and finishes its *node-$n_(i-1)$-refresh phase* at $t_(s t a r t\-(i-1))$ and $t_(e n d\-(i-1))$ then for any subrange $T$ of $[t_(e n d\-(i-1)), t_1]$ that does not overlap with a dequeue $d$ where $n_i in p a t h(d)$ and $d$ hasn't finished its *node $n_(i-1)$ refresh phase*, $m i n \- t s(r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.

  Extend $T_i$ to the left until we either:
  - Reach a dequeue $d$ such that $n_i in p a t h (d)$ and $d$ has just finished its *node-$n_(i-1)$-refresh phase*.
  - Reach $t_(e n d \- (i-1))$.
  Take the resulting range to be $T_(i-1)$. Obviously, $T_i subset.eq T_(i-1)$.

  $T_(i-1)$ satisifies both criteria:
  - It's a subrange of $[t_(e n d\-(i-1)), t_1]$.
  - It does not overlap with a dequeue $d$ where $n_i in p a t h(d)$ and $d$ hasn't finished its *node-$n_(i-1)$-refresh phase*.
  Therefore, $m i n \- t s(r a n k(n_(i-1), t_r), t_s) lt.eq c$ for any $t_r, t_s in T_(i-1)$.

  Consider the last successful `refreshNode` on $n_i$ ending not after $T_i$ starts. Take $t_s'$ and $t_e'$ to be the start and end time of this `refreshNode`'s CAS-sequence. Because right at the start of $T_i$, a *node-$n_i$-refresh phase* just ends, this `refreshNode` must be within this *node-$n_i$-refresh phase*. $(4)$

  This `refreshNode`'s CAS-sequence must be within $T_(i-1)$. This is because right at the start of $T_(i-1)$, a *node-$n_(i-1)$-refresh phase* just ends and $T_(i-1) supset.eq T_i$, $T_(i-1)$ must cover the *node-$n_i$-refresh phase* whose end $T_i$ starts from. Combining with $(4)$, $t_s' in T_(i-1)$ and $t_e' in T_i$. $(5)$

  Due to how `refreshNode` is defined and the fact that $n_(i-1)$ is a child of $n_i$:
  - $t_(r a n k)$ is the time `refreshNode` reads the rank stored in $n_(i-1)$, so that $t_s' lt.eq t_(r a n k) lt.eq t_e'$. Combining with $(5)$, $t_(r a n k) in T_(i-1)$.
  - $t_(t s)$ is the time `refreshNode` reads the timestamp from that rank $t_s' lt.eq t_(t s) lt.eq t_e'$. Combining with $(5)$, $t_(t s) in T_(i-1)$.
  - There exists a time $t'$, $t_s' lt.eq t' lt.eq t_e'$, #linebreak() $m i n \- t s(r a n k(n_i, t_e'), t') lt.eq m i n \- t s (r a n k(n_(i-1), t_(r a n k)), t_(t s))$. $(6)$

  From $(6)$ and the fact that $t_(r a n k) in T_(i-1)$ and $t_(t s) in T_(i-1)$, $m i n \- t s(r a n k(n_i, t_e'), t') lt.eq c$.

  There shall be no `spsc_dequeue` starting within $t_s'$ till the end of $T_i$ because:
  - If there's an `spsc_dequeue` starting within $T_i$, then $T_i$'s assumption is violated.
  - If there's an `spsc_dequeue` starting after $t_s'$ but before $T_i$, its dequeue must finish its *node-$n_i$-refresh phase* after $t_s'$ and before $T_i$. However, then $t_e'$ is no longer the end of the last successful `refreshNode` on $n_i$ not after $T_i$.
  Because there's no `spsc_dequeue` starting in this timespan, $m i n \- t s(r a n k(n_i, t_e'), t_e') lt.eq m i n \- t s(r a n k(n_i, t_e'), t') lt.eq c$.

  If there's no dequeue between $t_e'$ and the end of $T_i$ whose *node-$n_i$-refresh phase* hasn't finished, then by @ltqueue-monotonic-theorem, $m i n \- t s(r a n k(n_i, t_r), t_s)$ is monotonically decreasing for any $t_r$, $t_s$ starting from $t_e'$ till the end of $T_i$. Therefore, $m i n \- t s (r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T_i$.

  Suppose there's a dequeue whose *node-$n_i$-refresh phase* is in progress some time between $t_e'$ and the end of $T_i$. By definition, this dequeue must finish it before $T_i$. Because $t_e'$ is the time of the last successful refresh on $n_i$ before $T_i$, $t_e'$ must be within the *node-$n_i$-refresh phase* of this dequeue and there should be no dequeue after that. By the way $t_e'$ is defined, technically, this dequeue has finished its *node-$n_i$-refresh phase* right at $t_e'$. Therefore, similarly, we can apply @ltqueue-monotonic-theorem, $m i n \- t s (r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T_i$.

  By induction, we have proved the stronger version of the theorem. Therefore, the theorem directly follows.
]

#corollary[Suppose $r o o t$ is the root tree node. If an enqueue $e$ obtains a timestamp $c$, finishes at time $t_0$ and is still *unmatched* at time $t_1$, then for any subrange $T$ of $[t_0, t_1]$ that does not overlap with a dequeue, $m i n \- s p s c \- t s(r a n k(r o o t, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.] <ltqueue-unmatched-enqueue-corollary>

#proof[
  Call $t_(s t a r t)$ and $t_(e n d)$ to be the start and end time of $T$.

  Applying @ltqueue-unmatched-enqueue-theorem, we have that $m i n \- t s(r a n k(r o o t, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.

  Fix $t_r$ so that $r a n k(r o o t, t_r) = r$. We have that $m i n \- t s(r, t) lt.eq c$ for any $t in T$.

  $m i n \- t s(r, t)$ can only change due to a successful `refreshTimestamp` on the enqueuer node with rank $r$. Consider the last successful `refreshTimestamp` on the enqueuer node with rank $r$ not after $T$. Suppose that `refreshTimestamp` reads out the minimum timestamp of the local SPSC at $t' lt.eq t_(s t a r t)$.

  Therefore, $m i n \- t s(r, t_(s t a r t)) = m i n \- s p s c \- t s(r, t') lt.eq c$.

  We will prove that after $t'$ until $t_(e n d)$, there's no `spsc_dequeue` on $r$ running.

  Suppose the contrary, then this `spsc_dequeue` must be part of a dequeue. By definition, this dequeue must start and end before $t_(s t a r t)$, else it violates the assumption of $T$. If this `spsc_dequeue` starts after $t'$, then its `refreshTimestamp` must finish after $t'$ and before $t_(s t a r t)$. But this violates the assumption that the last `refreshTimestamp` not after $t_(s t a r t)$ reads out the minimum timestamp at $t'$.

  Therefore, there's no `spsc_dequeue` on $r$ running during $[t', t_(e n d)]$. Therefore, $m i n \- s p s c \- t s(r, t)$ remains constant during $[t', t_(e n d)]$ because it is not `MAX_TIMESTAMP`.

  In conclusion, $m i n \- s p s c \- t s(r, t) lt.eq c$ for $t in[t', t_(e n d)]$.

  We have proved the theorem.
]

#theorem[Given a rank $r$. If within $[t_0, t_1]$, there's no uncompleted enqueue on rank $r$ and all matching dequeues for any completed enqueues on rank $r$ has finished, then $r a n k(n, t) eq.not r$ for every node $n$ and $t in [t_0, t_1]$.] <ltqueue-matched-enqueue-theorem>

#proof[
  If $n$ doesn't lie on the path from root to the leaf node that is attached to the enqueuer node with rank $r$, the theorem obviously holds.

  Due to @ltqueue-one-dequeue-one-enqueue-corollary, there can only be one enqueue and one dequeue at a time at an enqueuer node with rank $r$. Therefore, there is a sequential ordering among the enqueues and a sequential ordering within the dequeues. Therefore, it is sensible to talk about the last enqueue before $t_0$ and the last matched dequeue $d$ before $t_0$.

  Since all of these dequeues and enqueues work on the same local SPSC and the SPSC is linearizable, $d$ must match the last enqueue. After this dequeue $d$, the local SPSC is empty.

  When $d$ finishes its *timestamp-refresh phase* at $t_(t s) lt.eq t_0$, due to @ltqueue-refresh-timestamp-theorem, there's at least one successful `refreshTimestamp` call in this phase. Because the last enqueue has been matched, $m i n \- t s(r, t) =$ `MAX_TIMESTAMP` for any $t in [t_(t s), t_1]$.

  Similarly, for a leaf node $n_0$, suppose $d$ finishes its *node-$n_0$-refresh phase* at $t_(r\-0) gt.eq t_(t s)$, then $r a n k(n_0, t) =$ `DUMMY_RANK` for any $t in [t_(r\-0), t_1]$. $(1)$

  For any non-leaf node $n_i in p a t h(d)$, when $d$ finishes its *node-$n_i$-refresh phase* at $t_(r\-i)$, there's at least one successful `refreshNode` call during this phase. Suppose this `refreshNode` call starts and ends at $t_(s t a r t \- i)$ and $t_(e n d\-i)$. Suppose $r a n k(n_(i-1), t) eq.not r$ for $t in [t_(r\-(i-1)), t_1]$. By the way `refreshNode` is defined after this `refreshNode` call, $n_i$ will store some rank other than $r$. Because of $(1)$, after this up until $t_1$, $r$ never has a chance to be visible to a `refreshNode` on node $n_i$ during $[n_(i-1), t]$. In other words, $r a n k(n_i, t) eq.not r$ for $t in [t_(r\-i), t_1]$.

  By induction, we obtain the theorem.
]

#theorem[
  All of dLTQueue's complete histories do not have the `VFresh` violation.
] <theo:dltqueue-vfresh>

#proof[
  Notice that the dequeuer dequeues by first reading the root node's rank and then returns a value by dequeuing from the local SPSC of the corresponding enqueuer. Suppose the SPSC is linearizable, the dequeued value must first be enqueued by some enqueuer. The theorem holds.
]

#theorem[
  All of dLTQueue's complete histories do not have the `VRepet` violation.
] <theo:dltqueue-vrepet>

#proof[
  The dequeuer dequeues by dequeuing from the local SPSC of some enqueuer. If two dequeues are dequeuing from two different local SPSC, there's no way for two dequeues to dequeue a value twice. Suppose the SPSC is linearizable, the same statement holds true for when the two dequeues are dequeuing from the same local SPSC. The theorem holds.
]

#theorem[
  All of dLTQueue's complete histories do not have the `VOrd` violation.
] <theo:dltqueue-vord>

#proof[
  Consider a complete history c and two enqueues $e_1$, $e_2$ such that $e_1$ precedes $e_2$.
  Because $e_1$ precedes $e_2$, its timestamp $c_1$ must be strictly smaller than $e_2$'s timestamp $c_2$. Suppose $e_1$ finishes at time $t_0$ and is still unmatched at time $t_1$. Then, by @ltqueue-unmatched-enqueue-corollary, for any subrange $T$ of $[t_0, t_1]$, for any $t_r, t_s in T$:
  $ m i n\- s p s c \- t s(r a n k(r o o t, t_r), t_s) <= c_1 < c_2 $ <eq1>
  Therefore, before $e_1$ is matched, there's no chance the root node can refer to $e_2$. It follows that $e_1$ must be matched before $e_2$. The theorem holds.
]

#theorem[
  All of dLTQueue's complete histories do not have the `VWit` violation.
] <theo:dltqueue-vwit>

#proof[
  Formally, we will prove that there doesn't exist an unmatched dequeue $d$ and a finished unmatched enqueue $e$ by the time $d$ starts.

  The only way for a dequeue to return `false` is for it to read out a `DUMMY` rank from the root node. If there's a finished unmatched enqueue by the time a dequeue starts, the root node must store a non-`DUMMY` rank, by @ltqueue-unmatched-enqueue-theorem. Therefore, the theorem holds.
]

#theorem[
  dLTQueue is wait-free.
] <theo:dltqueue-wait-free>

#proof[
  This is trivial, as dLTQueue never enters a loop.
]

#theorem[
  dLTQueue is linearizable.
] <theo:dltqueue-linearizable>

#proof[
  This follows directly from @theo:mpsc-linearizable, @theo:dltqueue-vfresh, @theo:dltqueue-vrepet, @theo:dltqueue-vord, @theo:dltqueue-vwit and @theo:dltqueue-wait-free.
]

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


