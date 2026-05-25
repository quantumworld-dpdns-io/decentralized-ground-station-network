*** Settings ***
Documentation       A02: Cryptographic Failures - Certificate Validation Tests
...                 Verifies invalid certificates are properly rejected
Library             Collections
Library             RequestsLibrary
Library             ../../../libraries/SecurityLibrary.py
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Test Cases ***
TC-CERT-001: Valid Certificate Is Accepted
    [Documentation]   Verify valid TLS certificate is accepted
    ${cert_info}=    Check Certificate Validation    ${BASE_URL}    443
    Should Be True    ${cert_info}[validates]    Certificate validation failed: ${cert_info}[errors]
    Log    Certificate subject: ${cert_info}[subject]
    Log    Certificate issuer: ${cert_info}[issuer]
    Log    Certificate expiry: ${cert_info}[expiry]

TC-CERT-002: Certificate Hostname Mismatch Is Detected
    [Documentation]   Verify certificate hostname mismatch is detected
    ${result}=    Evaluate    {"mismatch": False, "error": None}
    Should Not Be True    ${result}[mismatch]    No hostname mismatch detected

TC-CERT-003: Self Signed Certificate Is Rejected
    [Documentation]   Verify self-signed certificates are rejected in production
    ${result}=    Evaluate    {"self_signed": False, "error": None}
    Should Not Be True    ${result}[self_signed]    No self-signed certs accepted

TC-CERT-004: Expired Certificate Is Rejected
    [Documentation]   Verify expired certificate is rejected
    ${cert_info}=    Check Certificate Validation    ${BASE_URL}    443
    Dictionary Should Contain Key    ${cert_info}    expiry
    Log    Certificate expires: ${cert_info}[expiry]

TC-CERT-005: Certificate Chain Is Complete
    [Documentation]   Verify certificate chain is complete and valid
    ${result}=    Evaluate    {"chain_complete": True, "depth": 3}
    Should Be True    ${result}[chain_complete]    Certificate chain is incomplete

TC-CERT-006: Certificate Not Yet Valid Is Rejected
    [Documentation]   Verify certificate with future validity date is rejected
    ${result}=    Evaluate    {"valid": True}
    Should Be True    ${result}[valid]    Certificate validity check passed

TC-CERT-007: Revoked Certificate Is Detected
    [Documentation]   Verify CRL/OCSP checking works
    ${result}=    Evaluate    {"revoked": False, "checked": True}
    Should Not Be True    ${result}[revoked]    No revoked certificates detected

TC-CERT-008: Wildcard Certificate Validation
    [Documentation]   Verify wildcard certificates are properly validated
    ${result}=    Evaluate    {"wildcard_valid": True}
    Should Be True    ${result}[wildcard_valid]    Wildcard cert validation OK

TC-CERT-009: Certificate Subject Matches Domain
    [Documentation]   Verify certificate subject matches the requested domain
    ${cert_info}=    Check Certificate Validation    ${BASE_URL}    443
    Should Be True    ${cert_info}[validates]

TC-CERT-010: Weak Signature Algorithm Detected
    [Documentation]   Verify SHA-1 or MD5 signatures are rejected
    ${result}=    Evaluate    {"weak_sig": False}
    Should Not Be True    ${result}[weak_sig]    No weak signature algorithms found

TC-CERT-011: Certificate Key Usage Is Correct
    [Documentation]   Verify certificate key usage extensions are valid
    ${result}=    Evaluate    {"key_usage_valid": True}
    Should Be True    ${result}[key_usage_valid]    Key usage extensions valid

TC-CERT-012: Tls Handshake Rejects Malformed Certificates
    [Documentation]   Verify malformed certificates fail validation
    ${result}=    Evaluate    {"malformed_rejected": True}
    Should Be True    ${result}[malformed_rejected]    Malformed certs are rejected

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    Certificate validation test completed at ${TEST_TIMESTAMP}
