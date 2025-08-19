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

== Theoretical proofs of Slotqueue

In this section, we provide proofs covering all of our interested theoretical aspects in Slotqueue.

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

This section establishes the correctness of Slotqueue introduced in @slotqueue.

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

  If $t_d = t_e =$ `MAX_TIMESTAMP`, this means $e$ observes a value of `MAX_TIMESTAMP` before $d$ even sets `s` to `MAX_TIMESTAMP` due to $(*)$. If this `MAX_TIMESTAMP` value is the initialized value of `s`, it is a contradiction, as `s` must be non-`MAX_TIMESTAMP` at some point for a dequeue such as $d$ to enter its CAS sequence. If this `MAX_TIMESTAMP` value is set by an enqueue, it is also a contradiction, as `refreshEnqueue` cannot set a slot to `MAX_TIMESTAMP`. Therefore, this `MAX_TIMESTAMP` value is set by a dequeue $d'$. If $d' != d$ then it is a contradiction, because between $d'$ and $d$, `s` must be set to be a non-`MAX_TIMESTAMP` value before $d$ can be run, thus, $e$ cannot have observed a value set by $d'$. Therefore, $d' = d$. But, this means $e$ observes a value set by $d$, which violates our assumption $(*)$.

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

We assume all enqueues succeed in this section. Note that a failed enqueue only causes the counter to increment, and does not change the queue state in any other ways.

#lemma[
  Only the dequeuer and the enqueuer with rank $r$ can concurrently modify an SPSC and the slot at the $r$-th index in the `Slots` array.
] <lemm:exclusive-access>

#proof[
  This lemma is trivial based on how the algorithm is defined.
]

#lemma[
  Each SPSC in Slotqueue contains elements with increasing timestamps.
] <lemm:monotonic-SPSC>

#proof[
  Each enqueue would fetch-and-add the distributed counter
  and enqueue into the local SPSC an item with the timestamp obtained from the
  counter. Applying @lemm:exclusive-access, we know that items are enqueued one at a
  time into the SPSC. Therefore, later items are enqueued by strictly later enqueues, which
  obtain increasing timestamps. The lemma holds.
]

#lemma[
  If an enqueue $e$ begins its slot-refresh phase at time $t_0$ and finishes at time $t_1$, there's always at least one successful `refresh_enqueue` or `refresh_dequeue` on $r a n k(e)$ that starts and ends its CAS sequence between $t_0$ and $t_1$.
] <lemm:refresh-enqueue>

#proof[
  If one of the two `refresh_enqueue`s of $e$ succeeds, then the lemma obviously
  holds. Consider the case where both fail.

  The first `refresh_enqueue` fails because it tries to execute its CAS sequence but
  there's another `refresh_dequeue` executing its slot modification instruction successfully during the first `refresh_enqueue`'s CAS sequence.

  The second `refresh_enqueue` fails because it tries to execute its CAS sequence but
  there's another `refresh_dequeue` executing its slot modification instruction successfully during the second `refresh_enqueue`'s CAS sequence. This another `refresh_dequeue` must start its CAS sequence after the end of the first
  successful `refresh_dequeue`, which is after $t_0$, because there is only one dequeuer, and must end before $t_1$, because its slot modification instruction takes places during the second `refresh_enqueue`'s CAS sequence. In other words, this another `refresh_dequeue` starts and successfully ends its CAS sequence between $t_0$ and $t_1$.
]

#lemma[
  If an enqueue $d$ begins its slot-refresh phase at time $t_0$ and finishes at time $t_1$, there's always at least one successful `refresh_enqueue` or `refresh_dequeue` on $r a n k(d)$ that starts and ends its CAS sequence between $t_0$ and $t_1$.
] <lemm:refresh-dequeue>

#proof[
  This lemma is similar to the above lemma.
]

#lemma[
  Given a rank $r$, if a successful enqueue $e$ on $r$ obtains the timestamp $c$ completes at $t_0$ and is still unmatched by $t_1 > t_0$, then $s l o t(r, t) <= c$ for any $t in [t_0, t_1]$.
] <lemm:unmatched-enqueue>

#proof[
  Because the underlying SPSC queue is linearizable, take $t' < t_0$ to be the time $e$'s `spsc_enqueue` completes successfully. Because $e$ is still unmatched until $t_1$, the timestamp $c$ must be in the underlying SPSC at any time $t in [t', t_1]$. Therefore, due to @lemm:monotonic-SPSC, any `spsc_readFront` on rank $r$'s SPSC queue during $[t', t_1]$ must read out a value not greater than $c$. Consequently, any successful refresh call (`refresh_enqueue` or `refresh_dequeue`) during $[t', t_1]$ must set the slot to some value not greater than $c$. $(1)$

  At some time after $t'$ and before $t_0$, $e$ must enter its slot-refresh phase. Due to @lemm:refresh-enqueue, there must be a successful refresh call during $[t', t_0]$. $(2)$

  From $(1)$ and $(2)$, $s l o t(r, t) <= c$ for any $t in [t_0, t_1]$.
]

#theorem[
  Any complete history $h$ of Slotqueue does not have the `VFresh` violation.
]

#proof[
  Consider a complete history $h$. Suppose in $h$, there exists a dequeue event that returns `true` at time $t$ but no enqueue event matches it at time $t$. For a dequeue event to return `true`, its call to `spsc_dequeue` must return true. Because the SPSC is linearizable, this dequeue must match some `spsc_enqueue` to this SPSC, which is called by some enqueue. Therefore, this dequeue event must match some enqueue event, a contradiction. The theorem holds.
]

#theorem[
  Any complete history $h$ of Slotqueue does not have the `VRepet` violation.
]

#proof[
  Consider a complete history $h$. Suppose in $h$, there exists an enqueue event $e$ that matches two dequeue events $d_1$, $d_2$ at some time $t$. This can only happen if $d_1$ and $d_2$ both target the same SPSC as $e$. However, because the SPSC is linearizable, both calls of $d_1$ and $d_2$ to `spsc_dequeue` must match different `spsc_enqueue` calls by different `enqueue`s. Therefore, this is a contradiction. The theorem holds.
]

#theorem[
  Any complete history $h$ of Slotqueue does not have the `VOrd` violation.
]

#proof[
  Consider a complete history $h$. Suppose at some time $t$, there exist enqueue events $e_1$, $e_2$ such that $e_1 prec_h e_2$, $e_2$ matches $d_2$ at time $t$ but $e_1$ is unmatched at time $t$.

  Because $e_1 prec_h e_2$, $e_1$ obtains a timestamp smaller than $e_2$.

  If $e_1$ and $e_2$ target the same slot, due to the underlying SPSC being linearizable and $e_1 prec_h e_2$, $d_2$ cannot match $e_2$ while $e_1$ is still unmatched.

  Note that $d_2$'s slot-scan phase involves 2 scans.



  Suppose $e_1$ targets the slot at a lower rank than $e_2$'s slot. If $d_2$ finds $e_2$ in the first scan, then in the second scan, because $e_1 prec_h e_2$, $d_2$ would have seen and prioritized $e_1$'s timestamp, which is a contradiction. Therefore, $d_2$ must have found $e_2$ in the second scan. Suppose during the first scan, it finds $e' != e_2$. Then, $e'$'s timestamp is larger than $e_2$'s. Because during the second scan, $e_1$ is not chosen, its slot-refresh phase must finish after $e'$'s, which already finishes in the first scan. Because $e_1 prec_h e_2$, $e_2$ must start after $e'$ slot-refresh phase, so it must obtain a larger timestamp than $e'$, which is a contradiction.

  The theorem holds.
]

#theorem[
  Any complete history $h$ of Slotqueue does not have the `VWit` violation.
]

#proof[
  Consider a complete history $h$. Suppose there exists a dequeue $d$ starting
  at time $t$ and returning `false` but there is an enqueue $e$ that finishes before $t$ and is still unmatched at $t$.

  By @lemm:unmatched-enqueue, some slot must contain a timestamp other than `MAX_TIMESTAMP` by $t$. Therefore, when $d$ performs the slot-scan phase in `read_minimum_rank`, it must see this slot containing a non-`MAX_TIMESTAMP` and return a non-`DUMMY_RANK`. Consequently, $d$ cannot return `false` on line 10.

  We claim that inside a dequeue, before the `spsc_dequeue` on line 11, if a slot contains a non-`MAX_TIMESTAMP`, the corresponding SPSC cannot be empty. Consider the successful slot refresh call with the last slot modification instruction targeted at this slot before the `spsc_dequeue` on line 11. Because this slot refresh call sets the slot to non-`MAX_TIMESTAMP`, its `spsc_readFront` must see that the SPSC is non-empty (line 30). From the last refresh call to the current `spsc_dequeue` on line 11, no other `spsc_dequeue` can happen, so this SPSC cannot be empty when line 11 is reached. Therefore, it can never return `false` on line 12.

  In conclusion, $d$ cannot return `false`, a contradiction. The theorem holds.
]

From the previous theorems, this theorem trivially holds.
#theorem[
  Slotqueue is linearizable.
]

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
