*** Settings ***
Documentation       A01: Broken Access Control - Unauthorized API Access Tests
...                 Verifies API calls without auth token are properly rejected
Library             Collections
Library             RequestsLibrary
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Variables ***
${NO_AUTH_HEADERS}      ${EMPTY}

*** Test Cases ***
TC-UNAUTH-001: Get Stations Without Auth Returns 401
    [Documentation]   Verify /stations GET requires authentication
    ${response}=    GET    dgsn    /stations    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-UNAUTH-002: Get Receipts Without Auth Returns 401
    [Documentation]   Verify /receipts GET requires authentication
    ${response}=    GET    dgsn    /receipts    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-UNAUTH-003: Post Stations Without Auth Returns 401
    [Documentation]   Verify station creation requires auth
    ${payload}=    Generate Station Payload
    ${response}=    POST    dgsn    /stations    json=${payload}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-UNAUTH-004: Post Receipts Without Auth Returns 401
    [Documentation]   Verify receipt creation requires auth
    ${payload}=    Create Dictionary    station_id=test    frequency_mhz=437.5
    ${response}=    POST    dgsn    /receipts    json=${payload}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-UNAUTH-005: Put Resource Without Auth Returns 401
    [Documentation]   Verify updating resources requires auth
    ${response}=    PUT    dgsn    /stations/test-id    json={"name":"test"}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-UNAUTH-006: Delete Resource Without Auth Returns 401
    [Documentation]   Verify deleting resources requires auth
    ${response}=    DELETE    dgsn    /stations/test-id    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-UNAUTH-007: Invalid Token Returns 401
    [Documentation]   Verify invalid token is rejected
    ${headers}=    Create Dictionary    Authorization=Bearer ${INVALID_TOKEN}    Content-Type=application/json
    ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-UNAUTH-008: Expired Token Returns 401
    [Documentation]   Verify expired token is rejected
    ${headers}=    Create Dictionary    Authorization=Bearer ${EXPIRED_TOKEN}    Content-Type=application/json
    ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-UNAUTH-009: Empty Auth Header Returns 401
    [Documentation]   Verify empty Bearer token is rejected
    ${headers}=    Create Dictionary    Authorization=    Content-Type=application/json
    ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-UNAUTH-010: Malformed Auth Header Returns 401
    [Documentation]   Verify malformed Bearer token is rejected
    ${headers}=    Create Dictionary    Authorization=Basic sometoken    Content-Type=application/json
    ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-UNAUTH-011: Health Endpoint Is Accessible Without Auth
    [Documentation]   Verify health endpoint is publicly accessible
    ${response}=    GET    dgsn    /health    expected_status=anything
    Status Should Be    ${HTTP_OK}    ${response}

TC-UNAUTH-012: Login Endpoint Does Not Require Auth
    [Documentation]   Verify login is accessible without auth
    ${payload}=    Create Dictionary    username=${ADMIN_USERNAME}    password=${ADMIN_PASSWORD}
    ${response}=    POST    dgsn    /auth/login    json=${payload}    expected_status=anything
    Status Should Be    ${HTTP_OK}    ${response}

TC-UNAUTH-013: Auth Token In Query String Is Rejected
    [Documentation]   Verify token in query string is not accepted
    ${response}=    GET    dgsn    /stations?token=${INVALID_TOKEN}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-UNAUTH-014: Auth Token In Cookie Is Rejected
    [Documentation]   Verify token in cookie is not accepted
    ${cookies}=    Create Dictionary    token=${INVALID_TOKEN}
    ${response}=    GET    dgsn    /stations    cookies=${cookies}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-UNAUTH-015: Get Schedules Without Auth Returns 401
    [Documentation]   Verify /schedules requires authentication
    ${response}=    GET    dgsn    /schedules    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    Unauthorized API test completed at ${TEST_TIMESTAMP}
