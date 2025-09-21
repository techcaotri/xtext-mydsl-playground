package org.xtext.example.mydsl.tests

import com.google.inject.Inject
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.extensions.InjectionExtension
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Tag
import org.junit.jupiter.api.Tags  
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.^extension.ExtendWith
import org.xtext.example.mydsl.myDsl.Model

import static org.junit.jupiter.api.Assertions.*

@ExtendWith(InjectionExtension)
@InjectWith(MyDslInjectorProvider)
@DisplayName("DSL Parsing Tests")
@Tags(#[@Tag("unit"), @Tag("smoke"), @Tag("fast"), @Tag("parsing")])
class MyDslParsingTest {
    @Inject
    ParseHelper<Model> parseHelper
    
    @Test
    @Tag("basic")
    @Tag("quick")
    @DisplayName("Should parse basic model")
    def void loadModel() {
        val result = parseHelper.parse('''
            Hello Xtext!
        ''')
        assertNotNull(result)
        val errors = result.eResource.errors
        assertTrue(errors.isEmpty, '''Unexpected errors: «errors.join(", ")»''')
    }
    
    @Test
    @Tag("validation")
    @DisplayName("Should validate model structure")
    def void validateModelStructure() {
        val result = parseHelper.parse('''
            define BasicTypes {
                type uint32
                    category value
                    length 32
            }
            
            public struct TestStruct {
                uint32 field
            }
        ''')
        assertNotNull(result)
        assertTrue(result.eResource.errors.isEmpty)
    }
}
