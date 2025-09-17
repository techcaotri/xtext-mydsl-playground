#!/bin/bash

# Build and Test Script for MyDsl Project
# Generates test reports and code coverage with cross-module support
# Linux OS Support Only

set -e # Exit on error

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
	if ! command -v mvn &>/dev/null; then
		print_error "Maven is not installed or not in PATH"
		exit 1
	fi
	print_status "Maven version: $(mvn --version | head -n 1)"
}

# Function to build the project
build_project() {
	if [ "$SKIP_BUILD" = false ]; then
		print_status "Building main project..."

		# Step 1: Build main module first to ensure classes exist
		print_status "Building main module with Xtext/Xtend compilation..."
		cd org.xtext.example.mydsl
		mvn clean compile xtend:compile xtend:xtend-install-debug-info -T 12
		cd ..
		
		print_status "Main module build completed"
	else
		print_warning "Skipping build phase"
	fi
}

# Function to run tests with cross-module coverage
run_tests() {
	if [ "$SKIP_TESTS" = false ]; then
		print_status "Running tests with cross-module coverage..."
		
		TEST_FAILED=false

		cd org.xtext.example.mydsl.tests

		# Run tests with JaCoCo agent configured for cross-module coverage
		print_status "Executing tests with enhanced JaCoCo configuration..."
		mvn clean verify -T 12 \
			-Djacoco.includes="org.xtext.example.mydsl.*" \
			-Djacoco.append=true \
			-Djacoco.destFile="${PWD}/target/jacoco-combined.exec" \
			-Dmaven.test.failure.ignore=false \
			-Dsurefire.reportsDirectory="${REPORTS_DIR}/surefire" \
			-P${PROFILE} || TEST_FAILED=true

		# Copy execution data to necessary locations
		print_status "Copying execution data for coverage analysis..."
		cp target/jacoco*.exec ../jacoco-aggregate-report/ 2>/dev/null || true
		cp target/jacoco*.exec ../org.xtext.example.mydsl/target/ 2>/dev/null || true
		cp target/jacoco*.exec "${COVERAGE_DIR}/" 2>/dev/null || true

		# Generate standard JaCoCo report
		print_status "Generating standard coverage report..."
		mvn jacoco:report -T 12 \
			-Djacoco.dataFile="target/jacoco-combined.exec" \
			-Djacoco.outputDirectory="${COVERAGE_DIR}/jacoco-html"

		# Generate combined coverage report with all source directories
		print_status "Generating combined coverage report with all source directories..."
		mvn jacoco:report -T 12 \
			-Djacoco.dataFile="target/jacoco-combined.exec" \
			-Djacoco.sourceDirectories="../org.xtext.example.mydsl/src,../org.xtext.example.mydsl/xtend-gen,src,xtend-gen" \
			-Djacoco.classDirectories="../org.xtext.example.mydsl/target/classes,target/classes" \
			-Djacoco.outputDirectory="${COVERAGE_DIR}/jacoco-combined"

		# Generate fixed report using existing jacoco-report-pom.xml
		if [ -f "jacoco-report-pom.xml" ]; then
			print_status "Generating fixed coverage report..."
			mvn jacoco:report -f jacoco-report-pom.xml -T 12 \
				-Djacoco.outputDirectory="${COVERAGE_DIR}/jacoco-fixed"
		fi

		cd ..

		# Generate aggregate report if module exists
		if [ -d "jacoco-aggregate-report" ]; then
			print_status "Generating aggregate coverage report..."
			mvn clean verify -pl jacoco-aggregate-report -am -T 12
			
			# Copy aggregate report to coverage directory
			if [ -d "jacoco-aggregate-report/target/site/jacoco-aggregate" ]; then
				cp -r jacoco-aggregate-report/target/site/jacoco-aggregate "${COVERAGE_DIR}/"
				print_status "Aggregate report copied to coverage directory"
			fi
		fi

		if [ "$TEST_FAILED" = true ]; then
			print_error "Some tests failed. Check reports for details."
		else
			print_status "All tests passed!"
		fi
	else
		print_warning "Skipping test execution"
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

	cat >"${SUMMARY_FILE}" <<EOF
================================================================================
Test Execution Summary
Generated: $(date)
================================================================================

Project: MyDsl Xtext Project
Profile: ${PROFILE}

Test Results Location:
- Surefire Reports: ${REPORTS_DIR}/surefire/
- Coverage Reports: ${COVERAGE_DIR}/
  * Standard JaCoCo: ${COVERAGE_DIR}/jacoco-html/index.html
  * Combined Coverage: ${COVERAGE_DIR}/jacoco-combined/index.html
  * Fixed Coverage: ${COVERAGE_DIR}/jacoco-fixed/index.html
  * Aggregate Coverage: ${COVERAGE_DIR}/jacoco-aggregate/index.html

EOF

	# Add test statistics if available
	if [ -d "${REPORTS_DIR}/surefire" ]; then
		echo "Test Statistics:" >>"${SUMMARY_FILE}"
		echo "---------------" >>"${SUMMARY_FILE}"

		# Count test results from XML files
		TOTAL_TESTS=$(grep -h "tests=\"[0-9]*\"" ${REPORTS_DIR}/surefire/*.xml 2>/dev/null | sed 's/.*tests=\"\([0-9]*\)\".*/\1/' | awk '{sum += $1} END {print sum}' || echo "0")
		FAILED_TESTS=$(grep -h "failures=\"[0-9]*\"" ${REPORTS_DIR}/surefire/*.xml 2>/dev/null | sed 's/.*failures=\"\([0-9]*\)\".*/\1/' | awk '{sum += $1} END {print sum}' || echo "0")
		ERROR_TESTS=$(grep -h "errors=\"[0-9]*\"" ${REPORTS_DIR}/surefire/*.xml 2>/dev/null | sed 's/.*errors=\"\([0-9]*\)\".*/\1/' | awk '{sum += $1} END {print sum}' || echo "0")
		SKIPPED_TESTS=$(grep -h "skipped=\"[0-9]*\"" ${REPORTS_DIR}/surefire/*.xml 2>/dev/null | sed 's/.*skipped=\"\([0-9]*\)\".*/\1/' | awk '{sum += $1} END {print sum}' || echo "0")

		echo "Total Tests: ${TOTAL_TESTS}" >>"${SUMMARY_FILE}"
		echo "Passed: $((TOTAL_TESTS - FAILED_TESTS - ERROR_TESTS - SKIPPED_TESTS))" >>"${SUMMARY_FILE}"
		echo "Failed: ${FAILED_TESTS}" >>"${SUMMARY_FILE}"
		echo "Errors: ${ERROR_TESTS}" >>"${SUMMARY_FILE}"
		echo "Skipped: ${SKIPPED_TESTS}" >>"${SUMMARY_FILE}"
	fi

	# Add coverage statistics if available
	if ls ${COVERAGE_DIR}/jacoco*.exec 1>/dev/null 2>&1; then
		echo "" >>"${SUMMARY_FILE}"
		echo "Code Coverage Reports Generated:" >>"${SUMMARY_FILE}"
		echo "-------------------------------" >>"${SUMMARY_FILE}"
		echo "✓ Standard JaCoCo Report" >>"${SUMMARY_FILE}"
		echo "✓ Combined Cross-Module Report" >>"${SUMMARY_FILE}"
		[ -d "${COVERAGE_DIR}/jacoco-fixed" ] && echo "✓ Fixed Source References Report" >>"${SUMMARY_FILE}"
		[ -d "${COVERAGE_DIR}/jacoco-aggregate" ] && echo "✓ Aggregate Coverage Report" >>"${SUMMARY_FILE}"
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

# Function to open reports in browser (Linux only with user confirmation)
open_reports() {
	if [ "$SKIP_TESTS" = false ]; then
		echo ""
		print_status "Test and coverage reports are ready!"
		echo ""
		echo "Available reports:"
		echo "1. Standard JaCoCo: ${COVERAGE_DIR}/jacoco-html/index.html"
		echo "2. Combined Coverage: ${COVERAGE_DIR}/jacoco-combined/index.html"
		[ -d "${COVERAGE_DIR}/jacoco-fixed" ] && echo "3. Fixed Coverage: ${COVERAGE_DIR}/jacoco-fixed/index.html"
		[ -d "${COVERAGE_DIR}/jacoco-aggregate" ] && echo "4. Aggregate Coverage: ${COVERAGE_DIR}/jacoco-aggregate/index.html"
		echo ""
		
		read -p "Would you like to open the coverage reports in your browser? (y/n): " -n 1 -r
		echo ""
		
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			print_status "Opening reports in browser..."
			
			# Open the aggregate report if available, otherwise open combined report
			if [ -d "${COVERAGE_DIR}/jacoco-aggregate" ]; then
				xdg-open "${COVERAGE_DIR}/jacoco-aggregate/index.html" 2>/dev/null || print_warning "Could not open browser"
			elif [ -d "${COVERAGE_DIR}/jacoco-combined" ]; then
				xdg-open "${COVERAGE_DIR}/jacoco-combined/index.html" 2>/dev/null || print_warning "Could not open browser"
			else
				xdg-open "${COVERAGE_DIR}/jacoco-html/index.html" 2>/dev/null || print_warning "Could not open browser"
			fi
		else
			print_status "You can manually open the reports using the paths shown above."
		fi
	fi
}

# Main execution
main() {
	print_status "Starting build and test process..."
	echo ""

	check_maven
	build_project
	run_tests
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
	echo "  - Coverage Reports: ${COVERAGE_DIR}/"
	echo "    • Standard: ${COVERAGE_DIR}/jacoco-html/index.html"
	echo "    • Combined: ${COVERAGE_DIR}/jacoco-combined/index.html"
	[ -d "${COVERAGE_DIR}/jacoco-fixed" ] && echo "    • Fixed: ${COVERAGE_DIR}/jacoco-fixed/index.html"
	[ -d "${COVERAGE_DIR}/jacoco-aggregate" ] && echo "    • Aggregate: ${COVERAGE_DIR}/jacoco-aggregate/index.html"
	if [ -f "${REPORT_ARCHIVE}" ]; then
		echo "  - Archive: ${REPORT_ARCHIVE}"
	fi
	if [ "$GENERATE_SITE" = true ]; then
		echo "  - Maven Site: ${PROJECT_DIR}/target/site/index.html"
	fi
}

# Run main function
main
