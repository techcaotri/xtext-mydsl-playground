package org.xtext.example.mydsl.tests.suites

import org.junit.platform.suite.api.SelectClasses
import org.junit.platform.suite.api.Suite
import org.junit.platform.suite.api.SuiteDisplayName
import org.junit.platform.suite.api.IncludeTags
import java.util.Map
import java.util.HashMap
import java.util.List
import java.util.ArrayList

// Import test classes
import org.xtext.example.mydsl.tests.GeneratorTest
import org.xtext.example.mydsl.tests.TemplateLoaderTest

/**
 * Central Test Suite Manager - Simplified Version
 * Removed problematic TestExecutionSummary imports
 */
class TestSuiteManager {
    
    // Suite definitions
    static val Map<String, TestSuiteDefinition> SUITES = new HashMap() => [
        put("unit", new TestSuiteDefinition(
            "Unit Tests",
            "Fast, isolated unit tests for individual components",
            #[
                TemplateLoaderTest
            ],
            #["unit"]
        ))
        
        put("integration", new TestSuiteDefinition(
            "Integration Tests", 
            "Tests that verify component interactions and code generation",
            #[
                GeneratorTest
            ],
            #["integration"]
        ))
        
        put("all", new TestSuiteDefinition(
            "All Tests",
            "Complete test suite including all test categories",
            #[
                GeneratorTest,
                TemplateLoaderTest
            ],
            #[]
        ))
    ]
    
    /**
     * Main entry point for listing suites (command line usage)
     */
    def static void main(String[] args) {
        if (args.length == 0) {
            printUsage()
            return
        }
        
        val command = args.get(0)
        
        switch (command) {
            case "list": listSuites()
            case "describe": {
                if (args.length < 2) {
                    println("Error: Suite name required")
                } else {
                    describeSuite(args.get(1))
                }
            }
            default: {
                println("Unknown command: " + command)
                printUsage()
            }
        }
    }
    
    def static void printUsage() {
        println('''
            Test Suite Manager Usage:
            
            Commands:
              list              - List all available test suites
              describe <suite>  - Show detailed information about a suite
              
            Available Suites:
              «FOR suite : SUITES.keySet»
                - «suite»
              «ENDFOR»
        ''')
    }
    
    def static void listSuites() {
        println("Available Test Suites")
        println("====================")
        
        for (entry : SUITES.entrySet) {
            val name = entry.key
            val suite = entry.value
            
            println()
            println(name + ": " + suite.displayName)
            println("  " + suite.description)
            println("  Tests: " + suite.testClasses.size)
        }
    }
    
    def static void describeSuite(String suiteName) {
        val suite = SUITES.get(suiteName)
        
        if (suite === null) {
            println("Unknown suite: " + suiteName)
            return
        }
        
        println("Suite: " + suite.displayName)
        println("Description: " + suite.description)
        println("Test Classes:")
        
        for (testClass : suite.testClasses) {
            println("  - " + testClass.simpleName)
        }
    }
}

/**
 * Test Suite Definition
 */
class TestSuiteDefinition {
    public val String displayName
    public val String description
    public val List<Class<?>> testClasses
    public val List<String> tags
    
    new(String displayName, String description, List<Class<?>> testClasses, List<String> tags) {
        this.displayName = displayName
        this.description = description
        this.testClasses = new ArrayList(testClasses)
        this.tags = new ArrayList(tags)
    }
}

// Concrete suite classes for Tycho/Surefire execution
@Suite
@SuiteDisplayName("Unit Test Suite")
@SelectClasses(#[
    TemplateLoaderTest
])
@IncludeTags("unit")
class UnitTestSuite {
    // Marker class for unit tests
}

@Suite
@SuiteDisplayName("Integration Test Suite")
@SelectClasses(#[
    GeneratorTest
])
@IncludeTags("integration")
class IntegrationTestSuite {
    // Marker class for integration tests
}

@Suite
@SuiteDisplayName("All Tests Suite")
@SelectClasses(#[
    GeneratorTest,
    TemplateLoaderTest
])
class AllTestsSuite {
    // Marker class for all tests
}
