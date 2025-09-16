#!/bin/bash

# Build and Test Script for MyDsl Project
# Generates test reports and code coverage

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "MyDsl Build and Test Script"
echo "================================================"
echo ""

# Configuration
PROJECT_DIR="$(pwd)"
REPORTS_DIR="${PROJECT_DIR}/test-reports"
COVERAGE_DIR="${PROJECT_DIR}/coverage-reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_ARCHIVE="${PROJECT_DIR}/test-results-${TIMESTAMP}.tar.gz"

# Parse command line arguments
SKIP_CLEAN=false
SKIP_BUILD=false
SKIP_TESTS=false
GENERATE_SITE=false
PROFILE="test"

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-clean)
            SKIP_CLEAN=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --generate-site)
            GENERATE_SITE=true
            shift
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --skip-clean      Skip the clean phase"
            echo "  --skip-build      Skip the build phase"
            echo "  --skip-tests      Skip test execution"
            echo "  --generate-site   Generate Maven site with reports"
            echo "  --profile <name>  Use specific Maven profile (default: test)"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to print colored messages
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to check if Maven is installed
check_maven() {
    if ! command -v mvn &> /dev/null; then
        print_error "Maven is not installed or not in PATH"
        exit 1
    fi
    print_status "Maven version: $(mvn --version | head -n 1)"
}

# Function to create directories
setup_directories() {
    print_status "Setting up directories..."
    mkdir -p "${REPORTS_DIR}"
    mkdir -p "${COVERAGE_DIR}"
    mkdir -p "${PROJECT_DIR}/target"
}

# Function to clean the project
clean_project() {
    if [ "$SKIP_CLEAN" = false ]; then
        print_status "Cleaning project..."
        mvn clean -T 12
    else
        print_warning "Skipping clean phase"
    fi
}

# Function to build the project
build_project() {
    if [ "$SKIP_BUILD" = false ]; then
        print_status "Building project..."
        
        # First, generate Xtext artifacts
        print_status "Generating Xtext artifacts..."
        cd org.xtext.example.mydsl
        mvn clean compile -T 12
        cd ..
        
        # Build all modules
        print_status "Building all modules..."
        mvn install -DskipTests -T 12
    else
        print_warning "Skipping build phase"
    fi
}

# Function to run tests with coverage
run_tests() {
    if [ "$SKIP_TESTS" = false ]; then
        print_status "Running tests with coverage..."
        
        cd org.xtext.example.mydsl.tests
        
        # Run tests with JaCoCo coverage
        mvn clean test -T 12 \
            -Djacoco.destFile="${COVERAGE_DIR}/jacoco.exec" \
            -Dmaven.test.failure.ignore=false \
            -Dsurefire.reportsDirectory="${REPORTS_DIR}/surefire" \
            -P${PROFILE} \
            || TEST_FAILED=true
        
        # Generate JaCoCo reports
        print_status "Generating coverage reports..."
        mvn jacoco:report -T 12 \
            -Djacoco.dataFile="${COVERAGE_DIR}/jacoco.exec" \
            -Djacoco.outputDirectory="${COVERAGE_DIR}/jacoco-html"
        
        cd ..
        
        if [ "$TEST_FAILED" = true ]; then
            print_error "Some tests failed. Check reports for details."
        else
            print_status "All tests passed!"
        fi
    else
        print_warning "Skipping test execution"
    fi
}

# Function to run Tycho tests
run_tycho_tests() {
    print_status "Running Tycho Surefire tests..."
    
    mvn clean verify -T 12 \
        -Dtycho.testArgLine="-javaagent:${HOME}/.m2/repository/org/jacoco/org.jacoco.agent/0.8.11/org.jacoco.agent-0.8.11-runtime.jar=destfile=${COVERAGE_DIR}/jacoco-tycho.exec" \
        -P${PROFILE} \
        || TYCHO_TEST_FAILED=true
    
    if [ "$TYCHO_TEST_FAILED" = true ]; then
        print_warning "Some Tycho tests failed"
    fi
}

# Function to generate Maven site
generate_site() {
    if [ "$GENERATE_SITE" = true ]; then
        print_status "Generating Maven site with reports..."
        mvn site -T 12
        
        print_status "Site generated at: ${PROJECT_DIR}/target/site/index.html"
    fi
}

# Function to generate summary report
generate_summary() {
    print_status "Generating summary report..."
    
    SUMMARY_FILE="${REPORTS_DIR}/test-summary-${TIMESTAMP}.txt"
    
    cat > "${SUMMARY_FILE}" << EOF
================================================================================
Test Execution Summary
Generated: $(date)
================================================================================

Project: MyDsl Xtext Project
Profile: ${PROFILE}

Test Results Location:
- Surefire Reports: ${REPORTS_DIR}/surefire/
- Coverage Reports: ${COVERAGE_DIR}/
- JaCoCo HTML: ${COVERAGE_DIR}/jacoco-html/index.html

EOF

    # Add test statistics if available
    if [ -d "${REPORTS_DIR}/surefire" ]; then
        echo "Test Statistics:" >> "${SUMMARY_FILE}"
        echo "---------------" >> "${SUMMARY_FILE}"
        
        # Count test results from XML files
        TOTAL_TESTS=$(grep -h "tests=\"[0-9]*\"" ${REPORTS_DIR}/surefire/*.xml 2>/dev/null | sed 's/.*tests=\"\([0-9]*\)\".*/\1/' | awk '{sum += $1} END {print sum}' || echo "0")
        FAILED_TESTS=$(grep -h "failures=\"[0-9]*\"" ${REPORTS_DIR}/surefire/*.xml 2>/dev/null | sed 's/.*failures=\"\([0-9]*\)\".*/\1/' | awk '{sum += $1} END {print sum}' || echo "0")
        ERROR_TESTS=$(grep -h "errors=\"[0-9]*\"" ${REPORTS_DIR}/surefire/*.xml 2>/dev/null | sed 's/.*errors=\"\([0-9]*\)\".*/\1/' | awk '{sum += $1} END {print sum}' || echo "0")
        SKIPPED_TESTS=$(grep -h "skipped=\"[0-9]*\"" ${REPORTS_DIR}/surefire/*.xml 2>/dev/null | sed 's/.*skipped=\"\([0-9]*\)\".*/\1/' | awk '{sum += $1} END {print sum}' || echo "0")
        
        echo "Total Tests: ${TOTAL_TESTS}" >> "${SUMMARY_FILE}"
        echo "Passed: $((TOTAL_TESTS - FAILED_TESTS - ERROR_TESTS - SKIPPED_TESTS))" >> "${SUMMARY_FILE}"
        echo "Failed: ${FAILED_TESTS}" >> "${SUMMARY_FILE}"
        echo "Errors: ${ERROR_TESTS}" >> "${SUMMARY_FILE}"
        echo "Skipped: ${SKIPPED_TESTS}" >> "${SUMMARY_FILE}"
    fi
    
    # Add coverage statistics if available
    if [ -f "${COVERAGE_DIR}/jacoco.exec" ]; then
        echo "" >> "${SUMMARY_FILE}"
        echo "Code Coverage:" >> "${SUMMARY_FILE}"
        echo "-------------" >> "${SUMMARY_FILE}"
        echo "JaCoCo execution data: ${COVERAGE_DIR}/jacoco.exec" >> "${SUMMARY_FILE}"
        echo "HTML Report: ${COVERAGE_DIR}/jacoco-html/index.html" >> "${SUMMARY_FILE}"
    fi
    
    cat "${SUMMARY_FILE}"
}

# Function to archive reports
archive_reports() {
    print_status "Archiving test reports..."
    
    tar -czf "${REPORT_ARCHIVE}" \
        -C "${PROJECT_DIR}" \
        "test-reports" \
        "coverage-reports" \
        2>/dev/null || print_warning "Could not create archive"
    
    if [ -f "${REPORT_ARCHIVE}" ]; then
        print_status "Reports archived to: ${REPORT_ARCHIVE}"
    fi
}

# Function to open reports in browser
open_reports() {
    if [ "$SKIP_TESTS" = false ]; then
        print_status "Opening reports in browser..."
        
        # Detect OS and open accordingly
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            xdg-open "${COVERAGE_DIR}/jacoco-html/index.html" 2>/dev/null || true
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            open "${COVERAGE_DIR}/jacoco-html/index.html" 2>/dev/null || true
        elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
            start "${COVERAGE_DIR}/jacoco-html/index.html" 2>/dev/null || true
        fi
    fi
}

# Main execution
main() {
    print_status "Starting build and test process..."
    echo ""
    
    check_maven
    setup_directories
    clean_project
    build_project
    run_tests
    
    # Optionally run Tycho tests
    # run_tycho_tests
    
    generate_site
    generate_summary
    archive_reports
    open_reports
    
    echo ""
    echo "================================================"
    print_status "Build and test process completed!"
    echo "================================================"
    echo ""
    print_status "Reports available at:"
    echo "  - Test Reports: ${REPORTS_DIR}/"
    echo "  - Coverage: ${COVERAGE_DIR}/jacoco-html/index.html"
    if [ -f "${REPORT_ARCHIVE}" ]; then
        echo "  - Archive: ${REPORT_ARCHIVE}"
    fi
    if [ "$GENERATE_SITE" = true ]; then
        echo "  - Maven Site: ${PROJECT_DIR}/target/site/index.html"
    fi
}

# Run main function
main
