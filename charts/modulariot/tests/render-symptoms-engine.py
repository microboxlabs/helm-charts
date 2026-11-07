#!/usr/bin/env python3
"""Render real aliased dependencies and optionally compare legacy values to a base."""

import argparse
import difflib
import json
from pathlib import Path
import subprocess
import tempfile

import yaml


ROOT = Path(__file__).resolve().parents[3]
CHART = ROOT / "charts/modulariot"
ENGINE = "miot-symptoms-engine"


def render(chart, values=None, release="rel"):
    with tempfile.TemporaryDirectory(dir=ROOT / ".cache") as directory:
        if isinstance(values, Path):
            path = values
        else:
            path = Path(directory) / "values.yaml"
            path.write_text(yaml.safe_dump(values or {}))
        return subprocess.check_output(
            ["helm", "template", release, str(chart), "-f", str(path)]
        )


def documents(output):
    return [doc for doc in yaml.safe_load_all(output) if doc]


def check_instances():
    disabled = documents(render(CHART))
    assert not any(ENGINE in doc["metadata"]["name"] for doc in disabled)
    for release in ("rel", "miot-modulith", ENGINE, "miot-modulith-" + ENGINE, "r" * 53):
        enabled = documents(render(CHART, {ENGINE: {"enabled": True}}, release))
        instances = {
            doc["metadata"]["labels"]["app.kubernetes.io/name"]: doc
            for doc in enabled
            if doc["kind"] == "Deployment"
            and doc["metadata"]["labels"]["app.kubernetes.io/name"]
            in ("miot-modulith", ENGINE)
        }
        assert len(instances) == 2, release
        primary, engine = instances["miot-modulith"], instances[ENGINE]
        assert primary["metadata"]["name"] != engine["metadata"]["name"], release
        assert engine["spec"]["replicas"] == 2
        assert primary["spec"]["selector"] != engine["spec"]["selector"]
        container = engine["spec"]["template"]["spec"]["containers"][0]
        env = {entry["name"]: entry.get("value") for entry in container["env"]}
        assert env["MIOT_COMPONENT_SYMPTOMS_ENABLED"] == "true"
        assert env["MIOT_COMPONENT_FLEET_ENABLED"] == "false"
        assert env["QUARKUS_FLYWAY_MIGRATE_AT_START"] == "false"
        assert "QUARKUS_OIDC_AUTH_SERVER_URL" not in env
        identities = [
            (doc["apiVersion"], doc["kind"], doc["metadata"].get("namespace"),
             doc["metadata"]["name"])
            for doc in enabled
        ]
        assert len(identities) == len(set(identities)), release
        assert not any(
            doc["kind"] in ("Service", "Ingress", "ApisixRoute", "ApisixTls", "ServiceMonitor", "Pod")
            and doc["metadata"].get("labels", {}).get("app.kubernetes.io/name") == ENGINE
            for doc in enabled
        ), release

    # Asking for exposure must render the resources against the engine Service.
    exposed = documents(render(CHART, {ENGINE: {
        "enabled": True,
        "service": {"enabled": True},
        "ingress": {"enabled": True},
        "apisixRoute": {"enabled": True, "tls": [
            {"hosts": ["engine.example.invalid"], "secretName": "engine-tls"}
        ]},
        "metrics": {"enabled": True, "serviceMonitor": {"enabled": True}},
    }}))
    engine_resources = [doc for doc in exposed if doc["metadata"].get("labels", {}).get(
        "app.kubernetes.io/name") == ENGINE]
    assert {"Service", "Ingress", "ApisixRoute", "ApisixTls", "ServiceMonitor", "Pod"} <= {
        doc["kind"] for doc in engine_resources
    }
    print("PASS: disabled/enabled instances, unique identities, worker defaults and opt-in exposure")


def check_keda():
    trigger = {"type": "prometheus", "metadata": {
        "serverAddress": "http://prometheus.monitoring:9090",
        "query": "sum(example_backlog)", "threshold": "100", "activationThreshold": "10",
    }}
    for release in ("rel", "miot-modulith", ENGINE):
        docs = documents(render(CHART, {ENGINE: {
            "enabled": True, "keda": {"enabled": True, "triggers": [trigger]},
        }}, release))
        scaled = [doc for doc in docs if doc["kind"] == "ScaledObject"]
        assert len(scaled) == 1, release
        engine = next(doc for doc in docs if doc["kind"] == "Deployment"
                      and doc["metadata"]["labels"]["app.kubernetes.io/name"] == ENGINE)
        assert scaled[0]["spec"]["scaleTargetRef"]["name"] == engine["metadata"]["name"], release
        assert "replicas" not in engine["spec"], release
    both = subprocess.run(
        ["helm", "template", "rel", str(CHART), "--set", ENGINE + ".enabled=true",
         "--set", ENGINE + ".autoscaling.enabled=true", "--set", ENGINE + ".keda.enabled=true",
         "--set-json", ENGINE + ".keda.triggers=" + json.dumps([trigger])],
        capture_output=True, text=True,
    )
    assert both.returncode != 0 and "both true" in both.stderr, both.stderr
    print("PASS: engine KEDA ScaledObject target, no replicas, autoscaling+keda fails")


def legacy_cases(baseline):
    yield "defaults", {}
    # Include every YAML values file under tests/examples/ci, even fixtures for
    # unrelated charts, and apply custom subchart fixtures at their actual scope.
    files = subprocess.check_output(
        ["git", "ls-files", "*.yaml", "*.yml"], cwd=ROOT, text=True
    ).splitlines()
    for filename in files:
        path = Path(filename)
        if not {"tests", "examples", "ci"}.intersection(path.parts):
            continue
        if path.name.endswith("_test.yaml"):
            continue
        if "templates" in path.parts:
            continue
        source = baseline / path
        if not source.exists():
            continue
        data = yaml.safe_load(source.read_text())
        if not isinstance(data, dict) or "suite" in data:
            continue
        yield filename, source
        if len(path.parts) > 2 and path.parts[0] == "charts" and path.parts[1] != "alfresco":
            yield filename + " (subchart)", {path.parts[1]: {"enabled": True, **data}}

    # Existing unit tests also carry values inline in `set`, rather than files.
    for suite_path in sorted((baseline / "charts").glob("*/tests/*_test.yaml")):
        suite = yaml.safe_load(suite_path.read_text())
        chart = suite_path.parents[1].name
        for test in suite.get("tests", []):
            settings = {**suite.get("set", {}), **test.get("set", {})}
            if not settings:
                continue
            # Helm parses these paths, including quoted keys and array indices.
            # Preserve that parsing by using --set-json for each inline value.
            yield f"{suite_path.relative_to(baseline)}: {test['it']}", (chart, settings)

    yield "legacy ingress/APISIX/TLS/monitoring/fork/routes/HPA", {"miot-modulith": {
        "ingress": {"enabled": True},
        "apisixRoute": {"enabled": True, "tls": [
            {"hosts": ["api.example.invalid"], "secretName": "api-tls"}
        ]},
        "metrics": {"enabled": True, "serviceMonitor": {"enabled": True}},
        "autoscaling": {"enabled": True},
        "fork": {"enabled": True, "filters": {"ids.txt": "A1"}, "rules": [
            {"id": "mirror", "filterFile": "/config/fork/ids.txt", "paths": ["/track"],
             "targets": [{"id": "mirror", "mirrorHost": "https://mirror.example.invalid"}]}
        ]},
        "symptoms": {"routes": {"routes.json": "{}"}},
    }}


def check_legacy(baseline):
    count = 0
    for name, values in legacy_cases(baseline):
        if isinstance(values, tuple):
            child, settings = values
            prefix = "" if child == "modulariot" else child + "."
            outputs = []
            for chart in (baseline / "charts/modulariot", CHART):
                args = ["helm", "template", "rel", str(chart), "--set", ENGINE + ".enabled=false"]
                for key, value in settings.items():
                    args.extend(["--set-json", prefix + key + "=" + json.dumps(value)])
                outputs.append(subprocess.check_output(args))
            before, after = outputs
        else:
            if not isinstance(values, Path):
                values = {**values, ENGINE: {"enabled": False}}
            before = render(baseline / "charts/modulariot", values)
            after = render(CHART, values)
        if before != after:
            print("".join(difflib.unified_diff(
                before.decode().splitlines(True), after.decode().splitlines(True),
                fromfile="baseline: " + name, tofile="current: " + name)))
            raise AssertionError("Disabled umbrella changed: " + name)
        count += 1
        print("PASS byte-for-byte:", name)
    print(f"PASS: {count} legacy render comparisons (no normalization)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, help="repository snapshot with built umbrella dependencies")
    args = parser.parse_args()
    (ROOT / ".cache").mkdir(exist_ok=True)
    check_instances()
    check_keda()
    if args.baseline:
        check_legacy(args.baseline.resolve())


if __name__ == "__main__":
    main()
