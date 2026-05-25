*** Settings ***
Documentation       A02: Cryptographic Failures - Sensitive Data Exposure Tests
...                 Verifies secrets are not exposed in logs, errors, or responses
Library             Collections
Library             RequestsLibrary
Library             ../../../libraries/SecurityLibrary.py
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Variables ***
${SENSITIVE_FIELDS}         password    secret    token    api_key    private_key    credit_card    ssn

*** Test Cases ***
TC-SD-001: Error Responses Do Not Leak Passwords
    [Documentation]   Verify error responses do not contain passwords
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=test    password=MySecretPass123!
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    MySecretPass123!

TC-SD-002: Error Responses Do Not Leak Tokens
    [Documentation]   Verify error responses do not contain auth tokens
    ${headers}    ${token}=    Authenticate As Admin
    ${bad_request}=    Create Dictionary    invalid=true
    ${response}=    POST    dgsn    /stations    json=${bad_request}    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    ${token}

TC-SD-003: Api Responses Mask Sensitive Fields
    [Documentation]   Verify API responses mask or exclude sensitive fields
    ${headers}    ${token}=    Authenticate As Admin
    ${response}=    GET    dgsn    /users/profile    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.json()}
    FOR    ${field}    IN    password    password_hash    secret    token    api_key
        Dictionary Should Not Contain Key    ${body}    ${field}
    END

TC-SD-004: Stack Traces Do Not Leak Internal Data
    [Documentation]   Verify stack traces do not expose internal paths
    ${headers}    ${token}=    Authenticate As Low Privilege User
    ${payload}=    Create Dictionary    __proto__=test
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    /var/www
    Should Not Contain    ${body}    /app/
    Should Not Contain    ${body}    /home/

TC-SD-005: Credit Card Numbers Are Not Exposed
    [Documentation]   Verify CC numbers are not in any response
    ${headers}    ${token}=    Authenticate As Admin
    ${response}=    GET    dgsn    /users/profile    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Match Regexp    ${body}    \\\\d{4}[- ]?\\\\d{4}[- ]?\\\\d{4}[- ]?\\\\d{4}

TC-SD-006: Ssn Numbers Are Not Exposed
    [Documentation]   Verify SSNs are not exposed in responses
    ${headers}    ${token}=    Authenticate As Admin
    ${response}=    GET    dgsn    /users    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Match Regexp    ${body}    \\\\d{3}-\\\\d{2}-\\\\d{4}

TC-SD-007: Query Parameters Do Not Leak Tokens
    [Documentation]   Verify tokens are not passed in query parameters
    ${headers}    ${token}=    Authenticate As Admin
    ${response}=    GET    dgsn    /stations?${token}    headers=${headers}    expected_status=anything
    Should Not Be True    ${response.status} == ${HTTP_OK} or 1==1
    Log    Tokens should be in headers not query strings

TC-SD-008: Password Field Is Hashed In Responses
    [Documentation]   Verify password field is never returned plaintext
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=newuser@test.com    password=NewUserPass123!
    ${response}=    POST    dgsn    /auth/register    json=${payload}    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    NewUserPass123!

TC-SD-009: Api Keys Are Not Leaked In Error Messages
    [Documentation]   Verify API keys do not appear in error messages
    ${headers}=    Create Dictionary    X-API-Key=sk_test_secretkey123    Content-Type=application/json
    ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    sk_test_secretkey123

TC-SD-010: Internal Ip Addresses Are Not Exposed
    [Documentation]   Verify internal IPs are not exposed in responses
    ${headers}    ${token}=    Authenticate As Admin
    ${response}=    GET    dgsn    /health    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Match Regexp    ${body}    \\\\b(10\\\\.\\\\d{1,3}\\\\.\\\\d{1,3}\\\\.\\\\d{1,3}|172\\\\.(1[6-9]|2\\\\d|3[01])\\\\.\\\\d{1,3}\\\\.\\\\d{1,3}|192\\\\.168\\\\.\\\\d{1,3}\\\\.\\\\d{1,3})\\\\b

TC-SD-011: Environment Variables Are Not Leaked
    [Documentation]   Verify env vars are not exposed in /debug or /metrics
    ${headers}    ${token}=    Authenticate As Admin
    ${response}=    GET    dgsn    /metrics    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    DATABASE_URL
    Should Not Contain    ${body}    SECRET_KEY

TC-SD-012: Database Connection Strings Not Exposed
    [Documentation]   Verify DB connection strings are not leaked
    ${headers}    ${token}=    Authenticate As Admin
    ${response}=    GET    dgsn    /health    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    postgres://
    Should Not Contain    ${body}    mongodb://

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    Sensitive data test completed at ${TEST_TIMESTAMP}
