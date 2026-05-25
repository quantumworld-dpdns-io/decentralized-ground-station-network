{{- define "dgsn-signal.fullname" -}}
{{- printf "%s-%s" .Release.Name "signal" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "dgsn-signal.labels" -}}
helm.sh/chart: "{{ .Chart.Name }}-{{ .Chart.Version }}"
app.kubernetes.io/name: dgsn-signal
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: signal
{{- end -}}

{{- define "dgsn-signal.selectorLabels" -}}
app.kubernetes.io/name: dgsn-signal
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
