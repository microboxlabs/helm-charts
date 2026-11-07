{{/*
Expand the name of the chart.
*/}}
{{- define "miot-modulith.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
The primary chart reuses release names containing its name for compatibility.
Aliases always append their name so a release containing both chart names
cannot collapse the two instances onto the same resource names.
*/}}
{{- define "miot-modulith.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if and (eq .Chart.Name "miot-modulith") (contains $name .Release.Name) }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "miot-modulith.chart" -}}
{{- printf "%s-%s" .Chart.Name (.Values.chartLabelVersion | default .Chart.Version) | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "miot-modulith.labels" -}}
helm.sh/chart: {{ include "miot-modulith.chart" . }}
{{ include "miot-modulith.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "miot-modulith.selectorLabels" -}}
app.kubernetes.io/name: {{ include "miot-modulith.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "miot-modulith.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "miot-modulith.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the JDBC database URL (used by Flyway and JDBC datasource)
*/}}
{{- define "miot-modulith.databaseJdbcUrl" -}}
jdbc:postgresql://{{ .Values.postgresql.external.host }}:{{ .Values.postgresql.external.port }}/{{ .Values.postgresql.external.database }}
{{- end }}

{{/*
Create the reactive database URL (used by Hibernate Reactive Panache)
Note: no jdbc: prefix — this is the Vert.x reactive pg client format.
*/}}
{{- define "miot-modulith.databaseReactiveUrl" -}}
postgresql://{{ .Values.postgresql.external.host }}:{{ .Values.postgresql.external.port }}/{{ .Values.postgresql.external.database }}
{{- end }}

{{/*
Get the database credentials secret name
*/}}
{{- define "miot-modulith.databaseSecretName" -}}
{{- if .Values.postgresql.external.existingSecret }}
{{- .Values.postgresql.external.existingSecret }}
{{- else }}
{{- include "miot-modulith.fullname" . }}-db-credentials
{{- end }}
{{- end }}

{{/*
Get the OIDC credentials secret name (DEPRECATED — kept for backwards compat)
*/}}
{{- define "miot-modulith.oidcSecretName" -}}
{{- if .Values.oidc.existingSecret }}
{{- .Values.oidc.existingSecret }}
{{- else }}
{{- include "miot-modulith.fullname" . }}-oidc-credentials
{{- end }}
{{- end }}

{{/*
Get the Auth0 credentials secret name
*/}}
{{- define "miot-modulith.authSecretName" -}}
{{- if .Values.auth.existingSecret }}
{{- .Values.auth.existingSecret }}
{{- else }}
{{- include "miot-modulith.fullname" . }}-auth-credentials
{{- end }}
{{- end }}

{{/*
Name of the ConfigMap mounted at /config/fork, or empty when none.
*/}}
{{- define "miot-modulith.forkFiltersConfigMap" -}}
{{- if .Values.fork.existingFiltersConfigMap }}
{{- .Values.fork.existingFiltersConfigMap }}
{{- else if .Values.fork.filters }}
{{- include "miot-modulith.fullname" . }}-fork-filters
{{- end }}
{{- end }}

{{/*
Name of the ConfigMap mounted at /config/symptoms, or empty when none.
*/}}
{{- define "miot-modulith.symptomsRoutesConfigMap" -}}
{{- if .Values.symptoms.existingRoutesConfigMap }}
{{- .Values.symptoms.existingRoutesConfigMap }}
{{- else if .Values.symptoms.routes }}
{{- include "miot-modulith.fullname" . }}-symptoms-routes
{{- end }}
{{- end }}
