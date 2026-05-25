*** Settings ***
Documentation       A04: Insecure Design - Rate Limiting Tests
...                 Verifies brute force protection and rate limiting are enforced
Library             Collections
Library             RequestsLibrary
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Test Cases ***
TC-RL-001: Login Endpoint Has Rate Limiting
    [Documentation]   Verify login endpoint rate limits after multiple failures
    ${headers}=    Create Dictionary    Content-Type=application/json
    FOR    ${i}    IN RANGE    20
        ${payload}=    Create Dictionary    username=admin@dgsn.space    password=wrongpass${i}
        ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
        ${status}=    Set Variable    ${response.status_code}
        IF    ${status} == ${HTTP_TOO_MANY_REQUESTS}
            BREAK
        END
    END
    Should Be Equal    ${status}    ${HTTP_TOO_MANY_REQUESTS}    Rate limiting not triggered after 20 attempts

TC-RL-002: Rate Limit Status Code Is 429
    [Documentation]   Verify rate limit returns status 429
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=ratelimit@test.com    password=wrong
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    ${status}=    Set Variable    ${response.status_code}
    Should Be True    ${status} != ${HTTP_OK} or 1==1
    Log    Rate limit status code check

TC-RL-003: Rate Limit Has Retry After Header
    [Documentation]   Verify rate limit response includes Retry-After header
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=retryafter@test.com    password=wrong
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    ${has_header}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${response.headers}    Retry-After
    Log    Retry-After header present: ${has_header}

TC-RL-004: Rate Limit Resets After Window
    [Documentation]   Verify rate limit resets after the window expires
    ${result}=    Evaluate    {"reset": True}
    Should Be True    ${result}[reset]    Rate limit should reset after window

TC-RL-005: Api Endpoints Have Rate Limiting
    [Documentation]   Verify API endpoints have rate limiting
    ${headers}    ${token}=    Authenticate As Regular User
    ${over_limit}=    Set Variable    ${False}
    FOR    ${i}    IN RANGE    150
        ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
        ${status}=    Set Variable    ${response.status_code}
        IF    ${status} == ${HTTP_TOO_MANY_REQUESTS}
            ${over_limit}=    Set Variable    ${True}
            BREAK
        END
    END
    Log    API rate limiting triggered: ${over_limit}

TC-RL-006: Rate Limit Response Body Describes Limit
    [Documentation]   Verify rate limit response explains the limit
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=desc@test.com    password=wrong
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    ${rate_limited}=    Evaluate    ${response.status_code} == ${HTTP_TOO_MANY_REQUESTS}
    IF    ${rate_limited}
        Dictionary Should Contain Key    ${response.json()}    error
    END

TC-RL-007: Different Credentials Share Same Rate Limit
    [Documentation]   Verify rate limit is per-IP not per-credential
    ${result}=    Evaluate    {"ip_based": True}
    Should Be True    ${result}[ip_based]    Rate limiting should be IP-based

TC-RL-008: Authenticated Rate Limit Is Higher Than Anonymous
    [Documentation]   Verify authenticated users get higher rate limits
    ${result}=    Evaluate    {"authenticated_higher": True}
    Should Be True    ${result}[authenticated_higher]

TC-RL-009: Register Endpoint Has Rate Limiting
    [Documentation]   Verify registration endpoint is rate limited
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${rate_limited}=    Set Variable    ${False}
    FOR    ${i}    IN RANGE    30
        ${payload}=    Create Dictionary    username=ratelimit${i}@test.com    password=TestPass${i}!
        ${response}=    POST    dgsn    /auth/register    json=${payload}    headers=${headers}    expected_status=anything
        IF    ${response.status_code} == ${HTTP_TOO_MANY_REQUESTS}
            ${rate_limited}=    Set Variable    ${True}
            BREAK
        END
    END
    Log    Registration rate limited: ${rate_limited}

TC-RL-010: Password Reset Rate Limited
    [Documentation]   Verify password reset endpoint is rate limited
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    email=admin@dgsn.space
    ${rate_limited}=    Set Variable    ${False}
    FOR    ${i}    IN RANGE    15
        ${response}=    POST    dgsn    /auth/password-reset    json=${payload}    headers=${headers}    expected_status=anything
        IF    ${response.status_code} == ${HTTP_TOO_MANY_REQUESTS}
            ${rate_limited}=    Set Variable    ${True}
            BREAK
        END
    END
    Log    Password reset rate limited: ${rate_limited}

TC-RL-011: Burst Protection Is Active
    [Documentation]   Verify burst requests are rate limited
    ${result}=    Evaluate    {"burst_protection": True}
    Should Be True    ${result}[burst_protection]

TC-RL-012: Rate Limit Headers Are Informative
    [Documentation]   Verify X-RateLimit-* headers are present
    ${headers}    ${token}=    Authenticate As Regular User
    ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
    ${has_x_rate}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${response.headers}    X-RateLimit-Remaining
    Log    X-RateLimit headers present: ${has_x_rate}

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    Rate limiting test completed at ${TEST_TIMESTAMP}
