package org.xtext.example.mydsl.generator

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import com.google.inject.Inject
import org.xtext.example.mydsl.myDsl.*

/**
 * Main generator for DataType DSL
 * Generates C++ structs/enums and Protobuf files using templates
 */
class MyDslGenerator extends AbstractGenerator {

    @Inject DataTypeGenerator dataTypeGenerator
    @Inject ProtobufGenerator protobufGenerator
    @Inject TemplateLoader templateLoader
    
    // Configuration flags
    var boolean generateCpp = true
    var boolean generateProtobuf = true
    var boolean generateBinaryDescriptor = true
    
    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext context) {
        val model = resource.contents.head as Model
        
        // Initialize template loader
        if (templateLoader !== null) {
            templateLoader.setTemplateBasePath("/templates/")
            templateLoader.setCacheEnabled(true)
        }
        
        // Generate C++ code if enabled
        if (generateCpp) {
            dataTypeGenerator.generate(model, fsa)
        }
        
        // Generate Protobuf files if enabled  
        if (generateProtobuf) {
            protobufGenerator.generate(model, fsa, generateBinaryDescriptor)
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
