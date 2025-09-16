#!/bin/bash

echo "================================"
echo "Running Tests with Tycho"
echo "================================"
echo ""

# IMPORTANT: For Eclipse plugin tests, we need to use 'verify' or 'integration-test' goal
# NOT just 'test' goal

cd org.xtext.example.mydsl.tests

echo "Step 1: Clean and compile"
mvn clean compile xtend:compile xtend:xtend-install-debug-info -T 12

echo ""
echo "Step 2: Run tests with integration-test phase (THIS IS KEY!)"
# Use 'verify' to run integration tests and generate reports
mvn verify -T 12

echo ""
echo "Step 3: Check for test results"
if [ -d "target/surefire-reports" ]; then
    echo "Test reports found in: target/surefire-reports/"
    ls -la target/surefire-reports/
else
    echo "WARNING: No test reports found!"
fi

echo ""
echo "Step 4: Check for coverage data"
if [ -f "target/jacoco.exec" ]; then
    echo "Coverage data found: target/jacoco.exec"
    echo "Generating HTML report..."
    mvn jacoco:report -T 12 -X
    echo "Coverage report: target/site/jacoco/index.html"
else
    echo "WARNING: No coverage data found!"
fi

echo ""
echo "================================"
echo "Test execution complete"
echo "================================"
