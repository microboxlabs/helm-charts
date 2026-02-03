{{/*
Expand the name of the chart.
*/}}
{{- define "miot-calendar.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "miot-calendar.fullname" -}}
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
{{- define "miot-calendar.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "miot-calendar.labels" -}}
helm.sh/chart: {{ include "miot-calendar.chart" . }}
{{ include "miot-calendar.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "miot-calendar.selectorLabels" -}}
app.kubernetes.io/name: {{ include "miot-calendar.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "miot-calendar.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "miot-calendar.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the database URL
*/}}
{{- define "miot-calendar.databaseUrl" -}}
{{- if .Values.postgresql.external.enabled }}
jdbc:postgresql://{{ .Values.postgresql.external.host }}:{{ .Values.postgresql.external.port }}/{{ .Values.postgresql.external.database }}
{{- end }}
{{- end }}

{{/*
Get the database username
*/}}
{{- define "miot-calendar.databaseUsername" -}}
{{- if .Values.postgresql.external.existingSecret }}
{{- else }}
{{- .Values.postgresql.external.username }}
{{- end }}
{{- end }}

{{/*
Get the database password secret name
*/}}
{{- define "miot-calendar.databaseSecretName" -}}
{{- if .Values.postgresql.external.existingSecret }}
{{- .Values.postgresql.external.existingSecret }}
{{- else }}
{{- include "miot-calendar.fullname" . }}-db-credentials
{{- end }}
{{- end }}
