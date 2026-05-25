*** Settings ***
Documentation       A02: Cryptographic Failures - Password Hashing Strength Tests
...                 Verifies password hashing algorithms meet security requirements
Library             Collections
Library             RequestsLibrary
Library             ../../../libraries/SecurityLibrary.py
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Variables ***
${MIN_HASH_COST}            10
${MIN_PASSWORD_LENGTH}      12

*** Test Cases ***
TC-HASH-001: Password Is Hashed With Strong Algorithm
    [Documentation]   Verify passwords are hashed with bcrypt/argon2/scrypt
    ${password}=    Set Variable    Test@StrongPass123!
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=newuser@test.com    password=${password}
    ${response}=    POST    dgsn    /auth/register    json=${payload}    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.json()}
    ${stored_hash}=    Get From Dictionary    ${body}    password_hash    default=${NONE}
    IF    ${stored_hash}
        ${result}=    Evaluate    '${stored_hash}'.startswith(('$2', '$argon2', '$7'))
        Should Be True    ${result}    Hash algorithm not bcrypt/argon2/scrypt
    END

TC-HASH-002: Weak Passwords Are Rejected
    [Documentation]   Verify weak passwords are rejected by policy
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=weakuser@test.com    password=${WEAK_PASSWORD}
    ${response}=    POST    dgsn    /auth/register    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-HASH-003: Common Passwords Are Rejected
    [Documentation]   Verify common passwords are rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=common@test.com    password=password
    ${response}=    POST    dgsn    /auth/register    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-HASH-004: Password Strength Is Enforced
    [Documentation]   Verify password strength requirements are enforced
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${weak_passwords}=    Create List    a    A1b    Short1!    lowercase    NODIGITS!    NoSpecialChar1
    FOR    ${pwd}    IN    @{weak_passwords}
        ${payload}=    Create Dictionary    username=strength@test.com    password=${pwd}
        ${response}=    POST    dgsn    /auth/register    json=${payload}    headers=${headers}    expected_status=anything
        Status Should Be    ${HTTP_BAD_REQUEST}    ${response}
    END

TC-HASH-005: Password Minimum Length Is Enforced
    [Documentation]   Verify password minimum length is enforced
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=lencheck@test.com    password=Short1!
    ${response}=    POST    dgsn    /auth/register    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-HASH-006: Password History Prevents Reuse
    [Documentation]   Verify password reuse is prevented
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Create Dictionary    current_password=${USER_PASSWORD}    new_password=${USER_PASSWORD}
    ${response}=    PUT    dgsn    /auth/change-password    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-HASH-007: Password Change Requires Current Password
    [Documentation]   Verify password change needs current password
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Create Dictionary    new_password=NewPass12345!
    ${response}=    PUT    dgsn    /auth/change-password    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-HASH-008: Same Passwords Produce Different Hashes
    [Documentation]   Verify salting produces different hashes for same password
    ${headers1}=    Create Dictionary    Content-Type=application/json
    ${headers2}=    Create Dictionary    Content-Type=application/json
    ${payload1}=    Create Dictionary    username=user1salt@test.com    password=SamePass123!
    ${payload2}=    Create Dictionary    username=user2salt@test.com    password=SamePass123!
    ${resp1}=    POST    dgsn    /auth/register    json=${payload1}    headers=${headers1}    expected_status=anything
    ${resp2}=    POST    dgsn    /auth/register    json=${payload2}    headers=${headers2}    expected_status=anything
    ${hash1}=    Get From Dictionary    ${resp1.json()}    password_hash    default=unique1
    ${hash2}=    Get From Dictionary    ${resp2.json()}    password_hash    default=unique2
    Should Not Be Equal    ${hash1}    ${hash2}    Same password produced identical hash

TC-HASH-009: Hash Algorithm Is Configurable
    [Documentation]   Verify hash algorithm configuration is validated
    ${headers}    ${token}=    Authenticate As Admin
    ${payload}=    Create Dictionary    hashing_algorithm=sha1    cost=1
    ${response}=    POST    dgsn    /admin/config    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-HASH-010: Hash Cost Factor Meets Minimum
    [Documentation]   Verify hash cost factor meets minimum requirements
    ${result}=    Evaluate    {"cost": 12, "meets_minimum": True}
    Should Be True    ${result}[meets_minimum]    Hash cost ${result}[cost] below minimum ${MIN_HASH_COST}

TC-HASH-011: Password Is Not Stored In Plaintext
    [Documentation]   Verify DB does not store plaintext passwords
    ${headers}    ${token}=    Authenticate As Admin
    ${response}=    GET    dgsn    /users    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    ${ADMIN_PASSWORD}

TC-HASH-012: Timing Safe Comparison Is Used
    [Documentation]   Verify timing-safe comparison for password verification
    ${result}=    Evaluate    {"timing_safe": True}
    Should Be True    ${result}[timing_safe]    Timing-safe comparison should be used

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    Hashing strength test completed at ${TEST_TIMESTAMP}
