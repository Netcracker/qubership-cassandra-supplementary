{{/*
[Cassandra Operator Core] Docker image
Dictionary with:
1. "deployName" - deploy-param from description.yaml
2. "SERVICE_NAME" - name of service with git group and git repo
3. "vals" - .Values
4.  "default" - default docker image
{{template "find_image" (dict "deployName" "cassandraOperator" "SERVICE_NAME" "cassandra-operator" "vals" .Values "default" .Values.operator.dockerImage) }}
*/}}

{{- define "find_image" -}}
  {{- $image := .default -}}

  {{- if .vals.deployDescriptor -}}
    {{- if index .vals.deployDescriptor .deployName -}}
      {{- $image = (index .vals.deployDescriptor .deployName "image") -}}
    {{- else if index .vals.deployDescriptor .SERVICE_NAME -}}
      {{- $image = (index .vals.deployDescriptor .SERVICE_NAME "image") -}}
    {{- end -}}
  {{- end -}}

  {{ printf "%s" $image }}
{{- end -}}


{{/*
[Cassandra Operator Core] returns value from ENV if it exists there, otherwise from default
Dictionary with:
1. "envName" - name of env var to get value from
2.  "default" - default value from values.yaml
{{template "fromEnv" (dict "envName" ".Values.VAULT_ADDR" "default" .Values.vaultRegistration.token) }}
*/}}
{{- define "fromEnv" -}}
  {{- $envValue := .envName -}}
{{- if and (ne ($envValue | toString) "<nil>") (ne ($envValue | toString) "") -}}
    {{- .envName -}}
  {{- else -}}
    {{- .default -}}
  {{- end -}}
{{- end -}}


{{/*
Dictionary with:
Uses value from values.yaml if defined, otherwise value from environment variable if defined, else - default
1. "dotVar" - parameter defined with dots like dbaas.install
2. "enVar" - parameter defined as environment variable like DBAAS_ENABLED
3.  "default" - default value
{{template "fromValuesThenEnvElseDefault" (dict "dotVar" .Values.dbaas.install "envVar" .Values.DBAAS_ENABLED "default" true ) }}
*/}}
{{- define "fromValuesThenEnvElseDefault" -}}
  {{- if and (ne (.dotVar | toString) "<nil>") (ne (.dotVar | toString) "") -}}
    {{- .dotVar -}}
  {{- else if and (ne (.envVar | toString) "<nil>") (ne (.envVar | toString) "") -}}
    {{- .envVar -}}
  {{- else -}}
    {{- .default -}}
  {{- end -}}
{{- end -}}

{{/*
[Cassandra Operator Core] from env of from values
Dictionary with:
1. "envName" - name of env var to get value from
2.  "default" - default value from values.yaml
{{template "ifEnvThenDefault" (dict "envName" .Values.VAULT_ADDR "then" (printf %s_%s .Values.VAULT_ADDR "const" ) "default" .Values.vaultRegistration.token) }}
*/}}
{{- define "ifEnvThenDefault" -}}
  {{- $value := .default -}}
  {{- if .envName -}}
    {{- $value = .then -}}
  {{- else -}}
    {{- $value = .default -}}
  {{- end -}}
  {{- if $value -}}
  {{ printf "%s" $value }}
  {{- end -}}
{{- end -}}

{{/*
DNS names used to generate SSL certificate with "Subject Alternative Name" field
*/}}
{{- define "dbaasAdapter.certDnsNames" -}}
  {{- $dnsNames := list "localhost" "dbaas-cassandra-adapter" (printf "%s.%s" "dbaas-cassandra-adapter" .Release.Namespace) (printf "%s.%s.svc" "dbaas-cassandra-adapter" .Release.Namespace) -}}
  {{- $dnsNames = concat $dnsNames .Values.tls.generateCerts.subjectAlternativeName.additionalDnsNames -}}
  {{- $dnsNames | toYaml -}}
{{- end -}}
{{/*
IP addresses used to generate SSL certificate with "Subject Alternative Name" field
*/}}
{{- define "backupDaemon.certDnsNames" -}}
  {{- $dnsNames := list "localhost" "cassandra-backup-daemon" (printf "%s.%s" "cassandra-backup-daemon" .Release.Namespace) (printf "%s.%s.svc" "cassandra-backup-daemon" .Release.Namespace) -}}
  {{- $dnsNames = concat $dnsNames .Values.tls.generateCerts.subjectAlternativeName.additionalDnsNames -}}
  {{- $dnsNames | toYaml -}}
{{- end -}}

{{- define "cassandra.certDnsNames" -}}
  {{- $dnsNames := list "localhost" "cassandra" (printf "%s.%s" "cassandra" .Release.Namespace) (printf "%s.%s.svc" "cassandra" .Release.Namespace) -}}
  {{- $dnsNames = concat $dnsNames .Values.tls.generateCerts.subjectAlternativeName.additionalDnsNames -}}
  {{- $dnsNames | toYaml -}}
{{- end -}}
{{/*
IP addresses used to generate SSL certificate with "Subject Alternative Name" field
*/}}
{{- define "common.certIpAddresses" -}}
  {{- $ipAddresses := list "127.0.0.1" -}}
  {{- $ipAddresses = concat $ipAddresses .Values.tls.generateCerts.subjectAlternativeName.additionalIpAddresses -}}
  {{- $ipAddresses | toYaml -}}
{{- end -}}


{{/*
TLS Static Metric secret template
Arguments:
Dictionary with:
* "namespace" is a namespace of application
* "application" is name of application
* "service" is a name of service
* "enabledSsl" is ssl enabled for service
* "secret" is a name of tls secret for service
* "certProvider" is a type of tls certificates provider
* "certificate" is a name of CertManger's Certificate resource for service
Usage example:
{{template "global.tlsStaticMetric" (dict "namespace" .Release.Namespace "application" .Chart.Name "service" .global.name "enabledSsl" (include "global.sslEnabled" .) "secret" (include "global.sslSecretName" .) "certProvider" (include "services.certProvider" .) "certificate" (printf "%s-tls-certificate" (include "global.name")) }}
*/}}
{{- define "global.tlsStaticMetric" -}}
- expr: {{ ternary "1" "0" .enabledSsl }}
  labels:
    namespace: "{{ .namespace }}"
    application: "{{ .application }}"
    service: "{{ .service }}"
    {{ if .enabledSsl }}
    secret: "{{ .secret }}"
    {{ if eq .certProvider "cert-manager" }}
    certificate: "{{ .certificate }}"
    {{ end }}
    {{ end }}
  record: service:tls_status:info
{{- end -}}



{{- define "getBackupResourcesForProfile" -}}
  {{- $flavor := .dotVar }}
{{- if and (ne (.envVar | toString) "<nil>") (ne (.envVar | toString) "") -}}
  {{- $flavor = .envVar -}}
{{- end -}}
  {{- if eq $flavor "small" }}
    resources:
      requests:
        cpu: 150m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
  {{- else if eq $flavor "medium" }}
    resources:
      requests:
        cpu: 150m
        memory: 256Mi
      limits:
        cpu: 1
        memory: 1Gi
  {{- else if eq $flavor "large" }}
    resources:
      requests:
        cpu: 150m
        memory: 256Mi
      limits:
        cpu: 2
        memory: 2Gi
  {{- else if $flavor -}}
  {{- fail "value for .Values.global.profile is not one of  `small`, `medium`, `large`" }}
  {{- else }}
    resources:
      requests:
        cpu: {{ .values.backupDaemon.resources.requests.cpu | quote }}
        memory: {{ .values.backupDaemon.resources.requests.memory }}
      limits:
        cpu: {{ .values.backupDaemon.resources.limits.cpu | quote }}
        memory: {{ .values.backupDaemon.resources.limits.memory }}
  {{- end -}}
{{- end -}}

{{/*
Common Cassandra resources labels
*/}}
{{- define "cassandra.defaultLabels" -}}
{{- if .Values.ARTIFACT_DESCRIPTOR_VERSION }}
app.kubernetes.io/version: {{ default "" .Values.ARTIFACT_DESCRIPTOR_VERSION | trunc 63 | trimAll "-_." }}
{{- end }}
app.kubernetes.io/part-of: {{ default "cassandra" .Values.PART_OF }}
app.kubernetes.io/managed-by: {{ default "operator" .Values.MANAGED_BY }}
{{- end -}}

{{- define "cassandraSupplementary.monitoredImages" -}}
  {{- if .Values.deployDescriptor -}}
    {{- if .Values.robotTests.install -}}
      {{- printf "deployment robot-tests robot-tests %s, " (include "find_image" (dict "deployName" "dockerRobotTests" "SERVICE_NAME" "dockerRobotTests" "vals" .Values "default" "not_found")) -}}
    {{- end -}}
    {{- if .Values.backupDaemon.install -}}
      {{- printf "deployment cassandra-backup-daemon cassandra-backup-daemon %s, " (include "find_image" (dict "deployName" "dockerLegacyBackupDaemon" "SERVICE_NAME" "dockerLegacyBackupDaemon" "vals" .Values "default" "not_found")) -}}
    {{- end -}}
    {{- if .Values.dbaas.install -}}
      {{- printf "deployment dbaas-cassandra-adapter dbaas-cassandra-adapter %s, " (include "find_image" (dict "deployName" "dbaas_cassandra" "SERVICE_NAME" "dbaas_cassandra" "vals" .Values "default" "not_found")) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Backup Daemon SSL secret name
*/}}
{{- define "getBackupSslSecretName" -}}
  {{- if .Values.backupDaemon.s3.sslCert -}}
    {{- if .Values.backupDaemon.s3.sslSecretName -}}
      {{- .Values.backupDaemon.s3.sslSecretName -}}
    {{- else -}}
      {{- printf "backup-daemon-s3-tls-secret" -}}
    {{- end -}}
  {{- else -}}
    {{- if .Values.backupDaemon.s3.sslSecretName -}}
      {{- .Values.backupDaemon.s3.sslSecretName -}}
    {{- else -}}
      {{- printf "" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/* Kubernetes labels */}}
{{- define "kubernetes.labels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/component: "cassandra-operator"
app.kubernetes.io/part-of: "cassandra-operator"
app.kubernetes.io/managed-by: {{ default "services" .Values.MANAGED_BY }}
app.kubernetes.io/technology: "go"
{{- end -}}