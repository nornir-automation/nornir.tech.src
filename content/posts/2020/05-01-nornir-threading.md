---
title: "how many threads are enough threads?"
date: "2020-05-01"
tags: ["nornir", "gornir"]
---

The other night there was a discussion about python multi-threading on the nornir channel on [slack](https://networktocode.herokuapp.com/) so I decided to do some benchmarks and explain a couple of things. I am by no means an expert on the topic, I mostly know enough to be scared about the topic and to test assumptions to avoid surprises. I am also going to try to simplify things a bit so apologies in advanced if something is slightly inaccurate. Feel free to let me know if you think something needs further explanation or clarification.

The first thing you need to know is what a thread is, according to the [wikipedia](https://en.wikipedia.org/wiki/Thread_(computing)) "a thread of execution is the smallest sequence of programmed instructions that can be managed independently by a scheduler, which is typically a part of the operating system". The TL;DR; is that a thread is something you can put on a CPU core to be executed. Threads are somewhat expensive to create and manage as the OS needs to maintain several datastructures and run complex [algorithms](https://en.wikipedia.org/wiki/Scheduling_(computing)) so an alternative to threads are [coroutines](https://en.wikipedia.org/wiki/Coroutine). Coroutines offer similar functionality to OS threads but are managed by a runtime instead of by the operating system and are much more lightweight than OS threads. You probably heard about asyncio or golang's goroutines, those are examples of coroutine implementations.

Second thing you need to know is you can only run as many threads concurrently as cores you have available (twice with technologies like hyperthreading), however, computers have mechanisms to put threads in an idle state while waiting for some event to occur. For instance, if a python program runs `time.sleep(1)` it's going to go into this state for 1 second, during that second the program won't consume any CPU, and, when the time comes, the program will be woken up and resume operations. This same technique can be used when waiting for IO operations, for instance, when trying to read/write to disk or when waiting for the network to send you some information. Because those operations are several orders of magnitude slower than executing CPU instructions it is worth trying to parallelize as many of those operations as possible. If you have heard the term "IO-bound program", this is a summary of what it means.

## Testing assumptions

Now that we are experts on CPU design and have read all the research ever written around the topic of schedulers, let's design a simple test; we are going to simulate an IO-bound application by pretending we are going to connect to 10.000 devices. The application won't really connect to any device, instead it will just go to sleep for a given amount of time. This time we are sleeping should simulate RTT.

Note that this is a very simple test and doesn't really consume the same resources that a program connecting to real devices would consume (sockets, file descriptors, etc), resources that would add up and could cause side-effects, specially if you run the code on a shared machine. Quoting your favorite physics teacher ["this only works in the vacuum with no friction"](https://xkcd.com/669/)

Some of the things I want to see with the tests we are going to perform is:

1. How does RTT affect the execution of the program
2. How many threads are worth creating given they are expensive to create and manage under different RTTs
3. How helpful coroutines are, are they a fad or do they solve an actual problem?

### Counting threads with nornir

To see how many is worth using when attempting to parallelize the connection to 10.000 devices using different RTTs we are going to use `nornir`. A continuation you can see the script (note it's using a beta version of nornir 3.0 so it might not work out of the box if you try to execute it with nornir 2.0, however, it shouldn't affect performance):


``` python
import sys
import time

from nornir import InitNornir
from nornir.core.inventory import Defaults, Groups, Hosts,
                                  Host, Inventory
from nornir.core.plugins.inventory import InventoryPluginRegister
from nornir.core.task import Task


NUM_DEVICES = 10000


class TestInv:
    """
    Fake inventory that generates hosts dynamically
    """

    def load(self) -> Inventory:
        hosts = Hosts()
        for i in range(0, NUM_DEVICES):
            name = f"dev{i}"
            hosts[name] = Host(name)
        return Inventory(
          hosts=hosts, groups=Groups(), defaults=Defaults()
        )


def fake_task(task: Task, sleep_time: float) -> None:
    """
    fake task that simulates RTT
    """
    time.sleep(sleep_time)


def main(num_workers: int, sleep_time: float) -> None:
    InventoryPluginRegister.register("test-inv", TestInv)

    nr = InitNornir(
      inventory={"plugin": "test-inv"},
      core={"num_workers": num_workers},
    )
    nr.run(task=fake_task, sleep_time=sleep_time)


if __name__ == "__main__":
    num_workers = int(sys.argv[1])
    sleep_time = float(sys.argv[2])
    main(num_workers, sleep_time)
```

Great, now let's see the results of running this with different parameters. First, with an RTT of 50ms:

```
python script.py 100 0.05  0.78s user 0.29s system 19% cpu 5.532 total
python script.py 200 0.05  0.79s user 0.34s system 39% cpu 2.854 total
python script.py 500 0.05  0.65s user 0.37s system 73% cpu 1.389 total
python script.py 1000 0.05  0.81s user 0.37s system 118% cpu 0.995 total
python script.py 1500 0.05  0.73s user 0.48s system 125% cpu 0.969 total
python script.py 2000 0.05  0.78s user 0.47s system 125% cpu 0.993 total
python script.py 5000 0.05  0.78s user 0.47s system 126% cpu 0.987 total
python script.py 10000 0.05  0.82s user 0.37s system 123% cpu 0.962 total
```

Now, with an RTT of 100ms:

```
python script.py 100 0.1  0.77s user 0.30s system 10% cpu 10.551 total
python script.py 200 0.1  0.75s user 0.32s system 19% cpu 5.424 total
python script.py 500 0.1  0.79s user 0.35s system 47% cpu 2.376 total
python script.py 1000 0.1  0.82s user 0.35s system 84% cpu 1.391 total
python script.py 1500 0.1  0.86s user 0.56s system 119% cpu 1.192 total
python script.py 2000 0.1  0.89s user 0.62s system 128% cpu 1.177 total
python script.py 5000 0.1  0.89s user 0.84s system 136% cpu 1.266 total
python script.py 10000 0.1  1.08s user 0.74s system 140% cpu 1.292 total
```

A continuation with 300ms:

```
python script.py 100 0.3  0.82s user 0.24s system 3% cpu 31.016 total
python script.py 200 0.3  0.74s user 0.27s system 6% cpu 15.381 total
python script.py 500 0.3  0.75s user 0.30s system 16% cpu 6.360 total
python script.py 1000 0.3  0.73s user 0.38s system 33% cpu 3.354 total
python script.py 1500 0.3  0.82s user 0.42s system 50% cpu 2.460 total
python script.py 2000 0.3  0.94s user 0.42s system 67% cpu 2.004 total
python script.py 5000 0.3  1.15s user 1.28s system 154% cpu 1.575 total
python script.py 10000 0.3  1.14s user 1.04s system 141% cpu 1.535 total
```

And finally, with an RTT of 1s, just because reasons:

```
python script.py 100 1  0.70s user 0.28s system 0% cpu 1:40.55 total
python script.py 200 1  0.75s user 0.19s system 1% cpu 50.445 total
python script.py 500 1  0.64s user 0.30s system 4% cpu 20.335 total
python script.py 1000 1  0.77s user 0.28s system 10% cpu 10.360 total
python script.py 1500 1  0.73s user 0.39s system 15% cpu 7.364 total
python script.py 2000 1  0.86s user 0.37s system 22% cpu 5.507 total
python script.py 5000 1  1.04s user 0.79s system 60% cpu 3.005 total
python script.py 10000 1  1.43s user 1.11s system 97% cpu 2.598 total
```

As you can see latency has a huge impact. If latency is low (~50ms), the cost of creating a large amount of threads is relatively high compared to the time each thread is idle so going from 200 threads to 500 threads doesn't gain you a lot but it increase CPU consumption by 34%. With a latency of 100ms you can see the same effect going from 500 to 1000 threads. With 300 ms of latency there isn't a massive spike but you certainly don't gain much beyond 1000 threads. As a bonus, with a fake RTT of 1s you can see the sweet spot is around 1000 threads too, however, CPU is proportionally lower to the RTT, which makes sense as you are doing the same work over a longer period of time.


## Coroutines to the rescue

At the time of writing this post `nornir` doesn't have support for `asyncio` (even though there has been some proposals and even some working code, if you are interested in seeing this happen reach out to me). Instead, we are going to use `gornir` to perform the same tests as before but using coroutines instead (or `goroutines` as they are called in `golang`). First the code:


``` go
package main

import (
	"context"
	"flag"
	"fmt"
	"time"

	"github.com/nornir-automation/gornir/pkg/gornir"
	"github.com/nornir-automation/gornir/pkg/plugins/logger"
	"github.com/nornir-automation/gornir/pkg/plugins/runner"
)

func FakeInv() gornir.Inventory {
	hosts := make(map[string]*gornir.Host)
	for i := 0; i < 10000; i++ {
		name := fmt.Sprintf("dev%d", i)
		hosts[name] = &gornir.Host{Hostname: name}
	}
	return gornir.Inventory{
		Hosts: hosts,
	}
}

type fakeRTT struct {
	rtt time.Duration
}

func (t *fakeRTT) Metadata() *gornir.TaskMetadata { return nil }

func (t *fakeRTT) Run(ctx context.Context, logger gornir.Logger, host *gornir.Host) (gornir.TaskInstanceResult, error) {
	time.Sleep(t.rtt)
	return nil, nil
}

func main() {
	rtt := flag.Duration("fake-rtt", time.Millisecond, "")
	flag.Parse()

	log := logger.NewLogrus(false)

	gr := gornir.New().WithInventory(FakeInv()).WithLogger(log).WithRunner(runner.Parallel())

	_, err := gr.RunSync(
		context.Background(),
		&fakeRTT{rtt: *rtt},
	)
	if err != nil {
		log.Fatal(err)
	}
}
```

Before moving forward, some explanations of how multi-threading/coroutines work here:

1. For each device `gornir` is going to create a coroutine
2. The golang runtime is going to create as many threads as `GOMAXPROCS` indicates, by default the number of cores. These threads will be used to run the scheduler, the garbage collector, each coroutine, etc...

First we need to compile it:

```
$ go build -o fakertt-test main.go
```

If you haven't dealt with golang before, yes, it's that easy :) Now let's run it with the default number of threads for an RTT of 50ms:

```
./fakertt-test -fake-rtt 50ms  0.16s user 0.04s system 185% cpu 0.111 total
```

As you can see with the default number of threads (one per core) and using coroutines we managed to squeeze the CPU and execute the program in 111ms, barely more than twice the RTT we set. Let's see with only one thread:


```
GOMAXPROCS=1 ./fakertt-test -fake-rtt 50ms  0.09s user 0.03s system 74% cpu 0.158 total
```

CPU is now down to 74% and the application took 158ms, not bad. Let's now try with 100 threads:

```
GOMAXPROCS=100 ./fakertt-test -fake-rtt 50ms  0.15s user 0.12s system 187% cpu 0.139 total
```

Unsurprisingly, it took longer than using only one per core while consuming the same amount of CPU.

Let's do similar tests with higher latency, now with 100ms:

```
./fakertt-test -fake-rtt 100ms  0.12s user 0.11s system 144% cpu 0.160 total
GOMAXPROCS=1 ./fakertt-test -fake-rtt 100ms  0.10s user 0.03s system 62% cpu 0.208 total
GOMAXPROCS=100 ./fakertt-test -fake-rtt 100ms  0.19s user 0.13s system 168% cpu 0.192 total
```

We got similar results, CPU went down and execution time went up proportionally to the increase in RTT. Now let's try with 300ms of RTT:

```
./fakertt-test -fake-rtt 300ms  0.13s user 0.08s system 57% cpu 0.363 total
GOMAXPROCS=1 ./fakertt-test -fake-rtt 300ms  0.10s user 0.02s system 29% cpu 0.425 total
GOMAXPROCS=100 ./fakertt-test -fake-rtt 300ms  0.15s user 0.14s system 74% cpu 0.387 total
```

Which lead to similar results, and finally with 1s of RTT:

```
./fakertt-test -fake-rtt 1s  0.17s user 0.05s system 19% cpu 1.071 total
GOMAXPROCS=1 ./fakertt-test -fake-rtt 1s  0.08s user 0.05s system 11% cpu 1.121 total
GOMAXPROCS=100 ./fakertt-test -fake-rtt 1s  0.14s user 0.13s system 25% cpu 1.078 total
```

And again, consistent results.


It is worth noting that, as we saw in python (although several orders of magnitude different), the relative cost of creating threads diminishes as RTT increases. This makes sense as creating a thread is orders of magnitude faster than crossing the Atlantic. It is also worth noticing how CPU utilization goes down with RTT, which makes sense as well as the same amount of work is spread across a longer period of time.

It is also worth noting how efficient golang with its goroutines is. In all cases the software took barely a bit longer than the RTT to complete, squeezing the CPU as much as possible.

## Summary

Threads are great for parallelizing work and you can certainly create more than CPU cores you have, specially for IO-bound applications, however, they are not free, they have a cost. Coroutines help immensely lowering this cost but, specially in programming languages like python, having access to coroutines isn't trivial.

This post is not trying to convince you that using a high number of threads is bad, on the contrary, it's trying to encourage you to understand how computers work, your workload, and the environment you are running your code on as the same workload under different circumstances (different resources available, different latency, etc) may cause our application to behave differently.
