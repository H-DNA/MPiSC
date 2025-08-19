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


