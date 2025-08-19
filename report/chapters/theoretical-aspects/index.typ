= Theoretical aspects <theoretical-aspects>

This section discusses the correctness and progress guarantee properties of the distributed MPSC queue algorithms introduced in @distributed-queues[]. We also provide a theoretical performance model of these algorithms to predict how well they scale to multiple nodes.

#include "prologue.typ"
#include "spsc.typ"
#include "dltqueue.typ"
#include "slotqueue.typ"
