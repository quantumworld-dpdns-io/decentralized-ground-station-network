*** Settings ***
Documentation       A01: Broken Access Control - Insecure Direct Object Reference Tests
...                 Verifies users cannot access other users' receipts by ID
Library             Collections
Library             RequestsLibrary
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Test Cases ***
TC-IDOR-001: User Cannot Access Another Users Receipt By Id
    [Documentation]   Verify receipt access control between different users
    ${user1_headers}    ${user1_token}=    Authenticate As Regular User
    ${user2_headers}    ${user2_token}=    Authenticate As Low Privilege User
    ${station_id}=    Create Station And Return Id    ${user1_headers}
    ${receipt}=    Create Receipt For Station    ${station_id}    ${user1_headers}
    ${receipt_id}=    Get From Dictionary    ${receipt}    id
    ${response}=    GET    dgsn    /receipts/${receipt_id}    headers=${user2_headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-IDOR-002: User Cannot List Another Users Receipts
    [Documentation]   Verify receipt listing is scoped to authenticated user
    ${user1_headers}    ${token1}=    Authenticate As Regular User
    ${user2_headers}    ${token2}=    Authenticate As Low Privilege User
    ${response}=    GET    dgsn    /receipts?user_id=${ADMIN_USERNAME}    headers=${user2_headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-IDOR-003: User Cannot Modify Another Users Receipt
    [Documentation]   Verify PUT on other user's receipt returns 403
    ${user1_headers}    ${token1}=    Authenticate As Regular User
    ${user2_headers}    ${token2}=    Authenticate As Low Privilege User
    ${station_id}=    Create Station And Return Id    ${user1_headers}
    ${receipt}=    Create Receipt For Station    ${station_id}    ${user1_headers}
    ${receipt_id}=    Get From Dictionary    ${receipt}    id
    ${update}=    Create Dictionary    frequency_mhz=145.800
    ${response}=    PUT    dgsn    /receipts/${receipt_id}    json=${update}    headers=${user2_headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-IDOR-004: User Cannot Delete Another Users Receipt
    [Documentation]   Verify DELETE on other user's receipt returns 403
    ${user1_headers}    ${token1}=    Authenticate As Regular User
    ${user2_headers}    ${token2}=    Authenticate As Low Privilege User
    ${station_id}=    Create Station And Return Id    ${user1_headers}
    ${receipt}=    Create Receipt For Station    ${station_id}    ${user1_headers}
    ${receipt_id}=    Get From Dictionary    ${receipt}    id
    ${response}=    DELETE    dgsn    /receipts/${receipt_id}    headers=${user2_headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-IDOR-005: User Cannot Access Another Users Station By Id
    [Documentation]   Verify station access control between users
    ${user1_headers}    ${token1}=    Authenticate As Regular User
    ${user2_headers}    ${token2}=    Authenticate As Low Privilege User
    ${station_id}=    Create Station And Return Id    ${user1_headers}
    ${response}=    GET    dgsn    /stations/${station_id}    headers=${user2_headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-IDOR-006: User Cannot Modify Another Users Station
    [Documentation]   Verify PUT on other user's station returns 403
    ${user1_headers}    ${token1}=    Authenticate As Regular User
    ${user2_headers}    ${token2}=    Authenticate As Low Privilege User
    ${station_id}=    Create Station And Return Id    ${user1_headers}
    ${update}=    Create Dictionary    name=Hacked-Station
    ${response}=    PUT    dgsn    /stations/${station_id}    json=${update}    headers=${user2_headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-IDOR-007: Sequential Id Enumeration Is Protected
    [Documentation]   Verify accessing non-existent or other user receipt IDs
    ${user_headers}    ${token}=    Authenticate As Low Privilege User
    ${response}=    GET    dgsn    /receipts/999999999    headers=${user_headers}    expected_status=anything
    Status Should Be    ${HTTP_NOT_FOUND}    ${response}

TC-IDOR-008: User Cannot Access Admin Receipts
    [Documentation]   Verify regular user cannot list admin's receipts
    ${user_headers}    ${token}=    Authenticate As Low Privilege User
    ${response}=    GET    dgsn    /receipts?user=admin    headers=${user_headers}    expected_status=anything
    Status Should Be    ${HTTP_FORBIDDEN}    ${response}

TC-IDOR-009: Receipt Access By Uuid Pattern Is Enforced
    [Documentation]   Verify GUID/UUID receipt IDs are not guessable
    ${user_headers}    ${token}=    Authenticate As Low Privilege User
    ${fake_uuid}=    Evaluate    __import__('uuid').uuid4().__str__()
    ${response}=    GET    dgsn    /receipts/${fake_uuid}    headers=${user_headers}    expected_status=anything
    Status Should Be    ${HTTP_NOT_FOUND}    ${response}

TC-IDOR-010: Owner Can Access Own Receipt
    [Documentation]   Verify the owner can access their own receipt
    ${user_headers}    ${token}=    Authenticate As Regular User
    ${station_id}=    Create Station And Return Id    ${user_headers}
    ${receipt}=    Create Receipt For Station    ${station_id}    ${user_headers}
    ${receipt_id}=    Get From Dictionary    ${receipt}    id
    ${response}=    GET    dgsn    /receipts/${receipt_id}    headers=${user_headers}    expected_status=anything
    Status Should Be    ${HTTP_OK}    ${response}

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    IDOR test completed at ${TEST_TIMESTAMP}
