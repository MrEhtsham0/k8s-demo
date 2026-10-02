{{/*
Step 3: Shared helpers — chart name, labels, etc.
*/}}
{{- define "k8s-python.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "k8s-python.fullname" -}}
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

{{- define "k8s-python.labels" -}}
app.kubernetes.io/name: {{ include "k8s-python.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app: {{ include "k8s-python.fullname" . }}
{{- end }}

{{- define "k8s-python.selectorLabels" -}}
app: {{ include "k8s-python.fullname" . }}
{{- end }}

{{- define "k8s-python.postgresDatabaseUrl" -}}
postgresql+asyncpg://{{ .Values.postgres.user }}:{{ .Values.postgres.password }}@{{ .Values.postgres.name }}:5432/{{ .Values.postgres.database }}
{{- end }}
