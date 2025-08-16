package org.xtext.example.mydsl.generator

import org.xtext.example.mydsl.myDsl.*
import java.util.Set
import java.util.HashSet
import java.util.Map
import java.util.HashMap
import com.google.inject.Singleton
import org.eclipse.xtext.generator.IFileSystemAccess2
import java.io.ByteArrayOutputStream
import com.google.protobuf.DescriptorProtos
import com.google.protobuf.DescriptorProtos.FileDescriptorSet
import com.google.protobuf.DescriptorProtos.FileDescriptorProto
import com.google.protobuf.DescriptorProtos.FileOptions
import com.google.protobuf.DescriptorProtos.DescriptorProto
import com.google.protobuf.DescriptorProtos.FieldDescriptorProto
import com.google.protobuf.DescriptorProtos.EnumDescriptorProto
import com.google.protobuf.DescriptorProtos.EnumValueDescriptorProto
import org.eclipse.xtext.generator.JavaIoFileSystemAccess
import java.nio.file.Files
import java.nio.file.Paths
import java.nio.file.StandardOpenOption

/**
 * Protobuf generator for MyDsl models
 * Generates .proto files and binary .desc descriptor files
 * Note: Methods from entities are intentionally ignored in protobuf generation
 * 
 * @author Xtext/Xtend Generator Framework
 */
@Singleton
class ProtobufGenerator {
    
    static val Map<PrimitiveTypeName, FieldDescriptorProto.Type> TYPE_MAPPING = #{
        PrimitiveTypeName.BOOL -> FieldDescriptorProto.Type.TYPE_BOOL,
        PrimitiveTypeName.INT -> FieldDescriptorProto.Type.TYPE_INT32,
        PrimitiveTypeName.LONG -> FieldDescriptorProto.Type.TYPE_INT64,
        PrimitiveTypeName.LONGLONG -> FieldDescriptorProto.Type.TYPE_INT64,
        PrimitiveTypeName.FLOAT -> FieldDescriptorProto.Type.TYPE_FLOAT,
        PrimitiveTypeName.DOUBLE -> FieldDescriptorProto.Type.TYPE_DOUBLE,
        PrimitiveTypeName.STRING -> FieldDescriptorProto.Type.TYPE_STRING,
        PrimitiveTypeName.CHAR -> FieldDescriptorProto.Type.TYPE_INT32,
        PrimitiveTypeName.SIZE_T -> FieldDescriptorProto.Type.TYPE_UINT64
    }
    
    Map<String, Integer> fieldNumberCounter
    Set<String> imports
    
    /**
     * Generate Protobuf files for the model
     */
    def void generate(Model model, IFileSystemAccess2 fsa, boolean generateBinary) {
        fieldNumberCounter = new HashMap()
        imports = new HashSet()
        
        // Generate .proto file
        val protoFileName = '''proto/«model.name.toLowerCase».proto'''
        fsa.generateFile(protoFileName, generateProtoFile(model))
        
        // Generate binary descriptor set if requested
        if (generateBinary) {
            val descFileName = '''proto/«model.name.toLowerCase».desc'''
            val descriptorBytes = generateDescriptorSet(model)
            
            // Write binary file directly to file system
            writeBinaryFile(fsa, descFileName, descriptorBytes)
            
            // Also generate a text representation for debugging
            val infoFileName = '''proto/«model.name.toLowerCase».desc.info'''
            fsa.generateFile(infoFileName, generateDescriptorInfo(model, descriptorBytes))
        }
    }
    
    /**
     * Write binary file directly to the file system
     */
    def void writeBinaryFile(IFileSystemAccess2 fsa, String fileName, byte[] data) {
        if (fsa instanceof JavaIoFileSystemAccess) {
            // For JavaIoFileSystemAccess, we can get the output path and write directly
            val javaFsa = fsa as JavaIoFileSystemAccess
            val outputConfig = javaFsa.outputConfigurations.get("DEFAULT_OUTPUT")
            if (outputConfig !== null) {
                val outputDir = outputConfig.outputDirectory
                val filePath = Paths.get(outputDir, fileName)
                
                // Create parent directories if needed
                Files.createDirectories(filePath.parent)
                
                // Write binary data directly
                Files.write(filePath, data, 
                    StandardOpenOption.CREATE, 
                    StandardOpenOption.TRUNCATE_EXISTING,
                    StandardOpenOption.WRITE)
                
                return
            }
        }
        
        // Fallback: Generate a hex dump file and a conversion script
        val hexFileName = fileName + ".hex"
        val hexContent = generateHexDump(data)
        fsa.generateFile(hexFileName, hexContent)
        
        // Generate conversion script
        val scriptName = fileName + ".convert.sh"
        fsa.generateFile(scriptName, generateConversionScript(fileName))
    }
    
    /**
     * Generate hex dump of binary data
     */
    def CharSequence generateHexDump(byte[] data) '''
        # Hex dump of binary descriptor
        # Length: «data.length» bytes
        «FOR i : 0 ..< data.length»«String.format("%02X", data.get(i) as int)»«IF (i + 1) % 16 == 0»
        «ELSEIF (i + 1) < data.length» «ENDIF»«ENDFOR»
    '''
    
    /**
     * Generate conversion script for hex to binary
     */
    def CharSequence generateConversionScript(String fileName) '''
        #!/bin/bash
        # Convert hex dump to binary descriptor
        
        # Remove comments and spaces, then convert hex to binary
        grep -v '^#' «fileName».hex | tr -d ' \n' | xxd -r -p > «fileName»
        echo "Generated «fileName» from hex dump"
    '''
    
    /**
     * Generate info about the descriptor file
     */
    def CharSequence generateDescriptorInfo(Model model, byte[] descriptorBytes) '''
        # Protobuf Descriptor Information
        # Generated by MyDsl Generator
        # Source: «model.name».mydsl
        
        ## Binary Descriptor File: «model.name.toLowerCase».desc
        - Size: «descriptorBytes.length» bytes
        - Format: Protocol Buffers FileDescriptorSet
        - Encoding: Binary
        
        ## Contents:
        - Package: «determinePackage(model)»
        - Messages: «model.entities.size»
        - Enums: «model.enums.size»
        
        ## Usage:
        This descriptor file can be used with:
        - gRPC reflection API
        - Protocol buffer dynamic message parsing
        - Code generation tools
        - Protocol buffer inspection tools
        
        ## Verification:
        To inspect the contents of the descriptor file:
        ```bash
        # Using protoc (you need descriptor.proto in include path)
        protoc --decode=google.protobuf.FileDescriptorSet \
               /usr/include/google/protobuf/descriptor.proto < «model.name.toLowerCase».desc
        
        # Or decode raw
        protoc --decode_raw < «model.name.toLowerCase».desc
        ```
        
        ## Hex dump (first 256 bytes):
        «FOR i : 0 ..< Math.min(256, descriptorBytes.length)»«String.format("%02X", descriptorBytes.get(i) as int)»«IF (i + 1) % 16 == 0»
        «ELSEIF (i + 1) < Math.min(256, descriptorBytes.length)» «ENDIF»«ENDFOR»
        «IF descriptorBytes.length > 256»
        ... (truncated, total «descriptorBytes.length» bytes)
        «ENDIF»
    '''
    
    /**
     * Generate .proto file content
     */
    def CharSequence generateProtoFile(Model model) '''
        // Generated by MyDsl Generator
        // Source: «model.name»
        // Note: Methods are intentionally ignored for protobuf generation
        
        syntax = "proto3";
        
        «IF !determinePackage(model).empty»
        package «determinePackage(model)»;
        
        «ENDIF»
        option java_package = "«IF determinePackage(model).empty»com.generated«ELSE»«determinePackage(model)»«ENDIF»";
        option java_outer_classname = "«model.name»Proto";
        option java_multiple_files = true;
        option optimize_for = SPEED;
        
        «IF !imports.empty»
        «FOR imp : imports»
        import "«imp»";
        «ENDFOR»
        
        «ENDIF»
        «FOR enumDef : model.enums»
        «generateEnum(enumDef)»
        
        «ENDFOR»
        «FOR entity : model.entities»
        «generateMessage(entity)»
        
        «ENDFOR»
    '''
    
    /**
     * Generate enum definition
     */
    def CharSequence generateEnum(Enum enumDef) '''
        // Enum: «enumDef.name»
        enum «enumDef.name» {
            «val hasZero = enumDef.values.exists[value == 0]»
            «IF !hasZero»
            «enumDef.name.toUpperCase»_UNSPECIFIED = 0;
            «ENDIF»
            «FOR i : 0 ..< enumDef.values.size»
                «val value = enumDef.values.get(i)»
                «value.name»«IF value.value != 0» = «value.value»«ENDIF»;
            «ENDFOR»
        }
    '''
    
    /**
     * Generate message for entity
     */
    def CharSequence generateMessage(Entity entity) '''
        «IF entity.description !== null && !entity.description.empty»
        // «entity.description»
        «ELSE»
        // Message for entity: «entity.name»
        «ENDIF»
        message «entity.name» {
            «var fieldNumber = 1»
            «IF entity.superType !== null»
            // Inherited from «entity.superType.name»
            «entity.superType.name» base = «fieldNumber++»;
            «ENDIF»
            «FOR attr : entity.attributes»
            «val fieldDef = generateField(attr, fieldNumber++)»
            «IF fieldDef !== null»
            «fieldDef»
            «ENDIF»
            «ENDFOR»
            «FOR member : entity.staticMembers»
            «val fieldDef = generateStaticField(member, fieldNumber++)»
            «IF fieldDef !== null»
            «fieldDef»
            «ENDIF»
            «ENDFOR»
            «FOR inner : entity.innerClasses»
            
            «generateNestedMessage(inner, "    ")»
            «ENDFOR»
        }
    '''
    
    /**
     * Generate nested message
     */
    def CharSequence generateNestedMessage(Entity entity, String indent) '''
        «indent»// Inner class: «entity.name»
        «indent»message «entity.name» {
        «var fieldNumber = 1»
        «FOR attr : entity.attributes»
        «val fieldDef = generateField(attr, fieldNumber++)»
        «IF fieldDef !== null»
        «indent»    «fieldDef»
        «ENDIF»
        «ENDFOR»
        «indent»}
    '''
    
    /**
     * Generate field for attribute
     */
    def String generateField(Attribute attr) {
        generateField(attr, 0)
    }
    
    def String generateField(Attribute attr, int fieldNumber) {
        val fieldType = mapTypeToProto(attr.type)
        if (fieldType === null) {
            return null
        }
        
        val sb = new StringBuilder()
        
        // Add comment if description exists
        if (attr.description !== null && !attr.description.empty) {
            sb.append("// ").append(attr.description).append("\n    ")
        }
        
        // Handle repeated fields
        if (attr.type instanceof ArrayType || isListType(attr.type)) {
            sb.append("repeated ")
        }
        
        sb.append(fieldType).append(" ").append(toSnakeCase(attr.name))
        if (fieldNumber > 0) {
            sb.append(" = ").append(fieldNumber)
        }
        sb.append(";")
        
        return sb.toString()
    }
    
    /**
     * Generate static field
     */
    def String generateStaticField(StaticMember member, int fieldNumber) {
        val fieldType = mapTypeToProto(member.type)
        if (fieldType === null) {
            return null
        }
        
        return '''// static field
    «fieldType» «toSnakeCase(member.name)» = «fieldNumber»;'''
    }
    
    /**
     * Map Type to Protobuf type string
     */
    def String mapTypeToProto(Type type) {
        switch (type) {
            PrimitiveType: {
                switch(type.name) {
                    case BOOL: return "bool"
                    case INT: return "int32"
                    case LONG: return "int64"
                    case LONGLONG: return "int64"
                    case FLOAT: return "float"
                    case DOUBLE: return "double"
                    case STRING: return "string"
                    case CHAR: return "int32"
                    case SIZE_T: return "uint64"
                    case VOID: return null
                    default: return "bytes"
                }
            }
            CustomType: return type.name.name
            ArrayType: return mapTypeToProto(type.elementType)
            TemplateType: {
                // Handle common template types
                if (type.name == "vector" || type.name == "list") {
                    if (!type.templateArgs.empty) {
                        return mapTypeToProto(type.templateArgs.get(0))
                    }
                } else if (type.name == "map" && type.templateArgs.size == 2) {
                    val keyType = mapTypeToProto(type.templateArgs.get(0))
                    val valueType = mapTypeToProto(type.templateArgs.get(1))
                    return '''map<«keyType», «valueType»>'''
                }
                return "bytes"
            }
            default: return "bytes"
        }
    }
    
    /**
     * Check if type is a list type
     */
    def boolean isListType(Type type) {
        if (type instanceof TemplateType) {
            val name = type.name
            return name == "vector" || name == "list" || name == "set" || name == "deque"
        }
        return false
    }
    
    /**
     * Generate binary descriptor set - Fixed version
     */
    def byte[] generateDescriptorSet(Model model) {
        val fileBuilder = FileDescriptorProto.newBuilder()
        
        // Set file properties
        fileBuilder.setName(model.name.toLowerCase + ".proto")
        fileBuilder.setSyntax("proto3")
        
        val packageName = determinePackage(model)
        if (!packageName.empty) {
            fileBuilder.setPackage(packageName)
        }
        
        // Set options
        val optionsBuilder = FileOptions.newBuilder()
        optionsBuilder.setJavaPackage(if (packageName.empty) "com.generated" else packageName)
        optionsBuilder.setJavaOuterClassname(model.name + "Proto")
        optionsBuilder.setJavaMultipleFiles(true)
        optionsBuilder.setOptimizeFor(FileOptions.OptimizeMode.SPEED)
        fileBuilder.setOptions(optionsBuilder.build())
        
        // Add enums
        for (enumDef : model.enums) {
            fileBuilder.addEnumType(buildEnumDescriptor(enumDef))
        }
        
        // Add messages
        for (entity : model.entities) {
            fileBuilder.addMessageType(buildMessageDescriptor(entity))
        }
        
        // Build the FileDescriptorSet with the single file
        val setBuilder = FileDescriptorSet.newBuilder()
        setBuilder.addFile(fileBuilder.build())
        
        // Convert to byte array
        return setBuilder.build().toByteArray()
    }
    
    /**
     * Build enum descriptor
     */
    def EnumDescriptorProto buildEnumDescriptor(Enum enumDef) {
        val builder = EnumDescriptorProto.newBuilder()
        builder.setName(enumDef.name)
        
        // Add unspecified value if needed
        val hasZero = enumDef.values.exists[value == 0]
        if (!hasZero) {
            builder.addValue(EnumValueDescriptorProto.newBuilder()
                .setName(enumDef.name.toUpperCase + "_UNSPECIFIED")
                .setNumber(0)
                .build())
        }
        
        for (value : enumDef.values) {
            builder.addValue(EnumValueDescriptorProto.newBuilder()
                .setName(value.name)
                .setNumber(value.value)
                .build())
        }
        
        return builder.build()
    }
    
    /**
     * Build message descriptor
     */
    def DescriptorProto buildMessageDescriptor(Entity entity) {
        val builder = DescriptorProto.newBuilder()
        builder.setName(entity.name)
        
        var fieldNumber = 1
        
        // Handle inheritance
        if (entity.superType !== null) {
            builder.addField(FieldDescriptorProto.newBuilder()
                .setName("base")
                .setNumber(fieldNumber++)
                .setType(FieldDescriptorProto.Type.TYPE_MESSAGE)
                .setTypeName(entity.superType.name)
                .setLabel(FieldDescriptorProto.Label.LABEL_OPTIONAL)
                .build())
        }
        
        // Add fields for attributes only - methods are ignored
        for (attr : entity.attributes) {
            val field = buildFieldDescriptor(attr, fieldNumber++)
            if (field !== null) {
                builder.addField(field)
            }
        }
        
        // Add static members as fields
        for (member : entity.staticMembers) {
            val field = buildStaticFieldDescriptor(member, fieldNumber++)
            if (field !== null) {
                builder.addField(field)
            }
        }
        
        // Add nested messages for inner classes
        for (inner : entity.innerClasses) {
            builder.addNestedType(buildMessageDescriptor(inner))
        }
        
        return builder.build()
    }
    
    /**
     * Build field descriptor for attribute
     */
    def FieldDescriptorProto buildFieldDescriptor(Attribute attr, int fieldNumber) {
        val builder = FieldDescriptorProto.newBuilder()
        builder.setName(toSnakeCase(attr.name))
        builder.setNumber(fieldNumber)
        
        // Determine type and label
        var attrType = attr.type
        if (attrType instanceof ArrayType || isListType(attrType)) {
            builder.setLabel(FieldDescriptorProto.Label.LABEL_REPEATED)
            if (attrType instanceof ArrayType) {
                attrType = attrType.elementType
            } else if (attrType instanceof TemplateType) {
                // For template types like vector<T>, get the first template argument
                val templateType = attrType as TemplateType
                if (!templateType.templateArgs.empty) {
                    attrType = templateType.templateArgs.get(0)
                }
            }
        } else {
            builder.setLabel(FieldDescriptorProto.Label.LABEL_OPTIONAL)
        }
        
        // Set type
        if (attrType instanceof PrimitiveType) {
            val protoType = TYPE_MAPPING.get(attrType.name)
            if (protoType !== null) {
                builder.setType(protoType)
            } else {
                builder.setType(FieldDescriptorProto.Type.TYPE_BYTES)
            }
        } else if (attrType instanceof CustomType) {
            builder.setType(FieldDescriptorProto.Type.TYPE_MESSAGE)
            builder.setTypeName(attrType.name.name)
        } else {
            builder.setType(FieldDescriptorProto.Type.TYPE_BYTES)
        }
        
        return builder.build()
    }
    
    /**
     * Build field descriptor for static member
     */
    def FieldDescriptorProto buildStaticFieldDescriptor(StaticMember member, int fieldNumber) {
        val builder = FieldDescriptorProto.newBuilder()
        builder.setName(toSnakeCase(member.name))
        builder.setNumber(fieldNumber)
        builder.setLabel(FieldDescriptorProto.Label.LABEL_OPTIONAL)
        
        // Set type
        val memberType = member.type
        if (memberType instanceof PrimitiveType) {
            val protoType = TYPE_MAPPING.get(memberType.name)
            if (protoType !== null) {
                builder.setType(protoType)
            } else {
                builder.setType(FieldDescriptorProto.Type.TYPE_BYTES)
            }
        } else if (memberType instanceof CustomType) {
            builder.setType(FieldDescriptorProto.Type.TYPE_MESSAGE)
            builder.setTypeName(memberType.name.name)
        } else {
            builder.setType(FieldDescriptorProto.Type.TYPE_BYTES)
        }
        
        return builder.build()
    }
    
    /**
     * Determine package name from model
     */
    def String determinePackage(Model model) {
        // Try to find a common namespace from entities
        val namespaces = model.entities
            .map[namespace]
            .filterNull
            .filter[!empty]
            .toSet
            
        if (namespaces.size == 1) {
            return namespaces.head.replace("::", ".").replaceAll('''^"|"$''', "")
        }
        
        // Default package based on model name
        return '''com.generated.«model.name.toLowerCase»'''
    }
    
    /**
     * Convert camelCase to snake_case
     */
    def String toSnakeCase(String camelCase) {
        return camelCase.replaceAll("([a-z])([A-Z])", "$1_$2").toLowerCase
    }
}
