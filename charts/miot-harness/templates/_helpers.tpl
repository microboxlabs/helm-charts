{{/*
Expand the name of the chart.
*/}}
{{- define "miot-harness.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "miot-harness.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "miot-harness.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "miot-harness.labels" -}}
helm.sh/chart: {{ include "miot-harness.chart" . }}
{{ include "miot-harness.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "miot-harness.selectorLabels" -}}
app.kubernetes.io/name: {{ include "miot-harness.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "miot-harness.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "miot-harness.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Credentials Secret name (chart-managed). Returns the same fullname-suffixed
Secret used when any credential takes the literal-value path. Per-credential
helpers below pick this name OR the user-provided `existingSecret`.
*/}}
{{- define "miot-harness.credentialsSecretName" -}}
{{- printf "%s-credentials" (include "miot-harness.fullname" .) }}
{{- end }}

{{/*
Whether to render the chart-managed credentials Secret. True iff at least
one credential is supplied as a literal value AND no existingSecret is set
for it. Kept as a helper so secret.yaml's render-gate and the env helper's
secretKeyRef gates stay in lockstep.
*/}}
{{- define "miot-harness.shouldRenderCredentialsSecret" -}}
{{- $lf := .Values.observability.langfuse }}
{{- if or
      (and (not .Values.datasource.existingSecret) .Values.datasource.dsn)
      (and (not .Values.anthropic.existingSecret) .Values.anthropic.apiKey)
      (and (not .Values.openai.existingSecret) .Values.openai.apiKey)
      (and (not .Values.google.existingSecret) .Values.google.apiKey)
      (and (not $lf.existingSecret) (or $lf.publicKey $lf.secretKey))
      (and (not .Values.identity.existingSecret) .Values.identity.signingKey)
}}true{{- end }}
{{- end }}

{{/*
secretKeyRef body (name + key) for one credential channel. Args (list):
  0: root context
  1: channel block — needs `existingSecret` and `existingSecretKey` fields
  2: default key inside the existingSecret
  3: canonical key inside the chart-managed credentials Secret
Returns the `existingSecret` reference when set, else points at the
chart-managed Secret. Mirrors miot-calendar's `databaseSecretName` pattern.
*/}}
{{- define "miot-harness.credentialRef" -}}
{{- $root := index . 0 -}}
{{- $channel := index . 1 -}}
{{- $defaultKey := index . 2 -}}
{{- $managedKey := index . 3 -}}
{{- if $channel.existingSecret -}}
name: {{ $channel.existingSecret }}
key: {{ $channel.existingSecretKey | default $defaultKey }}
{{- else -}}
name: {{ include "miot-harness.credentialsSecretName" $root }}
key: {{ $managedKey }}
{{- end -}}
{{- end }}

{{/*
Container env for the harness. Three groups:
  1. Always-rendered contract vars (concrete chart defaults).
  2. Optional knobs — rendered only when the value is set (non-null and
     non-empty), so unset keys fall back to the harness built-in defaults
     and the chart never re-states them. Explicit `false` / `0` ARE
     rendered (e.g. agents.synthesizerStream kill switch).
  3. Credentials via secretKeyRef (never literal values).
*/}}
{{- define "miot-harness.env" -}}
# Process / runtime
- name: MIOT_HARNESS_ENV
  value: {{ .Values.env | quote }}
- name: MIOT_HARNESS_LOG_LEVEL
  value: {{ .Values.logLevel | quote }}
- name: MIOT_HARNESS_DEFAULT_TENANT_ID
  value: {{ .Values.defaultTenantId | quote }}
- name: MIOT_HARNESS_DEFAULT_USER_ID
  value: {{ .Values.defaultUserId | quote }}
- name: MIOT_HARNESS_REQUEST_ID_HEADER
  value: {{ .Values.requestIdHeader | quote }}
{{- if .Values.contextSkills.writable }}
# Writable operator-managed context and skill overlays live on the workspace
# volume rather than the read-only image filesystem.
- name: MIOT_HARNESS_CONTEXT_DIR
  value: "/app/.miot-workspace/context"
- name: MIOT_HARNESS_SKILLS_DIR
  value: "/app/.miot-workspace/skills"
{{- end }}
# Datasource seam (modulariot#604)
- name: MIOT_HARNESS_DATASOURCE_KIND
  value: {{ .Values.datasource.kind | quote }}
- name: MIOT_HARNESS_DATASOURCE_APPLICATION_NAME
  value: {{ .Values.datasource.applicationName | quote }}
# Auth0 RS256 defense-in-depth. issuer/JWKS/audience are public, so they
# ride plain values (no Secret). The lifespan fails fast if auth.enabled
# is true with any field unset.
- name: MIOT_HARNESS_AUTH_ENABLED
  value: {{ .Values.auth.enabled | quote }}
{{- if .Values.auth.enabled }}
- name: AUTH0_ISSUER
  value: {{ .Values.auth.issuer | quote }}
- name: AUTH0_JWKS_URL
  value: {{ .Values.auth.jwksUrl | quote }}
- name: AUTH0_RS256_AUDIENCE
  value: {{ .Values.auth.rs256Audience | quote }}
{{- end }}
# Optional knobs — unset (null/empty) means the harness default applies.
{{- range $pair := list
    (list "MIOT_HARNESS_ALLOW_DEBUG_TENANTS" .Values.allowDebugTenants)
    (list "MIOT_HARNESS_DATASOURCE_TENANT_LOCK" .Values.datasource.tenantLock)
    (list "MIOT_HARNESS_DATASOURCE_FRESHNESS_WARN_MINUTES" .Values.datasource.freshnessWarnMinutes)
    (list "MIOT_HARNESS_DATASOURCE_FRESHNESS_REFUSE_MINUTES" .Values.datasource.freshnessRefuseMinutes)
    (list "MIOT_HARNESS_NEXO_SEARCH_PATH" .Values.nexo.searchPath)
    (list "MIOT_HARNESS_NEXO_EXPLAIN_COST_THRESHOLD" .Values.nexo.explainCostThreshold)
    (list "MIOT_HARNESS_AGENTS_MAX_TURNS" .Values.agents.maxTurns)
    (list "MIOT_HARNESS_AGENTS_CRITIC_ENABLED" .Values.agents.criticEnabled)
    (list "MIOT_HARNESS_AGENTS_SUPERVISOR_MODE" .Values.agents.supervisorMode)
    (list "MIOT_HARNESS_AGENTS_FILTER_EXPERT_MODEL" .Values.agents.models.filterExpert)
    (list "MIOT_HARNESS_AGENTS_ANALYST_MODEL" .Values.agents.models.analyst)
    (list "MIOT_HARNESS_AGENTS_SYNTHESIZER_MODEL" .Values.agents.models.synthesizer)
    (list "MIOT_HARNESS_AGENTS_CRITIC_MODEL" .Values.agents.models.critic)
    (list "MIOT_HARNESS_AGENTS_SUMMARIZER_MODEL" .Values.agents.models.summarizer)
    (list "MIOT_HARNESS_AGENTS_SYNTHESIZER_STREAM" .Values.agents.synthesizerStream)
    (list "MIOT_HARNESS_AGENTS_SYNTHESIZER_THINKING_BUDGET" .Values.agents.synthesizerThinkingBudget)
    (list "MIOT_HARNESS_INTENT_ROUTER_MODEL" .Values.intentRouter.model)
    (list "MIOT_HARNESS_INTENT_ROUTER_CONFIDENCE_THRESHOLD" .Values.intentRouter.confidenceThreshold)
    (list "MIOT_HARNESS_CONVERSATION_TOKEN_BUDGET" .Values.conversationTokenBudget)
    (list "MIOT_HARNESS_IDENTITY_SKEW_SECONDS" .Values.identity.skewSeconds)
    (list "MIOT_HARNESS_LANGFUSE_HOST" .Values.observability.langfuse.host)
}}
{{- $name := index $pair 0 }}
{{- $value := index $pair 1 }}
{{- if and (not (kindIs "invalid" $value)) (ne (toString $value) "") }}
- name: {{ $name }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
{{- if .Values.observability.otel.enabled }}
# OTel exporter (off by default — nothing rendered when disabled).
- name: MIOT_HARNESS_OTEL_ENABLED
  value: "true"
{{- with .Values.observability.otel.endpoint }}
- name: MIOT_HARNESS_OTEL_ENDPOINT
  value: {{ . | quote }}
{{- end }}
{{- with .Values.observability.otel.serviceName }}
- name: MIOT_HARNESS_OTEL_SERVICE_NAME
  value: {{ . | quote }}
{{- end }}
- name: MIOT_HARNESS_OTEL_ENVIRONMENT
  value: {{ .Values.observability.otel.environment | default .Values.env | quote }}
{{- end }}
# Credentials. Always projected via secretKeyRef so values never appear
# in `kubectl describe pod`. Each ref resolves to the user-provided
# existingSecret, or to the chart-managed Secret (templates/secret.yaml)
# when the literal-value path is used.
{{- if or .Values.datasource.existingSecret .Values.datasource.dsn }}
- name: MIOT_HARNESS_DATASOURCE_DSN
  valueFrom:
    secretKeyRef:
      {{- include "miot-harness.credentialRef" (list . .Values.datasource "dsn" "datasource-dsn") | nindent 6 }}
{{- end }}
{{- if or .Values.anthropic.existingSecret .Values.anthropic.apiKey }}
- name: ANTHROPIC_API_KEY
  valueFrom:
    secretKeyRef:
      {{- include "miot-harness.credentialRef" (list . .Values.anthropic "api-key" "anthropic-api-key") | nindent 6 }}
{{- end }}
{{- if or .Values.openai.existingSecret .Values.openai.apiKey }}
- name: OPENAI_API_KEY
  valueFrom:
    secretKeyRef:
      {{- include "miot-harness.credentialRef" (list . .Values.openai "api-key" "openai-api-key") | nindent 6 }}
{{- end }}
{{- if or .Values.google.existingSecret .Values.google.apiKey }}
- name: GOOGLE_API_KEY
  valueFrom:
    secretKeyRef:
      {{- include "miot-harness.credentialRef" (list . .Values.google "api-key" "google-api-key") | nindent 6 }}
{{- end }}
{{- $lf := .Values.observability.langfuse }}
{{- if or $lf.existingSecret $lf.publicKey }}
- name: MIOT_HARNESS_LANGFUSE_PUBLIC_KEY
  valueFrom:
    secretKeyRef:
      {{- include "miot-harness.credentialRef" (list . (dict "existingSecret" $lf.existingSecret "existingSecretKey" $lf.existingSecretKeys.publicKey) "public-key" "langfuse-public-key") | nindent 6 }}
{{- end }}
{{- if or $lf.existingSecret $lf.secretKey }}
- name: MIOT_HARNESS_LANGFUSE_SECRET_KEY
  valueFrom:
    secretKeyRef:
      {{- include "miot-harness.credentialRef" (list . (dict "existingSecret" $lf.existingSecret "existingSecretKey" $lf.existingSecretKeys.secretKey) "secret-key" "langfuse-secret-key") | nindent 6 }}
{{- end }}
{{- if or .Values.identity.existingSecret .Values.identity.signingKey }}
- name: MIOT_HARNESS_IDENTITY_SIGNING_KEY
  valueFrom:
    secretKeyRef:
      {{- include "miot-harness.credentialRef" (list . .Values.identity "signing-key" "identity-signing-key") | nindent 6 }}
{{- end }}
{{- end }}
