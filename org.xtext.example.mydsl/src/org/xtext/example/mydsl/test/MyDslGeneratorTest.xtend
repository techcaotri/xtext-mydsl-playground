package org.xtext.example.mydsl.test

import org.xtext.example.mydsl.MyDslStandaloneSetup
import org.xtext.example.mydsl.generator.MyDslGenerator
import org.xtext.example.mydsl.generator.HybridGeneratorExample
import org.xtext.example.mydsl.generator.TemplateLoader
import org.xtext.example.mydsl.generator.AdvancedTemplateProcessor
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl
import org.eclipse.emf.common.util.URI
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import org.eclipse.xtext.generator.GeneratorContext
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.eclipse.xtext.generator.JavaIoFileSystemAccess
import org.eclipse.xtext.generator.OutputConfiguration
import org.eclipse.xtext.resource.IResourceServiceProvider
import java.io.File
import java.io.FileWriter
import java.io.BufferedWriter
import java.lang.reflect.Field
import java.util.Map
import java.util.HashMap

/**
 * Test runner for MyDslGenerator
 * Fixed version that properly handles file system access initialization
 */
class MyDslGeneratorTest {

	def static void main(String[] args) {
		if (args.length == 0) {
			println("Usage: java MyDslGeneratorTest <input.mydsl>")
			println("Example: java MyDslGeneratorTest test.mydsl")
			return
		}

		val inputFile = args.get(0)
		println("=== MyDsl Generator Test ===")
		println("Input file: " + inputFile)
		println("")

		// Initialize Xtext
		println("Initializing Xtext...")
		val injector = new MyDslStandaloneSetup().createInjectorAndDoEMFRegistration()

		// Load the model
		println("Loading model from: " + inputFile)
		val resourceSet = injector.getInstance(ResourceSetImpl)

		val file = new File(inputFile)
		if (!file.exists) {
			println("ERROR: File not found: " + file.absolutePath)
			return
		}

		val fileURI = URI.createFileURI(file.absolutePath)
		val resource = try {
				resourceSet.getResource(fileURI, true)
			} catch (Exception e) {
				println("ERROR: Could not load file: " + inputFile)
				println("  Reason: " + e.message)
				return
			}

		// Check for parse errors
		if (!resource.errors.empty) {
			println("ERROR: The model contains errors:")
			for (error : resource.errors) {
				println("  Line " + error.line + ": " + error.message)
			}
			return
		}

		// Check if model is empty
		if (resource.contents.empty) {
			println("WARNING: The model is empty or could not be parsed")
			return
		}

		// Try two different approaches
		var success = false

		// Approach 1: Try with properly initialized JavaIoFileSystemAccess
		try {
			println("\nApproach 1: Attempting with initialized JavaIoFileSystemAccess...")
			success = generateWithJavaIo(resource, injector)
		} catch (Exception e) {
			println("  Failed: " + e.message)
		}

		// Approach 2: Use InMemoryFileSystemAccess (more reliable)
		if (!success) {
			try {
				println("\nApproach 2: Using InMemoryFileSystemAccess...")
				generateWithInMemory(resource, injector)
				success = true
			} catch (Exception e) {
				println("  Failed: " + e.message)
				e.printStackTrace()
			}
		}

		if (success) {
			println("\n=== Generation Complete ===")
			val outputDir = new File("generated")
			println("Output directory: " + outputDir.absolutePath)

			if (outputDir.exists && outputDir.isDirectory) {
				println("\nGenerated structure:")
				printDirectory(outputDir, "  ")
			}
		} else {
			println("\nERROR: Generation failed")
		}
	}

	/**
	 * Approach 1: Try with properly initialized JavaIoFileSystemAccess
	 */
	def static boolean generateWithJavaIo(org.eclipse.emf.ecore.resource.Resource resource,
		com.google.inject.Injector injector) {
		try {
			// Get the registry from injector FIRST
			val registry = injector.getInstance(IResourceServiceProvider.Registry)

			// Create JavaIoFileSystemAccess
			val fsa = new JavaIoFileSystemAccess()

			// CRITICAL: Set the registry before doing anything else
			try {
				val registryField = JavaIoFileSystemAccess.getDeclaredField("registry")
				registryField.accessible = true
				registryField.set(fsa, registry)
				println("  Registry successfully set")
			} catch (Exception e) {
				println("  ERROR: Failed to set registry - " + e.message)
				// Cannot proceed without registry
				return false
			}

			// Now set output configurations
			val defaultOutput = new OutputConfiguration(IFileSystemAccess.DEFAULT_OUTPUT)
			defaultOutput.description = "Default output"
			defaultOutput.outputDirectory = "./generated"
			defaultOutput.overrideExistingResources = true
			defaultOutput.createOutputDirectory = true
			defaultOutput.setUseOutputPerSourceFolder(false)

			val outputConfigs = new HashMap<String, OutputConfiguration>()
			outputConfigs.put(IFileSystemAccess.DEFAULT_OUTPUT, defaultOutput)
			fsa.outputConfigurations = outputConfigs

			// Set the output path
			fsa.setOutputPath("generated/")

			// Initialize components that might be needed
			val templateLoader = new TemplateLoader()
			templateLoader.templateBasePath = "/templates/"
			templateLoader.cacheEnabled = true

			val templateProcessor = new AdvancedTemplateProcessor(templateLoader)

			// Create HybridGeneratorExample directly with proper initialization
			val hybridGenerator = new HybridGeneratorExample()

			// Inject dependencies via reflection if needed
			try {
				val loaderField = HybridGeneratorExample.getDeclaredField("templateLoader")
				loaderField.accessible = true
				loaderField.set(hybridGenerator, templateLoader)

				val processorField = HybridGeneratorExample.getDeclaredField("templateProcessor")
				processorField.accessible = true
				processorField.set(hybridGenerator, templateProcessor)
			} catch (Exception e) {
				// Fields might not exist or might be optional
				println("  Note: Could not inject template components - " + e.message)
			}

			// Generate using the hybrid generator directly
			val context = new GeneratorContext()
			hybridGenerator.doGenerate(resource, fsa, context)

			println("  Success!")
			return true

		} catch (Exception e) {
			println("  Failed: " + e.class.simpleName + " - " + e.message)
			e.printStackTrace()
			return false
		}
	}

	/**
	 * Approach 2: Use InMemoryFileSystemAccess and write files manually
	 */
	def static void generateWithInMemory(org.eclipse.emf.ecore.resource.Resource resource,
		com.google.inject.Injector injector) {
		// Create InMemoryFileSystemAccess
		val fsa = new InMemoryFileSystemAccess()
		val context = new GeneratorContext()

		// Initialize template components if available
		try {
			val templateLoader = injector.getInstance(TemplateLoader)
			val templateProcessor = injector.getInstance(AdvancedTemplateProcessor)

			if (templateLoader !== null) {
				templateLoader.templateBasePath = "/templates/"
				templateLoader.cacheEnabled = true
			}

			if (templateProcessor !== null && templateLoader !== null) {
				templateProcessor.templateLoader = templateLoader
			}
		} catch (Exception e) {
			// Template components not available, continue without them
		}

		// Get generator - try different options
		var generator = null as org.eclipse.xtext.generator.IGenerator2

		// Try MyDslGenerator first
		try {
			generator = injector.getInstance(MyDslGenerator)
			println("  Using MyDslGenerator")
		} catch (Exception e1) {
			// Try HybridGeneratorExample
			try {
				generator = injector.getInstance(HybridGeneratorExample)
				println("  Using HybridGeneratorExample")
			} catch (Exception e2) {
				throw new RuntimeException("No generator found", e2)
			}
		}

		// Generate
		println("  Generating code...")
		generator.doGenerate(resource, fsa, context)

		// Write files to disk
		println("  Writing files...")
		writeFiles(fsa)
	}

	/**
	 * Write files from InMemoryFileSystemAccess to disk
	 */
	def static void writeFiles(InMemoryFileSystemAccess fsa) {
		val outputDir = new File("generated")
		if (!outputDir.exists) {
			outputDir.mkdirs()
		}

		// Get all files - handle both textFiles and allFiles
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
					files.put(entry.key, new String(content as byte[]))
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
