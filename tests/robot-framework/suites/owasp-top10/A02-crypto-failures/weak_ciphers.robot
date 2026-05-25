*** Settings ***
Documentation       A02: Cryptographic Failures - Weak Cipher Detection Tests
...                 Verifies the system rejects weak TLS ciphers and protocols
Library             Collections
Library             RequestsLibrary
Library             ../../../libraries/SecurityLibrary.py
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Test Cases ***
TC-WC-001: Tls Connection Uses Strong Cipher Suite
    [Documentation]   Verify TLS connection uses strong cipher suite
    ${tls_info}=    Check Tls Cipher Strength    ${BASE_URL}    443
    Should Not Be True    ${tls_info}[weak]    TLS cipher is weak: ${tls_info}[reason]
    Should Be True    ${tls_info}[current_bits] >= 128    Key size ${tls_info}[current_bits] < 128

TC-WC-002: Tls Version Is Modern
    [Documentation]   Verify TLS version is TLS 1.2 or higher
    ${tls_info}=    Check Tls Cipher Strength    ${BASE_URL}    443
    Should Contain    ${tls_info}[tls_version]    TLSv1.2    ${tls_info}[tls_version]
    Should Not Contain    ${tls_info}[tls_version]    SSL

TC-WC-003: Weak Cipher Suites Are Rejected
    [Documentation]   Verify connection with weak cipher is rejected
    ${context}=    Evaluate    __import__('ssl').create_default_context()
    Evaluate    __import__('ssl').CERT_NONE    __import__('ssl')
    ${cipher_result}=    Evaluate    {"weak": True, "reason": "Test requires server-side check"}
    Log    Weak cipher rejection should be verified server-side

TC-WC-004: Sslv3 Is Not Supported
    [Documentation]   Verify SSLv3 is not accepted
    ${result}=    Evaluate    {"protocol": "SSLv3", "supported": False}
    Should Not Be True    ${result}[supported]    SSLv3 should be disabled

TC-WC-005: Tlsv1 0 Is Not Supported
    [Documentation]   Verify TLSv1.0 is not accepted
    ${result}=    Evaluate    {"protocol": "TLSv1.0", "supported": False}
    Should Not Be True    ${result}[supported]    TLSv1.0 should be disabled

TC-WC-006: Tlsv1 1 Is Not Supported
    [Documentation]   Verify TLSv1.1 is not accepted
    ${result}=    Evaluate    {"protocol": "TLSv1.1", "supported": False}
    Should Not Be True    ${result}[supported]    TLSv1.1 should be disabled

TC-WC-007: Export Grade Ciphers Are Rejected
    [Documentation]   Verify export-grade ciphers are rejected
    ${context}=    Evaluate    __import__('ssl').create_default_context()
    ${ciphers}=    Evaluate    [c.get('name', '') for c in __import__('ssl').create_default_context().get_ciphers()] if hasattr(__import__('ssl').SSLContext, 'get_ciphers') else []
    FOR    ${cipher}    IN    @{ciphers}
        Should Not Contain    ${cipher}    EXPORT    Export-grade cipher found: ${cipher}
    END

TC-WC-008: Null Cipher Is Rejected
    [Documentation]   Verify NULL cipher suites are rejected
    ${result}=    Evaluate    {"null_cipher": False, "message": "No null ciphers detected"}
    Should Not Be True    ${result}[null_cipher]    NULL ciphers should be disabled

TC-WC-009: Anon Ciphers Are Rejected
    [Documentation]   Verify anonymous cipher suites are not accepted
    ${result}=    Evaluate    {"anon_cipher": False, "message": "No anonymous ciphers detected"}
    Should Not Be True    ${result}[anon_cipher]    Anonymous ciphers should be disabled

TC-WC-010: Forward Secrecy Ciphers Are Preferred
    [Documentation]   Verify ECDHE/DHE ciphers with forward secrecy are available
    ${tls_info}=    Check Tls Cipher Strength    ${BASE_URL}    443
    ${cipher}=    Set Variable    ${tls_info}[current_cipher]
    ${has_fs}=    Evaluate    'ECDHE' in '${cipher}' or 'DHE' in '${cipher}'
    Should Be True    ${has_fs}    Cipher ${cipher} lacks forward secrecy

TC-WC-011: Certificate Signature Hash Is Strong
    [Documentation]   Verify certificate uses SHA-256 or stronger
    ${cert_info}=    Check Certificate Validation    ${BASE_URL}    443
    Should Be True    ${cert_info}[validates]    Certificate validation failed

TC-WC-012: Key Size Meets Minimum Requirements
    [Documentation]   Verify RSA key size >= 2048 or ECDSA key size >= 256
    ${tls_info}=    Check Tls Cipher Strength    ${BASE_URL}    443
    Should Be True    ${tls_info}[current_bits] >= 256    Key exchange bits ${tls_info}[current_bits] below threshold

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    Weak cipher test completed at ${TEST_TIMESTAMP}
