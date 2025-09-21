#!/bin/bash

# Build and Test Script for MyDsl Project with Test Suite Support
# Generates test reports and code coverage with cross-module support
# Linux OS Support Only

set -e # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Decoration functions
print_header() {
    local header_text="$1"
    local width=80
    local padding=$(( (width - ${#header_text} - 2) / 2 ))
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}║${NC}%*s${WHITE}%s${NC}%*s${CYAN}║${NC}\n" $padding "" "$header_text" $((width - padding - ${#header_text} - 2)) ""
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_subheader() {
    local text="$1"
    echo ""
    echo -e "${BLUE}┌──────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│ ${WHITE}$text${NC}"
    echo -e "${BLUE}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
}

print_step() {
    local step_num="$1"
    local step_text="$2"
    echo ""
    echo -e "${MAGENTA}[Step $step_num]${NC} ${WHITE}$step_text${NC}"
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────────────────${NC}"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_suite() {
    echo -e "${CYAN}[SUITE]${NC} $1"
}

print_test() {
    echo -e "${MAGENTA}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_failure() {
    echo -e "${RED}✗${NC} $1"
}

print_header "MyDsl Build and Test Script with Suite Support"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Working Directory: $(pwd)"

# Configuration
PROJECT_DIR="$(pwd)"
REPORTS_DIR="${PROJECT_DIR}/test-reports"
COVERAGE_DIR="${PROJECT_DIR}/coverage-reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_ARCHIVE="${PROJECT_DIR}/test-results-${TIMESTAMP}.tar.gz"

# Parse command line arguments
DO_CLEAN=false
SKIP_BUILD=false
SKIP_TESTS=false
GENERATE_SITE=false
PROFILE="test"
TEST_SUITE=""
LIST_SUITES=false
DESCRIBE_SUITE=""

while [[ $# -gt 0 ]]; do
	case $1 in
	--clean)
		DO_CLEAN=true
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
	--suite)
		TEST_SUITE="$2"
		shift 2
		;;
	--list-suites)
		LIST_SUITES=true
		shift
		;;
	--describe-suite)
		DESCRIBE_SUITE="$2"
		shift 2
		;;
	--help)
		print_header "Help Documentation"
		echo "Usage: $0 [options]"
		echo ""
		echo "Build Options:"
		echo "  --clean           Do the clean phase"
		echo "  --skip-build      Skip the build phase"
		echo "  --skip-tests      Skip test execution"
		echo "  --generate-site   Generate Maven site with reports"
		echo "  --profile <n>     Use specific Maven profile (default: test)"
		echo ""
		echo "Test Suite Options:"
		echo "  --suite <n>       Run specific test suite (unit, integration, smoke, all, fast, custom)"
		echo "  --list-suites     List all available test suites"
		echo "  --describe-suite <n>  Show detailed info about a test suite"
		echo ""
		echo "Examples:"
		echo "  $0 --clean --suite unit            # Clean build and run unit tests"
		echo "  $0 --list-suites                    # List available test suites"
		echo "  $0 --describe-suite integration     # Show integration suite details"
		echo "  $0 --skip-build --suite smoke       # Run smoke tests without building"
		echo "  $0 --suite all --generate-site      # Run all tests and generate site"
		exit 0
		;;
	*)
		print_error "Unknown option: $1"
		echo "Use --help for usage information"
		exit 1
		;;
	esac
done

# Function to check if Maven is installed
check_maven() {
	print_step "0" "Checking Prerequisites"
	
	if ! command -v mvn &>/dev/null; then
		print_failure "Maven is not installed or not in PATH"
		exit 1
	fi
	print_success "Maven version: $(mvn --version | head -n 1)"
	
	# Check Java version
	if command -v java &>/dev/null; then
		print_success "Java version: $(java -version 2>&1 | head -n 1)"
	fi
}

# Function to list test suites
list_test_suites() {
	print_header "Listing Available Test Suites"
	
	# Compile the test suite manager if needed
	if [ ! -f "org.xtext.example.mydsl.tests/target/classes/org/xtext/example/mydsl/tests/suites/TestSuiteManager.class" ]; then
		print_status "Compiling test suite manager..."
		cd org.xtext.example.mydsl.tests
		mvn compile -DskipTests -q
		cd ..
	fi
	
	# Run the test suite manager list command
	cd org.xtext.example.mydsl.tests
	java -cp "target/classes:target/test-classes:$(mvn dependency:build-classpath -DincludeScope=test -q -Dmdep.outputFile=/dev/stdout)" \
		org.xtext.example.mydsl.tests.suites.TestSuiteManager list
	cd ..
}

# Function to describe a test suite
describe_test_suite() {
	local suite_name="$1"
	
	print_header "Test Suite Description: $suite_name"
	
	if [ -z "$suite_name" ]; then
		print_error "Suite name is required"
		exit 1
	fi
	
	# Compile if needed
	if [ ! -f "org.xtext.example.mydsl.tests/target/classes/org/xtext/example/mydsl/tests/suites/TestSuiteManager.class" ]; then
		print_status "Compiling test suite manager..."
		cd org.xtext.example.mydsl.tests
		mvn compile -DskipTests -q
		cd ..
	fi
	
	# Run the describe command
	cd org.xtext.example.mydsl.tests
	java -cp "target/classes:target/test-classes:$(mvn dependency:build-classpath -DincludeScope=test -q -Dmdep.outputFile=/dev/stdout)" \
		org.xtext.example.mydsl.tests.suites.TestSuiteManager describe "$suite_name"
	cd ..
}

# Function to clean the project
clean_project() {
	print_step "1" "Clean Phase"
	
	if [ "$DO_CLEAN" = true ]; then
		print_status "Cleaning project (--clean specified)..."
		mvn clean -T 12
		print_success "Project cleaned"

		# Clean and recreate report directories
		print_status "Cleaning report directories..."
		rm -rf "${REPORTS_DIR}" "${COVERAGE_DIR}"
		mkdir -p "${REPORTS_DIR}"
		mkdir -p "${COVERAGE_DIR}"
		print_success "Report directories cleaned and recreated"
	else
		print_status "Skipping clean phase (use --clean to force cleaning)"
		# Still ensure directories exist
		mkdir -p "${REPORTS_DIR}"
		mkdir -p "${COVERAGE_DIR}"
	fi
}

# Function to build the project
build_project() {
	print_step "2" "Build Phase"
	
	if [ "$SKIP_BUILD" = false ]; then
		print_subheader "Building Target Platform"
		cd org.xtext.example.mydsl.target
		mvn clean install -DskipTests
		print_success "Target platform built"
		cd ..

		print_subheader "Building Main Module"
		cd org.xtext.example.mydsl

		# Step 1: Clean if requested
		if [ "$DO_CLEAN" = true ]; then
			mvn clean
		fi
		
		# Build with single thread to ensure proper ordering
		print_status "Running full build lifecycle (this may take a moment)..."
		mvn clean install -DskipTests -Pcoverage
		print_success "Main module built"
		
		cd ..

		print_subheader "Building Other Modules"
		mvn install -DskipTests -T 12 -Pcoverage -pl !org.xtext.example.mydsl
		
		print_success "Build phase completed successfully!"
	else
		print_warning "Skipping build phase"
	fi
}

# Function to run tests with specific suite
run_tests_with_suite() {
	local suite_name="$1"
	
	print_step "3" "Test Execution Phase"
	
	if [ -z "$suite_name" ]; then
		# No suite specified, run default
		run_tests
		return
	fi
	
	print_subheader "Running Test Suite: $suite_name"
	
	TEST_FAILED=false
	
	# Determine which suite class to run based on suite name
	case "$suite_name" in
		"all")
			print_status "Running all tests with pattern-based discovery..."
			# Use pattern-based test discovery for all tests
			mvn verify -T 12 \
				-Pcoverage \
				-Dmaven.test.failure.ignore=true \
				-DfailIfNoTests=false \
				-Dtest="**/*Test,**/*Tests,**/Test*" \
				-DfailIfNoTests=false || TEST_FAILED=true
			;;
		"unit")
			print_status "Running unit tests..."
			mvn verify -T 12 \
				-Pcoverage \
				-Dmaven.test.failure.ignore=true \
				-DfailIfNoTests=false \
				-Dtest="**/TemplateLoader*Test" || TEST_FAILED=true
			;;
		"integration")
			print_status "Running integration tests..."
			mvn verify -T 12 \
				-Pcoverage \
				-Dmaven.test.failure.ignore=true \
				-DfailIfNoTests=false \
				-Dtest="**/Generator*Test" || TEST_FAILED=true
			;;
		*)
			print_error "Unknown suite: $suite_name"
			print_warning "Available suites: unit, integration, smoke, all, fast, custom-generator"
			exit 1
			;;
	esac
	
	# Generate reports
	generate_coverage_reports
	
	if [ "$TEST_FAILED" = true ]; then
		print_failure "Some tests failed in suite: $suite_name"
		print_warning "Reports have been generated despite test failures."
	else
		print_success "All tests passed in suite: $suite_name!"
	fi
}

# Function to run tests (default, without suite)
run_tests() {
	print_step "3" "Test Execution Phase (All Tests)"
	
	if [ "$SKIP_TESTS" = false ]; then
		print_status "Discovering and running all test classes..."

		TEST_FAILED=false

		# Run tests with JaCoCo coverage using wildcard patterns
		print_status "Executing tests with JaCoCo coverage..."
		mvn verify -T 12 \
			-Pcoverage \
			-Dmaven.test.failure.ignore=true \
			-DfailIfNoTests=false \
			-Dtest="**/*Test,**/*Tests,**/Test*" || TEST_FAILED=true

		generate_coverage_reports

		if [ "$TEST_FAILED" = true ]; then
			print_failure "Some tests failed. Check reports for details."
			print_warning "Reports have been generated despite test failures."
		else
			print_success "All tests passed!"
		fi
	else
		print_warning "Skipping test execution"
	fi
}

# Function to generate coverage reports
generate_coverage_reports() {
	print_step "4" "Coverage Report Generation"
	
	print_subheader "Generating Individual Module Reports"
	
	cd org.xtext.example.mydsl
	mvn jacoco:report -Pcoverage -Dmaven.test.failure.ignore=true || true
	print_success "Main module coverage report generated"
	cd ..

	cd org.xtext.example.mydsl.tests
	mvn jacoco:report -Pcoverage -Dmaven.test.failure.ignore=true || true

	# Generate surefire HTML report
	print_subheader "Generating Surefire HTML Report"
	mvn surefire-report:report -T 12 -Dmaven.test.failure.ignore=true || true
	print_success "Surefire report generated"

	# Copy test reports
	if [ -d "target/surefire-reports" ]; then
		cp -r target/surefire-reports "${REPORTS_DIR}/"
		print_success "Surefire test reports copied to reports directory"
	fi

	# Copy surefire HTML report
	if [ -f "target/site/surefire-report.html" ]; then
		mkdir -p "${REPORTS_DIR}/site"
		cp target/site/surefire-report.html "${REPORTS_DIR}/site/" 2>/dev/null || true
		cp -r target/site/css "${REPORTS_DIR}/site/" 2>/dev/null || true
		cp -r target/site/images "${REPORTS_DIR}/site/" 2>/dev/null || true
		find target/site -maxdepth 1 -name "*.html" ! -name "*jacoco*" -exec cp {} "${REPORTS_DIR}/site/" \; 2>/dev/null || true
		print_success "Surefire HTML report copied to reports directory"
	fi

	# Copy coverage report
	if [ -d "target/site/jacoco" ]; then
		cp -r target/site/jacoco "${COVERAGE_DIR}/jacoco-test-module"
		print_success "Test module coverage report copied to coverage directory"
	fi

	cd ..

	print_subheader "Generating Aggregate Coverage Report"
	
	if [ -d "jacoco-aggregate-report" ]; then
		print_status "Generating aggregate coverage report (cross-module)..."

		mkdir -p jacoco-aggregate-report/target

		# Collect all jacoco.exec files
		find . -name "jacoco.exec" -type f | while read exec_file; do
			print_status "Found execution data: $exec_file"
			cp "$exec_file" "jacoco-aggregate-report/target/jacoco-$(basename $(dirname $(dirname $exec_file))).exec"
		done

		# Generate aggregate report
		mvn verify -pl jacoco-aggregate-report -am -T 12 \
			-Pcoverage \
			-Dmaven.test.failure.ignore=true || true

		# Copy aggregate report
		if [ -d "jacoco-aggregate-report/target/site/jacoco-aggregate" ]; then
			cp -r jacoco-aggregate-report/target/site/jacoco-aggregate "${COVERAGE_DIR}/"
			print_success "Aggregate cross-module coverage report copied to coverage directory"
		fi
	fi
}

# Function to generate Maven site
generate_site() {
	if [ "$GENERATE_SITE" = true ]; then
		print_step "5" "Site Generation Phase"
		
		print_status "Generating Maven site with reports..."
		mvn site -T 12 -Dmaven.test.failure.ignore=true || true
		print_success "Site generated at: ${PROJECT_DIR}/target/site/index.html"
	fi
}

# Function to generate summary report
generate_summary() {
	print_step "6" "Summary Report Generation"
	
	local suite_info=""
	if [ -n "$TEST_SUITE" ]; then
		suite_info="Test Suite: ${TEST_SUITE}"
	else
		suite_info="Test Suite: All Tests (default)"
	fi

	SUMMARY_FILE="${REPORTS_DIR}/test-summary-${TIMESTAMP}.txt"

	cat >"${SUMMARY_FILE}" <<EOF
================================================================================
Test Execution Summary
Generated: $(date)
================================================================================

Project: MyDsl Xtext Project
Profile: ${PROFILE}
${suite_info}

Test Results:
EOF

	if [ -f "${REPORTS_DIR}/site/surefire-report.html" ]; then
		echo "- Surefire HTML Report: ${REPORTS_DIR}/site/surefire-report.html" >>"${SUMMARY_FILE}"
	elif [ -f "org.xtext.example.mydsl.tests/target/site/surefire-report.html" ]; then
		echo "- Surefire HTML Report: org.xtext.example.mydsl.tests/target/site/surefire-report.html" >>"${SUMMARY_FILE}"
	fi

	if [ -d "${REPORTS_DIR}/surefire-reports" ]; then
		echo "- Surefire XML Reports: ${REPORTS_DIR}/surefire-reports/" >>"${SUMMARY_FILE}"
	fi

	echo "" >>"${SUMMARY_FILE}"
	echo "Coverage Reports:" >>"${SUMMARY_FILE}"

	if [ -d "${COVERAGE_DIR}/jacoco-test-module" ]; then
		echo "- Test Module Coverage: ${COVERAGE_DIR}/jacoco-test-module/index.html" >>"${SUMMARY_FILE}"
	fi
	if [ -d "${COVERAGE_DIR}/jacoco-aggregate" ]; then
		echo "- Aggregate Cross-Module Coverage: ${COVERAGE_DIR}/jacoco-aggregate/index.html" >>"${SUMMARY_FILE}"
	fi

	echo "" >>"${SUMMARY_FILE}"

	# Add test statistics if available
	if [ -d "${REPORTS_DIR}/surefire-reports" ]; then
		echo "Test Statistics:" >>"${SUMMARY_FILE}"
		echo "---------------" >>"${SUMMARY_FILE}"

		TOTAL_TESTS=$(grep -h "tests=\"[0-9]*\"" ${REPORTS_DIR}/surefire-reports/*.xml 2>/dev/null | sed 's/.*tests=\"\([0-9]*\)\".*/\1/' | awk '{sum += $1} END {print sum}' || echo "0")
		FAILED_TESTS=$(grep -h "failures=\"[0-9]*\"" ${REPORTS_DIR}/surefire-reports/*.xml 2>/dev/null | sed 's/.*failures=\"\([0-9]*\)\".*/\1/' | awk '{sum += $1} END {print sum}' || echo "0")
		ERROR_TESTS=$(grep -h "errors=\"[0-9]*\"" ${REPORTS_DIR}/surefire-reports/*.xml 2>/dev/null | sed 's/.*errors=\"\([0-9]*\)\".*/\1/' | awk '{sum += $1} END {print sum}' || echo "0")
		SKIPPED_TESTS=$(grep -h "skipped=\"[0-9]*\"" ${REPORTS_DIR}/surefire-reports/*.xml 2>/dev/null | sed 's/.*skipped=\"\([0-9]*\)\".*/\1/' | awk '{sum += $1} END {print sum}' || echo "0")

		echo "Total Tests: ${TOTAL_TESTS}" >>"${SUMMARY_FILE}"
		echo "Passed: $((TOTAL_TESTS - FAILED_TESTS - ERROR_TESTS - SKIPPED_TESTS))" >>"${SUMMARY_FILE}"
		echo "Failed: ${FAILED_TESTS}" >>"${SUMMARY_FILE}"
		echo "Errors: ${ERROR_TESTS}" >>"${SUMMARY_FILE}"
		echo "Skipped: ${SKIPPED_TESTS}" >>"${SUMMARY_FILE}"
	fi

	print_success "Summary report generated: ${SUMMARY_FILE}"
	cat "${SUMMARY_FILE}"
}

# Function to archive reports
archive_reports() {
	print_step "7" "Report Archiving"
	
	tar -czf "${REPORT_ARCHIVE}" \
		-C "${PROJECT_DIR}" \
		"test-reports" \
		"coverage-reports" \
		2>/dev/null || print_warning "Could not create full archive"

	if [ -f "${REPORT_ARCHIVE}" ]; then
		print_success "Reports archived to: ${REPORT_ARCHIVE}"
	fi
}

# Function to open reports in browser
open_reports() {
	if [ "$SKIP_TESTS" = false ]; then
		print_header "Test and Coverage Reports Ready"
		
		echo "Available reports:"

		if [ -n "$TEST_SUITE" ]; then
			echo -e "${CYAN}TEST SUITE: ${TEST_SUITE}${NC}"
		fi

		echo ""
		echo "TEST REPORTS:"
		if [ -f "${REPORTS_DIR}/site/surefire-report.html" ]; then
			echo "  • Surefire HTML: ${REPORTS_DIR}/site/surefire-report.html"
		elif [ -f "org.xtext.example.mydsl.tests/target/site/surefire-report.html" ]; then
			echo "  • Surefire HTML: org.xtext.example.mydsl.tests/target/site/surefire-report.html"
		fi

		echo ""
		echo "COVERAGE REPORTS:"
		[ -d "${COVERAGE_DIR}/jacoco-test-module" ] && echo "  • Test Module Coverage: ${COVERAGE_DIR}/jacoco-test-module/index.html"
		[ -d "${COVERAGE_DIR}/jacoco-aggregate" ] && echo "  • Aggregate Cross-Module Coverage: ${COVERAGE_DIR}/jacoco-aggregate/index.html"

		echo ""
		read -p "Would you like to open the coverage reports in your browser? (y/n): " -n 1 -r
		echo ""

		if [[ $REPLY =~ ^[Yy]$ ]]; then
			if [ -d "${COVERAGE_DIR}/jacoco-aggregate" ]; then
				{ xdg-open "${COVERAGE_DIR}/jacoco-aggregate/index.html" 2>/dev/null || print_warning "Could not open browser"; } &
			elif [ -d "jacoco-aggregate-report/target/site/jacoco-aggregate" ]; then
				{ xdg-open "jacoco-aggregate-report/target/site/jacoco-aggregate/index.html" 2>/dev/null || print_warning "Could not open browser"; } &
			elif [ -d "${COVERAGE_DIR}/jacoco-test-module" ]; then
				{ xdg-open "${COVERAGE_DIR}/jacoco-test-module/index.html" 2>/dev/null || print_warning "Could not open browser"; } &
			else
				print_warning "No coverage reports found to open"
			fi

			# Ask about test report
			if [ -f "${REPORTS_DIR}/site/surefire-report.html" ] || [ -f "org.xtext.example.mydsl.tests/target/site/surefire-report.html" ]; then
				echo ""
				read -p "Would you also like to open the test report? (y/n): " -n 1 -r
				echo ""
				if [[ $REPLY =~ ^[Yy]$ ]]; then
					if [ -f "${REPORTS_DIR}/site/surefire-report.html" ]; then
						{ xdg-open "${REPORTS_DIR}/site/surefire-report.html" 2>/dev/null || print_warning "Could not open browser"; } &
					else
						{ xdg-open "org.xtext.example.mydsl.tests/target/site/surefire-report.html" 2>/dev/null || print_warning "Could not open browser"; } &
					fi
				fi
			fi
		else
			print_status "You can manually open the reports using the paths shown above."
		fi
	fi
}

# Main execution
main() {
	# Handle special commands first
	if [ "$LIST_SUITES" = true ]; then
		check_maven
		list_test_suites
		exit 0
	fi
	
	if [ -n "$DESCRIBE_SUITE" ]; then
		check_maven
		describe_test_suite "$DESCRIBE_SUITE"
		exit 0
	fi
	
	# Normal build and test flow
	print_header "Build and Test Process Starting"
	
	if [ -n "$TEST_SUITE" ]; then
		print_suite "Selected test suite: $TEST_SUITE"
	fi
	
	echo "Configuration:"
	echo "  Clean: $DO_CLEAN"
	echo "  Skip Build: $SKIP_BUILD"
	echo "  Skip Tests: $SKIP_TESTS"
	echo "  Generate Site: $GENERATE_SITE"
	echo "  Profile: $PROFILE"
	[ -n "$TEST_SUITE" ] && echo "  Test Suite: $TEST_SUITE"
	echo ""

	check_maven
	clean_project
	build_project
	
	if [ "$SKIP_TESTS" = false ]; then
		if [ -n "$TEST_SUITE" ]; then
			run_tests_with_suite "$TEST_SUITE"
		else
			run_tests
		fi
	fi
	
	generate_site
	generate_summary
	archive_reports
	open_reports

	print_header "Build and Test Process Completed"
	
	if [ -n "$TEST_SUITE" ]; then
		print_success "Completed for suite: $TEST_SUITE"
	else
		print_success "All processes completed successfully!"
	fi
}

# Run main function
main
