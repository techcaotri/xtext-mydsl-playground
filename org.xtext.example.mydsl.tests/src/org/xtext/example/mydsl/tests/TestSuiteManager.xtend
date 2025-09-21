package org.xtext.example.mydsl.tests.suites

import org.junit.platform.suite.api.SelectClasses
import org.junit.platform.suite.api.Suite
import org.junit.platform.suite.api.SuiteDisplayName
import org.junit.platform.suite.api.IncludeTags
import org.xtext.example.mydsl.tests.TestConfiguration
import org.xtext.example.mydsl.tests.TestConfiguration.TestSuite

// Import test classes
import org.xtext.example.mydsl.tests.GeneratorTest
import org.xtext.example.mydsl.tests.TemplateLoaderTest
import org.xtext.example.mydsl.tests.MyDslParsingTest

/**
 * Test Suite Manager - Uses Central Configuration
 * All test suite definitions come from TestConfiguration class
 */
class TestSuiteManager {
    
    /**
     * Main entry point for command line usage
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
            case "get-pattern": {
                if (args.length < 2) {
                    println("Error: Suite name required")
                } else {
                    getPattern(args.get(1))
                }
            }
            case "export": {
                TestConfiguration.exportAsProperties()
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
              list                 - List all available test suites
              describe <suite>     - Show detailed information about a suite
              get-pattern <suite>  - Get Maven test pattern for a suite
              export              - Export configuration as properties
              
            Available Suites:
              «FOR suite : TestConfiguration.SUITES.keySet»
                - «suite»
              «ENDFOR»
        ''')
    }
    
    def static void listSuites() {
        println("Available Test Suites")
        println("====================")
        
        for (entry : TestConfiguration.SUITES.entrySet) {
            val name = entry.key
            val suite = entry.value
            
            println()
            println(name + ": " + suite.displayName)
            println("  " + suite.description)
            println("  Pattern: " + suite.mavenPattern)
            println("  Tests: " + suite.testClasses.size)
        }
    }
    
    def static void describeSuite(String suiteName) {
        val suite = TestConfiguration.getSuite(suiteName)
        
        if (suite === null) {
            println("Unknown suite: " + suiteName)
            return
        }
        
        println("Suite: " + suite.displayName)
        println("Description: " + suite.description)
        println("Maven Pattern: " + suite.mavenPattern)
        println("Test Classes:")
        
        for (testClass : suite.testClasses) {
            println("  - " + testClass.simpleName)
        }
        
        if (!suite.tags.empty) {
            println("Tags: " + suite.tags.join(", "))
        }
    }
    
    def static void getPattern(String suiteName) {
        val pattern = TestConfiguration.getMavenPattern(suiteName)
        // Output just the pattern for easy scripting
        println(pattern)
    }
}
