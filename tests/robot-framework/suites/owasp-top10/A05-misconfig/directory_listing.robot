*** Settings ***
Documentation       A05: Security Misconfiguration - Directory Listing Tests
...                 Verifies directory listing is disabled on all paths
Library             Collections
Library             RequestsLibrary
Library             ../../../libraries/SecurityLibrary.py
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Variables ***
@{SENSITIVE_PATHS}      /    /static    /static/    /uploads    /uploads/    /backup    /backup/    /config    /config/    /logs    /logs/    /.git    /.env    /admin    /admin/    /api    /api/    /tmp    /tmp/

*** Test Cases ***
TC-DL-001: Root Path Directory Listing Is Disabled
    [Documentation]   Verify root path does not list directories
    ${response}=    GET    dgsn    /    expected_status=anything
    ${body}=    Set Variable    ${response.text.lower()}
    Should Not Contain    ${body}    index of
    Should Not Contain    ${body}    directory listing

TC-DL-002: Static Directory Listing Is Disabled
    [Documentation]   Verify /static does not list files
    ${response}=    GET    dgsn    /static/    expected_status=anything
    ${body}=    Set Variable    ${response.text.lower()}
    Should Not Contain    ${body}    index of
    Should Not Contain    ${body}    parent directory

TC-DL-003: Uploads Directory Is Protected
    [Documentation]   Verify /uploads directory listing is disabled
    ${response}=    GET    dgsn    /uploads/    expected_status=anything
    Status Should Be    ${HTTP_NOT_FOUND}    ${response}

TC-DL-004: Backup Directory Listing Is Disabled
    [Documentation]   Verify /backup directory listing is disabled
    ${response}=    GET    dgsn    /backup/    expected_status=anything
    Status Should Be    ${HTTP_NOT_FOUND}    ${response}

TC-DL-005: Config Directory Listing Is Disabled
    [Documentation]   Verify /config directory listing is disabled
    ${response}=    GET    dgsn    /config/    expected_status=anything
    Status Should Be    ${HTTP_NOT_FOUND}    ${response}

TC-DL-006: Logs Directory Listing Is Disabled
    [Documentation]   Verify /logs directory listing is disabled
    ${response}=    GET    dgsn    /logs/    expected_status=anything
    Status Should Be    ${HTTP_NOT_FOUND}    ${response}

TC-DL-007: Git Directory Is Not Exposed
    [Documentation]   Verify /.git directory is not accessible
    ${response}=    GET    dgsn    /.git/config    expected_status=anything
    Status Should Be    ${HTTP_NOT_FOUND}    ${response}

TC-DL-008: Env File Is Not Exposed
    [Documentation]   Verify /.env is not accessible
    ${response}=    GET    dgsn    /.env    expected_status=anything
    Status Should Be    ${HTTP_NOT_FOUND}    ${response}

TC-DL-009: Tmp Directory Is Locked
    [Documentation]   Verify /tmp directory is not accessible
    ${response}=    GET    dgsn    /tmp/    expected_status=anything
    Status Should Be    ${HTTP_NOT_FOUND}    ${response}

TC-DL-010: Subdirectory Traversal Is Blocked
    [Documentation]   Verify path traversal through directories is blocked
    ${headers}    ${token}=    Authenticate As Regular User
    ${response}=    GET    dgsn    /stations/../../../etc/passwd    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_NOT_FOUND}    ${response}

TC-DL-011: Api Path Traversal Is Blocked
    [Documentation]   Verify API path traversal is blocked
    ${headers}    ${token}=    Authenticate As Regular User
    ${response}=    GET    dgsn    /api/../../etc/passwd    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_NOT_FOUND}    ${response}

TC-DL-012: Index File Is Properly Served
    [Documentation]   Verify proper index file is served for root
    ${response}=    GET    dgsn    /    expected_status=anything
    Status Should Be    ${HTTP_OK}    ${response}

TC-DL-013: Static Assets Directory Check
    [Documentation]   Verify static assets directory requires auth
    ${response}=    GET    dgsn    /static    expected_status=anything
    Should Not Be Equal    ${response.status_code}    ${HTTP_OK}

TC-DL-014: Node Modules Not Exposed
    [Documentation]   Verify node_modules is not accessible
    ${response}=    GET    dgsn    /node_modules/    expected_status=anything
    Status Should Be    ${HTTP_NOT_FOUND}    ${response}

TC-DL-015: Source Maps Not Exposed
    [Documentation]   Verify source maps are not exposed
    ${response}=    GET    dgsn    /static/js/main.js.map    expected_status=anything
    Status Should Be    ${HTTP_NOT_FOUND}    ${response}

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    Directory listing test completed at ${TEST_TIMESTAMP}
