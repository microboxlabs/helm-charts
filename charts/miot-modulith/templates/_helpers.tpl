{{/*
Expand the name of the chart.
*/}}
{{- define "miot-modulith.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "miot-modulith.fullname" -}}
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
{{- define "miot-modulith.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
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
Get the OIDC credentials secret name
*/}}
{{- define "miot-modulith.oidcSecretName" -}}
{{- if .Values.oidc.existingSecret }}
{{- .Values.oidc.existingSecret }}
{{- else }}
{{- include "miot-modulith.fullname" . }}-oidc-credentials
{{- end }}
{{- end }}
