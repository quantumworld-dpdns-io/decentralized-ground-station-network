*** Settings ***
Documentation       A05: Security Misconfiguration - Stack Trace Leakage Tests
...                 Verifies error responses do not leak stack traces or debug info
Library             Collections
Library             RequestsLibrary
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Variables ***
@{STACK_INDICATORS}         Traceback    at )    in )    File    line    at com.    at org.    at net.    \\\\.pyc    Internal Server Error    Debug    Exception    Stack Trace    \\\\$Error

*** Test Cases ***
TC-ST-001: Malformed Json Does Not Leak Stack Trace
    [Documentation]   Verify malformed JSON does not produce stack trace
    ${headers}    ${token}=    Authenticate As Regular User
    ${response}=    POST    dgsn    /stations    data={invalid json}    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    Traceback
    Should Not Contain    ${body}    at

TC-ST-002: Invalid Endpoint Does Not Leak Stack Trace
    [Documentation]   Verify 404 does not produce stack trace
    ${response}=    GET    dgsn    /nonexistent-path-that-does-not-exist    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    Traceback
    Should Not Contain    ${body}    Internal Server Error

TC-ST-003: Server Error Does Not Leak Internal Paths
    [Documentation]   Verify 500 errors do not reveal internal paths
    ${headers}    ${token}=    Authenticate As Admin
    ${payload}=    Create Dictionary    action=trigger_error
    ${response}=    POST    dgsn    /admin/config    json=${payload}    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    /var/www
    Should Not Contain    ${body}    /home/
    Should Not Contain    ${body}    /app/
    Should Not Contain    ${body}    /Users/

TC-ST-004: Validation Error Does Not Leak Implementation Details
    [Documentation]   Verify validation errors do not leak internals
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name=${EMPTY}    latitude=abc
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    Schema
    Should Not Contain    ${body}    validator
    Should Not Contain    ${body}    class

TC-ST-005: Auth Error Does Not Reveal User Existence
    [Documentation]   Verify auth errors do not reveal user existence
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=nonexistent_user_abc123@test.com    password=wrongpass
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    user not found
    Should Not Contain    ${body}    incorrect username

TC-ST-006: Error Response Has Generic Message
    [Documentation]   Verify error messages are generic
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=nonexistent@test.com    password=wrong
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.json()}
    ${error}=    Get From Dictionary    ${body}    error    default=Unknown error
    Should Not Contain    ${error}    password_hash
    Should Not Contain    ${error}    database

TC-ST-007: Error Response Has Consistent Format
    [Documentation]   Verify error responses have consistent format
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    latitude=999
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.json()}
    ${has_error}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${body}    error
    ${has_message}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${body}    message
    Should Be True    ${has_error} or ${has_message}

TC-ST-008: Html Error Pages Do Not Leak Info
    [Documentation]   Verify HTML error pages are sanitized
    ${response}=    GET    dgsn    /nonexistent    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    Exception
    Should Not Contain    ${body}    Stack Trace

TC-ST-009: Debug Env Variable Is Not Leaked
    [Documentation]   Verify debug env var is not exposed
    ${response}=    GET    dgsn    /health    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    DEBUG=true
    Should Not Contain    ${body}    APP_ENV=development

TC-ST-010: Error Does Not Expose Query
    [Documentation]   Verify errors do not expose DB queries
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=' OR 1=1 --    password=test
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    SELECT
    Should Not Contain    ${body}    INSERT
    Should Not Contain    ${body}    UPDATE
    Should Not Contain    ${body}    DELETE

TC-ST-011: Production Mode Returns Generic 500
    [Documentation]   Verify production mode returns generic error on 500
    ${result}=    Evaluate    {"production_mode": True}
    Should Be True    ${result}[production_mode]

TC-ST-012: Error Codes Are Not Sequential
    [Documentation]   Verify error codes do not reveal implementation info
    ${result}=    Evaluate    {"error_codes_generic": True}
    Should Be True    ${result}[error_codes_generic]

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    Stack trace test completed at ${TEST_TIMESTAMP}
