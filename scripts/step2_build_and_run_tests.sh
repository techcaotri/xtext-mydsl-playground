#!/bin/bash

# ----------------------------------
# Colors
# ----------------------------------
NOCOLOR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
LIGHTBLUE='\033[1;34m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# ----------------------------------
echo -e "${ORANGE}Building DSL project and running unit tests...${NOCOLOR}"
echo -e "${LIGHTBLUE}This will:${NOCOLOR}"
echo -e "${LIGHTBLUE}  1. Build org.xtext.example.mydsl (dependency)${NOCOLOR}"
echo -e "${LIGHTBLUE}  2. Compile org.xtext.example.mydsl.tests${NOCOLOR}"
echo -e "${LIGHTBLUE}  3. Run all unit tests${NOCOLOR}"
echo ""

set -e

# First, clean and update the target platform
echo -e "${YELLOW}Updating target platform...${NOCOLOR}"
mvn clean -pl org.xtext.example.mydsl.target 

# Build and run tests using Tycho Surefire
# -pl : project list - specifies which projects to build
# -am : also-make - builds the dependencies of the specified projects
# -T 12 : use 12 threads for parallel build
echo -e "${ORANGE}Running: mvn clean verify -pl org.xtext.example.mydsl.tests -am${NOCOLOR}"
mvn -T 12 clean verify \
    -pl org.xtext.example.mydsl.tests \
    -am \
    -Dtycho.localArtifacts=ignore \
    -DfailIfNoTests=false

# Check test results - Tycho Surefire puts results in a different location
TEST_RESULTS_DIR="org.xtext.example.mydsl.tests/target/surefire-reports"
TYCHO_TEST_RESULTS_DIR="org.xtext.example.mydsl.tests/target/surefire"

# Try both possible locations
if [ -d "$TYCHO_TEST_RESULTS_DIR" ]; then
    TEST_RESULTS_DIR="$TYCHO_TEST_RESULTS_DIR"
fi

if [ -d "$TEST_RESULTS_DIR" ]; then
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════${NOCOLOR}"
    echo -e "${GREEN}✓ Tests completed. Checking results...${NOCOLOR}"
    echo -e "${GREEN}═══════════════════════════════════════════════════${NOCOLOR}"
    
    # Count test results
    TOTAL_TESTS=0
    FAILED_TESTS=0
    ERROR_TESTS=0
    SKIPPED_TESTS=0
    
    # Check for XML test reports
    if ls "$TEST_RESULTS_DIR"/*.xml 1> /dev/null 2>&1; then
        for report in "$TEST_RESULTS_DIR"/*.xml; do
            if [ -f "$report" ]; then
                # Parse XML to get test counts (basic parsing)
                tests=$(grep -o 'tests="[0-9]*"' "$report" 2>/dev/null | grep -o '[0-9]*' || echo "0")
                failures=$(grep -o 'failures="[0-9]*"' "$report" 2>/dev/null | grep -o '[0-9]*' || echo "0")
                errors=$(grep -o 'errors="[0-9]*"' "$report" 2>/dev/null | grep -o '[0-9]*' || echo "0")
                skipped=$(grep -o 'skipped="[0-9]*"' "$report" 2>/dev/null | grep -o '[0-9]*' || echo "0")
                
                TOTAL_TESTS=$((TOTAL_TESTS + tests))
                FAILED_TESTS=$((FAILED_TESTS + failures))
                ERROR_TESTS=$((ERROR_TESTS + errors))
                SKIPPED_TESTS=$((SKIPPED_TESTS + skipped))
            fi
        done
        
        PASSED_TESTS=$((TOTAL_TESTS - FAILED_TESTS - ERROR_TESTS - SKIPPED_TESTS))
        
        echo -e "${LIGHTBLUE}Test Results Summary:${NOCOLOR}"
        echo -e "${LIGHTBLUE}┌─────────────────────────────────────────────────┐${NOCOLOR}"
        echo -e "  Total Tests:    ${TOTAL_TESTS}"
        if [ $PASSED_TESTS -gt 0 ]; then
            echo -e "  ${GREEN}✓ Passed:       ${PASSED_TESTS}${NOCOLOR}"
        fi
        if [ $FAILED_TESTS -gt 0 ]; then
            echo -e "  ${RED}✗ Failed:       ${FAILED_TESTS}${NOCOLOR}"
        fi
        if [ $ERROR_TESTS -gt 0 ]; then
            echo -e "  ${RED}✗ Errors:       ${ERROR_TESTS}${NOCOLOR}"
        fi
        if [ $SKIPPED_TESTS -gt 0 ]; then
            echo -e "  ${YELLOW}⊘ Skipped:      ${SKIPPED_TESTS}${NOCOLOR}"
        fi
        echo -e "${LIGHTBLUE}└─────────────────────────────────────────────────┘${NOCOLOR}"
        
        # Show test report location
        echo ""
        echo -e "${LIGHTBLUE}Detailed test reports available at:${NOCOLOR}"
        echo -e "  $TEST_RESULTS_DIR"
        
        # Exit with failure if tests failed
        if [ $FAILED_TESTS -gt 0 ] || [ $ERROR_TESTS -gt 0 ]; then
            echo ""
            echo -e "${RED}✗ Some tests failed. Please check the test reports for details.${NOCOLOR}"
            exit 1
        elif [ $TOTAL_TESTS -eq 0 ]; then
            echo ""
            echo -e "${YELLOW}⚠ No tests were executed. Check if tests are properly configured.${NOCOLOR}"
            echo -e "${YELLOW}  This might be due to compilation issues that need to be fixed first.${NOCOLOR}"
            exit 1
        else
            echo ""
            echo -e "${GREEN}✓ All tests passed successfully!${NOCOLOR}"
        fi
    else
        echo -e "${YELLOW}⚠ No test report files found. Tests may not have run.${NOCOLOR}"
        echo -e "${YELLOW}  Check the Maven output above for compilation or configuration issues.${NOCOLOR}"
        
        # Check if there were compilation errors
        if grep -q "BUILD FAILURE" ../maven.log 2>/dev/null; then
            echo -e "${RED}  Build failed. Please fix compilation errors first.${NOCOLOR}"
        fi
        exit 1
    fi
else
    echo -e "${RED}✗ Test results directory not found${NOCOLOR}"
    echo -e "${RED}  Expected: $TEST_RESULTS_DIR or $TYCHO_TEST_RESULTS_DIR${NOCOLOR}"
    echo -e "${YELLOW}  The build may have failed before tests could run.${NOCOLOR}"
    exit 1
fi

popd > /dev/null

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NOCOLOR}"
echo -e "${GREEN}✓ Build and test execution completed successfully!${NOCOLOR}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NOCOLOR}"
