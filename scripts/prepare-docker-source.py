#!/usr/bin/env python3
"""Apply minimal source compatibility fixes needed by the Docker config.

The stock s2 tree normally builds with memory cgroups/cpuset paths disabled,
so two stale/incomplete Android backports are hidden.  The dedicated Docker
config enables those paths and exposes the inconsistencies.  Keep the fixes
small and fail loudly if the expected source no longer matches.
"""

from pathlib import Path


def replace_once(path: Path, old: str, new: str, description: str) -> None:
    text = path.read_text()
    count = text.count(old)

    if count == 1:
        path.write_text(text.replace(old, new, 1))
        print(f"fixed: {description}")
        return

    if count == 0 and new and new in text:
        print(f"already fixed: {description}")
        return

    raise SystemExit(
        f"refusing to patch {path}: expected exactly one match for "
        f"{description!r}, found {count}"
    )


def fix_memcontrol() -> None:
    path = Path("mm/memcontrol.c")

    # This older per-controller Android permission check coexists with the
    # newer mem_cgroup_allow_attach() above that delegates to the common
    # subsys_cgroup_allow_attach() helper.  CONFIG_MEMCG makes both compile,
    # causing a hard redefinition error.  Keep the common helper path, which
    # is also what the CPU controller in this tree uses.
    duplicate = """\
static int mem_cgroup_allow_attach(struct cgroup *cgrp,
\t\t\t\t struct cgroup_taskset *tset)
{
\tconst struct cred *cred = current_cred(), *tcred;
\tstruct task_struct *task;

\tcgroup_taskset_for_each(task, cgrp, tset) {
\t\ttcred = __task_cred(task);

\t\tif ((current != task) && !capable(CAP_SYS_ADMIN) &&
\t\t    cred->euid != tcred->uid && cred->euid != tcred->suid)
\t\t\treturn -EACCES;
\t}

\treturn 0;
}

"""

    text = path.read_text()
    count = text.count(duplicate)
    if count == 1:
        path.write_text(text.replace(duplicate, "", 1))
        print("fixed: duplicate mem_cgroup_allow_attach")
    elif count == 0 and "return subsys_cgroup_allow_attach(cgroup, tset);" in text:
        print("already fixed: duplicate mem_cgroup_allow_attach")
    else:
        raise SystemExit(
            "refusing to patch mm/memcontrol.c: the duplicate "
            f"mem_cgroup_allow_attach block matched {count} times"
        )


def fix_cpuset() -> None:
    path = Path("kernel/cpuset.c")
    old = (
        "\tcpumask_and(&new_allowed, cs->cpus_requested, "
        "top_cpuset.cpus_allowed);"
    )
    new = (
        "\tcpumask_and(&new_allowed, cs->cpus_allowed, "
        "top_cpuset.cpus_allowed);"
    )

    replace_once(
        path,
        old,
        new,
        "incomplete cpus_requested hotplug backport",
    )

    remaining = path.read_text().count("cpus_requested")
    if remaining:
        raise SystemExit(
            "kernel/cpuset.c still contains cpus_requested references "
            f"({remaining}); a full backport may now be required"
        )


def main() -> None:
    fix_memcontrol()
    fix_cpuset()


if __name__ == "__main__":
    main()
