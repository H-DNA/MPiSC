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

== Theoretical proofs of the distributed SPSC

In this section, we focus on the correctness and progress guarantee of the simple distributed SPSC established in @distributed-spsc.

=== Correctness

This section establishes the correctness of our distributed SPSC.

==== ABA problem

There is no CAS instruction in our simple distributed SPSC, so there's no potential for ABA problem.

==== Memory reclamation

There is no dynamic memory allocation and deallocation in our simple distributed SPSC, so it is memory-safe.

==== Linearizability

We prove that our simple distributed SPSC is linearizable.

#theorem(
  name: "Linearizability of the simple distributed SPSC",
)[The distributed SPSC given in @distributed-spsc is linearizable.] <spsc-linearizability-theorem>

#proof[
  We claim that the following are the linearization points of our SPSC's methods:
  - The linearization point of an `spsc_enqueue` call (@spsc-enqueue) that returns `false` is @line-spsc-enqueue-resync-first.
  - The linearization point of an `spsc_enqueue` call (@spsc-enqueue) that returns `true` is @line-spsc-enqueue-increment-last.
  - The linearization point of an `spsc_dequeue` call (@spsc-dequeue) that returns `false` is @line-spsc-dequeue-resync-last.
  - The linearization point of an `spsc_dequeue` call (@spsc-dequeue) that returns `true` is @line-spsc-dequeue-swing-first.
  - The linearization point of `spsc_readFront`#sub(`e`) call (@spsc-enqueue-readFront) that returns `false` is @line-spsc-e-readFront-empty-once or @line-spsc-e-readFront-resync-first if @line-spsc-e-readFront-empty-once is passed.
  - The linearization point of `spsc_readFront`#sub(`e`) call (@spsc-enqueue-readFront) that returns `true` is @line-spsc-e-readFront-resync-first.
  - The linearization point of `spsc_readFront`#sub(`d`) call (@spsc-dequeue-readFront) that returns `false` is @line-spsc-d-readFront-resync-last.
  - The linearization point of `spsc_readFront`#sub(`d`) call (@spsc-dequeue-readFront) that returns `true` is right after @line-spsc-d-readFront-resync-last or right before @line-spsc-d-readFront-read if @line-spsc-d-readFront-resync-last is never executed.

  We define a total ordering $<$ on the set of completed method calls based on these linearization points: If the linearization point of a method call $A$ is before the linearization point of a method call $B$, then $A < B$.

  If the distributed SPSC is linearizable, $<$ would define a equivalent valid sequential execution order for our SPSC method calls.

  A valid sequential execution of SPSC method calls would possess the following characteristics.

  _An enqueue can only be matched by one dequeue_: Each time an `spsc_dequeue` is executed, it advances the `First` index. Because only one dequeue can happen at a time, it is guaranteed that each dequeue proceeds with one unique `First` index. Two dequeues can only dequeue out the same entry in the SPSC's array if their `First` indices are congurent modulo `Capacity`. However, by then, this entry must have been overwritten. Therefore, an enqueue can only be dequeued at most once.

  _A dequeue can only be matched by one enqueue_: This is trivial, as based on how @spsc-dequeue is defined, a dequeue can only dequeue out at most one value.

  _The order of item dequeues is the same as the order of item enqueues_: To put more precisely, if there are 2 `spsc_enqueue`s $e_1$, $e_2$ such that $e_1 < e_2$, then either $e_2$ is unmatched or $e_1$ matches $d_1$ and $e_2$ matches $d_2$ such that $d_1 < d_2$. If $e_2$ is unmatched, the statement holds. Suppose $e_2$ matches $d_2$. Because $e_1 < e_2$, based on how @spsc-enqueue is defined, $e_1$ corresponds to a value $i_1$ of `Last` and $e_2$ corresponds to a value $i_2$ of `Last` such that $i_1 < i_2$. Based on how @spsc-dequeue is defined, each time a dequeue happens successfully, `First` would be incremented. Therefore, for $e_2$ to be matched, $e_1$ must be matched first because `First` must surpass $i_1$ before getting to $i_2$. In other words, $e_1$ matches $d_1$ such that $d_1 < d_2$.

  _An enqueue can only be matched by a later dequeue_: To put more precisely, if an `spsc_enqueue` $e$ matches an `spsc_dequeue` $d$, then $e < d$. If $e$ hasn't executed its linearization point at @line-spsc-enqueue-increment-last, there's no way $d$'s @line-spsc-dequeue-read can see $e$'s value. Therefore, $d$'s linearization point at @line-spsc-dequeue-swing-first must be after $e$'s linearization point at @line-spsc-enqueue-increment-last. Therefore, $e < d$.

  _A dequeue would return `false` when the queue is empty_: To put more precisely, for an `spsc_dequeue` $d$, if by $d$'s linearization point, every successful `spsc_enqueue` $e'$ such that $e' < d$ has been matched by $d'$ such that $d' < d$, then $d$ would be unmatched and return `false`. By this assumption, any `spsc_enqueue` $e$ that has executed its linearization point at @line-spsc-enqueue-increment-last before $d$'s @line-spsc-dequeue-empty-once has been matched. Therefore, `First = Last` at @line-spsc-dequeue-empty-once, or `First >= Last_buf`, therefore, the if condition at @line-spsc-dequeue-empty-once - @line-spsc-dequeue-empty is entered. Also by the assumption, any `spsc_enqueue` $e$ that has executed its linearization point at @line-spsc-enqueue-increment-last before $d$'s @line-spsc-dequeue-empty-twice has been matched. Therefore, `First = Last` at @line-spsc-dequeue-empty-twice. Then, @line-spsc-dequeue-empty is executed and $d$ returns `false`.

  _A dequeue would return `true` and match an enqueue when the queue is not empty_: To put more precisely, for an `spsc_dequeue` $d$, if there exists a successful `spsc_enqueue` $e'$ such that $e' < d$ and has not been matched by a dequeue $d'$ such that $d' < e'$, then $d$ would be match some $e$ and return `true`. By this assumption, some $e'$ must have executed its linearization point at @line-spsc-enqueue-increment-last but is still unmatched by the time $d$ starts. Then, `First < Last`, so $d$ must match some enqueue $e$ and returns `true`.

  _An enqueue would return `false` when the queue is full_: To put more precisely, for an `spsc_enqueue` $e$, if by $e$'s linearization point, the number of unmatched successful `spsc_enqueue` $e' < e$ by the time $e$ starts equals `Capacity`, then $e$ returns `false`. By this assumption, any $d'$ that matches $e'$ must satisfy $e < d'$, or $d'$ must execute its synchronization point at @line-spsc-dequeue-swing-first after @line-spsc-enqueue-new-last and @line-spsc-enqueue-diff-cache-twice of $e$, then $e$'s @line-spsc-enqueue-full must have executed and return `false`.

  _An enqueue would return `true` when the queue is not full and the number of elements should increase by one_: To put more precisely, for an `spsc_enqueue` $e$, if by $e$'s linearization point, the number of unmatched successful `spsc_enqueue` $e' < e$ by the time $e$ starts is fewer than `Capacity`, then $e$ returns `true`. By this assumption, `First < Last` at least until $e$'s linearization point and because @line-spsc-enqueue-increment-last must be executed, which means the number of elements should increase by one.

  _A read-front would return `false` when the queue is empty_: To put more precisely, for a read-front $r$, if by $r$'s linearization point, every successful `spsc_enqueue` $e'$ such that $e' < r$ has been matched by $d'$ such that $d' < r$, then $r$ would return `false`. That means any unmatched successful `spsc_enqueue` $e$ must have executed its linearization point at @line-spsc-enqueue-increment-last after $r$'s, or `First = Last` before $r$'s linearization point
  - For an enqueuer's read-front, if $r$ doesn't pass @line-spsc-e-readFront-diff-cache-once, the statement holds. If $r$ passes @line-spsc-e-readFront-diff-cache-once, by the assumption, $r$ would execute @line-spsc-e-readFront-empty-twice, because $r$ sees that `First = Last`.
  - For a dequeuer's read-front, $r$ must enter @line-spsc-d-readFront-resync-last because `First_buf >= Last_buf`, which is due to from the dequeuer's point of view, `First_buf = First` and `Last_buf <= Last`. Similarly, $r$ must execute @line-spsc-d-readFront-empty and return `false`.

  _A read-front would return `true` and the first element in the queue is read out_: To put more precisely, for a read-front $r$, if before $r$'s linearization point, there exists some unmatched successful `spsc_enqueue` $e'$ such that $e' < r$, then $r$ would read out the same value as the first $d$ such that $r < d$. By this assumption, any $d'$ that matches some of these successful `spsc_enqueue` $e'$ must execute its linearization point at @line-spsc-dequeue-swing-first after $r$'s linearization point. Therefore, `First < Last` until $r$'s linearization point.
  - For an enqueuer's read-front, $r$ must not execute @line-spsc-e-readFront-empty-once and @line-spsc-e-readFront-empty-twice. Therefore, @line-spsc-e-readFront-read is executed, and `First_buf` at this point is the same as `First_buf` of the first $d$ such that $r < d$, because we have just read it at @line-spsc-e-readFront-resync-first, and any successful $d' > r$ must execute @line-spsc-dequeue-swing-first after @line-spsc-e-readFront-read, therefore, `First` has no chance to be incremented between @line-spsc-e-readFront-resync-first and @line-spsc-e-readFront-read.
  - For a dequeuer's read-front, $r$ must not execute @line-spsc-d-readFront-resync-last - @line-spsc-d-readFront-empty and execute @line-spsc-d-readFront-read instead. It's trivial that $r$ reads out the same value as the first dequeue $d$ such that $r < d$ because there can only be one dequeuer.

  In conclusion, for any completed history of method calls our SPSC can produce, we have defined a way to sequentially order them in a way that conforms to SPSC's sequential specification. Therefore, our SPSC is linearizable.
]

=== Progress guarantee

Our simple distributed SPSC is wait-free:
- `spsc_dequeue` (@spsc-dequeue) does not execute any loops or wait for any other method calls.
- `spsc_enqueue` (@spsc-enqueue) does not execute any loops or wait for any other method calls.
- `spsc_readFront`#sub(`e`) (@spsc-enqueue-readFront) does not execute any loops or wait for any other method calls.
- `spsc_readFront`#sub(`d`) (@spsc-dequeue-readFront) does not execute any loops or wait for any other method calls.

=== Theoretical performance

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


