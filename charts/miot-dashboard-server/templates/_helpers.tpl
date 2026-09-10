{{/*
Expand the name of the chart.
*/}}
{{- define "miot-dashboard-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "miot-dashboard-server.fullname" -}}
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
{{- define "miot-dashboard-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "miot-dashboard-server.labels" -}}
helm.sh/chart: {{ include "miot-dashboard-server.chart" . }}
{{ include "miot-dashboard-server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "miot-dashboard-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "miot-dashboard-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "miot-dashboard-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "miot-dashboard-server.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of the Secret this chart creates for credentials given as literals.
*/}}
{{- define "miot-dashboard-server.credentialsSecretName" -}}
{{- printf "%s-credentials" (include "miot-dashboard-server.fullname" .) }}
{{- end }}

{{/*
Every credential channel, so the Secret and the env block agree on what exists
without either restating the list.
*/}}
{{- define "miot-dashboard-server.credentialChannels" -}}
{{- $jwt := .Values.auth.jwt -}}
{{- list
      (dict "literal" $jwt.publicKey.value "existingSecret" $jwt.publicKey.existingSecret "managedKey" "jwt-public-key")
      (dict "literal" $jwt.secret.value "existingSecret" $jwt.secret.existingSecret "managedKey" "jwt-secret")
      (dict "literal" .Values.store.postgres.url "existingSecret" .Values.store.postgres.existingSecret "managedKey" "postgres-url")
      (dict "literal" .Values.tenants.serviceValue "existingSecret" .Values.tenants.existingSecret "managedKey" "tenants-service-value")
      (dict "literal" .Values.scopes.serviceValue "existingSecret" .Values.scopes.existingSecret "managedKey" "scopes-service-value")
   | toJson -}}
{{- end }}

{{/*
Whether any credential was given as a literal, and so needs a chart-managed
Secret. A channel that names an existingSecret contributes nothing.
*/}}
{{- define "miot-dashboard-server.shouldRenderCredentialsSecret" -}}
{{- $needed := false -}}
{{- range (include "miot-dashboard-server.credentialChannels" . | fromJsonArray) -}}
{{- if and (not .existingSecret) .literal -}}{{- $needed = true -}}{{- end -}}
{{- end -}}
{{- $needed -}}
{{- end }}

{{/*
secretKeyRef body for one credential channel.
Arguments: (list root channel managedKey)
*/}}
{{- define "miot-dashboard-server.credentialRef" -}}
{{- $root := index . 0 -}}
{{- $channel := index . 1 -}}
{{- $managedKey := index . 2 -}}
{{- if $channel.existingSecret -}}
name: {{ $channel.existingSecret }}
key: {{ $channel.existingSecretKey }}
{{- else -}}
name: {{ include "miot-dashboard-server.credentialsSecretName" $root }}
key: {{ $managedKey }}
{{- end -}}
{{- end }}

{{/*
An env var whose value came from configuration. Rendered when the value is
anything other than unset — an explicit 0 or false is a setting, not an
omission, and `with` would silently drop both.
Arguments: (list name value)
*/}}
{{- define "miot-dashboard-server.envIfSet" -}}
{{- $name := index . 0 -}}
{{- $value := index . 1 -}}
{{- if not (or (kindIs "invalid" $value) (eq (toString $value) "")) }}
- name: {{ $name }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}

{{/*
The container environment. Keys with a concrete value are always rendered;
everything else appears only when set, so the server's own defaults stay the
single source of truth for what "unset" means.
*/}}
{{- define "miot-dashboard-server.env" -}}
{{- $store := .Values.store -}}
{{- $jwt := .Values.auth.jwt -}}
{{- $data := trimSuffix "/" .Values.persistence.mountPath -}}
- name: PORT
  value: {{ .Values.service.port | quote }}
- name: MIOT_DASHBOARD_STORE
  value: {{ $store.kind | quote }}
{{- if eq $store.kind "sqlite" }}
- name: MIOT_DASHBOARD_SQLITE_PATH
  value: {{ printf "%s/dashboards.db" $data | quote }}
{{- end }}
{{- if eq $store.kind "postgres" }}
- name: MIOT_DASHBOARD_POSTGRES_URL
  valueFrom:
    secretKeyRef:
      {{- include "miot-dashboard-server.credentialRef" (list . $store.postgres "postgres-url") | nindent 6 }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_POSTGRES_POOL_SIZE" $store.postgres.poolSize) }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_POSTGRES_CONNECTION_TIMEOUT" $store.postgres.connectionTimeoutMs) }}
{{- end }}
{{- /* The server refuses MIOT_DASHBOARD_DOCUMENTS with the memory store rather
       than ignoring it, so it is rendered only where it means something. */}}
{{- if ne $store.kind "memory" }}
- name: MIOT_DASHBOARD_DOCUMENTS
  value: {{ .Values.documents.kind | quote }}
{{- if eq .Values.documents.kind "fs" }}
- name: MIOT_DASHBOARD_DOCUMENTS_PATH
  value: {{ printf "%s/documents" $data | quote }}
{{- end }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_DOCUMENTS_BUCKET" .Values.documents.bucket) }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_DOCUMENTS_PREFIX" .Values.documents.prefix) }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_S3_REGION" .Values.documents.region) }}
{{- end }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_ORPHAN_SWEEP_INTERVAL" .Values.orphan.sweepIntervalSeconds) }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_ORPHAN_MIN_AGE" .Values.orphan.minAgeSeconds) }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_SEED" .Values.seed.path) }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_BASE_PATH" .Values.basePath) }}
- name: MIOT_DASHBOARD_DOCS
  value: {{ .Values.docs | quote }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_CORS_ORIGINS" (join "," .Values.cors.origins)) }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_CORS_HEADERS" (join "," .Values.cors.headers)) }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_CORS_CREDENTIALS" .Values.cors.credentials) }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_JWT_ISSUER" $jwt.issuer) }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_JWT_AUDIENCE" $jwt.audience) }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_JWT_JWKS_URL" $jwt.jwksUrl) }}
{{- /* Exactly one key source may be configured: the algorithm is derived from
       which one it is, so "accept either" cannot be asked for. */}}
{{- if or $jwt.publicKey.value $jwt.publicKey.existingSecret }}
- name: MIOT_DASHBOARD_JWT_PUBLIC_KEY
  valueFrom:
    secretKeyRef:
      {{- include "miot-dashboard-server.credentialRef" (list . $jwt.publicKey "jwt-public-key") | nindent 6 }}
{{- end }}
{{- if or $jwt.secret.value $jwt.secret.existingSecret }}
- name: MIOT_DASHBOARD_JWT_SECRET
  valueFrom:
    secretKeyRef:
      {{- include "miot-dashboard-server.credentialRef" (list . $jwt.secret "jwt-secret") | nindent 6 }}
{{- end }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_JWT_USER_CLAIM" $jwt.claims.user) }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_JWT_GROUPS_CLAIM" $jwt.claims.groups) }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_JWT_NAME_CLAIM" $jwt.claims.displayName) }}
{{- include "miot-dashboard-server.envIfSet" (list "MIOT_DASHBOARD_JWT_CLOCK_TOLERANCE" $jwt.clockToleranceSeconds) }}
{{- include "miot-dashboard-server.authorityEnv" (list . .Values.tenants "TENANTS" "tenants-service-value") }}
{{- include "miot-dashboard-server.authorityEnv" (list . .Values.scopes "SCOPES" "scopes-service-value") }}
{{- end }}

{{/*
The tenant and scope authorities are configured the same way, over the same
variable names under a different prefix, so one template renders both.
`entitledPath` belongs to tenants and `rolePath`/`roleMap` to scopes; each is
absent from the other's values, and an absent key renders nothing.
Arguments: (list root authority prefix managedKey)
*/}}
{{- define "miot-dashboard-server.authorityEnv" -}}
{{- $root := index . 0 -}}
{{- $authority := index . 1 -}}
{{- $prefix := index . 2 -}}
{{- $managedKey := index . 3 -}}
{{- if $authority.url }}
- name: MIOT_DASHBOARD_{{ $prefix }}_URL
  value: {{ $authority.url | quote }}
{{- include "miot-dashboard-server.envIfSet" (list (printf "MIOT_DASHBOARD_%s_METHOD" $prefix) $authority.method) }}
{{- include "miot-dashboard-server.envIfSet" (list (printf "MIOT_DASHBOARD_%s_ENTITLED_PATH" $prefix) $authority.entitledPath) }}
{{- include "miot-dashboard-server.envIfSet" (list (printf "MIOT_DASHBOARD_%s_ROLE_PATH" $prefix) $authority.rolePath) }}
{{- include "miot-dashboard-server.envIfSet" (list (printf "MIOT_DASHBOARD_%s_ROLE_MAP" $prefix) $authority.roleMap) }}
{{- include "miot-dashboard-server.envIfSet" (list (printf "MIOT_DASHBOARD_%s_ABSENT_STATUS" $prefix) $authority.absentStatus) }}
{{- include "miot-dashboard-server.envIfSet" (list (printf "MIOT_DASHBOARD_%s_CACHE" $prefix) $authority.cacheSeconds) }}
{{- include "miot-dashboard-server.envIfSet" (list (printf "MIOT_DASHBOARD_%s_NEGATIVE_CACHE" $prefix) $authority.negativeCacheSeconds) }}
{{- include "miot-dashboard-server.envIfSet" (list (printf "MIOT_DASHBOARD_%s_TIMEOUT" $prefix) $authority.timeoutMs) }}
{{- include "miot-dashboard-server.envIfSet" (list (printf "MIOT_DASHBOARD_%s_SERVICE_HEADER" $prefix) $authority.serviceHeader) }}
{{- if or $authority.serviceValue $authority.existingSecret }}
- name: MIOT_DASHBOARD_{{ $prefix }}_SERVICE_VALUE
  valueFrom:
    secretKeyRef:
      {{- include "miot-dashboard-server.credentialRef" (list $root $authority $managedKey) | nindent 6 }}
{{- end }}
{{- end }}
{{- end }}
