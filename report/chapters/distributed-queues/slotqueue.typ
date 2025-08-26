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

== Slotqueue - dLTQueue-inspired distributed MPSC queue with all constant-time operations <slotqueue>

The straightforward dLTQueue algorithm we have ported in @dLTQueue pretty much preserves the original algorithm's characteristics, i.e. wait-freedom and time complexity of $Theta(log n)$ for `dequeue` and `enqueue` operations. We note that in shared-memory systems, this logarithmic growth is fine. However, in distributed systems, this increase in remote operations would present a bottleneck in enqueue and dequeue latency. Upon closer inspection, this logarithmic growth is due to the propagation process because it has to traverse every level in the tree. Intuitively, this is the problem of us trying to maintain the tree structure. Therefore, to be more suitable for distributed context, we propose a new algorithm Slotqueue inspired by LTQueue, which uses a slightly different structure. The key point is that both `enqueue` and `dequeue` only perform a constant number of remote operations, at the cost of `dequeue` having to perform $Theta(n)$ local operations, where $n$ is the number of enqueuers. Because remote operations are much more expensive, this might be a worthy tradeoff.

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
