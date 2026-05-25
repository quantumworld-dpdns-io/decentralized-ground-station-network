# Incident Response Runbook

## Overview

This runbook defines the incident response process for DGSN, following the NIST SP 800-61 revision 2 framework. All incidents follow the Prepare → Identify → Contain → Eradicate → Recover → Learn cycle.

## Incident Phases

### Phase 1: Preparation

#### Pre-Requisites
- **On-call rotation**: 24/7 SRE coverage (PagerDuty/OpsGenie)
- **Communication channels**: Slack #dgsn-alerts, #dgsn-incident
- **Access tools**: kubectl, Grafana, Loki, Vault, cloud console
- **Documentation**: Runbooks, architecture diagrams, vendor contacts
- **Testing**: Tabletop exercises quarterly, DR drills annually

#### Required Tools
| Tool | Purpose | Location |
|------|---------|----------|
| PagerDuty | Alert notification | https://dgsn.pagerduty.com |
| Grafana | Observability dashboards | https://grafana.dgsn.example.com |
| Loki | Log aggregation | https://loki.dgsn.example.com |
| Tempo | Distributed tracing | https://tempo.dgsn.example.com |
| Vault | Secrets management | https://vault.dgsn.example.com |
| ArgoCD | GitOps deployment | https://argo.dgsn.example.com |
| Slack | Incident communication | #dgsn-incident |

#### Severity Levels
| Level | Definition | Response Time | Escalation |
|-------|-----------|--------------|------------|
| SEV1 | Service unavailable or data loss | < 15 min | Engineering VP |
| SEV2 | Degraded performance or minor data issue | < 1 hour | Team lead |
| SEV3 | Non-critical issue, cosmetic bug | < 8 hours | Assignee |
| SEV4 | Feature request, minor enhancement | Next sprint | Product owner |

### Phase 2: Identification

#### Detection Sources
1. **Prometheus Alerts**: Automated threshold-based alerts
2. **PagerDuty**: Escalated alerts requiring immediate action
3. **User Reports**: Support tickets or Slack reports
4. **Security Scan**: Automated security findings
5. **Manual Observation**: Dashboard anomalies noticed by team

#### Triage Checklist
```
□ Confirm alert is valid (not test or false positive)
□ Determine severity level (SEV1-SEV4)
□ Declare incident in #dgsn-incident with severity tag
□ Assign incident commander (IC)
□ Create incident channel (#dgsn-incident-<yyyy-mm-dd>)
□ Begin documentation in incident document
□ Assemble response team (SRE, engineering, security if needed)
□ Estimate impact (users affected, services degraded, data at risk)
```

#### Investigation Commands

```bash
# Check service status
kubectl get pods -n dgsn
kubectl describe pod <pod-name> -n dgsn

# Check logs
kubectl logs -n dgsn -l app=dgsn-backend --tail=100
kubectl logs -n dgsn -l app=dgsn-crypto-kernel --tail=100

# Check recent events
kubectl get events -n dgsn --sort-by=.lastTimestamp

# Query Loki
logcli query '{service="dgsn-backend"} |= "error"'

# Check metrics
curl http://prometheus:9090/api/v1/query?query=up

# Check traces
# Use Grafana Tempo datasource to query recent traces
```

### Phase 3: Containment

#### Short-Term Containment
| Action | Command | Risk |
|--------|---------|------|
| Scale down affected deployment | `kubectl scale deploy/dgsn-backend --replicas=0` | Service disruption |
| Block offending IP via WAF | Update WAF rules | Legitimate users blocked |
| Isolate pod with network policy | Apply deny policy via Cilium | Complete isolation |
| Rotate compromised credentials | `vault lease revoke <lease-id>` | Service auth failures |
| Enable read-only mode | Feature flag toggle | No writes |

#### Long-Term Containment
- Deploy hotfix with mitigation
- Increase monitoring and alerting
- Implement temporary rate limits
- Redirect traffic to healthy instances
- Engage DDoS protection if needed

### Phase 4: Eradication

#### Root Cause Removal
1. Identify vulnerable component or misconfiguration
2. Develop and test fix in staging environment
3. Deploy fix via GitOps (ArgoCD)
4. Verify fix in canary deployment
5. Roll out to production with progressive delivery

#### Cleanup Actions
- Remove attacker persistence (if security incident)
- Rotate all potentially compromised secrets
- Update firewall rules and network policies
- Patch vulnerable dependencies
- Remove temporary containment measures

### Phase 5: Recovery

#### Verification Steps
```
□ Service health checks pass
□ All pods running and ready
□ Metrics return to baseline
□ No lingering alerts related to incident
□ Data integrity verified (receipt chain)
□ Monitoring confirms normal operation
□ Security scan passes
```

#### Gradual Rollout
1. Deploy to 10% of instances → Monitor 15 minutes
2. Deploy to 50% of instances → Monitor 15 minutes
3. Deploy to 100% of instances → Monitor 30 minutes
4. Declare recovery complete

### Phase 6: Lessons Learned

#### Post-Incident Review (PIR)
Hold within 5 business days. Required attendees: IC, responders, engineering lead, product owner.

#### PIR Document Template
```
# Post-Incident Review: <incident-title>

## Summary
- Date: <YYYY-MM-DD>
- Duration: <X hours X minutes>
- Severity: SEV<X>
- Services affected: <list>
- Impact: <X% degraded, X users affected>

## Timeline
| Time (UTC) | Event |
|------------|-------|
| HH:MM | Alert fired |
| HH:MM | Incident declared |
| HH:MM | Containment applied |
| HH:MM | Root cause identified |
| HH:MM | Fix deployed |
| HH:MM | Recovery verified |
| HH:MM | Incident closed |

## Root Cause
<detailed description of what caused the incident>

## Contributing Factors
- <factor 1>
- <factor 2>

## Detection
- How was this detected? <alert/user report/etc>
- Time to detection: <X minutes>
- Could detection be faster? <suggestions>

## Response
- What went well:
  - <item 1>
- What went wrong:
  - <item 1>
- What to improve:
  - <item 1>

## Action Items
| # | Action | Owner | Due Date | Tracking |
|---|--------|-------|----------|----------|
| 1 | <action> | <owner> | <date> | <JIRA-123> |

## Metrics
- MTTR: <minutes>
- MTTD: <minutes>
- Impact: <X requests lost, $X cost>
```

## Playbooks

### Playbook 1: Security Breach
**Trigger**: Unauthorized access detected, data exfiltration suspected

```
1. Triage
   □ Severity: SEV1
   □ Notify: CISO, Security team, Engineering VP
   □ Declare incident with tag #security-breach

2. Contain
   □ Isolate affected systems (network policy deny)
   □ Revoke all potentially compromised tokens/keys
   □ Enable read-only mode for affected services
   □ Block source IPs at WAF level
   □ Preserve forensic evidence (pod logs, network captures)

3. Investigate
   □ Review audit logs (Loki query: {service="dgsn-security"})
   □ Check Tetragon events for process anomalies
   □ Analyze network flows for data exfiltration
   □ Review Kubernetes audit logs
   □ Determine scope (data accessed, systems compromised)

4. Eradicate
   □ Patch vulnerability
   □ Rotate all secrets exposed
   □ Remove attacker access
   □ Rebuild compromised containers

5. Recover
   □ Restore from clean backup if needed
   □ Deploy patched version
   □ Verify data integrity
   □ Monitor for recurrence

6. PIR
   □ Full forensic report
   □ Legal notification assessment
   □ Compliance reporting (SOC 2, GDPR if applicable)
   □ Security control improvements
```

### Playbook 2: Service Outage
**Trigger**: Complete or partial service unavailability

```
1. Triage
   □ Severity: SEV1 if critical path down, SEV2 if partial
   □ Check scope: single pod, AZ, region
   □ Verify upstream dependencies (DB, Redis, cloud provider)

2. Common Causes & Remediation
   □ Pod crash: kubectl describe, check OOMKilled, fix resource limits
   □ DB connection exhaustion: increase pool size, check slow queries
   □ TLS cert expired: cert-manager renewal, check ACME provider
   □ Cloud provider issue: check status page, failover to DR
   □ Kubernetes node failure: kubectl cordon/drain, new node
   □ HPA scale-up delay: pre-warm pods, adjust min replicas

3. Recovery
   □ Apply targeted fix (scale, restart, config change)
   □ Verify health endpoint returns 200
   □ Monitor for 5 minutes after recovery

4. PIR
   □ Root cause analysis
   □ SLO impact assessment
   □ Runbook improvements
```

### Playbook 3: Data Loss
**Trigger**: Receipt data missing or corrupted

```
1. Triage
   □ Severity: SEV1
   □ Identify scope (time range, stations, receipt IDs)
   □ Check receipt chain integrity

2. Investigate
   □ Verify WAL archiving status
   □ Check backup snapshots (daily, WAL)
   □ Query Loki for deletion events
   □ Check audit log for unauthorized access

3. Recovery
   □ From WAL: pg_wal_replay to point-in-time
   □ From backup: restore RDS snapshot, replay WAL
   □ From replica: promote read replica if async
   □ Verify receipt chain continuity after restore

4. Prevention
   □ Immutable table triggers audit
   □ Enhanced monitoring for delete operations
   □ Additional replica for redundancy
```

### Playbook 4: Quantum Circuit Failure
**Trigger**: >10% circuit failure rate, timeout, fidelity degradation

```
1. Triage
   □ Severity: SEV2 (SEV1 if affecting receipts)
   □ Check quantum engine logs: kubectl logs -l app=dgsn-quantum
   □ Verify simulator vs hardware status
   □ Check GPU utilization and errors

2. Common Failures
   □ Circuit timeout (>300s): reduce circuit depth
   □ Fidelity degradation: switch to simulator
   □ GPU OOM: reduce qubit count
   □ Simulator bug: restart quantum engine
   □ Hardware unavailable: queue or failover to simulator

3. Recovery
   □ Restart failed circuits from checkpoint
   □ Switch backend (simulator ↔ hardware)
   □ Adjust circuit parameters (depth, shots, qubits)
   □ Update optimization algorithm if stuck
```

### Playbook 5: PQC Key Compromise
**Trigger**: Suspicious signing activity, key material exposed

```
1. Triage
   □ Severity: SEV1
   □ Notify: CryptoAdmin, CISO
   □ Do NOT revoke yet - investigate first

2. Investigate
   □ Check crypto kernel audit log for key usage
   □ Query Tempo for traces involving compromised key
   □ Review access to Vault/HSM around compromise time

3. Contain
   □ Generate new keypair via HSM
   □ Transition certificate (cross-signature)
   □ Revoke old certificate (after verification confirmed)
   □ Re-sign any receipts signed after compromise window

4. Recovery
   □ Deploy new public key to all services
   □ Verify all verification paths with new key
   □ Audit all signatures created during compromise window
   □ Run receipt chain validation for affected period

5. PIR
   □ Root cause of exposure
   □ Key management process improvements
   □ Consider shorter rotation period
```

### Playbook 6: DDoS Attack
**Trigger**: Traffic spike >10x baseline, latency increase, error rate spike

```
1. Triage
   □ Severity: SEV1
   □ Check traffic patterns: geography, user-agent, endpoints
   □ Verify not legitimate traffic surge (e.g., satellite pass coincidence)

2. Contain
   □ Enable rate limiting at WAF (100 req/min per IP)
   □ Block source ASNs if clearly malicious
   □ Enable Cloudflare/AWS Shield Advanced if available
   □ Increase HPA max replicas to absorb traffic
   □ Cache static responses at CDN level

3. Mitigation
   □ Rate limiting per endpoint (auth: 5/min, API: 1000/min)
   □ CAPTCHA/challenge for suspicious requests
   □ IP blacklisting at WAF
   □ Throttle non-critical API endpoints

4. Recovery
   □ Analyze attack pattern for future prevention
   □ Update WAF rules
   □ Consider Geo-IP filtering if attack source is narrow
```

## Communication Templates

### Incident Declaration
```
🚨 INCIDENT DECLARED: <summary>
Severity: SEV<1-4>
Services affected: <list>
Impact: <description>
Commander: @person
Channel: #dgsn-incident-<date>
Status: Investigating/Containment/Eradication/Recovery
```

### Status Update (every 30 minutes for SEV1)
```
🔄 INCIDENT UPDATE: <incident-id>
Time: <UTC timestamp>
Status: <phase>
Actions taken: <what was done>
Next steps: <what's planned>
ETA: <estimated resolution>
```

### Incident Resolution
```
✅ INCIDENT RESOLVED: <incident-id>
Duration: <X hours X minutes>
Root cause: <summary>
Action items: <link to PIR document>
```

## Escalation Contacts

| Role | Primary | Secondary | Tertiary |
|------|---------|-----------|----------|
| SRE On-call | @sre-1 | @sre-2 | @sre-3 |
| Backend Engineer | @be-eng-1 | @be-eng-2 | @be-eng-lead |
| Security Engineer | @sec-eng-1 | @sec-eng-2 | CISO |
| Quantum Engineer | @quantum-eng-1 | @quantum-eng-2 | @quantum-lead |
| Engineering VP | @vp-eng | CTO | CEO |
