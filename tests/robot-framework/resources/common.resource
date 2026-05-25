# DGSN Common Keywords
# Shared keywords for API calls, authentication, and data generators

*** Settings ***
Documentation   Common keywords used across all test suites
Library         Collections
Library         JSONLibrary
Library         OperatingSystem
Library         RequestsLibrary
Library         String
Library         DateTime
Library         ../libraries/DgsnLibrary.py
Library         ../libraries/SecurityLibrary.py
Variables       variables.resource

*** Keywords ***
Initialize Test Environment
    [Documentation]   Initialize global test state
    Create Session    dgsn    ${BASE_URL}    verify=true    disable_warnings=true
    ${auth_result}=   Create Auth Session    ${BASE_URL}    ${ADMIN_USERNAME}    ${ADMIN_PASSWORD}
    Set Suite Variable    ${AUTH_TOKEN}    ${auth_result}[access_token]
    Set Suite Variable    ${AUTH_RESULT}    ${auth_result}

Cleanup Test Environment
    [Documentation]   Clean up test data and sessions
    Delete All Sessions
    Clear Auth

Setup Test Case
    [Documentation]   Per-test-case setup
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    [Documentation]   Per-test-case teardown
    Log    Test completed at ${TEST_TIMESTAMP}

Authenticate As Admin
    [Documentation]   Authenticate as admin user
    ${auth}=    Create Auth Session    ${BASE_URL}    ${ADMIN_USERNAME}    ${ADMIN_PASSWORD}
    ${token}=    Get From Dictionary    ${auth}    access_token
    ${headers}=    Create Dictionary    Authorization=Bearer ${token}    Content-Type=application/json
    RETURN    ${headers}    ${token}

Authenticate As Regular User
    [Documentation]   Authenticate as regular user
    ${auth}=    Create Auth Session    ${BASE_URL}    ${USER_USERNAME}    ${USER_PASSWORD}
    ${token}=    Get From Dictionary    ${auth}    access_token
    ${headers}=    Create Dictionary    Authorization=Bearer ${token}    Content-Type=application/json
    RETURN    ${headers}    ${token}

Authenticate As Low Privilege User
    [Documentation]   Authenticate as low-privilege user
    ${auth}=    Create Auth Session    ${BASE_URL}    ${LOW_PRIV_USERNAME}    ${LOW_PRIV_PASSWORD}
    ${token}=    Get From Dictionary    ${auth}    access_token
    ${headers}=    Create Dictionary    Authorization=Bearer ${token}    Content-Type=application/json
    RETURN    ${headers}    ${token}

Authenticate With Token
    [Documentation]   Authenticate using a specific token
    [Arguments]    ${token}
    ${headers}=    Create Dictionary    Authorization=Bearer ${token}    Content-Type=application/json
    RETURN    ${headers}    ${token}

Create HTTP Headers
    [Documentation]   Create standard HTTP headers
    [Arguments]    ${token}=${NONE}
    ${headers}=    Create Dictionary    Content-Type=application/json
    IF    ${token}    Set To Dictionary    ${headers}    Authorization=Bearer ${token}
    RETURN    ${headers}

Send GET Request
    [Documentation]   Send a GET request with proper error handling
    [Arguments]    ${endpoint}    ${headers}=${NONE}    ${expected_status}=${HTTP_OK}    ${params}=${NONE}
    IF    ${headers} == ${NONE}
        ${headers}=    Create HTTP Headers
    END
    IF    ${params} == ${NONE}
        ${response}=    GET    dgsn    ${endpoint}    headers=${headers}    expected_status=anything
    ELSE
        ${response}=    GET    dgsn    ${endpoint}    headers=${headers}    params=${params}    expected_status=anything
    END
    Status Should Be    ${expected_status}    ${response}
    RETURN    ${response}

Send POST Request
    [Documentation]   Send a POST request with proper error handling
    [Arguments]    ${endpoint}    ${data}=${NONE}    ${headers}=${NONE}    ${expected_status}=${HTTP_OK}
    IF    ${headers} == ${NONE}
        ${headers}=    Create HTTP Headers
    END
    IF    ${data} == ${NONE}
        ${response}=    POST    dgsn    ${endpoint}    headers=${headers}    expected_status=anything
    ELSE
        ${response}=    POST    dgsn    ${endpoint}    json=${data}    headers=${headers}    expected_status=anything
    END
    Status Should Be    ${expected_status}    ${response}
    RETURN    ${response}

Send PUT Request
    [Documentation]   Send a PUT request with proper error handling
    [Arguments]    ${endpoint}    ${data}=${NONE}    ${headers}=${NONE}    ${expected_status}=${HTTP_OK}
    IF    ${headers} == ${NONE}
        ${headers}=    Create HTTP Headers
    END
    IF    ${data} == ${NONE}
        ${response}=    PUT    dgsn    ${endpoint}    headers=${headers}    expected_status=anything
    ELSE
        ${response}=    PUT    dgsn    ${endpoint}    json=${data}    headers=${headers}    expected_status=anything
    END
    Status Should Be    ${expected_status}    ${response}
    RETURN    ${response}

Send DELETE Request
    [Documentation]   Send a DELETE request with proper error handling
    [Arguments]    ${endpoint}    ${headers}=${NONE}    ${expected_status}=${HTTP_NO_CONTENT}
    IF    ${headers} == ${NONE}
        ${headers}=    Create HTTP Headers
    END
    ${response}=    DELETE    dgsn    ${endpoint}    headers=${headers}    expected_status=anything
    Status Should Be    ${expected_status}    ${response}
    RETURN    ${response}

Create Station And Return Id
    [Documentation]   Create a station and return its ID
    [Arguments]    ${headers}=${NONE}
    ${payload}=    Generate Station Payload
    ${response}=    Send POST Request    ${ENDPOINT_STATIONS}    ${payload}    ${headers}    ${HTTP_CREATED}
    ${body}=    Set Variable    ${response.json()}
    ${station_id}=    Get From Dictionary    ${body}    id
    RETURN    ${station_id}

Create Receipt For Station
    [Documentation]   Create a receipt associated with a station
    [Arguments]    ${station_id}    ${headers}=${NONE}
    ${payload}=    Generate Receipt Payload    ${station_id}
    ${response}=    Send POST Request    ${ENDPOINT_RECEIPTS}    ${payload}    ${headers}    ${HTTP_CREATED}
    ${body}=    Set Variable    ${response.json()}
    RETURN    ${body}

Create Schedule For Station
    [Documentation]   Create a schedule for a station
    [Arguments]    ${station_id}    ${headers}=${NONE}
    ${payload}=    Generate Schedule Payload    ${station_id}
    ${response}=    Send POST Request    ${ENDPOINT_SCHEDULES}    ${payload}    ${headers}    ${HTTP_CREATED}
    ${body}=    Set Variable    ${response.json()}
    RETURN    ${body}

Assert Response Contains
    [Documentation]   Assert that response contains expected key
    [Arguments]    ${response}    ${key}
    ${body}=    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${body}    ${key}

Assert Response Value
    [Documentation]   Assert a specific response value
    [Arguments]    ${response}    ${key}    ${expected}
    ${body}=    Set Variable    ${response.json()}
    ${actual}=    Get From Dictionary    ${body}    ${key}
    Should Be Equal    ${actual}    ${expected}

Assert Error Response
    [Documentation]   Assert proper error response structure
    [Arguments]    ${response}    ${expected_status}    ${expected_error_contains}=${NONE}
    Status Should Be    ${expected_status}    ${response}
    ${body}=    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${body}    error
    IF    ${expected_error_contains}    Should Contain    ${body}[error]    ${expected_error_contains}

Generate Random String
    [Documentation]   Generate a random alphanumeric string
    [Arguments]    ${length}=8
    ${chars}=    Evaluate    ''.join(random.choices(string.ascii_uppercase + string.digits, k=${length}))    random,string
    RETURN    ${chars}

Assert Security Header Present
    [Documentation]   Assert a security header is present in the response
    [Arguments]    ${response}    ${header_name}
    Dictionary Should Contain Key    ${response.headers}    ${header_name}

Assert Security Header Value
    [Documentation]   Assert a security header has expected value
    [Arguments]    ${response}    ${header_name}    ${expected_value}
    Assert Security Header Present    ${response}    ${header_name}
    Should Be Equal    ${response.headers}[${header_name}]    ${expected_value}

Get Json Value
    [Documentation]   Safely get a value from JSON response
    [Arguments]    ${response}    ${key}
    ${body}=    Set Variable    ${response.json()}
    ${value}=    Get From Dictionary    ${body}    ${key}
    RETURN    ${value}

Validate Paginated Response
    [Documentation]   Validate a paginated API response
    [Arguments]    ${response}
    ${body}=    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${body}    data
    Dictionary Should Contain Key    ${body}    total
    Dictionary Should Contain Key    ${body}    page
    Dictionary Should Contain Key    ${body}    page_size

Wait For Condition
    [Documentation]   Wait for a condition with timeout
    [Arguments]    ${condition_func}    ${timeout}=${TIMEOUT_DEFAULT}    ${interval}=1
    ${elapsed}=    Set Variable    ${0}
    WHILE    ${elapsed} < ${timeout}
        ${result}=    Evaluate    ${condition_func}()
        IF    ${result}    BREAK
        Sleep    ${interval}s
        ${elapsed}=    Evaluate    ${elapsed} + ${interval}
    END
    Should Be True    ${elapsed} < ${timeout}    Condition not met within ${timeout}s
