---
title: "Testing your network with Nornir TestsProcessor"
date: "2021-08-06"
tags: ["nornir", "guest", "testing", "network testing"]
---

_This is a guest post by Denis Mulyalin, follow [github account](https://github.com/dmulyalin) and [twitter feed](https://twitter.com/DMulyalin) for latest updates._

---

# Network testing overview

For the start lets introduce some terminology and structure. **Network Testing** 
could be roughly defined as a process of making sure that your network is adhere 
to a certain level of quality. Network tests itself could be classified based on 
a variety of properties. For example using **test scope** as a test metric allows 
us to sort tests across these categories:

- local (unit) - verify functionality and features contained within device itself 
e.g. platform state, software version, configuration
- adjacent (integration) - verify operation between device pairs e.g. various 
protocols peerings, links, point to point connectivity
- network (system) - verify network function end to end e.g. end-to-end 
connectivity and performance verification

Another criteria which is not the very apparent but quiet important from automation 
perspectives is **test complexity** which identifies how difficult is it to automate 
it. Using complexity we can separate tests across these sets:

- low complexity - easy to automate e.g. check that show command output contains 
particular pattern
- moderate complexity - requires correlation and testing of several criteria e.g. 
verify that all active ISIS enabled interfaces have certain MTU
- high complexity - usually this type of tests represent a collection of sub tests 
spread across time and domains e.g. verify customer service provisioning

In author's experience, about 70% of networking tests fall in the *low complexity* 
category, 20% of tests are of *moderate complexity* and *high complexity* tests account 
for around 9% of cases, 1% remaining probably cases that cannot be automated at all. 
These numbers of course can differ from environment to environment and only serve 
demonstration purposes to give us an idea of what are we dealing with.

# Network Testing tools landscape

If majority of tests are of low complexity to automate, why not we all already 
running automated tests suits on a constant basis? 

Probably complexity itself is the answer here, complexity is a very subjective 
criteria, it defines the entry barrier and if it too big, people just skip it 
falling back to traditional methods.

Nonetheless, some network testing frameworks/tools that Author aware of are:

- PyATS - Ecosystem of libraries and tools to set up and run automated network tests
- Napalm Validate - NAPALM built-in function to validate getters output 
- Batfish - Network Configuration Analysis tool

List is not exhaustive, quiet sure other open source or free tools exist that Author 
did not came across yet.

Another framework that we ca use for testing in general and network testing in 
particular is - *Python Programming Language*.

We can either use Python itself or testing libraries that are part of Python ecosystem 
such as [pytest](https://docs.pytest.org/) or [robot](https://robotframework.org/).

For instance, if we decide to use Pytest we can write something like:

```
from nornir import InitNornir
from nornir_netmiko import netmiko_send_command

nr = InitNornir(config_file="nornir_config.yaml")

def test_software_version():
    results = nr.run(
        task=netmiko_send_command,
        command_string="show version",
    )
    for host, result in results.items():
        assert "16.10.1" in result[0].result, "{} software version is wrong".format(host)

def test_syslog_config():
    results = nr.run(
        task=netmiko_send_command,
        command_string="show run | inc logging",
    )
    for host, result in results.items():
        assert "10.0.0.1" in result[0].result, "{} logging configuration is wrong".format(host)
``` 

Save above code in a file named `test_network_suite_v1.py` and provided that we have 
Nornir, Netmiko and Pytest installed and configured we can run above tests:

```
pytest test_network_suite_v1.py -vv
```

If all good we should get output similar to this:

```
collected 2 items

test_network_suite_v1.py::test_software_version PASSED   [ 50%]
test_network_suite_v1.py::test_syslog_config PASSED      [100%]

============== 2 passed, 0 warnings in 4.35s ==================
```

What remaining is "just" to re-factor the code to account for individual devices,
make script to emit testing results in some pretty format and write another 10 
or 100 test functions to have a satisfying test coverage.

Main benefit of that approach is that it gives the *ultimate flexibility* and 
control - things you can test only limited by your knowledge of Python Programming 
Language and its ecosystem of networking tools. It probably would be true to say 
that you can test virtually anything using that approach.

Main drawback - learning curve or entry barrier. To gain the power of ultimate 
flexibility one need to spend significant time and efforts to train itself. 

Also, another drawback, we need to write code, potentially quiet a lot of code to 
test even for something as simple as checking show commands output for pattern 
containment. 

Most of that code would end up redundant and could be organized in various functions
for better re-usability and DRY (don't repeat yourself) principles. But, as it 
usually happens, that already was done and in this case distributed in a form of 
Nornir `TestsProcessor` plugin within [nornir-salt](https://nornir-salt.readthedocs.io/)
package.

# Nornir TestsProcessor

Nornir [processors](https://nornir.readthedocs.io/en/latest/tutorial/processors.html)
are plugins that tap into task execution process to do various actions such as log 
events, work with results or do other processing.

Nornir-salt is a package that contains Nornir plugins and functions including 
`TestsProcessor`. Nornir-salt developed as part of SALTSTACK Nornir Proxy-Minion.
But, all plugins in Nornir-salt package designed to work with Nornir directly 
and does not have any SALTSTACK dependencies.

Sample code to run tests using `TestsProcessor` - save to `test_network_suite_v2.py` file:

```
from nornir import InitNornir
from nornir_salt import TestsProcessor, TabulateFormatter, netmiko_send_commands

nr = InitNornir(config_file="nornir_config.yaml")

# define your tests suite
tests_suite = [
    ["show version", "contains", "17.3.1", "Software version test"],
    ["show run | inc logging", "contains", "10.0.0.1", "Logging configuration check"],
    ["show interfaces", "!contains_lines", ["Half Duplex", "10Mbps"], "Duplex and speed test"]
]

# add tests processor
nr_with_tests = nr.with_processors(
    [
        TestsProcessor(tests_suite)
    ]
)

# collect output from devices using netmiko_send_commands task plugin
results = nr_with_tests.run(
    task=netmiko_send_commands,
    commands=[
        "show version",
        "show run | inc logging",
        "show interfaces"
    ]
)

# prettify results transforming them in a text table using TabulateFormatter
table = TabulateFormatter(results, tabulate="brief")

# print results
print(table)
```

Running above code:

```
python3 test_network_suite_v2.py
```

Should give us this output:

```
+----+--------+-----------------------------+----------+-----------------------+
|    | host   | name                        | result   | exception             |
+====+========+=============================+==========+=======================+
|  0 | R1     | Software version test       | FAIL     | Pattern not in output |
+----+--------+-----------------------------+----------+-----------------------+
|  1 | R1     | Logging configuration check | PASS     |                       |
+----+--------+-----------------------------+----------+-----------------------+
|  2 | R1     | Duplex and speed test       | PASS     |                       |
+----+--------+-----------------------------+----------+-----------------------+
|  3 | R2     | Software version test       | FAIL     | Pattern not in output |
+----+--------+-----------------------------+----------+-----------------------+
|  4 | R2     | Logging configuration check | PASS     |                       |
+----+--------+-----------------------------+----------+-----------------------+
|  5 | R2     | Duplex and speed test       | PASS     |                       |
+----+--------+-----------------------------+----------+-----------------------+
```

`TestsProcessor` uses tests suite to run the tests - test suite is a list of 
dictionaries or a list of lists, where each dictionary or list contains tests details. 

List of lists tests suite is more concise but only allows to define these four test parameters:

- first list item - mandatory, Nornir results task name
- second list item - mandatory, test function name
- third list item - mandatory, test criteria, pattern
- last item - optional, test name

Sample list of lists test suite with single test in it:

```python
tests_suite = [
    ["show version", "contains", "17.3.1", "Test software version"],
]
```

List of dictionaries is more verbose and allows to specify more options, example:

```python
tests_suite = [
    {
        "name": "Test version",
        "task": "show version",
        "test": "contains",
        "pattern": "17.3.1",
        "err_msg": "Software version is wrong"
    }
]
```

Test dictionary `task` key indicates name of the Nornir task, results of that task 
feed into test function. `netmiko_send_commands` task plugin conveniently uses command 
string as a name for the sub-tasks, making it easy to identify results by command itself.

`TestsProcessor` significantly simplifies running tests for containment or
equality checks using these test functions:

- `contains` - tests if result contains pattern
- `!contains` or `ncontains` - tests if result does not contain pattern
- `contains_lines` - tests if result contains any of the patterns from the list
- `!contains_lines` or `contains_lines` - tests if result does not contain any of the patterns
- `contains_re` - tests if result contains regular expression pattern
- `!contains_re` or `ncontains_re` - tests if result does not contains regular expression pattern
- `contains_lines_re` - tests if result contains any of the regex patterns from the list
- `!contains_lines_re` or `ncontains_lines_re` - tests if result does not contain any of regex patterns
- `equal` - checks that results are equal to provided value
- `!equal` or `nequal` - checks that results are not equal to provided value

Containment or equality checks are very similar to how we, Humans, verify output 
from devices:

1. Run show command 
2. Check if output contains certain values 
3. Decide if test failed or succeeded

Containment test functions do exactly that but in an automated fashion using 
output collected from devices by Nornir.

With above test functions we already can test significant set of use cases:

- device configuration content verification
- single show commands output checks
- verify ping command results

To make up for more "production" ready example lets use simple trick - move definition of
our tests suite in a `tests_suite.yaml` file:

```yaml
- name: Software version test
  task: show version
  test: contains
  pattern: "17.3.1"
  err_msg: Software version is wrong
  
- name: Logging configuration check
  task: "show run | inc logging"
  test: contains
  pattern: 10.0.0.1
  err_msg: Logging configuration is wrong
  
- name: Duplex and speed test
  task: "show interfaces"
  test: "!contains_lines"
  pattern: 
    - Half Duplex
    - 10Mbps
  err_msg: Logging configuration is wrong
```

Update `test_network_suite_v2.py` code and save it in `test_network_suite_v3.py` file:

```python
import yaml
from nornir import InitNornir
from nornir_salt import TestsProcessor, TabulateFormatter, netmiko_send_commands

nr = InitNornir(config_file="nornir_config.yaml")

# read tests suite
with open("tests_suite.yaml") as f:
    tests_suite = yaml.safe_load(f.read())

# add tests processor
nr_with_tests = nr.with_processors(
    [
        TestsProcessor(tests_suite)
    ]
)

# collect commands to get from devices accounting 
# for case when task is a list of commands
commands = []
for item in tests_suite:
    if isinstance(item["task"], str):
        commands.append(item["task"])
    elif isinstance(item["task"], list):    
        commands.extend(item["task"])
        
# collect output from devices using netmiko_send_commands task plugin
results = nr_with_tests.run(
    task=netmiko_send_commands,
    commands=commands
)

# prettify results transforming them in a text table using TabulateFormatter
table = TabulateFormatter(results, tabulate="brief")

# print results
print(table)
```

Execute above code:

```
python3 test_network_suite_v3.py
```

If all good we should see same output as before but this time tests 
suite sourced from YAML file.

Abstracting tests suite in a YAML document makes it easy to add or remove tests.

For instance, what if requirements comes in to verify CRC errors counter is below 
1000 on all device's interfaces, we can append this test to `tests_suite.yaml` file:

```yaml

- name: Test interfaces CRC count
  task: "show interfaces | inc CRC"
  test: "!contains_re"
  pattern: "\\d{4,} CRC"
  err_msg: Interfaces CRC errors above 999
```

Regex pattern `\\d{4,} CRC` will match any 4 digit numbers and above, if such matches 
found in output we can be positive that CRC errors are above 999 at least on one of 
the interfaces.

Running same `python3 test_network_suite_v3.py` now gives these results:

```
+----+--------+-----------------------------+----------+---------------------------+
|    | host   | name                        | result   | exception                 |
+====+========+=============================+==========+===========================+
|  0 | R1     | Software version test       | FAIL     | Software version is wrong |
+----+--------+-----------------------------+----------+---------------------------+
|  1 | R1     | Logging configuration check | PASS     |                           |
+----+--------+-----------------------------+----------+---------------------------+
|  2 | R1     | Duplex and speed test       | PASS     |                           |
+----+--------+-----------------------------+----------+---------------------------+
|  3 | R1     | Test interfaces CRC count   | PASS     |                           |
+----+--------+-----------------------------+----------+---------------------------+
|  4 | R2     | Software version test       | FAIL     | Software version is wrong |
+----+--------+-----------------------------+----------+---------------------------+
|  5 | R2     | Logging configuration check | PASS     |                           |
+----+--------+-----------------------------+----------+---------------------------+
|  6 | R2     | Duplex and speed test       | PASS     |                           |
+----+--------+-----------------------------+----------+---------------------------+
|  7 | R2     | Test interfaces CRC count   | PASS     |                           |
+----+--------+-----------------------------+----------+---------------------------+
```

That is it, now testing your network is as simple as adding more tests in your 
`tests_suite.yaml` file.

# Nornir TestsProcessor - advance to Python

In cases where functionality of containment and pattern matching tests is not enough 
we can fall-back on Python Language capabilities. `TestsProcessor` comes with these 
two test functions to help us with exactly that:

- `eval` test function - uses Python `eval` and `exec` built-in function to evaluate 
Python expression to produce test results
- `custom` test function - uses any custom-defined Python function to perform results 
testing

**Using `eval` or `custom` test functions is equivalent to running Python code directly**
**on your system, do not use custom test functions or test suites from untrusted/unverified** 
**sources.**

By the set of use cases it can address `eval` probably sits in the middle between 
predefined and `custom` test functions:

1. Predefined test functions only provide pre-baked functionality, but tests easily 
defined in a test suite
2. With `eval` you already can use Python Language, but limited to a single expression
3. `custom` test function gives full access to Python Language but requires to write the code

From the perspectives of **test complexity** classification we described previously, 
predefined and `eval` test functions help to address low to moderate complexity test 
cases while custom test function aims moderate to high complexity scenarios. 

This is of course guidelines only, as technically all pre-defined and `eval` test 
functions could be replaced with custom functions.

To demonstrate how to use `eval` test function lets say new requirements comes in - need to 
verify that all interfaces have MTU set to 9200, for that we can append this test 
case to `tests_suite.yaml` file:

```yaml

- name: Test interfaces MTU
  task: "show interfaces | inc MTU"
  test: "eval"
  expr: "all(['9200' in line for line in result.splitlines()])"
  err_msg: Interface MTU out of range
```

Running `python3 test_network_suite_v3.py` one more time gives these additional results:

```
+----+--------+-----------------------------+----------+----------------------------+
|    | host   | name                        | result   | exception                  |
+====+========+=============================+==========+============================+
...
+----+--------+-----------------------------+----------+----------------------------+
|  4 | R1     | Test interfaces MTU         | FAIL     | Interface MTU out of range |
+----+--------+-----------------------------+----------+----------------------------+
...
+----+--------+-----------------------------+----------+----------------------------+
|  9 | R2     | Test interfaces MTU         | FAIL     | Interface MTU out of range |
+----+--------+-----------------------------+----------+----------------------------+
```

`eval` test function injects `result` variable in global space while evaluating Python 
expression, that variable contains Nornir task execution results for that particular 
task or subtask.

One more interesting use case that `eval` can help with is processing and testing 
structured data. For example, we can parse output from device using `textfsm`, `Genie` 
or `TTP` parser so that task result will contain structured data that we can test 
using `eval` test function.

However, while `eval` is quiet powerful test function it still can fall short in some 
scenarios. Moreover, `eval` expressions could look rather foreign for somebody who does not 
familiar with Python. In that case using `custom` test function could be a better 
option.

Let's say new requirement comes in - we need to verify that dot1q tags and IP addresses 
configured on device for all sub interfaces that are in UP/UP state.

That type of requirement usually can be addresses following this approach:

1. Collect show commands output from devices
2. In case if task result is a text - parse it using libraries like `TextFSM`, `Genie` or `TTP`
3. Process structured data further to produce test results

`custom` test function requires reference to testing function to feed task results into, 
most straightforward way to provide that reference is by using path to a text file with 
testing function content - in this case `test_sub_interfaces_ip.py` file:

```
from ttp import ttp

ttp_template_intf_cfg = """
interface {{ name | contains(".") }}
 ip address {{ ip }} {{ mask }}
 encapsulation dot1Q {{ dot1q }}
"""

ttp_template_intf_state = """
<group name="{{ interface }}">
{{ interface | contains(".") }} is up, line protocol is up
</group>
"""

def run(results):
    ret = []
    
    # parse show commands output
    parsed_results = {}
    for result in results:
        if result.name == "show run":
            parser = ttp(data=result.result, template=ttp_template_intf_cfg)
            parser.parse()
            parsed_results["cfg"] = parser.result(structure="flat_list")
        elif result.name == "show interfaces | inc line protocol is up":
            parser = ttp(data=result.result, template=ttp_template_intf_state)
            parser.parse()
            parsed_results["up_interfaces"] = parser.result(structure="flat_list")[0]
            
    # parsed_output structure should look like this:
    # {
    #     'cfg': [
    #         {
    #             'ip': '1.2.3.4', 
    #             'mask': '255.255.255.0', 
    #             'name': 'GigabitEthernet5.17', 
    #             'dot1q': '17'
    #         }
    #     ], 
    #     'up_interfaces': {'GigabitEthernet5.17': {}}
    # }    
    
    # process results further
    for interface in parsed_results["cfg"]:
        # skip interfaces that are not up/up
        if interface["name"] not in parsed_results["up_interfaces"]:
            continue
        # if no dot1q tag or IP configured, it is error
        if "ip" not in interface or "dot1q" not in interface:
            ret.append(
                {
                    "result": "FAILED",
                    "exception": "{} is UP/UP but no IP or dot1q configured".format(
                        interface["name"]
                    )
                }
            )
            
    return ret
```

Add new test to `tests_suite.yaml` file:

```yaml
- name: Test sub-interfaces IP
  task: 
    - "show run"
    - "show interfaces | inc line protocol is up"
  test: custom
  function_file: "test_sub_interfaces_ip.py"
```

Running our suite one more time - `python3 test_network_suite_v3.py` - gives these results:

```
+----+--------+-----------------------------+----------+------------------------------------------------------------+
|    | host   | name                        | result   | exception                                                  |
+====+========+=============================+==========+============================================================+
|  0 | R1     | Software version test       | FAIL     | Software version is wrong                                  |
+----+--------+-----------------------------+----------+------------------------------------------------------------+
|  1 | R1     | Logging configuration check | PASS     |                                                            |
+----+--------+-----------------------------+----------+------------------------------------------------------------+
|  2 | R1     | Duplex and speed test       | PASS     |                                                            |
+----+--------+-----------------------------+----------+------------------------------------------------------------+
|  3 | R1     | Test interfaces CRC count   | PASS     |                                                            |
+----+--------+-----------------------------+----------+------------------------------------------------------------+
|  4 | R1     | Test sub-interfaces IP      | FAILED   | GigabitEthernet5.31 is UP/UP but no IP or dot1q configured |
+----+--------+-----------------------------+----------+------------------------------------------------------------+
|  5 | R1     | Test sub-interfaces IP      | FAILED   | GigabitEthernet2.34 is UP/UP but no IP or dot1q configured |
+----+--------+-----------------------------+----------+------------------------------------------------------------+
|  6 | R1     | Test sub-interfaces IP      | FAILED   | GigabitEthernet4.77 is UP/UP but no IP or dot1q configured |
+----+--------+-----------------------------+----------+------------------------------------------------------------+
|  7 | R2     | Software version test       | FAIL     | Software version is wrong                                  |
+----+--------+-----------------------------+----------+------------------------------------------------------------+
|  8 | R2     | Logging configuration check | PASS     |                                                            |
+----+--------+-----------------------------+----------+------------------------------------------------------------+
|  9 | R2     | Duplex and speed test       | PASS     |                                                            |
+----+--------+-----------------------------+----------+------------------------------------------------------------+
| 10 | R2     | Test interfaces CRC count   | PASS     |                                                            |
+----+--------+-----------------------------+----------+------------------------------------------------------------+
| 11 | R2     | Test sub-interfaces IP      | FAILED   | GigabitEthernet6.18 is UP/UP but no IP or dot1q configured |
+----+--------+-----------------------------+----------+------------------------------------------------------------+
```

Ok, looks like our test suite working and we have some issues to fix.

Custom function file contains single function called `run` - this is the default name of the 
function that `TestsProcessor` `custom` test function looks for and executes by default.

Custom test function should accept at least one argument with Nornir task results and 
should return single dictionary or a list of dictionaries where each dictionary contains 
test results.

In our case test definition `task` attribute contains a list of commands, because of that 
`TestsProcessor` will feed a list of `nornir.core.task.Result` objects each containing output 
for certain command. 

# In conclusion

Testing is a crucial component for many processes - initial device deployment, new hardware
or software evaluation, ongoing and on failure verifications, pre/post-change tests to name 
a few.

Be it a simple containment or pattern check, complex cross output correlation tests or structured 
output evaluation - Python, Nornir and now TestsProcessor will be on your side to help 
you cope with new requirements and improve the quality of your network.

> “Quality is not an act, it is a habit.”— Aristotle

# Reference notes

Code examples above reference various files, their content provided below. All `.yaml` and 
`.py` files should be in same folder.

`nornir_config.yaml` file:

```
inventory:
    plugin: SimpleInventory
    options:
        host_file: "hosts.yaml"
        
runner:
    plugin: threaded
    options:
        num_workers: 5
```

`hosts.yaml` file:

```
R1:
  hostname: 192.168.1.10
  platform: ios
  password: nornir
  username: nornir
      
R2:
  hostname: 192.168.1.11
  platform: ios
  password: nornir
  username: nornir
```
        
Software versions Author used to run the code:

- Python 3.6
- Nornir 3.1.1 - `pip install nornir`
- Nornir-netmiko 0.1.1 - `pip install nornir-netmiko`
- Netmiko 3.4.0 - `pip install netmiko`
- Nornir-salt 0.4.0 - `pip install nornir-salt`
- Tabulate 0.8.3 - `pip install tabulate`
- PyYAML 5.3.1 - `pip install pyyaml`
- Pytest 6.2.4 - `pip install pytest`
- TTP 0.7.2 - `pip install ttp`
