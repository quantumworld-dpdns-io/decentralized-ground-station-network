{{/* Expand the name of the chart. */}}
{{- define "dgsn-backend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Create a default fully qualified app name. We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec). If release name contains chart name it will be used as a full name. */}}
{{- define "dgsn-backend.fullname" -}}
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

{{/* Create chart name and version as used by the chart label. */}}
{{- define "dgsn-backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Common labels */}}
{{- define "dgsn-backend.labels" -}}
app.kubernetes.io/name: {{ include "dgsn-backend.name" . }}
helm.sh/chart: {{ include "dgsn-backend.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels */}}
{{- define "dgsn-backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dgsn-backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Service account name */}}
{{- define "dgsn-backend.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "dgsn-backend.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
