package org.xtext.example.mydsl.generator

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.eclipse.xtext.generator.JavaIoFileSystemAccess
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import org.eclipse.xtext.resource.IResourceServiceProvider
import com.google.inject.Inject
import java.lang.reflect.Field

/**
 * Generates code from your model files on save.
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#code-generation
 */
class MyDslGenerator extends AbstractGenerator {

    @Inject HybridGeneratorExample hybridGenerator
    @Inject TemplateLoader templateLoader
    @Inject AdvancedTemplateProcessor templateProcessor
    @Inject(optional=true) IResourceServiceProvider.Registry registry
    
    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext context) {
        // Initialize template loader and processor
        templateLoader.setTemplateBasePath("/templates/")
        templateProcessor.setTemplateLoader(templateLoader)
        
        // Check if we need to fix JavaIoFileSystemAccess
        if (fsa instanceof JavaIoFileSystemAccess) {
            ensureJavaIoFSAInitialized(fsa as JavaIoFileSystemAccess)
        }
        
        // Delegate to the hybrid generator
        hybridGenerator.doGenerate(resource, fsa, context)
    }
    
    /**
     * Ensure JavaIoFileSystemAccess has its registry field set
     */
    private def void ensureJavaIoFSAInitialized(JavaIoFileSystemAccess fsa) {
        try {
            // Check if registry is already set
            val registryField = JavaIoFileSystemAccess.getDeclaredField("registry")
            registryField.accessible = true
            val currentRegistry = registryField.get(fsa)
            
            if (currentRegistry === null && registry !== null) {
                // Set the registry if it's not set
                registryField.set(fsa, registry)
                println("[MyDslGenerator] Fixed null registry in JavaIoFileSystemAccess")
            }
        } catch (Exception e) {
            // Log but don't fail - the generation might still work
            System.err.println("[MyDslGenerator] Warning: Could not check/fix registry: " + e.message)
        }
    }
}
