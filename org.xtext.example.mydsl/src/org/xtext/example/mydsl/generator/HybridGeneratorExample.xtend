package org.xtext.example.mydsl.generator

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import com.google.inject.Inject
import java.util.HashMap
import java.util.List
import java.util.ArrayList
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import org.xtext.example.mydsl.myDsl.*

/**
 * Complete Hybrid Generator Implementation - Fixed Version
 * Combines Xtend templates with external template files for maximum flexibility
 * 
 * @author Xtext/Xtend Generator Framework
 */
class HybridGeneratorExample extends AbstractGenerator {
    
    @Inject TemplateLoader templateLoader
    @Inject AdvancedTemplateProcessor templateProcessor
    
    // Configuration
    static val String TEMPLATE_PATH = "/templates/"
    static val String OUTPUT_PATH = "generated/"
    
    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext context) {
        val model = resource.contents.head as Model
        
        // Generate CMakeLists.txt for the entire project
        generateCMakeFile(model, fsa)
        
        // Generate code for each entity
        for (entity : model.entities) {
            generateHeaderFile(entity, fsa)
            generateImplementationFile(entity, fsa)
            generateTestFile(entity, fsa)
        }
        
        // Generate main.cpp if entities exist
        if (!model.entities.empty) {
            generateMainFile(model, fsa)
        }
        
        // Generate enums
        for (enumDef : model.enums) {
            generateEnumHeader(enumDef, fsa)
        }
        
        // Generate utility headers
        generateUtilityHeaders(model, fsa)
    }
    
    /**
     * Generate C++ header file using hybrid approach
     */
    def void generateHeaderFile(Entity entity, IFileSystemAccess2 fsa) {
        val fileName = '''«OUTPUT_PATH»include/«entity.name».h'''
        fsa.generateFile(fileName, generateHeaderContent(entity))
    }
    
    /**
     * Header content generation - Hybrid approach
     */
    def CharSequence generateHeaderContent(Entity entity) '''
        «IF templateLoader.templateExists(TEMPLATE_PATH + "header/copyright.template")»
            «templateLoader.loadTemplate(TEMPLATE_PATH + "header/copyright.template")»
        «ELSE»
            // Auto-generated C++ header file
        «ENDIF»
        
        #ifndef «entity.name.toUpperCase»_H
        #define «entity.name.toUpperCase»_H
        
        «generateIncludes(entity)»
        
        «IF entity.namespace !== null»
        namespace «entity.namespace» {
        «ENDIF»
        
        «IF templateLoader.templateExists(TEMPLATE_PATH + "header/class_documentation.template")»
            «templateLoader.loadTemplate(TEMPLATE_PATH + "header/class_documentation.template")
                .replace("{{CLASS_NAME}}", entity.name)
                .replace("{{DESCRIPTION}}", entity.description ?: "Generated class")
                .replace("{{AUTHOR}}", "Xtext/Xtend Generator")
                .replace("{{DATE}}", LocalDateTime.now.format(DateTimeFormatter.ISO_LOCAL_DATE))»
        «ELSE»
            /**
             * @class «entity.name»
             * @brief «entity.description ?: "Generated class"»
             */
        «ENDIF»
        
        class «entity.name»«IF entity.superType !== null» : public «entity.superType.name»«ENDIF» {
        «generateClassBody(entity)»
        };
        
        «IF entity.namespace !== null»
        } // namespace «entity.namespace»
        «ENDIF»
        
        «generateInlineImplementations(entity)»
        
        #endif // «entity.name.toUpperCase»_H
    '''
    
    /**
     * Generate includes section
     */
    def CharSequence generateIncludes(Entity entity) '''
        // Standard library includes
        #include <iostream>
        #include <memory>
        #include <string>
        #include <vector>
        #include <map>
        
        // Project includes
        «IF entity.superType !== null»
        #include "«entity.superType.name».h"
        «ENDIF»
        
        // Custom includes based on features
        «IF hasThreadingSupport(entity)»
        #include <thread>
        #include <mutex>
        #include <atomic>
        «ENDIF»
        «IF hasSerializationSupport(entity)»
        #include <sstream>
        #include <iomanip>
        #include "Serializable.h"
        «ENDIF»
    '''
    
    /**
     * Generate class body
     */
    def CharSequence generateClassBody(Entity entity) '''
        «val accessSections = generateAccessSections(entity)»
        «FOR section : accessSections»
        «section.visibility»:
            «section.content»
            
        «ENDFOR»
    '''
    
    /**
     * Generate access sections
     */
    def List<AccessSection> generateAccessSections(Entity entity) {
        val sections = new ArrayList<AccessSection>()
        
        // Private section
        if (hasPrivateMembers(entity)) {
            sections.add(new AccessSection("private", generatePrivateSection(entity)))
        }
        
        // Protected section
        if (hasProtectedMembers(entity)) {
            sections.add(new AccessSection("protected", generateProtectedSection(entity)))
        }
        
        // Public section
        sections.add(new AccessSection("public", generatePublicSection(entity)))
        
        return sections
    }
    
    /**
     * Generate private section
     */
    def CharSequence generatePrivateSection(Entity entity) '''
        «FOR attr : entity.attributes.filter[visibility == Visibility.PRIVATE]»
        «generateAttribute(attr)»
        «ENDFOR»
        
        «IF hasThreadingSupport(entity)»
        // Thread safety
        mutable std::mutex m_mutex;
        «ENDIF»
        
        «FOR staticMember : entity.staticMembers.filter[visibility == Visibility.PRIVATE]»
        static «mapType(staticMember.type)» «staticMember.name»«IF staticMember.initialValue !== null» = «expressionToString(staticMember.initialValue)»«ENDIF»;
        «ENDFOR»
    '''
    
    /**
     * Generate protected section
     */
    def CharSequence generateProtectedSection(Entity entity) '''
        «FOR attr : entity.attributes.filter[visibility == Visibility.PROTECTED]»
        «generateAttribute(attr)»
        «ENDFOR»
        
        «FOR method : entity.methods.filter[visibility == Visibility.PROTECTED]»
        «generateMethodDeclaration(method)»
        «ENDFOR»
    '''
    
    /**
     * Generate public section
     */
    def CharSequence generatePublicSection(Entity entity) '''
        // Constructors and Destructor
        «generateConstructors(entity)»
        «generateDestructor(entity)»
        
        «IF hasCopySemantics(entity)»
        // Copy semantics
        «entity.name»(const «entity.name»& other);
        «entity.name»& operator=(const «entity.name»& other);
        «ENDIF»
        
        «IF hasMoveSemantics(entity)»
        // Move semantics
        «entity.name»(«entity.name»&& other) noexcept;
        «entity.name»& operator=(«entity.name»&& other) noexcept;
        «ENDIF»
        
        // Public methods
        «FOR method : entity.methods.filter[visibility == Visibility.PUBLIC]»
        «generateMethodDeclaration(method)»
        «ENDFOR»
        
        // Getters and Setters
        «generateAccessors(entity)»
        
        «IF hasOperatorOverloads(entity)»
        // Operator overloads
        bool operator==(const «entity.name»& other) const;
        bool operator!=(const «entity.name»& other) const;
        «ENDIF»
        
        «IF hasSerializationSupport(entity)»
        // Serialization interface
        «generateSerializationMethods(entity)»
        «ENDIF»
        
        «FOR innerClass : entity.innerClasses»
        // Inner class
        «generateInnerClass(innerClass)»
        «ENDFOR»
        
        «FOR friend : entity.friends»
        friend «IF friend.friendClass !== null»class «friend.friendClass.name»«ELSE»«friend.friendFunction»«ENDIF»;
        «ENDFOR»
    '''
    
    /**
     * Generate implementation file
     */
    def void generateImplementationFile(Entity entity, IFileSystemAccess2 fsa) {
        val fileName = '''«OUTPUT_PATH»src/«entity.name».cpp'''
        fsa.generateFile(fileName, generateImplementationContent(entity))
    }
    
    /**
     * Implementation content generation
     */
    def CharSequence generateImplementationContent(Entity entity) '''
        #include "«entity.name».h"
        
        «IF entity.namespace !== null»
        namespace «entity.namespace» {
        «ENDIF»
        
        «generateConstructorImplementations(entity)»
        
        «generateDestructorImplementation(entity)»
        
        «IF hasCopySemantics(entity)»
        «generateCopyImplementations(entity)»
        «ENDIF»
        
        «IF hasMoveSemantics(entity)»
        «generateMoveImplementations(entity)»
        «ENDIF»
        
        «generateMethodImplementations(entity)»
        
        «IF hasOperatorOverloads(entity)»
        «generateOperatorImplementations(entity)»
        «ENDIF»
        
        «IF hasSerializationSupport(entity)»
        «generateSerializationImplementations(entity)»
        «ENDIF»
        
        «IF entity.namespace !== null»
        } // namespace «entity.namespace»
        «ENDIF»
    '''
    
    /**
     * Generate constructor implementations - Fixed
     */
    def CharSequence generateConstructorImplementations(Entity entity) '''
        // Default constructor
        «entity.name»::«entity.name»() {
            «FOR attr : entity.attributes.filter[defaultValue !== null]»
            «attr.name» = «expressionToString(attr.defaultValue)»;
            «ENDFOR»
        }
        
        «FOR constructor : entity.constructors»
        // Custom constructor
        «entity.name»::«entity.name»(«generateParameterList(constructor.parameters)»)
            «IF !constructor.initializerList.empty»
            : «FOR init : constructor.initializerList SEPARATOR ', '»«init.member»(«expressionToString(init.value)»)«ENDFOR»
            «ENDIF» {
            «IF constructor.body !== null»
            // Constructor body
            «ENDIF»
        }
        «ENDFOR»
    '''
    
    /**
     * Generate method implementations
     */
    def CharSequence generateMethodImplementations(Entity entity) '''
        «FOR method : entity.methods.filter[!isPureVirtual]»
        «mapType(method.returnType)» «entity.name»::«method.name»(«generateParameterList(method.parameters)»)«IF method.isConst» const«ENDIF»«IF method.isNoexcept» noexcept«ENDIF» {
            «IF method.description !== null»
            // «method.description»
            «ENDIF»
            // TODO: Implement «method.name»
            «IF !(method.returnType instanceof PrimitiveType && (method.returnType as PrimitiveType).name == PrimitiveTypeName.VOID)»
            return {};
            «ENDIF»
        }
        
        «ENDFOR»
    '''
    
    /**
     * Generate enum header file
     */
    def void generateEnumHeader(Enum enumDef, IFileSystemAccess2 fsa) {
        val fileName = '''«OUTPUT_PATH»include/«enumDef.name».h'''
        fsa.generateFile(fileName, generateEnumContent(enumDef))
    }
    
    /**
     * Generate enum content
     */
    def CharSequence generateEnumContent(Enum enumDef) '''
        #ifndef «enumDef.name.toUpperCase»_H
        #define «enumDef.name.toUpperCase»_H
        
        enum «IF enumDef.isClass»class «ENDIF»«enumDef.name»«IF enumDef.underlyingType !== null» : «mapType(enumDef.underlyingType)»«ENDIF» {
            «FOR i : 0 ..< enumDef.values.size»
                «val value = enumDef.values.get(i)»
                «value.name»«IF value.value != 0» = «value.value»«ENDIF»«IF i < enumDef.values.size - 1»,«ENDIF»
            «ENDFOR»
        };
        
        #endif // «enumDef.name.toUpperCase»_H
    '''
    
    // Helper Methods
    
    def CharSequence generateAttribute(Attribute attr) '''
        «IF attr.isStatic»static «ENDIF»«IF attr.isConst»const «ENDIF»«IF attr.isMutable»mutable «ENDIF»«mapType(attr.type)» «attr.name»«IF attr.defaultValue !== null» = «expressionToString(attr.defaultValue)»«ENDIF»;
    '''
    
    def CharSequence generateMethodDeclaration(Method method) '''
        «IF method.isStatic»static «ENDIF»«IF method.isVirtual»virtual «ENDIF»«IF method.isInline»inline «ENDIF»«mapType(method.returnType)» «method.name»(«generateParameterList(method.parameters)»)«IF method.isConst» const«ENDIF»«IF method.isNoexcept» noexcept«ENDIF»«IF method.isOverride» override«ENDIF»«IF method.isFinal» final«ENDIF»«IF method.isPureVirtual» = 0«ENDIF»;
    '''
    
    def CharSequence generateParameterList(List<Parameter> parameters) '''
        «FOR param : parameters SEPARATOR ', '»«IF param.isConst»const «ENDIF»«mapType(param.type)»«IF param.isReference»&«ELSEIF param.isPointer»*«ELSEIF param.isRValueReference»&&«ENDIF» «param.name»«IF param.defaultValue !== null» = «expressionToString(param.defaultValue)»«ENDIF»«ENDFOR»
    '''
    
    /**
     * Map Type to C++ string - Fixed
     */
    def String mapType(Type type) {
        switch (type) {
            PrimitiveType: {
                switch(type.name) {
                    case STRING: return "std::string"
                    case BOOL: return "bool"
                    case INT: return "int"
                    case LONG: return "long"
                    case LONGLONG: return "long long"
                    case FLOAT: return "float"
                    case DOUBLE: return "double"
                    case VOID: return "void"
                    case AUTO: return "auto"
                    default: return type.name.toString.toLowerCase
                }
            }
            CustomType: return type.name.name
            TemplateType: return '''«type.name»<«FOR arg : type.templateArgs SEPARATOR ', '»«mapType(arg)»«ENDFOR»>'''
            ArrayType: {
                // size is primitive int, defaults to 0 when not set
                val sizeStr = if (type.size > 0) type.size.toString else "0"
                return '''std::array<«mapType(type.elementType)», «sizeStr»>'''
            }
            PointerType: return '''«mapType(type.pointedType)»*«IF type.isConst» const«ENDIF»'''
            ReferenceType: return '''«mapType(type.referencedType)»&«IF type.isConst» const«ENDIF»'''
            FunctionType: return '''std::function<«mapType(type.returnType)»(«FOR paramType : type.paramTypes SEPARATOR ', '»«mapType(paramType)»«ENDFOR»)>'''
            default: return "void"
        }
    }
    
    /**
     * Convert Expression to string
     */
    def String expressionToString(Expression expr) {
        switch (expr) {
            LiteralExpression: return literalToString(expr.value)
            IdentifierExpression: return expr.id
            BinaryExpression: return '''«expressionToString(expr.left)» «expr.operator» «expressionToString(expr.right)»'''
            UnaryExpression: return '''«expr.operator»«expressionToString(expr.operand)»'''
            CallExpression: return '''«expressionToString(expr.function)»(«FOR arg : expr.arguments SEPARATOR ', '»«expressionToString(arg)»«ENDFOR»)'''
            MemberExpression: return '''«expressionToString(expr.object)».«expr.member»'''
            ArrayAccessExpression: return '''«expressionToString(expr.array)»[«expressionToString(expr.index)»]'''
            default: return ""
        }
    }
    
    def String literalToString(Literal literal) {
        switch (literal) {
            StringLiteral: return '''"«literal.value»"'''
            IntLiteral: return String.valueOf(literal.value)
            FloatLiteral: return literal.value
            BooleanLiteral: return literal.value
            NullLiteral: return "nullptr"
            default: return ""
        }
    }
    
    def boolean hasThreadingSupport(Entity entity) {
        entity.options.exists[
            it instanceof ThreadingOption && (it as ThreadingOption).threading == "true"
        ]
    }
    
    def boolean hasSerializationSupport(Entity entity) {
        entity.options.exists[
            it instanceof SerializationOption && (it as SerializationOption).serialization == "true"
        ]
    }
    
    def boolean hasOperatorOverloads(Entity entity) {
        entity.options.exists[
            it instanceof OperatorsOption && (it as OperatorsOption).operators == "true"
        ]
    }
    
    def boolean hasCopySemantics(Entity entity) {
        entity.options.exists[
            it instanceof CopySemanticsOption && (it as CopySemanticsOption).copySemantics == "true"
        ]
    }
    
    def boolean hasMoveSemantics(Entity entity) {
        entity.options.exists[
            it instanceof MoveSemanticsOption && (it as MoveSemanticsOption).moveSemantics == "true"
        ]
    }
    
    def boolean hasPrivateMembers(Entity entity) {
        !entity.attributes.filter[visibility == Visibility.PRIVATE].empty ||
        !entity.staticMembers.filter[visibility == Visibility.PRIVATE].empty
    }
    
    def boolean hasProtectedMembers(Entity entity) {
        !entity.attributes.filter[visibility == Visibility.PROTECTED].empty ||
        !entity.methods.filter[visibility == Visibility.PROTECTED].empty
    }
    
    // Stub methods for remaining functionality
    
    def void generateTestFile(Entity entity, IFileSystemAccess2 fsa) {
        val fileName = '''«OUTPUT_PATH»test/«entity.name»Test.cpp'''
        fsa.generateFile(fileName, '''
            #include <gtest/gtest.h>
            #include "«entity.name».h"
            
            TEST(«entity.name»Test, Constructor) {
                «entity.name» obj;
                ASSERT_TRUE(true);
            }
        ''')
    }
    
    def void generateMainFile(Model model, IFileSystemAccess2 fsa) {
        val fileName = '''«OUTPUT_PATH»src/main.cpp'''
        fsa.generateFile(fileName, '''
            #include <iostream>
            «FOR entity : model.entities»
            #include "«entity.name».h"
            «ENDFOR»
            
            int main(int argc, char* argv[]) {
                std::cout << "Generated C++ Application" << std::endl;
                return 0;
            }
        ''')
    }
    
    def void generateCMakeFile(Model model, IFileSystemAccess2 fsa) {
        val fileName = '''«OUTPUT_PATH»CMakeLists.txt'''
        fsa.generateFile(fileName, '''
            cmake_minimum_required(VERSION 3.16)
            project(«model.name»)
            
            set(CMAKE_CXX_STANDARD 17)
            
            add_executable(«model.name»
                src/main.cpp
                «FOR entity : model.entities»
                src/«entity.name».cpp
                «ENDFOR»
            )
            
            target_include_directories(«model.name» PRIVATE include)
        ''')
    }
    
    def void generateUtilityHeaders(Model model, IFileSystemAccess2 fsa) {
        // Generate Serializable interface if needed
        if (model.entities.exists[hasSerializationSupport]) {
            val fileName = '''«OUTPUT_PATH»include/Serializable.h'''
            fsa.generateFile(fileName, '''
                #ifndef SERIALIZABLE_H
                #define SERIALIZABLE_H
                
                #include <string>
                
                class ISerializable {
                public:
                    virtual ~ISerializable() = default;
                    virtual std::string serialize() const = 0;
                    virtual bool deserialize(const std::string& data) = 0;
                };
                
                #endif // SERIALIZABLE_H
            ''')
        }
    }
    
    def CharSequence generateConstructors(Entity entity) '''
        «entity.name»();
        «FOR constructor : entity.constructors»
        «IF constructor.isExplicit»explicit «ENDIF»«entity.name»(«generateParameterList(constructor.parameters)»)«IF constructor.isNoexcept» noexcept«ENDIF»;
        «ENDFOR»
    '''
    
    def CharSequence generateDestructor(Entity entity) '''
        «IF entity.methods.exists[isVirtual]»virtual «ENDIF»~«entity.name»();
    '''
    
    def CharSequence generateDestructorImplementation(Entity entity) '''
        «entity.name»::~«entity.name»() {
            // Destructor implementation
        }
    '''
    
    def CharSequence generateCopyImplementations(Entity entity) '''
        // Copy constructor
        «entity.name»::«entity.name»(const «entity.name»& other) {
            // Copy implementation
        }
        
        // Copy assignment operator
        «entity.name»& «entity.name»::operator=(const «entity.name»& other) {
            if (this != &other) {
                // Copy implementation
            }
            return *this;
        }
    '''
    
    def CharSequence generateMoveImplementations(Entity entity) '''
        // Move constructor
        «entity.name»::«entity.name»(«entity.name»&& other) noexcept {
            // Move implementation
        }
        
        // Move assignment operator
        «entity.name»& «entity.name»::operator=(«entity.name»&& other) noexcept {
            if (this != &other) {
                // Move implementation
            }
            return *this;
        }
    '''
    
    def CharSequence generateAccessors(Entity entity) '''
        «FOR attr : entity.attributes.filter[hasGetter || hasSetter]»
        «IF attr.hasGetter»
        «mapType(attr.type)» get«attr.name.toFirstUpper»() const { return «attr.name»; }
        «ENDIF»
        «IF attr.hasSetter»
        void set«attr.name.toFirstUpper»(const «mapType(attr.type)»& value) { «attr.name» = value; }
        «ENDIF»
        «ENDFOR»
    '''
    
    def CharSequence generateOperatorImplementations(Entity entity) '''
        bool «entity.name»::operator==(const «entity.name»& other) const {
            // Comparison implementation
            return true;
        }
        
        bool «entity.name»::operator!=(const «entity.name»& other) const {
            return !(*this == other);
        }
    '''
    
    def CharSequence generateSerializationMethods(Entity entity) '''
        std::string serialize() const override;
        bool deserialize(const std::string& data) override;
    '''
    
    def CharSequence generateSerializationImplementations(Entity entity) '''
        std::string «entity.name»::serialize() const {
            // Serialization implementation
            return "";
        }
        
        bool «entity.name»::deserialize(const std::string& data) {
            // Deserialization implementation
            return true;
        }
    '''
    
    def CharSequence generateInnerClass(Entity innerClass) '''
        class «innerClass.name» {
        public:
            «innerClass.name»();
            ~«innerClass.name»();
        };
    '''
    
    def CharSequence generateInlineImplementations(Entity entity) '''
        // Inline implementations
    '''
    
    // Helper class
    static class AccessSection {
        public String visibility
        public CharSequence content
        
        new(String visibility, CharSequence content) {
            this.visibility = visibility
            this.content = content
        }
    }
}