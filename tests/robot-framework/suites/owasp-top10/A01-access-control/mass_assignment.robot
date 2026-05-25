*** Settings ***
Documentation       A01: Broken Access Control - Mass Assignment Tests
...                 Verifies protected fields cannot be overridden via mass assignment
Library             Collections
Library             RequestsLibrary
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Variables ***
${PROTECTED_FIELD_ROLE}         role
${PROTECTED_FIELD_IS_ADMIN}     is_admin
${PROTECTED_FIELD_IS_ACTIVE}    is_active
${PROTECTED_FIELD_OWNER}        owner
${PROTECTED_FIELD_BALANCE}      balance

*** Test Cases ***
TC-MA-001: Cannot Override Role Field During Registration
    [Documentation]   Verify role field cannot be set during user registration
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=attack@test.com    password=Pass123!    role=admin
    ${response}=    POST    dgsn    /auth/register    json=${payload}    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.json()}
    ${role}=    Get From Dictionary    ${body}    role    default=user
    Should Not Be Equal    ${role}    admin

TC-MA-002: Cannot Override Is Admin Field In User Update
    [Documentation]   Verify is_admin cannot be set during profile update
    ${user_headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Create Dictionary    is_admin=true
    ${response}=    PUT    dgsn    /users/profile    json=${payload}    headers=${user_headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}
    ${body}=    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${body}    error

TC-MA-003: Cannot Override Owner Field In Station Creation
    [Documentation]   Verify owner field is ignored when creating stations
    ${user_headers}    ${token}=    Authenticate As Low Privilege User
    ${payload}=    Generate Station Payload
    Set To Dictionary    ${payload}    owner=admin    owner_id=admin@dgsn.space
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${user_headers}    expected_status=anything
    ${body}=    Set Variable    ${response.json()}
    ${assigned_owner}=    Get From Dictionary    ${body}    owner    default=
    Should Not Be Equal    ${assigned_owner}    admin

TC-MA-004: Cannot Override Balance Field In Profile Update
    [Documentation]   Verify balance/credits fields are protected
    ${user_headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Create Dictionary    balance=1000000    credits=999999
    ${response}=    PUT    dgsn    /users/profile    json=${payload}    headers=${user_headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-MA-005: Cannot Override Is Active On Other Users Station
    [Documentation]   Verify is_active override on other user's station is rejected
    ${user1_headers}    ${token1}=    Authenticate As Regular User
    ${user2_headers}    ${token2}=    Authenticate As Low Privilege User
    ${station_id}=    Create Station And Return Id    ${user1_headers}
    ${payload}=    Create Dictionary    is_active=false
    ${response}=    PUT    dgsn    /stations/${station_id}    json=${payload}    headers=${user2_headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-MA-006: Extra Fields In Payload Are Stripped Or Rejected
    [Documentation]   Verify extra unexpected fields are rejected
    ${user_headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload
    Set To Dictionary    ${payload}    hidden_field=malicious    _secret=leaked
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${user_headers}    expected_status=${HTTP_CREATED}
    ${body}=    Set Variable    ${response.json()}
    Dictionary Should Not Contain Key    ${body}    hidden_field

TC-MA-007: Nested Protected Fields Cannot Be Set
    [Documentation]   Verify nested protected fields are rejected
    ${user_headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Create Dictionary    settings=${CREATE_DICT}    permissions=${CREATE_DICT}
    Set To Dictionary    ${payload}    settings    role=admin
    Set To Dictionary    ${payload}    permissions    can_delete_users=true
    ${response}=    PUT    dgsn    /users/profile    json=${payload}    headers=${user_headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-MA-008: Json Array Injection Cannot Override Fields
    [Documentation]   Verify JSON array injection for fields is rejected
    ${user_headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Create Dictionary    role=["admin","superadmin"]
    ${response}=    PUT    dgsn    /users/profile    json=${payload}    headers=${user_headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-MA-009: Prototype Pollution Attempt Is Rejected
    [Documentation]   Verify prototype pollution payload is rejected
    ${user_headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Evaluate    {"__proto__": {"role": "admin"}, "name": "test"}
    ${response}=    PUT    dgsn    /users/profile    json=${payload}    headers=${user_headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-MA-010: Constructor Pollution Attempt Is Rejected
    [Documentation]   Verify constructor pollution is rejected
    ${user_headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Evaluate    {"constructor": {"prototype": {"role": "admin"}}, "name": "test"}
    ${response}=    PUT    dgsn    /users/profile    json=${payload}    headers=${user_headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    Mass assignment test completed at ${TEST_TIMESTAMP}
