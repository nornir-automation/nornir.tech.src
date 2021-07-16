---
title: "SALTSTACK Nornir Proxy Minion introduction"
date: "2021-07-16"
tags: ["nornir", "SALTSTACK", "SALT", "guest"]
---

_This is a guest post by Denis Mulyalin, follow [github account](https://github.com/dmulyalin) and [twitter feed](https://twitter.com/DMulyalin) for latest updates._

---

# SALTSTACK Nornir Proxy Minion introduction

Network Automation is a complex but interesting topic with a lot of challenges to explore and a lot to learn, defined by one of the [vendors](https://www.cisco.com/c/en/us/solutions/automation/network-automation.html) as:

> Network automation is the process of automating the configuring, managing, testing, deploying, and operating of physical and virtual devices within a network.

This post is an introduction to SALTSTACK and Nornir and how the Network Automation field can benefit from combining them.

## Nornir ~~or~~ and SALTSTACK

Many systems were developed to address automation aspects of networking, Nornir and SALTSTACK fall in the same category and could be succinctly described as:

**Nornir** - *is an automation framework written in python to be used with python* - it is a general purpose automation system that uses plugins to address specific problems at specific layers.

**SALTSTACK** - *Built on python, Salt uses simple and human-readable YAML combined with event-driven automation to deploy and configure complex IT systems* - it is a general purpose and hierarchical automation system that uses modules to address specific problems at specific levels.

Both systems share many common aspects, such as:

- Both written in Python and can be directly interfaced using Python API
- Both use plugins/modules to interact with devices and external systems
- Both are open-source (SALTSTACK community) and available on GitHub
- Both follow *"everything is pluggable and extendable"* paradigm

But, while Nornir targets mainly automation of networks, SALTSTACK was initially developed to automate IT systems - servers, virtual machines, operating systems, applications.

SALT also aims to address a much wider set of use cases compared to Nornir, it has more components, longer history (111,991 commits) and big community. Moreover, SALTSTACK has a Team of developers backing it up and was recently [purchased](https://blogs.vmware.com/management/2020/10/vmware-completes-saltstack-acquisition-to-bolster-software-configuration-management-and-infrastructure-automation.html) by VMWare. Worth noting that SALTSTACK has an Enterprise version as well.

## Nornir intro

Nornir is a Python based framework or package if you'd like. That package contains pluggable core that uses plugins to do its work.

Diagram to recap key Nornir components:
```
    +-------Nornir Framework-------+ 
    |                              |
    | Inventory       Transform    |
    |  Plugins         Plugins     |
    |     |               |        |
    |  ======Nornir CORE======     |
    |            |                 |
    |         Runners  Processors  |
    |             |          |     |
    |           Tasks <------+     |
    |             |                |
    |     Connection Plugins       |
    |      |              |        |
    |   SSH/API        SSH/API     |
    |      |              |        |
    |   +------+       +------+    |
    |   |DEVICE|       |DEVICE|    |
    |   +------+       +------+    |
    |                              |
    +------------------------------+
```
Plugins can be developed independently of the main Core package and registered during runtime to execute tasks on devices.

## SALTSTACK intro

Key aspects of SALT architecture could be summarized as below:

```
                      |-RUNNERS    |-REACTOR      |-SCHEDULERS
                      |-CLOUD      |-FILE SERVER  |-STATE 
                      |-WHEEL      |-AUTH         |-RENDERERS 
                      |-MINE       |-PILLAR       |-OUTPUT 
                      +------------+--------------+               
                                   |                     
                    |           MASTER             |
                    |                              |
                    +----------Server/VM-----------+
    ENGINES                        |                       API
       |                           |                        |
       |                           |                        |
===========================ZeroMQ  EVENT BUS=============================
                 |                                    |
                 |                                    |
      +------Server/VM-------+              +------Server/VM-------+
      |                      |              |                      |
      |  OS (Windows/Linux)  |              |  OS (Windows/Linux)  |
      |   |-MINION process   |              |   |-PROXY-MINION     |   
      |     |-BEACON         |              |     |-BEACON         |   
      |     |-GRAINS         |              |     |-GRAINS         |   
      |     |-RETURNER       |              |     |-RETURNER       |   
      |     |-SCHEDULER      |              |     |-SCHEDULER      |   
      |     |-EXECUTION      |              |     |-EXECUTION      |
      |       MODULES        |              |       MODULES        |
      |                      |              |                      |
      +----------------------+              +----------------------+
                                                      |         
                                                   SSH/API    
                                                      |         
                                                   +------+     
                                                   |DEVICE|     
                                                   +------+ 
```
SALT Master is the HUB of the overall system, it communicates with Minions to execute various tasks. SALTSTACK uses [modules](https://docs.saltproject.io/en/latest/ref/index.html) to address various use cases.

In the simplest master-less case no Master is required and only a Minion process need to run. Most common deployment, however, is a two tier hierarchy system where Master controls many Minions. Each Minion acts as an agent natively running on the Operating System of the server or device being managed. 

The two-tier approach works well while you need to manage devices that can run Python and other packages required by Minion. But it falls short when you need to manage systems that do not provide such capabilities and instead could be managed over API (HTTP, Netconf etc.) or SSH/Telnet.

A three-tier hierarchy was developed to accommodate systems that cannot run Minion processes. For that case, special minion process need to run somewhere where it is reachable by the Master and able to talk with the managed device - this type of minion is called proxy-minion. 

For completeness it is good to mention that [SALT Syndic](https://docs.saltproject.io/en/latest/topics/topology/syndic.html) architecture also exists, that architecture allows to introduce Master of Masters node for big scale deployments. For redundancy purposes several Masters can be deployed in an active-standby manner.

Proxy Minions and Normal minions use execution modules to provide SALT Master and ultimately end-user with functionality to manage target systems/devices. For example, latest (at the time) version of SALT 3003.1 shipped with 529 execution modules each containing several functions. Many execution modules can be used by proxy-minions.

## SALTSTACK how to use it

The preferred way of interacting manually with SALT is a collection of CLI utilities that you invoke on Master, main ones are `salt` and `salt-run`.

For machines/scripts SALT exposes a native [Python API](https://docs.saltproject.io/en/latest/ref/clients/index.html#client-apis) same as Nornir. In addition to that, SALT can run REST API server, which acts as a thin wrapper around Python API.

Here is an example of running `clock` shell command on the remote Linux machine called *srv-1* through the minion using `salt` utility on SALT Master:

```
salt srv-1 cmd.run 'clock'
```

Or, example of running `show clock` command from SALT-Master on the remote network router called *router-1* managed over SSH by NAPALM Proxy Minion:

```
salt router-1 net.cli "show clock"
```

Or same example as above but using [Python Local Client API](https://docs.saltproject.io/en/latest/ref/clients/index.html#localclient) on SALT Master:

```
import salt.client

client = salt.client.LocalClient()

response = client.cmd(tgt="router-1", fun="net.cli", arg=["show clock"])
```

Another option to run SALT commands from the CLI on your local machine could be [Pepper Library](https://github.com/saltstack/pepper), which leverages SALT REST API server.

Worth noting that various SALTSTACK web GUI applications were developed as well.

## How Nornir fits the picture

SALTSTACK gained prominent capabilities to manage network devices a while ago, mainly thanks to development of [NAPALM proxy-minion](https://docs.saltproject.io/en/latest/topics/network_automation/index.html#napalm) module in year 2016. 

However, the main drawback of proxy-minion for network automation, or better say, the main drawback of three tier hierarchy for network devices automation is that each network device requires to run dedicated proxy-minion process, each consuming ~100Mbyte of RAM.

If you have somewhat small network of say 50-100 devices (routers, switches, firewalls etc.) you might end up running 50-100 proxy minion processes (one for each managed devices) consuming about 4-10Gbyte of RAM combined. 

If your network is of a bigger size and has about 500-1000 devices in it, you might need 40-100Gbyte of RAM to run your proxy-minions.

For a service provider or big enterprise with thousands of devices, the resources needed for the proxy-minions can be significant.

To address this scaling problem we can improve three-tier hierarchy by making single proxy-minion process to manage several devices using Nornir:

```
                    +------------------------------+               
                    |           MASTER             |
                    +------------------------------+
                                   |                       
                                   |                       
===========================ZeroMQ  EVENT BUS=============================
                 |                                      |
                 |                                      |
       +------Server/VM-------+            +--------Server/VM---------+
       |                      |            |                          |
       |  OS (Windows/Linux)  |            |  OS (Windows/Linux)      |
       |   |-PROXY-MINION     |            |   |-Nornir-PROXY-MINION  |
       |     |-BEACON         |            |     |-BEACON             |
       |     |-GRAINS         |            |     |-GRAINS             |
       |     |-RETURNER       |            |     |-RETURNER           |
       |     |-SCHEDULER      |            |     |-SCHEDULER          |
       |     |-EXECUTION      |            |     |-EXECUTION          |
       |       MODULES        |            |       MODULES            |
       |                      |            |                          |
       +----------------------+            +--------------------------+
                 |                             |        |        |         
              SSH/API                       SSH/API  SSH/API  SSH/API    
                 |                             |        |        |         
              +------+                      +------+ +------+ +------+     
              |DEVICE|                      |DEVICE| |DEVICE| |DEVICE|     
              +------+                      +------+ +------+ +------+     
```
Integrating Nornir with SALT proxy-minion allows us to manage multiple network devices from single proxy-minion process. 

If single Nornir proxy-minion manages 10 network devices, we will decrease RAM resource requirements approximately by a factor of 9 compared to normal proxy-minion. 

If we opt for 50 devices per Nornir proxy-minion, resources will decrease by a factor of ~25-30. Or in other words, with 50 devices per proxy-minion and 40 proxy-minion processes one should be able to manage 2000 network devices using about 8Gbyte of RAM.

In addition to addressing scaling problem SALTSTACK and Nornir can deeply complement one another. 

For instance, a single proxy-minion process can use several Nornir connection plugins to communicate with devices and switching between Netmiko, Scrapli or NAPALM to push configuration to devices would become a matter of specifying single command line argument:

```
salt nornir-proxy-1 nr.cfg "loopback 1000" "description 'Configured by SALT and Nornir'" plugin=netmiko
salt nornir-proxy-1 nr.cfg "loopback 1000" "description 'Configured by SALT and Nornir'" plugin=napalm
salt nornir-proxy-1 nr.cfg "loopback 1000" "description 'Configured by SALT and Nornir'" plugin=scrapli
```

Or running any Nornir task plugin by specifying Python import path or path to a file with the code:

```
salt nornir-proxy-1 nr.task "nornir_napalm.plugins.tasks.napalm_get" getters="get_facts"
salt nornir-proxy-1 nr.task "salt://path/to/task_function.py"
```

On the flip side, Nornir gains access to SALTSTACK subsystems such as:
- SALT CLI to work with Nornir framework using SALT Master command line terminal 
- Exposure to SALT Python API or REST API to interact with network devices via Nornir plugins
- SALT Event Bus allowing to build distributed network of proxy-minions with linear scaling-out characteristics
- Configuration rendering using SALT text renderers e.g. Jinja2, Mako, Cheetah, Genshi and others with access to SALT pillar, grains or mine systems for data sourcing
- Emitting events to event-bus for failed tasks - add SALT Reactor and you have a recipe for event-driven automation
- SALT file server to store and download configuration files, custom tasks, tests, lists of commands and actions to perform
- Schedulers to run Nornir tasks on a periodic or one-off basis
- Returners to emit task's results to external databases - Elasticsearch, MongoDB, MySQL etc. - or to email or text them to slack
- Storing devices output to SALT-Mine on a periodic basis to have a snapshot of latest state
- SALTSTACK States system to integrate network configuration in work flows of applications provisioning

On the output we getting results that can help us, Network Engineers, be less restricted, be more flexible and efficient and put to work all the efforts Open Source community invested in building Nornir and SALTSTACK systems.

# Conclusion

Nornir and SALTSTACK both aiming to help people manage their infrastructure in a more efficient way. Both produced by community for community. Both pluggable, extendable, built on Python with Python API readily available to solve your problems. 

Combining Nornir and SALTSTACK together gives us something new, something bigger, something that we can work and tinker with, something we can face with to ever growing, complex and intricate world of Network Automation.

Thank you for reading, hope you enjoyed it. Author would like to leave reader with a set of links to explore this topic further:

- Nornir Proxy Minion [documentation](https://salt-nornir.readthedocs.io/en/latest/index.html) 
- SALTSTACK [website](https://saltproject.io/)
- SALTSTACK Network Automation [article](https://docs.saltproject.io/en/latest/topics/network_automation/index.html)
- Remarkable Mircea Ulinic [blog](https://mirceaulinic.net/) with SALT Network Automation articles 
- Informative "Network Automation at scale" [presentation](https://ripe74.ripe.net/presentations/18-RIPE-74-Network-automation-at-scale-up-and-running-in-60-minutes.pdf)
