{{- define "dgsn-infra.fullname" -}}
{{- printf "%s-%s" .Release.Name "infra" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "dgsn-infra.labels" -}}
helm.sh/chart: "{{ .Chart.Name }}-{{ .Chart.Version }}"
app.kubernetes.io/name: dgsn-infra
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
