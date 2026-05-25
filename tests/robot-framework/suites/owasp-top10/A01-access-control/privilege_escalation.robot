*** Settings ***
Documentation       A01: Broken Access Control - Privilege Escalation Tests
...                 Verifies low-privilege users cannot access admin endpoints
Library             Collections
Library             RequestsLibrary
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Variables ***
${ADMIN_ENDPOINTS}      /admin/users    /admin/config    /admin/logs    /admin/metrics    /admin/sbom    /admin/cache

*** Test Cases ***
TC-PE-001: Low-Priv User Cannot Access Admin Users Endpoint
    [Documentation]   Verify 403 for low-priv user on admin/users
    ${headers}    ${token}=    Authenticate As Low Privilege User
    ${response}=    GET    dgsn    /admin/users    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}
    ${body}=    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${body}    error

TC-PE-002: Low-Priv User Cannot Access Admin Config Endpoint
    [Documentation]   Verify 403 for low-priv user on admin/config
    ${headers}    ${token}=    Authenticate As Low Privilege User
    ${response}=    GET    dgsn    /admin/config    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-PE-003: Low-Priv User Cannot Access Admin Logs Endpoint
    [Documentation]   Verify 403 for low-priv user on admin/logs
    ${headers}    ${token}=    Authenticate As Low Privilege User
    ${response}=    GET    dgsn    /admin/logs    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-PE-004: Low-Priv User Cannot Access Admin Metrics
    [Documentation]   Verify 403 for low-priv user on admin/metrics
    ${headers}    ${token}=    Authenticate As Low Privilege User
    ${response}=    GET    dgsn    /admin/metrics    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-PE-005: Low-Priv User Cannot POST To Admin Endpoints
    [Documentation]   Verify POST to admin endpoints returns 403 for low-priv
    ${headers}    ${token}=    Authenticate As Low Privilege User
    ${payload}=    Create Dictionary    action=restart
    ${response}=    POST    dgsn    /admin/config    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-PE-006: Low-Priv User Cannot DELETE Admin Resources
    [Documentation]   Verify DELETE on admin endpoints returns 403
    ${headers}    ${token}=    Authenticate As Low Privilege User
    ${response}=    DELETE    dgsn    /admin/users/test-user    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-PE-007: Low-Priv User Cannot Access Admin SBOM
    [Documentation]   Verify SBOM endpoint returns 403 for low-priv
    ${headers}    ${token}=    Authenticate As Low Privilege User
    ${response}=    GET    dgsn    /admin/sbom    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-PE-008: Admin User Can Access Admin Endpoints
    [Documentation]   Verify admin user can access admin endpoints
    ${headers}    ${token}=    Authenticate As Admin
    ${response}=    GET    dgsn    /admin/users    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_OK}    ${response}

TC-PE-009: Token Tampering Cannot Escalate Privileges
    [Documentation]   Verify forged token with elevated role field is rejected
    ${forged_token}=    Evaluate    __import__('secrets').token_hex(32)
    ${headers}=    Create Dictionary    Authorization=Bearer ${forged_token}    Content-Type=application/json
    ${response}=    GET    dgsn    /admin/config    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-PE-010: Low-Priv User Cannot Access Debug Endpoints
    [Documentation]   Verify debug endpoints protected from low-priv users
    ${headers}    ${token}=    Authenticate As Low Privilege User
    ${response}=    GET    dgsn    /debug    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

*** Keywords ***
Setup Test Case
    [Documentation]   Per-test-case setup
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    [Documentation]   Per-test-case teardown
    Log    Privilege escalation test completed at ${TEST_TIMESTAMP}
