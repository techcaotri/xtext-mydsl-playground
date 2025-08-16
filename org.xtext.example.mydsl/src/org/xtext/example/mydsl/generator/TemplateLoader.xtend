package org.xtext.example.mydsl.generator

import java.io.InputStream
import java.io.InputStreamReader
import java.io.BufferedReader
import java.util.Map
import java.util.HashMap
import java.util.concurrent.ConcurrentHashMap
import com.google.inject.Singleton
import com.google.inject.Inject
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Paths
import java.nio.file.Path
import java.io.File
import java.util.Set

/**
 * Template loader utility for loading and caching external template files
 * Supports both classpath and file system loading
 * 
 * @author Xtext/Xtend Generator Framework
 */
@Singleton
class TemplateLoader {
    
    // Cache for loaded templates to improve performance
    val templateCache = new ConcurrentHashMap<String, String>()
    
    // Configuration
    var boolean cacheEnabled = true
    var String templateBasePath = "/templates/"
    
    /**
     * Load a template from the classpath or file system
     * @param templatePath Path to the template file
     * @return Template content as string
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
            throw new TemplateNotFoundException('''Template not found: «templatePath»''')
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
            // Log error but don't throw - will try other methods
            logDebug('''Failed to load from classpath: «templatePath» - «e.message»''')
        }
        return null
    }
    
    /**
     * Load template from file system
     */
    private def String loadFromFileSystem(String templatePath) {
        try {
            // Try relative path first
            var Path path = Paths.get(templatePath)
            
            if (!Files.exists(path)) {
                // Try absolute path
                path = Paths.get(System.getProperty("user.dir"), templatePath)
            }
            
            if (Files.exists(path)) {
                return new String(Files.readAllBytes(path), StandardCharsets.UTF_8)
            }
        } catch (Exception e) {
            logDebug('''Failed to load from file system: «templatePath» - «e.message»''')
        }
        return null
    }
    
    /**
     * Load template and replace simple placeholders
     * @param templatePath Path to template
     * @param replacements Map of placeholder to replacement value
     * @return Processed template content
     */
    def String loadAndProcessTemplate(String templatePath, Map<String, String> replacements) {
        var template = loadTemplate(templatePath)
        
        // Simple string replacement for placeholders
        for (entry : replacements.entrySet) {
            template = template.replace("{{" + entry.key + "}}", entry.value ?: "")
        }
        
        return template
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
     * Clear template cache
     */
    def void clearCache() {
        templateCache.clear()
    }
    
    /**
     * Enable or disable caching
     */
    def void setCacheEnabled(boolean enabled) {
        this.cacheEnabled = enabled
        if (!enabled) {
            clearCache()
        }
    }
    
    /**
     * Set base path for templates
     */
    def void setTemplateBasePath(String basePath) {
        this.templateBasePath = basePath
        // Clear cache when base path changes
        clearCache()
    }
    
    /**
     * Check if a template exists
     */
    def boolean templateExists(String templatePath) {
        try {
            // Try loading from classpath
            val stream = class.getResourceAsStream(templatePath)
            if (stream !== null) {
                stream.close()
                return true
            }
            
            // Try loading from file system
            val path = Paths.get(templatePath)
            if (Files.exists(path)) {
                return true
            }
            
            // Try with base path
            if (!templatePath.startsWith(templateBasePath)) {
                return templateExists(templateBasePath + templatePath)
            }
            
            return false
        } catch (Exception e) {
            return false
        }
    }
    
    /**
     * Load multiple templates and concatenate
     */
    def String loadAndConcatenate(String... templatePaths) {
        val result = new StringBuilder()
        
        for (path : templatePaths) {
            if (result.length > 0) {
                result.append("\n")
            }
            result.append(loadTemplate(path))
        }
        
        return result.toString()
    }
    
    /**
     * Load template with fallback
     */
    def String loadWithFallback(String primaryPath, String fallbackPath) {
        try {
            return loadTemplate(primaryPath)
        } catch (TemplateNotFoundException e) {
            return loadTemplate(fallbackPath)
        }
    }
    
    /**
     * Get all cached template keys
     */
    def java.util.Set<String> getCachedTemplateKeys() {
        return templateCache.keySet()
    }
    
    /**
     * Get cache size
     */
    def int getCacheSize() {
        return templateCache.size()
    }
    
    /**
     * Preload templates into cache
     */
    def void preloadTemplates(String... templatePaths) {
        for (path : templatePaths) {
            try {
                loadTemplate(path)
            } catch (Exception e) {
                logDebug('''Failed to preload template: «path»''')
            }
        }
    }
    
    /**
     * Simple logging method
     */
    private def void logDebug(String message) {
        // In production, replace with proper logging framework
        if (System.getProperty("template.loader.debug", "false").equals("true")) {
            System.err.println("[TemplateLoader] " + message)
        }
    }
}

/**
 * Custom exception for template not found
 */
class TemplateNotFoundException extends RuntimeException {
    new(String message) {
        super(message)
    }
    
    new(String message, Throwable cause) {
        super(message, cause)
    }
}