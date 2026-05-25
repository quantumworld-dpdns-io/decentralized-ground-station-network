*** Settings ***
Documentation       A02: Cryptographic Failures - PQC Fallback Tests
...                 Verifies the system enforces PQC requirements and rejects classical fallback
Library             Collections
Library             RequestsLibrary
Library             ../../../libraries/QuantumLibrary.py
Library             ../../../libraries/DgsnLibrary.py
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Variables ***
${PQC_REQUIRED}             True

*** Test Cases ***
TC-PQC-001: Pqc Key Generation Enforces Dilithium
    [Documentation]   Verify PQC key generation uses Dilithium3 algorithms
    ${headers}    ${token}=    Authenticate As Admin
    ${payload}=    Create Dictionary    algorithm=${PQC_ALGORITHM_DILITHIUM}
    ${response}=    POST    dgsn    /crypto/pqc/key    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_OK}    ${response}
    ${body}=    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${body}    public_key
    Dictionary Should Contain Key    ${body}    algorithm
    Should Be Equal    ${body}[algorithm]    ${PQC_ALGORITHM_DILITHIUM}

TC-PQC-002: Pqc Key Generation Enforces Kyber
    [Documentation]   Verify PQC key generation uses Kyber768
    ${headers}    ${token}=    Authenticate As Admin
    ${payload}=    Create Dictionary    algorithm=${PQC_ALGORITHM_KYBER}
    ${response}=    POST    dgsn    /crypto/pqc/key    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_OK}    ${response}
    ${body}=    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${body}    public_key

TC-PQC-003: Classical Rsa Signature Is Rejected
    [Documentation]   Verify classical RSA signature is rejected when PQC required
    ${headers}    ${token}=    Authenticate As Admin
    ${payload}=    Create Dictionary    algorithm=RSA    data=test-message
    ${response}=    POST    dgsn    /crypto/pqc/sign    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}
    ${body}=    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${body}    error

TC-PQC-004: Classical Ecdsa Signature Is Rejected
    [Documentation]   Verify classical ECDSA signature is rejected
    ${headers}    ${token}=    Authenticate As Admin
    ${payload}=    Create Dictionary    algorithm=ECDSA    data=test-message
    ${response}=    POST    dgsn    /crypto/pqc/sign    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-PQC-005: Pqc Signature Verification With Dilithium
    [Documentation]   Verify PQC signature verification works with Dilithium
    ${headers}    ${token}=    Authenticate As Admin
    ${key_payload}=    Create Dictionary    algorithm=${PQC_ALGORITHM_DILITHIUM}
    ${key_resp}=    POST    dgsn    /crypto/pqc/key    json=${key_payload}    headers=${headers}    expected_status=anything
    ${key_body}=    Set Variable    ${key_resp.json()}
    ${public_key}=    Get From Dictionary    ${key_body}    public_key
    ${sign_payload}=    Create Dictionary    algorithm=${PQC_ALGORITHM_DILITHIUM}    data=test-message    public_key=${public_key}
    ${sign_resp}=    POST    dgsn    /crypto/pqc/sign    json=${sign_payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_OK}    ${sign_resp}
    ${sign_body}=    Set Variable    ${sign_resp.json()}
    Dictionary Should Contain Key    ${sign_body}    signature

TC-PQC-006: Pqc Verification Rejects Tampered Data
    [Documentation]   Verify PQC verification rejects tampered data
    ${headers}    ${token}=    Authenticate As Admin
    ${verification}=    Create Dictionary
    ...    algorithm=${PQC_ALGORITHM_DILITHIUM}
    ...    data=original-message
    ...    signature=tampered-signature-here
    ...    public_key=test-public-key
    ${response}=    POST    dgsn    /crypto/pqc/verify    json=${verification}    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.json()}
    ${valid}=    Get From Dictionary    ${body}    valid    default=False
    Should Not Be True    ${valid}    Tampered signature should not verify

TC-PQC-007: Pqc Signing Rejects Unknown Algorithm
    [Documentation]   Verify unknown PQC algorithm is rejected
    ${headers}    ${token}=    Authenticate As Admin
    ${payload}=    Create Dictionary    algorithm=Unknown-Algorithm    data=test
    ${response}=    POST    dgsn    /crypto/pqc/sign    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-PQC-008: Pqc Key Generation Rejects Weak Parameters
    [Documentation]   Verify weak PQC parameters are rejected
    ${headers}    ${token}=    Authenticate As Admin
    ${payload}=    Create Dictionary    algorithm=${PQC_ALGORITHM_DILITHIUM}    security_level=low
    ${response}=    POST    dgsn    /crypto/pqc/key    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-PQC-009: Falcon Algorithm Is Supported
    [Documentation]   Verify Falcon-512 is supported
    ${headers}    ${token}=    Authenticate As Admin
    ${payload}=    Create Dictionary    algorithm=${PQC_ALGORITHM_FALCON}
    ${response}=    POST    dgsn    /crypto/pqc/key    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_OK}    ${response}

TC-PQC-010: Sphincs Algorithm Is Supported
    [Documentation]   Verify SPHINCS+ is supported
    ${headers}    ${token}=    Authenticate As Admin
    ${payload}=    Create Dictionary    algorithm=${PQC_ALGORITHM_SPHINCS}
    ${response}=    POST    dgsn    /crypto/pqc/key    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_OK}    ${response}

TC-PQC-011: Pqc Endpoints Require Authentication
    [Documentation]   Verify PQC endpoints require auth
    ${response}=    POST    dgsn    /crypto/pqc/key    json={"algorithm":"Dilithium3"}    expected_status=anything
    Status Should Be    ${HTTP_UNAUTHORIZED}    ${response}

TC-PQC-012: Classical Fallback Config Is Rejected
    [Documentation]   Verify configuring classical crypto fallback is rejected
    ${headers}    ${token}=    Authenticate As Admin
    ${payload}=    Create Dictionary    allow_classical_fallback=true    pqc_only=false
    ${response}=    POST    dgsn    /admin/config    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    PQC fallback test completed at ${TEST_TIMESTAMP}
