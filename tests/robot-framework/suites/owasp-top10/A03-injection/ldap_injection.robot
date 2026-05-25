*** Settings ***
Documentation       A03: Injection - LDAP Injection Tests
...                 Verifies LDAP injection payloads are rejected
Library             Collections
Library             RequestsLibrary
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Variables ***
@{LDAP_PAYLOADS}    *)(uid=*    *|(&(uid=*))    admin*)(uid=*    *)(|(password=*))    *)(cn=*))    admin*    *    *|(uid=*)

*** Test Cases ***
TC-LDAP-001: Ldap Injection In Username Field
    [Documentation]   Verify LDAP injection in username is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=${LDAP_PAYLOAD_1}    password=test
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-LDAP-002: Wildcard Ldap Injection
    [Documentation]   Verify wildcard LDAP injection is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=${LDAP_PAYLOAD_2}    password=test
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-LDAP-003: Ldap Injection Via Search Parameter
    [Documentation]   Verify LDAP injection in search is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${params}=    Create Dictionary    search=${LDAP_PAYLOAD_1}
    ${response}=    GET    dgsn    /stations    headers=${headers}    params=${params}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-LDAP-004: Ldap Injection In Email Field
    [Documentation]   Verify LDAP injection in email is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=test@test.com    password=TestPass123!    email=${LDAP_PAYLOAD_1}
    ${response}=    POST    dgsn    /auth/register    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-LDAP-005: Ldap Injection With Or Condition
    [Documentation]   Verify LDAP OR injection is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=${LDAP_PAYLOAD_4}    password=test
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-LDAP-006: Ldap Injection With Cn Condition
    [Documentation]   Verify LDAP cn= injection is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=${LDAP_PAYLOAD_5}    password=test
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-LDAP-007: Ldap Injection In Station Name
    [Documentation]   Verify LDAP injection in station name is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name=${LDAP_PAYLOAD_6}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-LDAP-008: Ldap Wildcard Search Injection
    [Documentation]   Verify wildcard-only search is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${params}=    Create Dictionary    filter=${LDAP_PAYLOAD_7}
    ${response}=    GET    dgsn    /stations    headers=${headers}    params=${params}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-LDAP-009: Ldap Pipe Injection
    [Documentation]   Verify LDAP pipe injection is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${params}=    Create Dictionary    filter=${LDAP_PAYLOAD_8}
    ${response}=    GET    dgsn    /stations    headers=${headers}    params=${params}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-LDAP-010: Ldap Injection Filter Bypass
    [Documentation]   Verify filter bypass injection is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=admin)(uid=*    password=test
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    LDAP injection test completed at ${TEST_TIMESTAMP}
