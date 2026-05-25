{{- define "dgsn-frontend.fullname" -}}
{{- printf "%s-%s" .Release.Name "frontend" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "dgsn-frontend.labels" -}}
helm.sh/chart: "{{ .Chart.Name }}-{{ .Chart.Version }}"
app.kubernetes.io/name: dgsn-frontend
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: frontend
{{- end -}}

{{- define "dgsn-frontend.selectorLabels" -}}
app.kubernetes.io/name: dgsn-frontend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
