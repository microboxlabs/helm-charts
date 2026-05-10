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
for it. Kept as a helper so secret.yaml's render-gate and deployment.yaml's
secretKeyRef gates stay in lockstep.
*/}}
{{- define "miot-harness.shouldRenderCredentialsSecret" -}}
{{- if or
      (and (not .Values.nexo.existingSecret) .Values.nexo.dsn)
      (and (not .Values.anthropic.existingSecret) .Values.anthropic.apiKey)
      (and (not .Values.openai.existingSecret) .Values.openai.apiKey)
}}true{{- end }}
{{- end }}

{{/*
Per-credential Secret name + key. Each helper returns the `existingSecret`
when set, else the chart-managed Secret name + canonical key. Mirrors
miot-calendar's `databaseSecretName` pattern.
*/}}

{{- define "miot-harness.nexoSecretName" -}}
{{- if .Values.nexo.existingSecret }}
{{- .Values.nexo.existingSecret }}
{{- else }}
{{- include "miot-harness.credentialsSecretName" . }}
{{- end }}
{{- end }}

{{- define "miot-harness.nexoSecretKey" -}}
{{- if .Values.nexo.existingSecret }}
{{- .Values.nexo.existingSecretKey | default "dsn" }}
{{- else }}
{{- "nexo-dsn" }}
{{- end }}
{{- end }}

{{- define "miot-harness.anthropicSecretName" -}}
{{- if .Values.anthropic.existingSecret }}
{{- .Values.anthropic.existingSecret }}
{{- else }}
{{- include "miot-harness.credentialsSecretName" . }}
{{- end }}
{{- end }}

{{- define "miot-harness.anthropicSecretKey" -}}
{{- if .Values.anthropic.existingSecret }}
{{- .Values.anthropic.existingSecretKey | default "api-key" }}
{{- else }}
{{- "anthropic-api-key" }}
{{- end }}
{{- end }}

{{- define "miot-harness.openaiSecretName" -}}
{{- if .Values.openai.existingSecret }}
{{- .Values.openai.existingSecret }}
{{- else }}
{{- include "miot-harness.credentialsSecretName" . }}
{{- end }}
{{- end }}

{{- define "miot-harness.openaiSecretKey" -}}
{{- if .Values.openai.existingSecret }}
{{- .Values.openai.existingSecretKey | default "api-key" }}
{{- else }}
{{- "openai-api-key" }}
{{- end }}
{{- end }}
