---
title: "Nornir 3 beta"
date: "2020-05-18"
tags: ["nornir"]
---

I am happy to announce that nornir3 is in beta for you to test. The truth is that it's been out already for a while but at this point I am confident it's stable enough to open it to the wider public for testing.

To install nornir beta you will need to execute the following command:

``` shell
$ pip install --pre "nornir>=3.0.0b0"
```

Don't forget the `--pre` option as otherwise `pip` won't let you install it as it's considered a pre-release.

There are many new features and some changes but the main change is that `nornir` won't ship with plugins, instead plugins will live in their own repository. This should minimize the amount of dependencies needed to deploy nornir and also allow maintainers to better maintain the plugins they are experts on :)

To find plugins you can visit [the plugin repository](/nornir/plugins/) and if you want to list your own just open a PR.

Instructions for installing plugins is plugin specific but in most cases it will be just a matter of using pip. For instance:

```
$ pip install nornir-napalm nornir-utils nornir-jinja2
```

Plugins' documentation should have more info about it.

You can find the docs [here](https://nornir.readthedocs.io/en/3.0.0/) and the upgrading notes [here](https://nornir.readthedocs.io/en/3.0.0/upgrading/2_to_3.html)

Finally, a working example using nornir3:


``` python
from nornir import InitNornir
from nornir_napalm.plugins.tasks import napalm_cli

nr = InitNornir(
    inventory={
        "plugin": "SimpleInventory",
        "options": {
            "host_file": "inventory/hosts.yaml",
            "group_file": "inventory/groups.yaml",
            "defaults_file": "inventory/defaults.yaml",
        }
    },
    dry_run=True,
)

result = nr.run(
    napalm_cli,
    commands=["show version", "show interfaces"],
)

print(result["rtr00"][0].result["show version"])
```

Which is pretty much what you are used to with the difference the import path for `napalm_cli` is now different and points to the plugin library.

Feel free to check the documentation, try it out and contact me on slack, open issues and/or PRs if you find issues or have questions.
