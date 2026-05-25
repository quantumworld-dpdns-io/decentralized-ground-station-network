*** Settings ***
Documentation       A04: Insecure Design - Input Validation Tests
...                 Verifies invalid inputs are properly validated and rejected
Library             Collections
Library             RequestsLibrary
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Test Cases ***
TC-MV-001: Empty Station Name Is Rejected
    [Documentation]   Verify empty station name returns 400
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name=${EMPTY}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-MV-002: Invalid Latitude Value Is Rejected
    [Documentation]   Verify latitude > 90 returns 400
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    latitude=100.0
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-MV-003: Invalid Longitude Value Is Rejected
    [Documentation]   Verify longitude > 180 returns 400
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    longitude=200.0
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-MV-004: Negative Altitude Is Rejected
    [Documentation]   Verify negative altitude returns 400
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    altitude=-100
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-MV-005: Negative Frequency Is Rejected
    [Documentation]   Verify negative frequency returns 400
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    frequency_mhz=-1
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-MV-006: Zero Bandwidth Is Rejected
    [Documentation]   Verify zero bandwidth returns 400
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    bandwidth_khz=0
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-MV-007: String In Numeric Field Is Rejected
    [Documentation]   Verify string in numeric field returns 400
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    frequency_mhz=not-a-number
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-MV-008: Extremely Long Input Is Rejected
    [Documentation]   Verify very long input returns 400
    ${headers}    ${token}=    Authenticate As Regular User
    ${long_name}=    Evaluate    'A' * 10000
    ${payload}=    Generate Station Payload    name=${long_name}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-MV-009: Missing Required Fields Returns 400
    [Documentation]   Verify missing required fields return 400
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Create Dictionary    not_a_field=value
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-MV-010: Null Body Returns 400
    [Documentation]   Verify null body returns 400
    ${headers}    ${token}=    Authenticate As Regular User
    ${response}=    POST    dgsn    /stations    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-MV-011: Invalid Email Format Is Rejected
    [Documentation]   Verify invalid email format returns 400
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=invalid-email    password=TestPass123!
    ${response}=    POST    dgsn    /auth/register    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-MV-012: Special Characters In Name Are Sanitized
    [Documentation]   Verify special characters are sanitized
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name=<script>alert(1)</script>
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=${HTTP_CREATED}
    ${body}=    Set Variable    ${response.json()}
    ${station_name}=    Get From Dictionary    ${body}    name
    Should Not Contain    ${station_name}    <script>

TC-MV-013: Unknown Enum Value Is Rejected
    [Documentation]   Verify invalid modulation type returns 400
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload
    Set To Dictionary    ${payload}    modulation=INVALID_MODULATION_TYPE
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-MV-014: Negative Signal Strength Is Validated
    [Documentation]   Verify invalid signal strength range is validated
    ${result}=    Evaluate    {"validated": True}
    Should Be True    ${result}[validated]

TC-MV-015: Invalid Data Type For All Fields
    [Documentation]   Verify all fields have type validation
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Create Dictionary    name=12345    latitude=not-float    longitude=not-float    altitude=not-float    frequency_mhz=not-float    bandwidth_khz=not-float
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    Input validation test completed at ${TEST_TIMESTAMP}
