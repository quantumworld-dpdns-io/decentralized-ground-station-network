# DGSN Global Variables
# API URLs and Endpoints

*** Settings ***
Documentation   Global variable definitions for DGSN test suites

*** Variables ***
# Base URLs
${BASE_URL}                     http://localhost:8080
${WS_URL}                       ws://localhost:8080/ws
${AUTH_URL}                     ${BASE_URL}/auth
${API_URL}                      ${BASE_URL}/api/v1

# API Endpoints
${ENDPOINT_LOGIN}               /auth/login
${ENDPOINT_REGISTER}            /auth/register
${ENDPOINT_REFRESH}             /auth/refresh
${ENDPOINT_LOGOUT}              /auth/logout
${ENDPOINT_MFA_SETUP}           /auth/mfa/setup
${ENDPOINT_MFA_VERIFY}          /auth/mfa/verify
${ENDPOINT_PASSWORD_RESET}      /auth/password-reset
${ENDPOINT_USERS}               /users
${ENDPOINT_STATIONS}            /stations
${ENDPOINT_RECEIPTS}            /receipts
${ENDPOINT_SCHEDULES}           /schedules
${ENDPOINT_SIGNALS}             /signals
${ENDPOINT_QUANTUM}             /quantum
${ENDPOINT_HEALTH}              /health
${ENDPOINT_METRICS}             /metrics
${ENDPOINT_ADMIN}               /admin
${ENDPOINT_DEBUG}               /debug
${ENDPOINT_CIRCUITS}            /quantum/circuits
${ENDPOINT_SIMULATE}            /quantum/simulate
${ENDPOINT_PQC_KEY}             /crypto/pqc/key
${ENDPOINT_PQC_SIGN}            /crypto/pqc/sign
${ENDPOINT_PQC_VERIFY}          /crypto/pqc/verify
${ENDPOINT_MERKLE_PROOF}        /crypto/merkle/proof
${ENDPOINT_MERKLE_VERIFY}       /crypto/merkle/verify
${ENDPOINT_PROCESS_SIGNAL}      /signals/process
${ENDPOINT_UPLOAD_SIGNAL}       /signals/upload
${ENDPOINT_MODULATE}            /signals/modulate
${ENDPOINT_SBOM}                /admin/sbom

# Credentials
${ADMIN_USERNAME}               admin@dgsn.space
${ADMIN_PASSWORD}               Admin@SecurePass123!
${USER_USERNAME}                user@dgsn.space
${USER_PASSWORD}                User@Pass5678!
${LOW_PRIV_USERNAME}            lowpriv@dgsn.space
${LOW_PRIV_PASSWORD}            Low@Priv1234!
${DEFAULT_USERNAME}             admin
${DEFAULT_PASSWORD}             admin
${WEAK_PASSWORD}                password123

# Authentication
${BEARER_PREFIX}                Bearer
${INVALID_TOKEN}                invalid.jwt.token.here
${EXPIRED_TOKEN}                eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MTUwMDAwMDB9.xxx
${NONE_ALG_TOKEN}               eyJhbGciOiJub25lIn0.eyJzdWIiOiJhZG1pbiJ9.

# Test Data
${TEST_STATION_NAME}            Test-Ground-Station-Alpha
${TEST_STATION_LAT}             40.7128
${TEST_STATION_LNG}             -74.0060
${TEST_STATION_ALTITUDE}        100
${TEST_FREQUENCY_MHZ}           437.500
${TEST_BANDWIDTH_KHZ}           50
${TEST_SIGNAL_STRENGTH_DBM}     -70
${TEST_MODULATION}              QPSK
${TEST_SAMPLE_RATE_MHZ}         2.4
${TEST_QUANTUM_CIRCUIT_DEPTH}   10
${TEST_QUANTUM_SHOTS}           1024

# Security Headers
${HSTS_HEADER}                  Strict-Transport-Security
${CSP_HEADER}                   Content-Security-Policy
${XFO_HEADER}                   X-Frame-Options
${XCT_HEADER}                   X-Content-Type-Options
${RP_HEADER}                    Referrer-Policy
${PERM_POLICY_HEADER}           Permissions-Policy

# Injection Payloads
${SQL_PAYLOAD_1}                ' OR '1'='1
${SQL_PAYLOAD_2}                '; DROP TABLE users; --
${SQL_PAYLOAD_3}                ' UNION SELECT * FROM users; --
${CMD_PAYLOAD_1}                ; rm -rf /
${CMD_PAYLOAD_2}                | cat /etc/passwd
${CMD_PAYLOAD_3}                $(whoami)
${LDAP_PAYLOAD_1}               *)(uid=*
${LDAP_PAYLOAD_2}               *|(&(uid=*))
${XXE_PAYLOAD}                  <?xml version="1.0"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
${SSTI_PAYLOAD_1}               {{config}}
${SSTI_PAYLOAD_2}               ${7*7}

# Expected Status Codes
${HTTP_OK}                      200
${HTTP_CREATED}                 201
${HTTP_NO_CONTENT}              204
${HTTP_BAD_REQUEST}             400
${HTTP_UNAUTHORIZED}            401
${HTTP_FORBIDDEN}               403
${HTTP_NOT_FOUND}               404
${HTTP_CONFLICT}                409
${HTTP_TOO_MANY_REQUESTS}       429
${HTTP_SERVER_ERROR}            500

# Rate Limits
${RATE_LIMIT_LOGIN}             5
${RATE_LIMIT_API}               100
${RATE_LIMIT_WINDOW_SEC}        60

# Timeouts (ms)
${TIMEOUT_DEFAULT}              30000
${TIMEOUT_LONG}                 60000
${TIMEOUT_SHORT}                5000

# Performance
${PERF_CONCURRENT_USERS}        50
${PERF_RAMP_TIME_SEC}           10
${PERF_DURATION_SEC}            60
${STRESS_MAX_USERS}             500
${ENDURANCE_DURATION_HOURS}     24
${ENDURANCE_CHECK_INTERVAL}     300

# PQC Parameters
${PQC_ALGORITHM_DILITHIUM}      Dilithium3
${PQC_ALGORITHM_KYBER}          Kyber768
${PQC_ALGORITHM_FALCON}         Falcon-512
${PQC_ALGORITHM_SPHINCS}        SPHINCS+-128s
${MERKLE_TREE_DEPTH}            16
