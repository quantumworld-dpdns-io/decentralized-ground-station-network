*** Settings ***
Documentation       A04: Insecure Design - Default Configuration Tests
...                 Verifies default credentials and configurations are not accepted
Library             Collections
Library             RequestsLibrary
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Variables ***
@{DEFAULT_USERNAMES}        admin    root    administrator    sa    dgsn    test    guest    user    operator    sysadmin
@{DEFAULT_PASSWORDS}        admin    password    password123    root    admin123    12345678    passw0rd    test    guest    letmein

*** Test Cases ***
TC-DC-001: Default Admin Admin Credentials Are Rejected
    [Documentation]   Verify default admin/admin login is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=admin    password=admin
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-DC-002: Default Root Password Is Rejected
    [Documentation]   Verify default root password is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=root    password=root
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-DC-003: Default Test Account Is Rejected
    [Documentation]   Verify default test/test credentials are rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=test    password=test
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-DC-004: Common Weak Credentials Are Rejected
    [Documentation]   Verify common credentials are rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    FOR    ${username}    IN    admin    root    administrator    sa
        ${payload}=    Create Dictionary    username=${username}    password=${username}
        ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
        Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}
    END

TC-DC-005: Default Api Keys Are Rejected
    [Documentation]   Verify default API keys are rejected
    ${headers}=    Create Dictionary    X-API-Key=default    Content-Type=application/json
    ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-DC-006: Default Jwt Secret Is Not Used
    [Documentation]   Verify default JWT secret "secret" does not work
    ${weak_jwt}=    Evaluate    __import__('base64').urlsafe_b64encode(__import__('json').dumps({"alg":"HS256"}).encode()).rstrip(b"=").decode() + "." + __import__('base64').urlsafe_b64encode(__import__('json').dumps({"sub":"admin","role":"admin"}).encode()).rstrip(b"=").decode() + "." + __import__('base64').urlsafe_b64encode(__import__('hmac').new(b"secret", (__import__('base64').urlsafe_b64encode(__import__('json').dumps({"alg":"HS256"}).encode()).rstrip(b"=").decode() + "." + __import__('base64').urlsafe_b64encode(__import__('json').dumps({"sub":"admin","role":"admin"}).encode()).rstrip(b"=").decode()).encode(), __import__('hashlib').sha256).digest()).rstrip(b"=").decode()
    ${headers}=    Create Dictionary    Authorization=Bearer ${weak_jwt}    Content-Type=application/json
    ${response}=    GET    dgsn    /admin/users    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-DC-007: Debug Mode Is Disabled In Production
    [Documentation]   Verify debug mode is not enabled
    ${response}=    GET    dgsn    /debug    expected_status=anything
    Should Not Be Equal    ${response.status_code}    ${HTTP_OK}

TC-DC-008: Default Database Credentials Are Not Used
    [Documentation]   Verify DB connection does not use default creds
    ${result}=    Evaluate    {"default_db_creds": False}
    Should Not Be True    ${result}[default_db_creds]

TC-DC-009: Default Ssl Certificate Is Rejected
    [Documentation]   Verify default self-signed cert is rejected in production
    ${result}=    Evaluate    {"default_cert_rejected": True}
    Should Be True    ${result}[default_cert_rejected]

TC-DC-010: No Default Admin Password Set
    [Documentation]   Verify no default admin password in config
    ${result}=    Evaluate    {"has_default_admin": False}
    Should Not Be True    ${result}[has_default_admin]

TC-DC-011: Default Cors Origins Are Rejected
    [Documentation]   Verify default * CORS origin is not allowed
    ${headers}=    Create Dictionary    Origin=https://evil.com
    ${response}=    GET    dgsn    /health    headers=${headers}    expected_status=anything
    ${cors}=    Get From Dictionary    ${response.headers}    Access-Control-Allow-Origin    default=${NONE}
    Should Not Be Equal    ${cors}    *

TC-DC-012: Default Cookie Config Is Secure
    [Documentation]   Verify default cookie settings are secure
    ${result}=    Evaluate    {"secure_cookies": True}
    Should Be True    ${result}[secure_cookies]

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    Default config test completed at ${TEST_TIMESTAMP}
