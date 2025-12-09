{{/*
Expand the name of the chart.
*/}}
{{- define "greenwatt.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "greenwatt.fullname" -}}
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
{{- define "greenwatt.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "greenwatt.labels" -}}
helm.sh/chart: {{ include "greenwatt.chart" . }}
{{ include "greenwatt.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "greenwatt.selectorLabels" -}}
app.kubernetes.io/name: {{ include "greenwatt.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Backend labels
*/}}
{{- define "greenwatt.backend.labels" -}}
{{ include "greenwatt.labels" . }}
app: greenwatt
component: backend
{{- end }}

{{- define "greenwatt.backend.selectorLabels" -}}
app: greenwatt
component: backend
{{- end }}

{{/*
Frontend labels
*/}}
{{- define "greenwatt.frontend.labels" -}}
{{ include "greenwatt.labels" . }}
app: greenwatt
component: frontend
{{- end }}

{{- define "greenwatt.frontend.selectorLabels" -}}
app: greenwatt
component: frontend
{{- end }}

{{/*
Postgres labels
*/}}
{{- define "greenwatt.postgres.labels" -}}
{{ include "greenwatt.labels" . }}
app: greenwatt
component: postgres
{{- end }}

{{- define "greenwatt.postgres.selectorLabels" -}}
app: greenwatt
component: postgres
{{- end }}

{{/*
Redis labels
*/}}
{{- define "greenwatt.redis.labels" -}}
{{ include "greenwatt.labels" . }}
app: greenwatt
component: redis
{{- end }}

{{- define "greenwatt.redis.selectorLabels" -}}
app: greenwatt
component: redis
{{- end }}

{{/*
Namespace - Use Release.Namespace (set by -n flag during install)
*/}}
{{- define "greenwatt.namespace" -}}
{{- .Release.Namespace }}
{{- end }}
