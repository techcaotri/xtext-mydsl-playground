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
DO_CLEAN=false
SKIP_BUILD=false
SKIP_TESTS=false
GENERATE_SITE=false
PROFILE="test"

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
	--help)
		echo "Usage: $0 [options]"
		echo "Options:"
		echo "  --clean           Do the clean phase"
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

# Function to clean the project
clean_project() {
	if [ "$DO_CLEAN" = true ]; then
		print_status "Cleaning project (--clean specified)..."
		mvn clean -T 12

		# Clean and recreate report directories
		print_status "Cleaning report directories..."
		rm -rf "${REPORTS_DIR}" "${COVERAGE_DIR}"
		mkdir -p "${REPORTS_DIR}"
		mkdir -p "${COVERAGE_DIR}"
	else
		print_status "Skipping clean phase (use --clean to force cleaning)"
		# Still ensure directories exist
		mkdir -p "${REPORTS_DIR}"
		mkdir -p "${COVERAGE_DIR}"
	fi
}

# Function to build the project
build_project() {
	if [ "$SKIP_BUILD" = false ]; then
		print_status "Building project with coverage profile..."
		echo "Building target platform..."
		cd org.xtext.example.mydsl.target
		mvn clean install -DskipTests
		cd ..

		# CRITICAL: Build main module sequentially to avoid race conditions
		print_status "Building main module with proper compilation order..."
		cd org.xtext.example.mydsl

    # Step 1: Clean if requested
		if [ "$DO_CLEAN" = true ]; then
			mvn clean
		fi
		
		# Build with single thread to ensure proper ordering
		# Use install directly - it will run all phases in correct order
		print_status "Running full build lifecycle (this may take a moment)..."
		mvn clean install -DskipTests -Pcoverage
		
		cd ..

		# Now build remaining modules (these can be parallel)
		print_status "Building other modules..."
		mvn install -DskipTests -T 12 -Pcoverage -pl !org.xtext.example.mydsl

		print_status "Build completed successfully!"
	else
		print_warning "Skipping build phase"
	fi
}

# Function to run tests with cross-module coverage
run_tests() {
	if [ "$SKIP_TESTS" = false ]; then
		print_status "Running tests with cross-module coverage..."

		TEST_FAILED=false

		# Run tests with JaCoCo coverage
		print_status "Executing tests with JaCoCo coverage..."
		mvn verify -T 12 \
			-Pcoverage \
			-Dmaven.test.failure.ignore=true \
			-DfailIfNoTests=false || TEST_FAILED=true

		# Generate coverage reports
		print_status "Generating JaCoCo coverage reports..."

		# Generate individual module reports
		cd org.xtext.example.mydsl
		mvn jacoco:report -Pcoverage -Dmaven.test.failure.ignore=true || true
		cd ..

		cd org.xtext.example.mydsl.tests
		mvn jacoco:report -Pcoverage -Dmaven.test.failure.ignore=true || true

		# Generate surefire HTML report
		print_status "Generating Surefire HTML report..."
		mvn surefire-report:report -T 12 -Dmaven.test.failure.ignore=true || true

		# Copy test reports
		if [ -d "target/surefire-reports" ]; then
			cp -r target/surefire-reports "${REPORTS_DIR}/"
			print_status "Surefire test reports copied to reports directory"
		fi

		# Copy surefire HTML report to reports directory (but exclude jacoco directories)
		if [ -f "target/site/surefire-report.html" ]; then
			# Only copy surefire-related files, not coverage reports
			mkdir -p "${REPORTS_DIR}/site"
			cp target/site/surefire-report.html "${REPORTS_DIR}/site/" 2>/dev/null || true
			cp -r target/site/css "${REPORTS_DIR}/site/" 2>/dev/null || true
			cp -r target/site/images "${REPORTS_DIR}/site/" 2>/dev/null || true
			# Explicitly exclude jacoco directories
			find target/site -maxdepth 1 -name "*.html" ! -name "*jacoco*" -exec cp {} "${REPORTS_DIR}/site/" \; 2>/dev/null || true
			print_status "Surefire HTML report copied to reports directory"
		fi

		# Copy coverage report
		if [ -d "target/site/jacoco" ]; then
			cp -r target/site/jacoco "${COVERAGE_DIR}/jacoco-test-module"
			print_status "Test module coverage report copied to coverage directory"
		fi

		cd ..

		# Generate aggregate coverage report
		if [ -d "jacoco-aggregate-report" ]; then
			print_status "Generating aggregate coverage report (cross-module)..."

			# First ensure execution data is collected
			mkdir -p jacoco-aggregate-report/target

			# Collect all jacoco.exec files
			find . -name "jacoco.exec" -type f | while read exec_file; do
				print_status "Found execution data: $exec_file"
				cp "$exec_file" "jacoco-aggregate-report/target/jacoco-$(basename $(dirname $(dirname $exec_file))).exec"
			done

			# Merge execution data files
			if [ -f "org.xtext.example.mydsl.tests/target/jacoco.exec" ]; then
				cp org.xtext.example.mydsl.tests/target/jacoco.exec jacoco-aggregate-report/target/jacoco-merged.exec
			fi

			# Generate aggregate report
			mvn verify -pl jacoco-aggregate-report -am -T 12 \
				-Pcoverage \
				-Dmaven.test.failure.ignore=true || true

			# Copy aggregate report
			if [ -d "jacoco-aggregate-report/target/site/jacoco-aggregate" ]; then
				cp -r jacoco-aggregate-report/target/site/jacoco-aggregate "${COVERAGE_DIR}/"
				print_status "Aggregate cross-module coverage report copied to coverage directory"
			fi
		fi

		if [ "$TEST_FAILED" = true ]; then
			print_error "Some tests failed. Check reports for details."
			print_warning "Reports have been generated despite test failures."
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
		mvn site -T 12 -Dmaven.test.failure.ignore=true || true

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

	if [ -d "jacoco-aggregate-report/target/site/jacoco-aggregate" ]; then
		echo "- Aggregate (Original Location): jacoco-aggregate-report/target/site/jacoco-aggregate/index.html" >>"${SUMMARY_FILE}"
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

	cat "${SUMMARY_FILE}"
}

# Function to archive reports
archive_reports() {
	print_status "Archiving test reports..."

	tar -czf "${REPORT_ARCHIVE}" \
		-C "${PROJECT_DIR}" \
		"test-reports" \
		"coverage-reports" \
		2>/dev/null || print_warning "Could not create full archive"

	if [ -f "${REPORT_ARCHIVE}" ]; then
		print_status "Reports archived to: ${REPORT_ARCHIVE}"
	fi
}

# Function to open reports in browser
open_reports() {
	if [ "$SKIP_TESTS" = false ]; then
		echo ""
		print_status "Test and coverage reports are ready!"
		echo ""
		echo "Available reports:"

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

		if [ ! -d "${COVERAGE_DIR}/jacoco-aggregate" ] && [ -d "jacoco-aggregate-report/target/site/jacoco-aggregate" ]; then
			echo "  • Aggregate (Original location): jacoco-aggregate-report/target/site/jacoco-aggregate/index.html"
		fi

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
	print_status "Starting build and test process..."
	echo ""

	check_maven
	clean_project
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
}

# Run main function
main
