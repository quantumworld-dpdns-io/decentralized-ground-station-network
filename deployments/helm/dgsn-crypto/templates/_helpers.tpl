{{- define "dgsn-crypto.fullname" -}}
{{- printf "%s-%s" .Release.Name "crypto" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "dgsn-crypto.labels" -}}
helm.sh/chart: "{{ .Chart.Name }}-{{ .Chart.Version }}"
app.kubernetes.io/name: dgsn-crypto
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: crypto
{{- end -}}

{{- define "dgsn-crypto.selectorLabels" -}}
app.kubernetes.io/name: dgsn-crypto
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
