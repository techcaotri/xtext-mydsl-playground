# Testing Guide for MyDsl Xtext Project

## Table of Contents
- [Overview](#overview)
- [Quick Start](#quick-start)
- [Build and Test Script](#build-and-test-script)
- [Test Suites](#test-suites)
- [Common Use Cases](#common-use-cases)
- [Customizing Test Suites](#customizing-test-suites)
- [Test Reports](#test-reports)
- [Troubleshooting](#troubleshooting)

## Overview

The MyDsl project uses a comprehensive testing framework built on JUnit 5, Maven, and Tycho. All test configurations are centralized in `TestConfiguration.xtend` for consistency across build scripts, test runners, and coverage reports.

### Key Components
- **build-and-test.sh**: Main build and test orchestration script
- **TestConfiguration.xtend**: Central test suite definitions
- **TestSuiteManager.xtend**: Test suite query and management
- **JaCoCo**: Code coverage analysis with cross-module support

## Quick Start

```bash
# Run all tests with coverage
./build-and-test.sh

# Run specific test suite
./build-and-test.sh --suite unit

# Clean build and run integration tests
./build-and-test.sh --clean --suite integration

# List available test suites
./build-and-test.sh --list-suites
```

## Build and Test Script

### Script Options

| Option | Description | Example |
|--------|-------------|---------|
| `--clean` | Perform clean build | `./build-and-test.sh --clean` |
| `--skip-build` | Skip build phase, only run tests | `./build-and-test.sh --skip-build --suite smoke` |
| `--skip-tests` | Build only, skip test execution | `./build-and-test.sh --skip-tests` |
| `--suite <name>` | Run specific test suite | `./build-and-test.sh --suite unit` |
| `--list-suites` | List all available test suites | `./build-and-test.sh --list-suites` |
| `--describe-suite <name>` | Show details about a test suite | `./build-and-test.sh --describe-suite integration` |
| `--generate-site` | Generate Maven site with reports | `./build-and-test.sh --generate-site` |
| `--export-config` | Export test configuration as properties | `./build-and-test.sh --export-config` |
| `--help` | Show help documentation | `./build-and-test.sh --help` |

### Build Phases

The script executes the following phases in order:

1. **Prerequisites Check**: Verifies Maven and Java installation
2. **Clean Phase** (optional): Removes build artifacts and old reports
3. **Build Phase**: Compiles all modules with proper ordering
4. **Test Execution**: Runs selected test suite with coverage
5. **Report Generation**: Creates Surefire and JaCoCo reports
6. **Site Generation** (optional): Generates Maven site
7. **Summary**: Displays test results and report locations

## Test Suites

All test suites are defined in `org.xtext.example.mydsl.tests/src/org/xtext/example/mydsl/tests/TestConfiguration.xtend`.

### Available Test Suites

| Suite | Description | Test Classes | Tags |
|-------|-------------|--------------|------|
| **unit** | Fast, isolated unit tests | TemplateLoaderTest | unit, fast |
| **integration** | Component interaction tests | GeneratorTest | integration, generator |
| **parsing** | DSL parsing tests | MyDslParsingTest | parsing, unit, fast |
| **smoke** | Quick functionality checks | MyDslParsingTest | smoke, fast |
| **fast** | All quick-running tests | TemplateLoaderTest, MyDslParsingTest | fast |
| **all** | Complete test suite | All test classes | - |

## Common Use Cases

### 1. Daily Development Testing

```bash
# Quick smoke test during development
./build-and-test.sh --skip-build --suite smoke

# Full unit test run
./build-and-test.sh --suite unit
```

### 2. Pre-Commit Testing

```bash
# Clean build with all fast tests
./build-and-test.sh --clean --suite fast
```

### 3. CI/CD Pipeline

```bash
# Full clean build with all tests and site generation
./build-and-test.sh --clean --suite all --generate-site

# Integration tests only
./build-and-test.sh --suite integration
```

### 4. Coverage Analysis

```bash
# Generate comprehensive coverage report
./build-and-test.sh --suite all

# Open coverage report (when prompted)
# Or manually: xdg-open coverage-reports/jacoco-aggregate/index.html
```

### 5. Test Suite Investigation

```bash
# See what test suites are available
./build-and-test.sh --list-suites

# Get details about a specific suite
./build-and-test.sh --describe-suite integration

# Export configuration for external tools
./build-and-test.sh --export-config > test-config.properties
```

## Customizing Test Suites

### Adding a New Test Suite

1. **Edit TestConfiguration.xtend**:

```xtend
// In TestConfiguration.xtend
put("performance", new TestSuite(
    "performance",
    "Performance Tests",
    "Tests focusing on performance and scalability",
    #[
        PerformanceTest,  // Your test class
        LoadTest          // Another test class
    ],
    "**/Performance*Test,**/Load*Test",  // Maven pattern
    #["performance", "slow"]  // Tags
))
```

2. **Update TestSuiteManager.xtend** (optional for JUnit Suite):

```xtend
@Suite
@SuiteDisplayName("Performance Test Suite")
@SelectClasses(#[
    PerformanceTest,
    LoadTest
])
@IncludeTags("performance")
class PerformanceTestSuite {
    // Suite marker class
}
```

3. **Use the new suite**:

```bash
./build-and-test.sh --suite performance
```

### Adding Test Classes to Existing Suite

1. **Create your test class** in `org.xtext.example.mydsl.tests/src/`:

```xtend
package org.xtext.example.mydsl.tests

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Tag
import org.junit.jupiter.api.DisplayName
import static org.junit.jupiter.api.Assertions.*

@DisplayName("My New Test")
@Tag("unit")
class MyNewTest {
    
    @Test
    @DisplayName("Should do something")
    def void testSomething() {
        // Your test implementation
        assertTrue(true)
    }
}
```

2. **Add to TestConfiguration.xtend**:

```xtend
put("unit", new TestSuite(
    "unit",
    "Unit Tests",
    "Fast, isolated unit tests for individual components",
    #[
        TemplateLoaderTest,
        MyNewTest  // Add your test here
    ],
    "**/TemplateLoader*Test,**/MyNew*Test",  // Update pattern
    #["unit", "fast"]
))
```

### Creating Custom Test Patterns

Test patterns use Maven Surefire syntax:

- `**/*Test` - Matches all classes ending with "Test"
- `**/Generator*Test` - Matches classes containing "Generator" and ending with "Test"
- `com/example/**/*Test` - Matches tests in specific package
- Multiple patterns: `**/*Test,**/*Tests,**/Test*`

## Test Reports

### Report Locations

After test execution, reports are available at:

| Report Type | Location | Description |
|-------------|----------|-------------|
| **Surefire HTML** | `test-reports/site/surefire-report.html` | Test execution summary |
| **Surefire XML** | `test-reports/surefire-reports/*.xml` | Detailed test results |
| **JaCoCo Coverage** | `coverage-reports/jacoco-aggregate/index.html` | Cross-module coverage |
| **Test Summary** | `test-reports/test-summary-{timestamp}.txt` | Text summary |
| **Maven Site** | `target/site/index.html` | Complete project documentation |

### Understanding Coverage Reports

The JaCoCo aggregate report shows:
- **Line Coverage**: Percentage of code lines executed
- **Branch Coverage**: Percentage of decision branches tested
- **Complexity**: Cyclomatic complexity coverage
- **Cross-Module Analysis**: Coverage across main and test modules

### Report Archive

Test results are automatically archived:
```bash
# Archive location
test-results-{timestamp}.tar.gz

# Extract archive
tar -xzf test-results-*.tar.gz
```

## Troubleshooting

### Common Issues

#### 1. Tests Not Found
```bash
# Verify test configuration
./verify-test-config.sh

# Check if test classes are compiled
cd org.xtext.example.mydsl.tests
mvn compile
```

#### 2. Coverage Not Generated
```bash
# Ensure coverage profile is active
./build-and-test.sh --suite all

# Check JaCoCo execution data exists
find . -name "jacoco.exec"
```

#### 3. Build Failures
```bash
# Clean everything and rebuild
./build-and-test.sh --clean

# Check Maven dependencies
mvn dependency:tree
```

#### 4. Out of Memory
```bash
# Increase Maven memory
export MAVEN_OPTS="-Xmx2048m -XX:MaxPermSize=512m"
./build-and-test.sh
```

### Debug Mode

Enable detailed output:
```bash
# Verbose Maven output
mvn -X verify

# Debug test execution
mvn verify -Dtest=MyTest -Dmaven.surefire.debug
```

### Verification Scripts

```bash
# Verify test configuration consistency
./verify-test-config.sh

# Check which tests will run for a suite
./build-and-test.sh --describe-suite unit
```

## Best Practices

1. **Keep Tests Fast**: Add slow tests to separate suites
2. **Use Appropriate Tags**: Tag tests for easy filtering
3. **Maintain Central Config**: Always update TestConfiguration.xtend
4. **Regular Clean Builds**: Use `--clean` periodically
5. **Review Coverage**: Aim for >80% coverage on critical code
6. **Document Test Purpose**: Use @DisplayName annotations
7. **Isolate Test Data**: Don't share state between tests
8. **CI Integration**: Run different suites for different pipeline stages

## Integration with IDEs

### Eclipse
1. Import as existing Maven project
2. Right-click test class → Run As → JUnit Test
3. Coverage: Use EclEmma plugin

### IntelliJ IDEA
1. Import Maven project
2. Right-click test → Run with Coverage
3. View coverage in editor margins

### VS Code
1. Install Java Test Runner extension
2. Use Testing sidebar for test execution
3. Install Coverage Gutters for inline coverage

## Support

For issues or questions:
1. Check test configuration: `./build-and-test.sh --list-suites`
2. Verify setup: `./verify-test-config.sh`
3. Review logs in `test-reports/` directory
4. Check Maven output with `-X` flag for debugging