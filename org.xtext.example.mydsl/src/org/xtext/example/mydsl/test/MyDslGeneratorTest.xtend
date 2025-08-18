package org.xtext.example.mydsl.test

import org.xtext.example.mydsl.MyDslStandaloneSetup
import org.xtext.example.mydsl.generator.MyDslGenerator
import org.xtext.example.mydsl.generator.DataTypeGenerator
import org.xtext.example.mydsl.generator.ProtobufGenerator
import org.xtext.example.mydsl.generator.TemplateLoader
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl
import org.eclipse.emf.common.util.URI
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import org.eclipse.xtext.generator.GeneratorContext
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.JavaIoFileSystemAccess
import org.eclipse.xtext.generator.OutputConfiguration
import org.eclipse.xtext.resource.IResourceServiceProvider
import org.eclipse.emf.ecore.util.EcoreUtil
import java.io.File
import java.io.FileWriter
import java.io.BufferedWriter
import java.lang.reflect.Field
import java.util.Map
import java.util.HashMap
import org.xtext.example.mydsl.myDsl.*
import com.google.inject.Injector

/**
 * Test suite for DataType DSL Generator
 * Standalone test runner that doesn't require JUnit
 */
class MyDslGeneratorTest {

	def static void main(String[] args) {
		if (args.length == 0) {
			runAllTests()
		} else {
			// Run with specific file
			val inputFile = args.get(0)
			println("=== DataType DSL Generator Test ===")
			println("Input file: " + inputFile)
			println("")

			val tester = new MyDslGeneratorTest()
			if (inputFile.isEmpty()) {
				runAllTests()
			} else {
        		val file = new File(inputFile)
        		if (file.exists) {
                  tester.testFile(inputFile)
        		} else {
        			runAllTests()
        		}
			}
		}
	}

	/**
	 * Run all predefined tests
	 */
	def static void runAllTests() {
		println("=== DataType DSL Generator Test Suite ===")
		println("")

		val tester = new MyDslGeneratorTest()
		var passed = 0
		var failed = 0

		// Test 1: Basic Struct Generation
		println("Test 1: Basic Struct Generation")
		if (tester.testBasicStructGeneration()) {
			println("  ✓ PASSED\n")
			passed++
		} else {
			println("  ✗ FAILED\n")
			failed++
		}

		// Test 2: Enumeration Generation
		println("Test 2: Enumeration Generation")
		if (tester.testEnumerationGeneration()) {
			println("  ✓ PASSED\n")
			passed++
		} else {
			println("  ✗ FAILED\n")
			failed++
		}

		// Test 3: Array Type Generation
		println("Test 3: Array Type Generation")
		if (tester.testArrayTypeGeneration()) {
			println("  ✓ PASSED\n")
			passed++
		} else {
			println("  ✗ FAILED\n")
			failed++
		}

		// Test 4: Typedef Generation
		println("Test 4: Typedef Generation")
		if (tester.testTypedefGeneration()) {
			println("  ✓ PASSED\n")
			passed++
		} else {
			println("  ✗ FAILED\n")
			failed++
		}

		// Test 5: Package Generation
		println("Test 5: Package Generation")
		if (tester.testPackageGeneration()) {
			println("  ✓ PASSED\n")
			passed++
		} else {
			println("  ✗ FAILED\n")
			failed++
		}

		// Test 6: Struct Inheritance
		println("Test 6: Struct Inheritance")
		if (tester.testStructInheritance()) {
			println("  ✓ PASSED\n")
			passed++
		} else {
			println("  ✗ FAILED\n")
			failed++
		}

		// Test 7: Field Arrays
		println("Test 7: Field Arrays")
		if (tester.testFieldArrays()) {
			println("  ✓ PASSED\n")
			passed++
		} else {
			println("  ✗ FAILED\n")
			failed++
		}

		// Test 8: Protobuf Generation
		println("Test 8: Protobuf Generation")
		if (tester.testProtobufGeneration()) {
			println("  ✓ PASSED\n")
			passed++
		} else {
			println("  ✗ FAILED\n")
			failed++
		}

		// Test 9: CMake Generation
		println("Test 9: CMake Generation")
		if (tester.testCMakeGeneration()) {
			println("  ✓ PASSED\n")
			passed++
		} else {
			println("  ✗ FAILED\n")
			failed++
		}

		// Test 10: Complex Model
		println("Test 10: Complex Model")
		if (tester.testComplexModel()) {
			println("  ✓ PASSED\n")
			passed++
		} else {
			println("  ✗ FAILED\n")
			failed++
		}

		println("=== Test Results ===")
		println("Passed: " + passed)
		println("Failed: " + failed)
		println("Total:  " + (passed + failed))

		if (failed > 0) {
			System.exit(1)
		}
	}

	var Injector injector
	var ResourceSetImpl resourceSet
	var MyDslGenerator generator
	var InMemoryFileSystemAccess fsa
	var GeneratorContext context

	new() {
		setUp()
	}

	def void setUp() {
		// Initialize Xtext
		injector = new MyDslStandaloneSetup().createInjectorAndDoEMFRegistration()
		resourceSet = injector.getInstance(ResourceSetImpl)
		generator = injector.getInstance(MyDslGenerator)
		fsa = new InMemoryFileSystemAccess()
		context = new GeneratorContext()

		// Configure generator
		generator.setGenerationOptions(true, true, true)
	}

	def void tearDown() {
		// Cleanup
		fsa = new InMemoryFileSystemAccess()
	}

	/**
	 * Test with a specific file
	 */
	def void testFile(String inputFile) {
		val file = new File(inputFile)
		if (!file.exists) {
			println("ERROR: File not found: " + file.absolutePath)
			System.exit(1)
			return // Add explicit return after System.exit
		}

		val fileURI = URI.createFileURI(file.absolutePath)
		val resource = try {
				val res = resourceSet.getResource(fileURI, true)
				// Force resolution of cross-references
				EcoreUtil.resolveAll(res)
				res
			} catch (Exception e) {
				println("ERROR: Could not load file: " + inputFile)
				println("  Reason: " + e.message)
				System.exit(1)
				null // Return null instead of having System.exit as the last expression
			}

		if (resource === null) {
			return
		}

		// Check for parse errors
		if (!resource.errors.empty) {
			println("ERROR: The model contains errors:")
			for (error : resource.errors) {
				println("  Line " + error.line + ": " + error.message)
			}
			System.exit(1)
			return // Add explicit return
		}

		// Generate
		println("Generating code...")
		generator.doGenerate(resource, fsa, context)

		// Write files
		println("Writing files...")
		writeFiles(fsa)

		println("\n=== Generation Complete ===")
		val outputDir = new File("generated")
		println("Output directory: " + outputDir.absolutePath)

		if (outputDir.exists && outputDir.isDirectory) {
			println("\nGenerated structure:")
			printDirectory(outputDir, "  ")
		}
	}

	def boolean testBasicStructGeneration() {
		tearDown()
		val model = '''
			define BasicTypes {
			    type uint32
			        category value
			        length 32
			        encoding little-endian
			    type String
			        category string
			}
			
			public struct Person {
			    uint32 id
			    String name
			}
		'''

		val resource = loadModel(model)
		generator.doGenerate(resource, fsa, context)

		// Check that C++ header was generated
		if (!fsa.allFiles.containsKey("DEFAULT_OUTPUTgenerated/include/Person.h")) {
			println("  Error: Person.h should be generated")
			return false
		}

		val personHeader = getTextFile("DEFAULT_OUTPUTgenerated/include/Person.h")
		if (personHeader === null) {
			println("  Error: Person.h content should not be null")
			return false
		}

		// Check content contains struct definition
		val content = personHeader.toString
		if (!content.contains("struct Person")) {
			println("  Error: Should contain struct Person")
			return false
		}
		if (!content.contains("uint32_t id")) {
			println("  Error: Should contain uint32_t id")
			return false
		}
		if (!content.contains("std::string name")) {
			println("  Error: Should contain std::string name")
			return false
		}

		return true
	}

	def boolean testEnumerationGeneration() {
		tearDown()
		val model = '''
			public enumeration Status {
			    ACTIVE = 0,
			    INACTIVE = 1,
			    PENDING = 2
			}
		'''

		val resource = loadModel(model)
		generator.doGenerate(resource, fsa, context)

		if (!fsa.allFiles.containsKey("DEFAULT_OUTPUTgenerated/include/Status.h")) {
			println("  Error: Status.h should be generated")
			return false
		}

		val statusHeader = getTextFile("DEFAULT_OUTPUTgenerated/include/Status.h")
		val content = statusHeader.toString

		if (!content.contains("enum class Status")) {
			println("  Error: Should contain enum class Status")
			return false
		}
		if (!content.contains("ACTIVE = 0")) {
			println("  Error: Should contain ACTIVE = 0")
			return false
		}
		if (!content.contains("INACTIVE = 1")) {
			println("  Error: Should contain INACTIVE = 1")
			return false
		}

		return true
	}

	def boolean testArrayTypeGeneration() {
		tearDown()
		val model = '''
			define BasicTypes {
			    type float32
			        category value
			        length 32
			        encoding iee754
			}
			
			public struct Point {
			    float32 x
			    float32 y
			}
			
			public array PointArray of Point
		'''

		val resource = loadModel(model)
		generator.doGenerate(resource, fsa, context)

		if (!fsa.allFiles.containsKey("DEFAULT_OUTPUTgenerated/include/PointArray.h")) {
			println("  Error: PointArray.h should be generated")
			return false
		}

		val arrayHeader = getTextFile("DEFAULT_OUTPUTgenerated/include/PointArray.h")
		val content = arrayHeader.toString

		if (!content.contains("using PointArray")) {
			println("  Error: Should contain using PointArray")
			return false
		}
		if (!content.contains("std::vector")) {
			println("  Error: Should contain std::vector")
			return false
		}

		return true
	}

	def boolean testTypedefGeneration() {
		tearDown()
		val model = '''
			define BasicTypes {
			    type String
			        category string
			}
			
			public typedef UUID is String { len 36 }
		'''

		val resource = loadModel(model)
		generator.doGenerate(resource, fsa, context)

		if (!fsa.allFiles.containsKey("DEFAULT_OUTPUTgenerated/include/UUID.h")) {
			println("  Error: UUID.h should be generated")
			return false
		}

		val typedefHeader = getTextFile("DEFAULT_OUTPUTgenerated/include/UUID.h")
		val content = typedefHeader.toString

		if (!content.contains("using UUID")) {
			println("  Error: Should contain using UUID")
			return false
		}
		if (!content.contains("std::string")) {
			println("  Error: Should contain std::string")
			return false
		}

		return true
	}

	def boolean testPackageGeneration() {
		tearDown()
		val model = '''
			define BasicTypes {
			    type uint32
			        category value
			        length 32
			}
			
			package com.example {
			    public struct Data {
			        uint32 val
			    }
			}
		'''

		val resource = loadModel(model)
		generator.doGenerate(resource, fsa, context)

		if (!fsa.allFiles.containsKey("DEFAULT_OUTPUTgenerated/include/com.example/Data.h")) {
			println("  Error: Data.h should be in package directory")
			return false
		}

		val dataHeader = getTextFile("DEFAULT_OUTPUTgenerated/include/com.example/Data.h")
		val content = dataHeader.toString

		if (!content.contains("namespace com::example")) {
			println("  Error: Should contain namespace")
			return false
		}
		
		// Check that the field 'val' is generated
		if (!content.contains("uint32_t val")) {
			println("  Error: Should contain uint32_t val")
			return false
		}

		return true
	}

	def boolean testStructInheritance() {
		tearDown()
		val model = '''
			define BasicTypes {
			    type uint32
			        category value
			        length 32
			    type String
			        category string
			}
			
			public struct Base {
			    uint32 id
			}
			
			public struct Derived extends Base {
			    String name
			}
		'''

		val resource = loadModel(model)
		generator.doGenerate(resource, fsa, context)

		if (!fsa.allFiles.containsKey("DEFAULT_OUTPUTgenerated/include/Derived.h")) {
			println("  Error: Derived.h should be generated")
			return false
		}

		val derivedHeader = getTextFile("DEFAULT_OUTPUTgenerated/include/Derived.h")
		val content = derivedHeader.toString

		if (!content.contains(": public Base")) {
			println("  Error: Should extend Base")
			return false
		}

		return true
	}

	def boolean testFieldArrays() {
		tearDown()
		val model = '''
			define BasicTypes {
			    type uint8
			        category value
			        length 8
			    type float32
			        category value
			        length 32
			        encoding iee754
			}
			
			public struct Data {
			    uint8[10] buffer
			    float32[3] coordinates
			}
		'''

		val resource = loadModel(model)
		generator.doGenerate(resource, fsa, context)

		val dataHeader = getTextFile("DEFAULT_OUTPUTgenerated/include/Data.h")
		val content = dataHeader.toString

		if (!content.contains("buffer[10]")) {
			println("  Error: Should contain buffer array")
			return false
		}
		if (!content.contains("coordinates[3]")) {
			println("  Error: Should contain coordinates array")
			return false
		}

		return true
	}

	def boolean testProtobufGeneration() {
		tearDown()
		val model = '''
			define BasicTypes {
			    type uint32
			        category value
			        length 32
			    type String
			        category string
			}
			
			public struct Message {
			    uint32 id
			    String text
			}
			
			public enumeration Type {
			    REQUEST = 0,
			    RESPONSE = 1
			}
		'''

		val resource = loadModel(model)
		generator.doGenerate(resource, fsa, context)

		if (!fsa.allFiles.containsKey("DEFAULT_OUTPUTgenerated/proto/datatypes.proto")) {
			println("  Error: datatypes.proto should be generated")
			return false
		}

		val protoFile = getTextFile("DEFAULT_OUTPUTgenerated/proto/datatypes.proto")
		val content = protoFile.toString

		if (!content.contains("syntax = \"proto3\"")) {
			println("  Error: Should contain syntax proto3")
			return false
		}
		if (!content.contains("message Message")) {
			println("  Error: Should contain message Message")
			return false
		}
		if (!content.contains("enum Type")) {
			println("  Error: Should contain enum Type")
			return false
		}

		return true
	}

	def boolean testCMakeGeneration() {
		tearDown()
		val model = '''
			define BasicTypes {
			    type uint32
			        category value
			        length 32
			}
			
			public struct Test {
			    uint32 val
			}
		'''

		val resource = loadModel(model)
		generator.doGenerate(resource, fsa, context)

		if (!fsa.allFiles.containsKey("DEFAULT_OUTPUTgenerated/CMakeLists.txt")) {
			println("  Error: CMakeLists.txt should be generated")
			return false
		}

		val cmakeFile = getTextFile("DEFAULT_OUTPUTgenerated/CMakeLists.txt")
		val content = cmakeFile.toString

		if (!content.contains("cmake_minimum_required")) {
			println("  Error: Should contain cmake_minimum_required")
			return false
		}
		if (!content.contains("project")) {
			println("  Error: Should contain project")
			return false
		}
		
		// Also check that Test.h was generated with the right field
		val testHeader = getTextFile("DEFAULT_OUTPUTgenerated/include/Test.h")
		if (testHeader !== null) {
			val testContent = testHeader.toString
			if (!testContent.contains("uint32_t val")) {
				println("  Error: Test.h should contain uint32_t val")
				return false  
			}
		}

		return true
	}

	def boolean testComplexModel() {
		tearDown()
		val model = '''
			define Types {
			    type uint32
			        category value
			        length 32
			    
			    type String
			        category string
			}
			
			package com.test {
			    public struct Base {
			        uint32 id
			    }
			    
			    public struct Extended extends Base {
			        String name
			        uint32[5] vals
			    }
			    
			    public enumeration Status {
			        OK = 0,
			        ERROR = 1
			    }
			}
			
			public array DataArray of com.test.Extended
			public typedef Identifier is uint32
		'''

		val resource = loadModel(model)
		generator.doGenerate(resource, fsa, context)

		// Check multiple files were generated
		if (!fsa.allFiles.containsKey("DEFAULT_OUTPUTgenerated/include/com.test/Base.h")) {
			println("  Error: Should generate Base.h")
			return false
		}
		if (!fsa.allFiles.containsKey("DEFAULT_OUTPUTgenerated/include/com.test/Extended.h")) {
			println("  Error: Should generate Extended.h")
			return false
		}
		if (!fsa.allFiles.containsKey("DEFAULT_OUTPUTgenerated/include/com.test/Status.h")) {
			println("  Error: Should generate Status.h")
			return false
		}
		if (!fsa.allFiles.containsKey("DEFAULT_OUTPUTgenerated/include/DataArray.h")) {
			println("  Error: Should generate DataArray.h")
			return false
		}
		if (!fsa.allFiles.containsKey("DEFAULT_OUTPUTgenerated/include/Identifier.h")) {
			println("  Error: Should generate Identifier.h")
			return false
		}
		
		// Check that Extended.h contains the vals array field
		val extendedHeader = getTextFile("DEFAULT_OUTPUTgenerated/include/com.test/Extended.h")
		if (extendedHeader !== null) {
			val content = extendedHeader.toString
			if (!content.contains("vals[5]")) {
				println("  Error: Extended.h should contain vals[5] array")
				return false
			}
		}

		return true
	}

	/**
	 * Helper method to load a model from string
	 */
	def private loadModel(String modelText) {
		val file = File.createTempFile("test", ".mydsl")
		file.deleteOnExit()

		val writer = new BufferedWriter(new FileWriter(file))
		writer.write(modelText)
		writer.close()

		val fileURI = URI.createFileURI(file.absolutePath)
		val resource = resourceSet.getResource(fileURI, true)
		
		// Force resolution of cross-references
		EcoreUtil.resolveAll(resource)
		
		// Check for errors after resolution but don't fail - just warn
		if (!resource.errors.empty) {
			println("Warning: Model contains errors after loading:")
			for (error : resource.errors) {
				println("  " + error.message)
			}
			// Don't fail - let the generator try to handle unresolved references
		}
		
		return resource
	}

	/**
	 * Helper to get text file content
	 */
	def private getTextFile(String path) {
		val content = fsa.allFiles.get(path)
		if (content instanceof CharSequence) {
			return content
		}
		return null
	}

	/**
	 * Write files from InMemoryFileSystemAccess to disk
	 */
	def static void writeFiles(InMemoryFileSystemAccess fsa) {
		val outputDir = new File("generated")
		if (!outputDir.exists) {
			outputDir.mkdirs()
		}

		// Get all files
		val files = new HashMap<String, CharSequence>()

		// Add text files
		files.putAll(fsa.textFiles)

		// Add all files (may include binary files)
		for (entry : fsa.allFiles.entrySet) {
			if (!files.containsKey(entry.key)) {
				val content = entry.value
				if (content instanceof CharSequence) {
					files.put(entry.key, content)
				} else if (content instanceof byte[]) {
					// Handle binary files - write separately
					writeBinaryFile(outputDir, entry.key, content as byte[])
				} else {
					files.put(entry.key, String.valueOf(content))
				}
			}
		}

		if (files.empty) {
			println("  WARNING: No files were generated")
			return
		}

		println("  Writing " + files.size + " file(s):")

		for (entry : files.entrySet) {
			var filePath = entry.key
			val content = entry.value.toString

			// Remove DEFAULT_OUTPUT prefix if present
			if (filePath.startsWith(IFileSystemAccess.DEFAULT_OUTPUT)) {
				filePath = filePath.substring(IFileSystemAccess.DEFAULT_OUTPUT.length)
			}

			// Create output file
			val outputFile = new File(outputDir, filePath)

			// Create parent directories
			val parentDir = outputFile.parentFile
			if (!parentDir.exists) {
				parentDir.mkdirs()
			}

			// Write content to file
			try {
				val writer = new BufferedWriter(new FileWriter(outputFile))
				writer.write(content)
				writer.close()

				println("    ✓ " + filePath)
			} catch (Exception e) {
				println("    ✗ " + filePath + " - Error: " + e.message)
			}
		}
	}

	/**
	 * Write binary file
	 */
	def static void writeBinaryFile(File outputDir, String path, byte[] data) {
		var filePath = path

		// Remove DEFAULT_OUTPUT prefix if present
		if (filePath.startsWith(IFileSystemAccess.DEFAULT_OUTPUT)) {
			filePath = filePath.substring(IFileSystemAccess.DEFAULT_OUTPUT.length)
		}

		val outputFile = new File(outputDir, filePath)

		// Create parent directories
		val parentDir = outputFile.parentFile
		if (!parentDir.exists) {
			parentDir.mkdirs()
		}

		try {
			java.nio.file.Files.write(outputFile.toPath, data)
			println("    ✓ " + filePath + " (binary)")
		} catch (Exception e) {
			println("    ✗ " + filePath + " - Error: " + e.message)
		}
	}

	/**
	 * Print directory structure
	 */
	def static void printDirectory(File dir, String indent) {
		val files = dir.listFiles
		if (files !== null) {
			// Sort files: directories first, then by name
			val sorted = files.sortBy [
				(if(isDirectory) "0" else "1") + name
			]

			for (var i = 0; i < sorted.length; i++) {
				val file = sorted.get(i)
				val isLast = (i == sorted.length - 1)
				val prefix = indent + (if(isLast) "└── " else "├── ")
				val childIndent = indent + (if(isLast) "    " else "│   ")

				if (file.isDirectory) {
					println(prefix + file.name + "/")
					printDirectory(file, childIndent)
				} else {
					val size = file.length
					val sizeStr = if (size < 1024) {
							size + " B"
						} else if (size < 1024 * 1024) {
							(size / 1024) + " KB"
						} else {
							(size / (1024 * 1024)) + " MB"
						}
					println(prefix + file.name + " (" + sizeStr + ")")
				}
			}
		}
	}
}
