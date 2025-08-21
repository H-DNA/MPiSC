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

== dLTQueueV2 <dLTQueue-v2>

The structure of dLTQueueV2 is the same as in dLTQueue. There are two key differences from dLTQueue:
- The `min-timestamp` variables are no longer hosted on the enqueuers, but on the sole dequeuer. This helps bring the number of remote operations of the dequeue operation to a constant number.
- The enqueuer only performs the propagation procedure when its enqueued item is the only item in the local SPSC queue. This avoids unnecessary propogations in most cases, which help bring the number of remote operations of the enqueue operation to a constant number most of the time.

The new enqueuer process is presented in @ltqueue-v2-enqueue. Otherwise, dLTQueueV2 is similar to dLTQueue, as in @dLTQueue.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i,
    booktabs: true,
    numbered-title: [`bool enqueue(data_t value)`],
  )[
    + #line-label(<line-ltqueue-v2-enqueue-obtain-timestamp>) `timestamp = faa(Counter, 1)                                            `
    + #line-label(<line-ltqueue-v2-enqueue-insert>) *if* `(!spsc_enqueue(&Spsc, (value, timestamp)))`
      + #line-label(<line-ltqueue-v2-enqueue-failure>) *return* `false`
    + #line-label(<line-ltqueue-v2-init-front>) `front = (data_t {}, timestamp_t {})`
    + #line-label(<line-ltqueue-v2-read-front>) `is_empty = !spsc_readFront(Spsc, &front)`
    + #line-label(<line-ltqueue-v2-should-skip-read-front>) *if* `(!is_empty && front.timestamp.value != timestamp)`
      + #line-label(<line-ltqueue-v2-enqueue-success-short-path>) *return* `true`
    + #line-label(<line-ltqueue-v2-enqueue-propagate>) `propagate`#sub(`e`)`()`
    + #line-label(<line-ltqueue-v2-enqueue-success>) *return* `true`
  ],
) <ltqueue-v2-enqueue>

@ltqueue-v2-enqueue, compared to @ltqueue-enqueue, adds a small check on line @line-ltqueue-v2-init-front - @line-ltqueue-v2-enqueue-success-short-path. This check reads the front element (@line-ltqueue-v2-read-front) and compares its timestamp with the enqueued timestamp (@line-ltqueue-v2-should-skip-read-front). If they are equal, then the propagation process can be safely skipped (@line-ltqueue-v2-enqueue-success-short-path).
