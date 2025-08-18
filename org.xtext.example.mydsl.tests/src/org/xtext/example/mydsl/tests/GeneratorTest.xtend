package org.xtext.example.mydsl.tests

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.BeforeEach
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.extensions.InjectionExtension
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import org.xtext.example.mydsl.myDsl.Model
import org.xtext.example.mydsl.myDsl.FStructType
import org.xtext.example.mydsl.myDsl.FEnumerationType
import org.xtext.example.mydsl.myDsl.FTypeDef
import org.xtext.example.mydsl.myDsl.FArrayType
import org.eclipse.xtext.testing.util.ParseHelper
import org.eclipse.xtext.generator.IGeneratorContext
import org.eclipse.xtext.generator.GeneratorContext
import com.google.inject.Inject
import org.junit.jupiter.api.^extension.ExtendWith

import static org.junit.jupiter.api.Assertions.assertNotNull
import static org.junit.jupiter.api.Assertions.assertEquals
import static org.junit.jupiter.api.Assertions.assertTrue
import static org.junit.jupiter.api.Assertions.fail
import org.xtext.example.mydsl.generator.MyDslGenerator

@ExtendWith(InjectionExtension)
@InjectWith(MyDslInjectorProvider)
class GeneratorTest {
    @Inject ParseHelper<Model> parseHelper
    @Inject MyDslGenerator generator

    InMemoryFileSystemAccess fsa
    IGeneratorContext context
    
    @BeforeEach
    def void setup() {
        fsa = new InMemoryFileSystemAccess()
        context = new GeneratorContext()
    }
    
    @Test
    def void testStructGeneration() {
        val modelText = '''
            define BasicTypes {
                type String
                    category string
                type uint32
                    category value
                    length 32
            }
            
            public struct Person {
                String name
                uint32 age
            }
        '''
        
        println("Testing struct generation")
        val model = parseHelper.parse(modelText)
        
        if (model === null) {
            fail("Model parsing returned null")
        }
        
        // Check for errors in the resource
        val errors = model.eResource.errors
        if (!errors.empty) {
            println("Parse errors:")
            errors.forEach[println("  " + it.message)]
            fail("Model has parse errors")
        }
        
        assertNotNull(model)
        assertEquals(1, model.primitiveDefinitions.size)
        assertEquals(1, model.types.size, "Expected 1 type (Person struct)")
        
        val struct = model.types.get(0) as FStructType
        assertEquals("Person", struct.name)
        assertEquals(2, struct.elements.size)
        
        // Test generation
        generator.doGenerate(model.eResource, fsa, context)
        
        println("Generated files:")
        fsa.allFiles.keySet.forEach[println("  " + it)]
        
        assertTrue(fsa.allFiles.containsKey("DEFAULT_OUTPUTgenerated/include/Person.h"))
    }
    
    @Test
    def void testEnumGeneration() {
        val modelText = '''
            public enumeration Status {
                ACTIVE = 0,
                INACTIVE = 1
            }
        '''
        
        println("Testing enum generation")
        val model = parseHelper.parse(modelText)
        
        if (model === null) {
            fail("Model parsing returned null")
        }
        
        val errors = model.eResource.errors
        if (!errors.empty) {
            println("Parse errors:")
            errors.forEach[println("  " + it.message)]
            fail("Model has parse errors")
        }
        
        assertNotNull(model)
        assertEquals(1, model.types.size)
        
        val enumType = model.types.get(0) as FEnumerationType
        assertEquals("Status", enumType.name)
        assertEquals(2, enumType.enumerators.size)
        
        // Test generation
        generator.doGenerate(model.eResource, fsa, context)
        
        assertTrue(fsa.allFiles.containsKey("DEFAULT_OUTPUTgenerated/include/Status.h"))
    }
    
    @Test
    def void testPackageGeneration() {
        val modelText = '''
            define BasicTypes {
                type uint32
                    category value
                    length 32
            }
            
            package com.example {
                public struct Data {
                    uint32 id
                }
            }
        '''
        
        println("Testing package generation")
        val model = parseHelper.parse(modelText)
        
        if (model === null) {
            fail("Model parsing returned null")
        }
        
        val errors = model.eResource.errors
        if (!errors.empty) {
            println("Parse errors:")
            errors.forEach[println("  " + it.message)]
            fail("Model has parse errors")
        }
        
        assertNotNull(model)
        assertEquals(1, model.packages.size)
        
        val pkg = model.packages.get(0)
        assertEquals("com.example", pkg.name)
        assertEquals(1, pkg.types.size)
        
        // Test generation
        generator.doGenerate(model.eResource, fsa, context)
        
        assertTrue(fsa.allFiles.containsKey("DEFAULT_OUTPUTgenerated/include/com.example/Data.h"))
    }
    
    @Test
    def void testComplexModel() {
        val modelText = '''
            define BasicTypes {
                type uint32
                    category value
                    length 32
                type String
                    category string
            }
            
            package com.test {
                public struct Message {
                    uint32 id
                    String content
                }
                
                public enumeration Type {
                    REQUEST = 0,
                    RESPONSE = 1
                }
            }
            
            public struct GlobalStruct {
                uint32 field
            }
            
            public enumeration GlobalEnum {
                VALUE1 = 0,
                VALUE2 = 1
            }
        '''
        
        println("Testing complex model")
        val model = parseHelper.parse(modelText)
        
        if (model === null) {
            fail("Model parsing returned null")
        }
        
        val errors = model.eResource.errors
        if (!errors.empty) {
            println("Parse errors:")
            errors.forEach[println("  " + it.message)]
            fail("Model has parse errors")
        }
        
        assertNotNull(model)
        
        // Check primitive definitions
        assertEquals(1, model.primitiveDefinitions.size)
        
        // Check packages
        assertEquals(1, model.packages.size)
        val pkg = model.packages.get(0)
        assertEquals("com.test", pkg.name)
        assertEquals(2, pkg.types.size)
        
        // Check global types
        assertEquals(2, model.types.size)
        
        // Verify struct
        val globalStruct = model.types.findFirst[it instanceof FStructType] as FStructType
        assertNotNull(globalStruct)
        assertEquals("GlobalStruct", globalStruct.name)
        
        // Verify enum
        val globalEnum = model.types.findFirst[it instanceof FEnumerationType] as FEnumerationType
        assertNotNull(globalEnum)
        assertEquals("GlobalEnum", globalEnum.name)
    }
    
    @Test
    def void testInheritance() {
        val modelText = '''
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
        
        println("Testing inheritance")
        val model = parseHelper.parse(modelText)
        
        if (model === null) {
            fail("Model parsing returned null")
        }
        
        val errors = model.eResource.errors
        if (!errors.empty) {
            println("Parse errors:")
            errors.forEach[println("  " + it.message)]
            fail("Model has parse errors")
        }
        
        assertNotNull(model)
        assertEquals(2, model.types.size)
        
        val derived = model.types.findFirst[
            it instanceof FStructType && (it as FStructType).name == "Derived"
        ] as FStructType
        assertNotNull(derived)
        assertNotNull(derived.base)
        assertEquals("Base", derived.base.name)
    }
    
    @Test
    def void testArrayType() {
        val modelText = '''
            define BasicTypes {
                type uint8
                    category value
                    length 8
                type float32
                    category value
                    length 32
            }
            
            public struct Data {
                uint8[10] buffer
                float32[3] coordinates
            }
        '''
        
        println("Testing array type")
        val model = parseHelper.parse(modelText)
        
        if (model === null) {
            fail("Model parsing returned null")
        }
        
        val errors = model.eResource.errors
        if (!errors.empty) {
            println("Parse errors:")
            errors.forEach[println("  " + it.message)]
            fail("Model has parse errors")
        }
        
        assertNotNull(model)
        assertEquals(1, model.types.size)
        
        val struct = model.types.get(0) as FStructType
        assertEquals(2, struct.elements.size)
        
        val bufferField = struct.elements.get(0)
        assertTrue(bufferField.array)
        assertEquals(10, bufferField.size)
        
        val coordField = struct.elements.get(1)
        assertTrue(coordField.array)
        assertEquals(3, coordField.size)
    }
    
    @Test
    def void testTypedef() {
        val modelText = '''
            define BasicTypes {
                type String
                    category string
            }
            
            public typedef UUID is String
        '''
        
        println("Testing typedef")
        val model = parseHelper.parse(modelText)
        
        if (model === null) {
            fail("Model parsing returned null")
        }
        
        val errors = model.eResource.errors
        if (!errors.empty) {
            println("Parse errors:")
            errors.forEach[println("  " + it.message)]
            fail("Model has parse errors")
        }
        
        assertNotNull(model)
        assertEquals(1, model.types.size)
        
        val typedef = model.types.get(0) as FTypeDef
        assertEquals("UUID", typedef.name)
    }
    
    @Test
    def void testArrayDeclaration() {
        val modelText = '''
            define BasicTypes {
                type float32
                    category value
                    length 32
            }
            
            public struct Point {
                float32 x
                float32 y
            }
            
            public array PointArray of Point
        '''
        
        println("Testing array declaration")
        val model = parseHelper.parse(modelText)
        
        if (model === null) {
            fail("Model parsing returned null")
        }
        
        val errors = model.eResource.errors
        if (!errors.empty) {
            println("Parse errors:")
            errors.forEach[println("  " + it.message)]
            fail("Model has parse errors")
        }
        
        assertNotNull(model)
        assertEquals(2, model.types.size)
        
        // Find the array type
        val arrayType = model.types.findFirst[it instanceof FArrayType] as FArrayType
        assertNotNull(arrayType)
        assertEquals("PointArray", arrayType.name)
    }
    
    @Test
    def void testAnnotations() {
        // Try without spaces in annotations first
        val modelText = '''
            define BasicTypes {
                type uint32
                    category value
                    length 32
            }
            
            <**StructComment**>
            public struct Annotated {
                <**FieldComment**>
                uint32 field
            }
        '''
        
        println("Testing annotations")
        val model = parseHelper.parse(modelText)
        
        if (model === null) {
            fail("Model parsing returned null")
        }
        
        val errors = model.eResource.errors
        if (!errors.empty) {
            println("Parse errors:")
            errors.forEach[println("  " + it.message)]
            fail("Model has parse errors")
        }
        
        assertNotNull(model)
        assertEquals(1, model.types.size)
        
        val struct = model.types.get(0) as FStructType
        assertNotNull(struct.comment)
        assertEquals(1, struct.comment.elements.size)
        assertEquals("StructComment", struct.comment.elements.get(0).rawText)
        
        val field = struct.elements.get(0)
        assertNotNull(field.comment)
        assertEquals(1, field.comment.elements.size)
        assertEquals("FieldComment", field.comment.elements.get(0).rawText)
    }
    
    @Test
    def void testEnumWithoutValues() {
        val modelText = '''
            public enumeration SimpleEnum {
                FIRST,
                SECOND,
                THIRD
            }
        '''
        
        println("Testing enum without values")
        val model = parseHelper.parse(modelText)
        
        if (model === null) {
            fail("Model parsing returned null")
        }
        
        val errors = model.eResource.errors
        if (!errors.empty) {
            println("Parse errors:")
            errors.forEach[println("  " + it.message)]
            fail("Model has parse errors")
        }
        
        assertNotNull(model)
        assertEquals(1, model.types.size)
        
        val enumType = model.types.get(0) as FEnumerationType
        assertEquals(3, enumType.enumerators.size)
    }
    
    @Test
    def void testFieldWithInitializer() {
        val modelText = '''
            define BasicTypes {
                type uint32
                    category value
                    length 32
                type String
                    category string
            }
            
            public struct Config {
                uint32 { init 42 } defaultValue
                String { init "hello" } greeting
            }
        '''
        
        println("Testing field with initializer")
        val model = parseHelper.parse(modelText)
        
        if (model === null) {
            fail("Model parsing returned null")
        }
        
        val errors = model.eResource.errors
        if (!errors.empty) {
            println("Parse errors:")
            errors.forEach[println("  " + it.message)]
            fail("Model has parse errors")
        }
        
        assertNotNull(model)
        assertEquals(1, model.types.size)
        
        val struct = model.types.get(0) as FStructType
        assertEquals(2, struct.elements.size)
        
        val field1 = struct.elements.get(0)
        assertNotNull(field1.type.value)
        
        val field2 = struct.elements.get(1)
        assertNotNull(field2.type.value)
    }
    
    @Test
    def void testMultiplePackages() {
        val modelText = '''
            define BasicTypes {
                type uint32
                    category value
                    length 32
            }
            
            package com.example.model {
                public struct ModelData {
                    uint32 id
                }
            }
            
            package com.example.service {
                public struct ServiceData {
                    uint32 serviceId
                }
            }
        '''
        
        println("Testing multiple packages")
        val model = parseHelper.parse(modelText)
        
        if (model === null) {
            fail("Model parsing returned null")
        }
        
        val errors = model.eResource.errors
        if (!errors.empty) {
            println("Parse errors:")
            errors.forEach[println("  " + it.message)]
            fail("Model has parse errors")
        }
        
        assertNotNull(model)
        assertEquals(2, model.packages.size)
        
        val pkg1 = model.packages.get(0)
        assertEquals("com.example.model", pkg1.name)
        assertEquals(1, pkg1.types.size)
        
        val pkg2 = model.packages.get(1)
        assertEquals("com.example.service", pkg2.name)
        assertEquals(1, pkg2.types.size)
    }
}
