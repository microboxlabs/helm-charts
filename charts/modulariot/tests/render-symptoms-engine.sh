#!/usr/bin/env bash
# Renders the umbrella with and without miot-symptoms-engine and checks the
# Deployments. Run `helm dependency build charts/modulariot` first.
set -euo pipefail
chart="$(cd "$(dirname "$0")/.." && pwd)"

deployments() {
  helm template rel "$chart" "$@" \
    | yq -r 'select(.kind == "Deployment" and (.metadata.name | test("modulith|symptoms-engine")))
             | [.metadata.name, .spec.replicas,
                (.spec.template.spec.containers[0].env[]
                 | select(.name | test("^MIOT_COMPONENT_(FLEET|SYMPTOMS)_ENABLED$"))
                 | .name + "=" + .value)] | join(" ")' \
    | sed '/^$/d'
}

default_out="$(deployments)"
enabled_out="$(deployments --set miot-symptoms-engine.enabled=true)"

echo "default:"; echo "$default_out"
echo "engine enabled:"; echo "$enabled_out"

expected_default="rel-miot-modulith 1 MIOT_COMPONENT_FLEET_ENABLED=true MIOT_COMPONENT_SYMPTOMS_ENABLED=false"
expected_enabled="$expected_default
rel-miot-symptoms-engine 2 MIOT_COMPONENT_FLEET_ENABLED=false MIOT_COMPONENT_SYMPTOMS_ENABLED=true"

[[ "$default_out" == "$expected_default" ]] || { echo "unexpected default render" >&2; exit 1; }
[[ "$enabled_out" == "$expected_enabled" ]] || { echo "unexpected render with engine enabled" >&2; exit 1; }
if helm template rel "$chart" --set miot-symptoms-engine.enabled=true \
    | yq -e 'select(.kind == "Service" and .metadata.name == "rel-miot-symptoms-engine")' >/dev/null 2>&1; then
  echo "engine must not render a Service by default" >&2; exit 1
fi
echo OK
