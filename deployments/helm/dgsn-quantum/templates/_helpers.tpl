{{- define "dgsn-quantum.fullname" -}}
{{- printf "%s-%s" .Release.Name "quantum" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "dgsn-quantum.labels" -}}
helm.sh/chart: "{{ .Chart.Name }}-{{ .Chart.Version }}"
app.kubernetes.io/name: dgsn-quantum
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: quantum
{{- end -}}

{{- define "dgsn-quantum.selectorLabels" -}}
app.kubernetes.io/name: dgsn-quantum
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
