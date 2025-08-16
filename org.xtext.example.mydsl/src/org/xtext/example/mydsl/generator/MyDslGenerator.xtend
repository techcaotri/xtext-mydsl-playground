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
import org.xtext.example.mydsl.myDsl.Model

/**
 * Generates code from your model files on save.
 * Now includes Protobuf generation alongside C++ generation.
 */
class MyDslGenerator extends AbstractGenerator {

    @Inject HybridGeneratorExample hybridGenerator
    @Inject ProtobufGenerator protobufGenerator
    @Inject TemplateLoader templateLoader
    @Inject AdvancedTemplateProcessor templateProcessor
    @Inject(optional=true) IResourceServiceProvider.Registry registry
    
    // Configuration flags (can be set via properties or configuration)
    var boolean generateCpp = true
    var boolean generateProtobuf = true
    var boolean generateBinaryDescriptor = true
    
    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext context) {
        // Initialize template loader and processor
        templateLoader.setTemplateBasePath("/templates/")
        templateProcessor.setTemplateLoader(templateLoader)
        
        // Check if we need to fix JavaIoFileSystemAccess
        if (fsa instanceof JavaIoFileSystemAccess) {
            ensureJavaIoFSAInitialized(fsa as JavaIoFileSystemAccess)
        }
        
        // Get the model
        val model = resource.contents.head as Model
        
        // Generate C++ code if enabled
        if (generateCpp) {
            hybridGenerator.doGenerate(resource, fsa, context)
        }
        
        // Generate Protobuf files if enabled
        if (generateProtobuf) {
            protobufGenerator.generate(model, fsa, generateBinaryDescriptor)
        }
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
    
    /**
     * Configure generation options
     */
    def void setGenerationOptions(boolean cpp, boolean protobuf, boolean binaryDesc) {
        this.generateCpp = cpp
        this.generateProtobuf = protobuf
        this.generateBinaryDescriptor = binaryDesc
    }
}
