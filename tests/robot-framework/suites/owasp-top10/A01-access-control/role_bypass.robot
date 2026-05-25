*** Settings ***
Documentation       A01: Broken Access Control - Role Bypass Tests
...                 Verifies role-based access controls cannot be bypassed
Library             Collections
Library             RequestsLibrary
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Variables ***
@{BYPASS_HEADERS}       X-Forwarded-For    X-Real-IP    X-Original-URL    X-Rewrite-URL

*** Test Cases ***
TC-RB-001: Role In User Header Cannot Be Overridden
    [Documentation]   Verify role parameter in body is ignored
    ${headers}    ${token}=    Authenticate As Low Privilege User
    ${payload}=    Create Dictionary    role=admin    action=delete_user
    ${response}=    POST    dgsn    /admin/users    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-RB-002: X-Forwarded-For Cannot Bypass Ip Based Roles
    [Documentation]   Verify IP spoofing cannot bypass access control
    ${headers}    ${token}=    Authenticate As Low Privilege User
    Set To Dictionary    ${headers}    X-Forwarded-For=127.0.0.1
    ${response}=    GET    dgsn    /admin    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-RB-003: Http Method Override Cannot Bypass Access Control
    [Documentation]   Verify X-HTTP-Method-Override cannot bypass
    ${headers}    ${token}=    Authenticate As Low Privilege User
    Set To Dictionary    ${headers}    X-HTTP-Method-Override=GET
    ${response}=    POST    dgsn    /admin/users    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-RB-004: Path Traversal Cannot Access Admin
    [Documentation]   Verify path traversal to admin endpoints is blocked
    ${headers}    ${token}=    Authenticate As Low Privilege User
    ${response}=    GET    dgsn    /../admin/users    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-RB-005: Double Encoding Cannot Bypass Access Control
    [Documentation]   Verify URL-encoded bypass attempts are rejected
    ${headers}    ${token}=    Authenticate As Low Privilege User
    ${response}=    GET    dgsn    /%61%64%6d%69%6e/users    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-RB-006: Case Sensitivity Cannot Bypass Access Control
    [Documentation]   Verify case variations of admin path are protected
    ${headers}    ${token}=    Authenticate As Low Privilege User
    ${response}=    GET    dgsn    /Admin/Users    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-RB-007: Null Byte Injection Cannot Bypass
    [Documentation]   Verify null byte injection cannot bypass access control
    ${headers}    ${token}=    Authenticate As Low Privilege User
    ${response}=    GET    dgsn    /admin%00/users    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-RB-008: Admin Token Required For Admin Operations
    [Documentation]   Verify admin operations require valid admin token
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Create Dictionary    username=newuser    password=Pass123!    role=admin
    ${response}=    POST    dgsn    /admin/users    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-RB-009: Elevated Privileges In Token Are Validated
    [Documentation]   Verify forged elevated privileges are rejected
    ${parsed}=    Evaluate    __import__('json').dumps({"sub":"lowpriv@dgsn.space","role":"admin"})
    ${b64}=    Evaluate    __import__('base64').urlsafe_b64encode(__import__('json').dumps({"alg":"HS256"}).encode()).rstrip(b"=").decode() + "." + __import__('base64').urlsafe_b64encode(__import__('json').dumps({"sub":"lowpriv@dgsn.space","role":"admin"}).encode()).rstrip(b"=").decode()
    ${forged}=    Set Variable    ${b64}.fakesignature
    ${headers}=    Create Dictionary    Authorization=Bearer ${forged}    Content-Type=application/json
    ${response}=    GET    dgsn    /admin/users    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-RB-010: GraphQL Introspection Cannot Expose Admin Schema
    [Documentation]   Verify admin operations are hidden from non-admins
    ${headers}    ${token}=    Authenticate As Low Privilege User
    ${payload}=    Create Dictionary    query=query{__schema{types{name}}}
    ${response}=    POST    dgsn    /graphql    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-RB-011: Multiple Role Headers Are Not Honored
    [Documentation]   Verify multiple role claim headers are ignored
    ${headers}    ${token}=    Authenticate As Low Privilege User
    Set To Dictionary    ${headers}    X-Role=admin    X-User-Role=superadmin
    ${response}=    GET    dgsn    /admin    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-RB-012: Referer Header Cannot Bypass Access Control
    [Documentation]   Verify Referer header cannot bypass access control
    ${headers}    ${token}=    Authenticate As Low Privilege User
    Set To Dictionary    ${headers}    Referer=https://admin.dgsn.space
    ${response}=    GET    dgsn    /admin    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    Role bypass test completed at ${TEST_TIMESTAMP}
