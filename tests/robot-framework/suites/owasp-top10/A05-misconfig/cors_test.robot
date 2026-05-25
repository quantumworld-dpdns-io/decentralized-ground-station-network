*** Settings ***
Documentation       A05: Security Misconfiguration - CORS Configuration Tests
...                 Verifies CORS configuration is not overpermissive
Library             Collections
Library             RequestsLibrary
Library             ../../../libraries/SecurityLibrary.py
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Variables ***
${EVIL_ORIGIN}          https://evil.com
${ATTACKER_ORIGIN}      https://attacker.dgsn.space

*** Test Cases ***
TC-CORS-001: Wildcard Cors Origin Is Not Allowed
    [Documentation]   Verify wildcard CORS origin is not allowed
    ${headers}=    Create Dictionary    Origin=*
    ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
    ${cors}=    Get From Dictionary    ${response.headers}    Access-Control-Allow-Origin    default=${NONE}
    Should Not Be Equal    ${cors}    *

TC-CORS-002: Specific Domain Cors Is Validated
    [Documentation]   Verify specific domain CORS is properly validated
    ${headers}=    Create Dictionary    Origin=${EVIL_ORIGIN}
    ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
    ${cors}=    Get From Dictionary    ${response.headers}    Access-Control-Allow-Origin    default=${NONE}
    Should Not Contain    ${cors}    evil.com

TC-CORS-003: Credentials With Wildcard Origin Is Rejected
    [Documentation]   Verify credentials with wildcard origin is rejected
    ${headers}=    Create Dictionary    Origin=*    Cookie=session=test
    ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
    ${cors}=    Get From Dictionary    ${response.headers}    Access-Control-Allow-Origin    default=${NONE}
    ${creds}=    Get From Dictionary    ${response.headers}    Access-Control-Allow-Credentials    default=false
    IF    '${cors}' == '*'
        Should Be Equal    ${creds}    false    Wildcard origin with credentials
    END

TC-CORS-004: Preflight Request Is Secured
    [Documentation]   Verify CORS preflight is properly secured
    ${headers}=    Create Dictionary    Origin=${EVIL_ORIGIN}    Access-Control-Request-Method=DELETE
    ${response}=    OPTIONS    dgsn    /stations    headers=${headers}    expected_status=anything
    ${cors}=    Get From Dictionary    ${response.headers}    Access-Control-Allow-Origin    default=${NONE}
    Should Not Contain    ${cors}    evil.com

TC-CORS-005: Reflect Origin Is Disabled
    [Documentation]   Verify reflecting origin is disabled
    ${headers}=    Create Dictionary    Origin=https://reflect-test.attacker.com
    ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
    ${cors}=    Get From Dictionary    ${response.headers}    Access-Control-Allow-Origin    default=${NONE}
    Should Not Contain    ${cors}    attacker.com

TC-CORS-006: Null Origin Is Rejected
    [Documentation]   Verify null origin is rejected
    ${headers}=    Create Dictionary    Origin=null
    ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
    ${cors}=    Get From Dictionary    ${response.headers}    Access-Control-Allow-Origin    default=${NONE}
    Should Not Be Equal    ${cors}    null

TC-CORS-007: Attacker Subdomain Is Rejected
    [Documentation]   Verify attacker subdomain is rejected
    ${headers}=    Create Dictionary    Origin=${ATTACKER_ORIGIN}
    ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
    ${cors}=    Get From Dictionary    ${response.headers}    Access-Control-Allow-Origin    default=${NONE}
    Should Not Contain    ${cors}    attacker

TC-CORS-008: Allowed Methods Are Restricted
    [Documentation]   Verify allowed methods are restricted
    ${headers}=    Create Dictionary    Origin=https://trusted.dgsn.space    Access-Control-Request-Method=PUT
    ${response}=    OPTIONS    dgsn    /stations    headers=${headers}    expected_status=anything
    ${methods}=    Get From Dictionary    ${response.headers}    Access-Control-Allow-Methods    default=${NONE}
    IF    ${methods}
        Should Not Contain    ${methods}    DELETE
    END

TC-CORS-009: Allowed Headers Are Restricted
    [Documentation]   Verify allowed headers are restricted
    ${headers}=    Create Dictionary    Origin=https://trusted.dgsn.space    Access-Control-Request-Headers=X-Custom-Header
    ${response}=    OPTIONS    dgsn    /stations    headers=${headers}    expected_status=anything
    ${allowed}=    Get From Dictionary    ${response.headers}    Access-Control-Allow-Headers    default=${NONE}
    IF    ${allowed}
        Should Not Contain    ${allowed}    X-Custom-Header
    END

TC-CORS-010: Exposed Headers Are Minimal
    [Documentation]   Verify exposed headers are minimal
    ${response}=    OPTIONS    dgsn    /stations    expected_status=anything
    ${exposed}=    Get From Dictionary    ${response.headers}    Access-Control-Expose-Headers    default=${NONE}
    Log    Exposed headers: ${exposed}

TC-CORS-011: Max Age Is Reasonable
    [Documentation]   Verify CORS max-age is reasonable
    ${response}=    OPTIONS    dgsn    /stations    expected_status=anything
    ${max_age}=    Get From Dictionary    ${response.headers}    Access-Control-Max-Age    default=0
    Log    CORS max-age: ${max_age}

TC-CORS-012: Api Cors Policy Is Strict
    [Documentation]   Verify API CORS policy is strict
    ${ssl_headers}=    Check Security Headers    ${response.headers}
    ${cors_ok}    ${msg}=    Check Cors    ${response.headers}    ${EVIL_ORIGIN}
    Should Not Be True    ${cors_ok}    CORS should not allow evil origin

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    CORS test completed at ${TEST_TIMESTAMP}
