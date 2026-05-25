# SOC 2 Compliance Mapping

## Overview

This document maps DGSN controls to SOC 2 Trust Services Criteria (TSC). DGSN is designed to meet SOC 2 Type II requirements across Security, Availability, Processing Integrity, Confidentiality, and Privacy categories.

## Trust Service Criteria Mapping

### Security (CC1-CC9)

#### CC1: Control Environment
| Criterion | DGSN Control | Evidence | Monitoring |
|-----------|-------------|----------|------------|
| CC1.1 | Security policies documented in CONTRIBUTING.md and team wiki | Policy documents, acceptance signatures | Annual review |
| CC1.2 | Code of conduct, security training for developers | Training records, signed acknowledgments | Quarterly |
| CC1.3 | Organizational structure with clear security roles | Role definitions in RBAC documentation | On change |
| CC1.4 | Board/management oversight of security program | Quarterly security reviews, risk register | Quarterly |
| CC1.5 | Accountability measured via KPIs | Security metrics dashboard | Monthly |

#### CC2: Communication and Information
| Criterion | DGSN Control | Evidence | Monitoring |
|-----------|-------------|----------|------------|
| CC2.1 | Security incident communication plan | Runbook: incident-response.md | Tested quarterly |
| CC2.2 | Internal security announcements via Slack/Teams | Communication logs | Continuous |
| CC2.3 | External breach notification procedure | Legal-reviewed notification template | Annually |
| CC2.4 | Security expectations communicated to vendors | Vendor security questionnaire | On onboarding |

#### CC3: Risk Assessment
| Criterion | DGSN Control | Evidence | Monitoring |
|-----------|-------------|----------|------------|
| CC3.1 | Annual risk assessment covering all components | Risk register in docs/architecture/threat-model.md | Annually |
| CC3.2 | Third-party/vendor risk assessment | Vendor security reviews, penetration tests | Quarterly |
| CC3.3 | Risk identification includes emerging threats | PQC migration roadmap, NIST monitoring | Continuous |

#### CC4: Monitoring Activities
| Criterion | DGSN Control | Evidence | Monitoring |
|-----------|-------------|----------|------------|
| CC4.1 | Continuous monitoring via Prometheus/Grafana | Alert rules, dashboard screenshots | 24/7 |
| CC4.2 | Internal control monitoring | Automated compliance checks in CI | Per deployment |
| CC4.3 | Control deficiency remediation tracking | Jira/Linear tickets, SLAs | Weekly review |

#### CC5: Control Activities
| Criterion | DGSN Control | Evidence | Monitoring |
|-----------|-------------|----------|------------|
| CC5.1 | Control activities mapped to risks | This document | Annual review |
| CC5.2 | Segregation of duties (RBAC) | Role definitions, access reviews | Quarterly |
| CC5.3 | Configuration management | GitOps with ArgoCD, code review required | Per change |
| CC5.4 | Access provisioning/deprovisioning | Automated via OIDC + SCIM | Real-time |
| CC5.5 | Control selection based on risk | PQC deployment, zero-trust networking | Per risk |

#### CC6: Logical and Physical Access
| Criterion | DGSN Control | Evidence | Monitoring |
|-----------|-------------|----------|------------|
| CC6.1 | OIDC with MFA for all human access | Auth logs, MFA enrollment records | Continuous |
| CC6.2 | mTLS for service-to-service communication | Certificate inventory, mTLS config | Daily scan |
| CC6.3 | Least privilege via RBAC | Role definitions, access audit logs | Quarterly review |
| CC6.4 | Physical security of data centers | Cloud provider SOC 2 reports (AWS/GCP) | Annually |
| CC6.5 | Secure disposal of data | Data retention policy, secure deletion procedure | Per request |
| CC6.6 | Network segmentation via Cilium | NetworkPolicy configurations | Per deployment |
| CC6.7 | Vulnerability management | Trivy scans, dependency updates, penetration tests | CI + quarterly |

#### CC7: System Operations
| Criterion | DGSN Control | Evidence | Monitoring |
|-----------|-------------|----------|------------|
| CC7.1 | Change management process | PR reviews, staging deployment, approval gates | Per change |
| CC7.2 | Technology stack security standards | Container security, language-specific hardening | CI enforced |
| CC7.3 | Malware protection | Container image scanning, runtime security (Tetragon) | Continuous |
| CC7.4 | Incident response plan | Incident response runbook | Tested quarterly |
| CC7.5 | Recovery from security incidents | Documented recovery procedures, DR drills | Annually |

#### CC8: Change Management
| Criterion | DGSN Control | Evidence | Monitoring |
|-----------|-------------|----------|------------|
| CC8.1 | Authorized development methodology | Git flow, semantic release, automated CI/CD | Per commit |
| CC8.2 | Code review and testing requirements | PR approvals, linting, unit tests, e2e tests | Per PR |
| CC8.3 | Security testing in CI | SAST (golangci-lint, clippy), DAST (OWASP ZAP) | CI pipeline |
| CC8.4 | Production changes authorized | Change advisory board, deployment windows | Per deployment |
| CC8.5 | Emergency change process | Documented hotfix procedure, post-mortem | As needed |

#### CC9: Risk Mitigation
| Criterion | DGSN Control | Evidence | Monitoring |
|-----------|-------------|----------|------------|
| CC9.1 | Business continuity plan | Multi-AZ deployment, DR region | Tested annually |
| CC9.2 | Disaster recovery plan | DR runbook, RTO/RPO defined | Tested annually |
| CC9.3 | Insurance coverage | Cyber insurance policy | Annually |

### Availability (A1-A2)

| Criterion | DGSN Control | Evidence | Monitoring |
|-----------|-------------|----------|------------|
| A1.1 | Redundant infrastructure (multi-AZ, HPA) | Kubernetes topology spread, HPA configs | Continuous |
| A1.2 | Monitoring for availability metrics | Uptime dashboard, SLO alerts | 24/7 |
| A1.3 | Incident response for outages | Service outage playbook | On incident |
| A2.1 | User notification of availability issues | Status page, Slack alerts | On detection |

### Processing Integrity (PI1-PI2)

| Criterion | DGSN Control | Evidence | Monitoring |
|-----------|-------------|----------|------------|
| PI1.1 | Receipt creation integrity checks | ML-DSA signatures, receipt chain hashing | Per receipt |
| PI1.2 | Input validation at every layer | API validation, gRPC interceptors | Per request |
| PI1.3 | Error handling and logging | Structured logging, error budgets | Continuous |
| PI2.1 | Processing monitoring | Latency dashboards, error rate alerts | 24/7 |

### Confidentiality (C1-C2)

| Criterion | DGSN Control | Evidence | Monitoring |
|-----------|-------------|----------|------------|
| C1.1 | Encryption at rest (TDE, AEAD) | Storage encryption configs | Quarterly audit |
| C1.2 | Encryption in transit (TLS 1.3, mTLS) | Network policy, TLS configs | Continuous scanning |
| C1.3 | Access controls (RBAC, OIDC) | AuthZ logs, access reviews | Quarterly |
| C1.4 | Data classification | PII labeling, field-level encryption | On creation |
| C2.1 | Confidentiality breach notification | Incident response runbook | On incident |

### Privacy (P1-P5)

| Criterion | DGSN Control | Evidence | Monitoring |
|-----------|-------------|----------|------------|
| P1.1 | Privacy notice published | Privacy policy on website | Annually |
| P2.1 | Consent for data collection | OIDC consent screen, terms | On registration |
| P3.1 | Data minimization | Only essential fields collected | Design review |
| P3.2 | Data retention limits | Retention policies in Loki, PostgreSQL | Quarterly audit |
| P4.1 | Access to personal data | User data export API | On request |
| P5.1 | Data correction/deletion | Account deletion API, GDPR compliance | On request |

## Evidence Collection Methods

| Control Area | Collection Method | Frequency | Tool |
|-------------|-------------------|-----------|------|
| Access logs | Automated log shipping | Real-time | Loki + Grafana |
| Configuration changes | Git commit log | Per change | GitHub + ArgoCD |
| Vulnerability scans | CI pipeline output | Per deployment | Trivy, Grype |
| Penetration tests | External pentest report | Quarterly | External vendor |
| Uptime monitoring | Prometheus metrics | 15s intervals | Grafana |
| Incident response | Post-mortem documents | On incident | Linear/Jira |
| Access reviews | Manual + automated | Quarterly | Okta/Azure AD |
| Training records | HR system | On hire/annually | LMS |
| Vendor assessments | Questionnaire | Onboarding | Vendor portal |

## Monitoring Procedures

### Daily
- Review active alerts (PagerDuty/OpsGenie)
- Check dashboard for anomalies
- Verify all services are UP

### Weekly
- Review security event trends
- Check certificate expiry status
- Review access audit logs for anomalies

### Monthly
- Vulnerability scan review and remediation tracking
- Performance regression review
- Error budget consumption review

### Quarterly
- Access control review (user list audit)
- Penetration test execution
- Incident response tabletop exercise
- Vendor security review

### Annually
- Full SOC 2 audit preparation
- Disaster recovery drill
- Risk assessment update
- Security policy review

## Auditor Guide

### Sample Audit Request List
1. System description and boundary diagram
2. Control implementation evidence
3. Monitoring and alerting configurations
4. Incident response documentation
5. Access review records (last 4 quarters)
6. Vulnerability scan results (last 4 quarters)
7. Penetration test reports (last 2 quarters)
8. Change management records (sample of 25 changes)
9. Vendor management program documentation
10. Business continuity/disaster recovery test results

### Key Personnel
- CISO: Security program ownership
- SRE Lead: Infrastructure monitoring and availability
- Engineering Lead: Change management and code quality
- Compliance Officer: SOC 2 program management
- Legal Counsel: Privacy and breach notification

### Common Audit Findings and Remediation
| Finding | Likelihood | Remediation |
|---------|-----------|-------------|
| Incomplete access reviews | Low | Automate access review reminders |
| Timely patch management gaps | Medium | Auto-patch policy for critical CVEs |
| Documentation drift | Medium | Annual documentation review cycle |
| Vendor risk assessment backlog | Low | Dedicated vendor risk resource |
| Incident response documentation | Low | Post-incident documentation checklist |
