package org.xtext.example.mydsl.generator

import java.io.InputStream
import java.io.InputStreamReader
import java.io.BufferedReader
import java.util.Map
import java.util.HashMap
import java.util.concurrent.ConcurrentHashMap
import com.google.inject.Singleton
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Paths
import java.nio.file.Path

/**
 * Template loader utility for loading external template files
 * 
 * @author DataType DSL Generator Framework
 */
@Singleton
class TemplateLoader {

	// Cache for loaded templates
	val templateCache = new ConcurrentHashMap<String, String>()

	// Configuration
	var boolean cacheEnabled = true
	var String templateBasePath = "/templates/"

	/**
	 * Enable or disable template caching
	 */
	def void setCacheEnabled(boolean enabled) {
		this.cacheEnabled = enabled
	}

	/**
	 * Load a template from the classpath or file system
	 */
	def String loadTemplate(String templatePath) {
		// Check cache first
		if (cacheEnabled && templateCache.containsKey(templatePath)) {
			return templateCache.get(templatePath)
		}

		var String content = null

		// Try loading from classpath first
		content = loadFromClasspath(templatePath)

		// If not found in classpath, try file system
		if (content === null) {
			content = loadFromFileSystem(templatePath)
		}

		// If still not found, try with base path
		if (content === null && !templatePath.startsWith(templateBasePath)) {
			content = loadTemplate(templateBasePath + templatePath)
		}

		if (content === null) {
			// Return empty string instead of throwing exception
			return ""
		}

		// Cache the loaded template
		if (cacheEnabled) {
			templateCache.put(templatePath, content)
		}

		return content
	}

	/**
	 * Load template from classpath
	 */
	private def String loadFromClasspath(String templatePath) {
		try {
			val stream = class.getResourceAsStream(templatePath)
			if (stream !== null) {
				return readStream(stream)
			}
		} catch (Exception e) {
			// Silent fail - will try other methods
		}
		return null
	}

	/**
	 * Load template from file system
	 */
	private def String loadFromFileSystem(String templatePath) {
		try {
			// Try relative path first
			var Path path = Paths.get("src/resources" + templatePath)

			if (!Files.exists(path)) {
				// Try without src/resources prefix
				path = Paths.get(templatePath)
			}

			if (!Files.exists(path)) {
				// Try with current directory
				path = Paths.get(System.getProperty("user.dir"), "src/resources", templatePath)
			}

			if (Files.exists(path)) {
				return new String(Files.readAllBytes(path), StandardCharsets.UTF_8)
			}
		} catch (Exception e) {
			// Silent fail
		}
		return null
	}

	/**
	 * Read stream content
	 */
	private def String readStream(InputStream stream) {
		val reader = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8))
		val content = new StringBuilder()

		try {
			var line = reader.readLine()
			while (line !== null) {
				if (content.length > 0) {
					content.append("\n")
				}
				content.append(line)
				line = reader.readLine()
			}
		} finally {
			reader.close()
			stream.close()
		}

		return content.toString()
	}

	/**
	 * Process template with variable replacements
	 */
	def String processTemplate(String templatePath, Map<String, String> variables) {
		var template = loadTemplate(templatePath)

		if (template.empty) {
			return ""
		}

		// Replace variables in format {{VARIABLE_NAME}}
		for (entry : variables.entrySet) {
			val placeholder = "{{" + entry.key + "}}"
			template = template.replace(placeholder, entry.value ?: "")
		}

		return template
	}

	/**
	 * Check if a template exists
	 */
	def boolean templateExists(String templatePath) {
		val content = loadTemplate(templatePath)
		return content !== null && !content.empty
	}

	/**
	 * Clear template cache
	 */
	def void clearCache() {
		templateCache.clear()
	}

	/**
	 * Set base path for templates
	 */
	def void setTemplateBasePath(String basePath) {
		this.templateBasePath = basePath
		clearCache()
	}
}
