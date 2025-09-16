package org.xtext.example.mydsl.tests

import org.junit.platform.suite.api.SelectClasses
import org.junit.platform.suite.api.Suite
import org.junit.platform.suite.api.SuiteDisplayName

/**
 * Test Suite Runner for MyDsl Generator Tests
 * This suite runs all generator-related tests
 * 
 * Use with JUnit 5 Platform Launcher:
 * - Maven: Will be picked up automatically by Surefire 2.22.0+
 * - IDE: Run as JUnit 5 Suite
 * - Programmatically: Use Launcher API
 */
@Suite
@SuiteDisplayName("MyDsl Generator Test Suite")
@SelectClasses(#[
    GeneratorTest,
    MyDslParsingTest
])
class TestSuiteRunner {
    // Test suite runner - no implementation needed
    // The @Suite annotation is sufficient for JUnit 5
}
