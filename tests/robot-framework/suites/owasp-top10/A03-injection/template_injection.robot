*** Settings ***
Documentation       A03: Injection - Server-Side Template Injection Tests
...                 Verifies SSTI payloads are properly rejected
Library             Collections
Library             RequestsLibrary
Resource            ../../../resources/common.resource
Resource            ../../../resources/variables.resource
Test Setup          Setup Test Case
Test Teardown       Teardown Test Case

*** Variables ***
@{SSTI_ENGINES}          Jinja2    Mako    Pug    Handlebars    Mustache    Django

*** Test Cases ***
TC-SSTI-001: Jinja2 Template Injection In Name
    [Documentation]   Verify Jinja2 SSTI in name is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name={{config}}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SSTI-002: Mako Template Injection
    [Documentation]   Verify Mako SSTI is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name=\${self.module.cache.util.execute("id")}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SSTI-003: Expression Language Injection
    [Documentation]   Verify EL injection is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name=\${7*7}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SSTI-004: Template Injection Via Email
    [Documentation]   Verify SSTI in email field is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username=ssti@test.com    password=TestPass123!    email={{7*7}}@test.com
    ${response}=    POST    dgsn    /auth/register    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SSTI-005: Handlebars Template Injection
    [Documentation]   Verify Handlebars SSTI is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name={{#with "s" as |string|}}{{#with "e"}}{{#with split as |conslist|}}{{this.pop}}{{this.push (lookup string.sub "constructor")}}{{this.pop}}{{#with string.split as |codelist|}}{{this.pop}}{{this.push "return require('child_process').execSync('id').toString();"}}{{this.pop}}{{#each conslist}}{{#with (string.sub.apply 0 codelist)}}{{this}} {{/with}}{{/each}}{{/with}}{{/with}}{{/with}}{{/with}}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SSTI-006: Freemarker Template Injection
    [Documentation]   Verify Freemarker SSTI is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name=\${"freemarker.template.utility.Execute"?new()("id")}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SSTI-007: Velocity Template Injection
    [Documentation]   Verify Velocity SSTI is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name=#set($x=$class.inspect("java.lang.Runtime").getRuntime().exec("id"))
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SSTI-008: Twig Template Injection
    [Documentation]   Verify Twig SSTI is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name={{_self.env.registerUndefinedFilterCallback("exec")}}{{_self.env.getFilter("id")}}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SSTI-009: Smarty Template Injection
    [Documentation]   Verify Smarty SSTI is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name={system('id')}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SSTI-010: Jade Pug Template Injection
    [Documentation]   Verify Pug SSTI is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name=#{global.process.mainModule.require('child_process').execSync('id')}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SSTI-011: Mustache Template Injection In Search
    [Documentation]   Verify Mustache SSTI in query parameter is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${params}=    Create Dictionary    search={{7*7}}
    ${response}=    GET    dgsn    /stations    headers=${headers}    params=${params}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SSTI-012: Nunjucks Template Injection
    [Documentation]   Verify Nunjucks SSTI is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name={{range.constructor("return global.process.mainModule.require('child_process').execSync('id')")()}}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SSTI-013: Config Based Ssti
    [Documentation]   Verify config object access SSTI is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    ${payload}=    Generate Station Payload    name={{self.__init__.__globals__}}
    ${response}=    POST    dgsn    /stations    json=${payload}    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SSTI-014: Ssti In Http Headers
    [Documentation]   Verify SSTI in HTTP headers is rejected
    ${headers}    ${token}=    Authenticate As Regular User
    Set To Dictionary    ${headers}    User-Agent={{7*7}}
    ${response}=    GET    dgsn    /stations    headers=${headers}    expected_status=anything
    Status Should Be    ${HTTP_BAD_REQUEST}    ${response}

TC-SSTI-015: Ssti Via Error Template
    [Documentation]   Verify SSTI in error templates is rejected
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${payload}=    Create Dictionary    username={{7*7}}    password=test
    ${response}=    POST    dgsn    /auth/login    json=${payload}    headers=${headers}    expected_status=anything
    ${body}=    Set Variable    ${response.text}
    Should Not Contain    ${body}    49

*** Keywords ***
Setup Test Case
    ${timestamp}=    Get Current Date    result_format=epoch
    Set Test Variable    ${TEST_TIMESTAMP}    ${timestamp}

Teardown Test Case
    Log    Template injection test completed at ${TEST_TIMESTAMP}
