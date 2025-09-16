package org.xtext.example.mydsl.tests

import org.junit.platform.launcher.core.LauncherDiscoveryRequestBuilder
import org.junit.platform.launcher.core.LauncherFactory
import org.junit.platform.launcher.listeners.SummaryGeneratingListener
import org.junit.platform.launcher.listeners.TestExecutionSummary
import org.junit.platform.engine.discovery.DiscoverySelectors
import java.io.PrintWriter
import java.nio.file.Files
import java.nio.file.Paths
import org.xtext.example.mydsl.MyDslStandaloneSetup
import org.junit.platform.launcher.listeners.LoggingListener
import java.util.logging.Level
import java.util.logging.Logger
import org.junit.platform.engine.discovery.ClassNameFilter
import org.junit.platform.launcher.LauncherDiscoveryRequest

/**
 * Standalone test runner for executing tests without Maven/Tycho
 */
class StandaloneTestRunner {
    
    def static void main(String[] args) {
        println("=== MyDsl Test Runner ===")
        println("")
        
        // Initialize Xtext
        new MyDslStandaloneSetup().createInjectorAndDoEMFRegistration()
        
        val runner = new StandaloneTestRunner()
        val exitCode = runner.runTests(args)
        
        System.exit(exitCode)
    }
    
    def int runTests(String[] args) {
        val reportDir = if (args.length > 0) args.get(0) else "test-reports"
        
        // Create report directory
        val reportPath = Paths.get(reportDir)
        if (!Files.exists(reportPath)) {
            Files.createDirectories(reportPath)
        }
        
        println("Running tests...")
        println("Report directory: " + reportPath.toAbsolutePath())
        println("")
        
        try {
            // Run tests using the JUnit Platform Launcher
            val result = runWithProgrammaticLauncher()
            
            generateReport(result, reportPath)
            
            if (result.testsFailedCount > 0) {
                println("\n✗ TESTS FAILED")
                return 1
            } else {
                println("\n✓ ALL TESTS PASSED")
                return 0
            }
            
        } catch (Exception e) {
            println("Error running tests: " + e.message)
            e.printStackTrace()
            return 2
        }
    }
    
    def TestExecutionSummary runWithProgrammaticLauncher() {
        // Build the launcher discovery request
        val LauncherDiscoveryRequest request = LauncherDiscoveryRequestBuilder.request()
            .selectors(
                // Add test classes
                DiscoverySelectors.selectClass(GeneratorTest),
                DiscoverySelectors.selectClass(MyDslParsingTest),
                // Alternatively, scan for all test classes
                DiscoverySelectors.selectPackage("org.xtext.example.mydsl.tests")
            )
            .filters(
                // Include only test classes
                ClassNameFilter.includeClassNamePatterns(".*Test", ".*Tests", "Test.*")
            )
            .build()
        
        // Create the launcher
        val launcher = LauncherFactory.create()
        
        // Create listeners
        val summaryListener = new SummaryGeneratingListener()
        
        // Optional: Add logging listener for console output
        val logger = Logger.getLogger("org.junit.platform.launcher")
        val loggingListener = LoggingListener.forJavaUtilLogging(Level.INFO)
        
        // Execute tests
        println("Discovering and running tests...")
        launcher.execute(request, summaryListener, loggingListener)
        
        // Get the summary
        val summary = summaryListener.summary
        
        // Print summary to console
        printSummary(summary)
        
        return summary
    }
    
    def void printSummary(TestExecutionSummary summary) {
        println("")
        println("Test Discovery:")
        println("  Tests found: " + summary.testsFoundCount)
        println("")
        println("Test Execution:")
        println("  Tests started: " + summary.testsStartedCount)
        println("  Tests succeeded: " + summary.testsSucceededCount)
        println("  Tests failed: " + summary.testsFailedCount)
        println("  Tests skipped: " + summary.testsSkippedCount)
        println("  Tests aborted: " + summary.testsAbortedCount)
        
        if (!summary.failures.empty) {
            println("")
            println("Failures:")
            for (failure : summary.failures) {
                println("  - " + failure.testIdentifier.displayName)
                val ex = failure.exception
                if (ex !== null) {
                    println("    " + ex.class.simpleName + ": " + ex.message)
                }
            }
        }
    }
    
    def void generateReport(TestExecutionSummary summary, java.nio.file.Path reportPath) {
        println("\n=== Test Results ===")
        println("Tests run: " + summary.testsStartedCount)
        println("Tests passed: " + summary.testsSucceededCount)
        println("Tests failed: " + summary.testsFailedCount)
        println("Tests skipped: " + summary.testsSkippedCount)
        println("Tests aborted: " + summary.testsAbortedCount)
        
        // Write detailed report
        val reportFile = reportPath.resolve("test-summary.txt")
        val writer = new PrintWriter(Files.newBufferedWriter(reportFile))
        
        try {
            writer.println("Test Execution Summary")
            writer.println("======================")
            writer.println("")
            writer.println("Timestamp: " + java.time.LocalDateTime.now())
            writer.println("")
            writer.println("Statistics:")
            writer.println("  Total tests found: " + summary.testsFoundCount)
            writer.println("  Total tests started: " + summary.testsStartedCount)
            writer.println("  Passed: " + summary.testsSucceededCount)
            writer.println("  Failed: " + summary.testsFailedCount)
            writer.println("  Skipped: " + summary.testsSkippedCount)
            writer.println("  Aborted: " + summary.testsAbortedCount)
            
            val successRate = if (summary.testsStartedCount > 0) {
                ((summary.testsSucceededCount as double / summary.testsStartedCount) * 100).intValue
            } else {
                0
            }
            writer.println("  Success rate: " + successRate + "%")
            writer.println("")
            
            if (!summary.failures.empty) {
                writer.println("Failures:")
                writer.println("---------")
                for (failure : summary.failures) {
                    writer.println("")
                    writer.println("Test: " + failure.testIdentifier.displayName)
                    writer.println("Test ID: " + failure.testIdentifier.uniqueId)
                    
                    val ex = failure.exception
                    if (ex !== null) {
                        writer.println("Exception: " + ex.class.name)
                        writer.println("Message: " + ex.message)
                        writer.println("Stack trace:")
                        ex.printStackTrace(writer)
                    }
                    writer.println("")
                }
            }
            
            writer.flush()
            println("\nDetailed report written to: " + reportFile.toAbsolutePath())
            
        } finally {
            writer.close()
        }
    }
}
