# MyDsl Xtext Project Architecture Design Document

## 1. Executive Summary

This document describes the architecture of the MyDsl Xtext project, a Domain Specific Language (DSL) implementation for defining data types with automatic code generation capabilities for C++ and Protocol Buffers. The project uses Maven for build management, Xtext for DSL implementation, and Xtend for code generation.

## 2. System Overview

### 2.1 High-Level Architecture

```mermaid
graph TB
    subgraph "Input Layer"
        DSL[DSL Files<br/>.mydsl]
        Templates[Template Files<br/>.template]
    end
    
    subgraph "Processing Layer"
        Parser[Xtext Parser]
        Model[EMF Model]
        Generators[Code Generators]
    end
    
    subgraph "Output Layer"
        CPP[C++ Headers<br/>.h files]
        Proto[Protobuf Files<br/>.proto]
        Binary[Binary Descriptors<br/>.desc]
    end
    
    DSL --> Parser
    Parser --> Model
    Model --> Generators
    Templates --> Generators
    Generators --> CPP
    Generators --> Proto
    Generators --> Binary
```

### 2.2 Module Dependencies

```mermaid
graph TD
    Parent[org.xtext.example.mydsl.parent<br/>Parent POM]
    Core[org.xtext.example.mydsl<br/>Core Language & Generators]
    Tests[org.xtext.example.mydsl.tests<br/>Test Suite]
    IDE[org.xtext.example.mydsl.ide<br/>IDE Support]
    UI[org.xtext.example.mydsl.ui<br/>Eclipse UI]
    UITests[org.xtext.example.mydsl.ui.tests<br/>UI Tests]
    Target[org.xtext.example.mydsl.target<br/>Target Platform]
    Standalone[org.xtext.example.mydsl.standalone<br/>CLI Tool]
    Coverage[jacoco-aggregate-report<br/>Coverage Aggregation]
    
    Parent --> Core
    Parent --> Tests
    Parent --> IDE
    Parent --> UI
    Parent --> UITests
    Parent --> Target
    Parent --> Standalone
    Parent --> Coverage
    
    Tests -.->|depends on| Core
    IDE -.->|depends on| Core
    UI -.->|depends on| Core
    UI -.->|depends on| IDE
    UITests -.->|depends on| UI
    Standalone -.->|depends on| Core
    Coverage -.->|aggregates| Tests
    Coverage -.->|aggregates| Core
```

## 3. Core Module Architecture

### 3.1 Generator Components

```mermaid
classDiagram
    class MyDslGenerator {
        -boolean generateCpp
        -boolean generateProtobuf
        -boolean generateBinaryDescriptor
        +doGenerate(Resource, IFileSystemAccess2, IGeneratorContext)
        +setGenerationOptions(boolean, boolean, boolean)
    }
    
    class DataTypeGenerator {
        -TemplateLoader templateLoader
        -String OUTPUT_PATH
        +generate(Model, IFileSystemAccess2)
        +generateTypesHeader(Model, IFileSystemAccess2)
        +generateTypeHeader(FType, Model, IFileSystemAccess2)
        +generateStructWithTemplate(FStructType, Model)
        +generateEnumWithTemplate(FEnumerationType)
        +generateArrayWithTemplate(FArrayType, Model)
        +generateTypeDefWithTemplate(FTypeDef, Model)
    }
    
    class ProtobufGenerator {
        -TemplateLoader templateLoader
        -Map fieldNumberCounter
        -Set imports
        +generate(Model, IFileSystemAccess2, boolean)
        +generateProtoFileWithTemplate(Model)
        +generatePackageProtoFileWithTemplate(Package, Model)
        +generateDescriptorSet(Model)
        +writeBinaryDescriptor(IFileSystemAccess2, String, byte[])
    }
    
    class TemplateLoader {
        -Map templateCache
        -boolean cacheEnabled
        -String templateBasePath
        +loadTemplate(String)
        +processTemplate(String, Map)
        +templateExists(String)
        +clearCache()
    }
    
    MyDslGenerator --> DataTypeGenerator : uses
    MyDslGenerator --> ProtobufGenerator : uses
    MyDslGenerator --> TemplateLoader : uses
    DataTypeGenerator --> TemplateLoader : uses
    ProtobufGenerator --> TemplateLoader : uses
```

### 3.2 DSL Model Structure

```mermaid
classDiagram
    class Model {
        +List~PrimitiveDefinition~ primitiveDefinitions
        +List~Package~ packages
        +List~FType~ types
    }
    
    class FType {
        <<abstract>>
        +String name
        +FAnnotationBlock comment
    }
    
    class FStructType {
        +FStructType base
        +List~FField~ elements
    }
    
    class FEnumerationType {
        +FBasicTypeId base
        +List~FEnumerator~ enumerators
    }
    
    class FArrayType {
        +FTypeRef elementType
    }
    
    class FTypeDef {
        +FTypeRef actualType
    }
    
    class FField {
        +String name
        +FTypeRef type
        +boolean array
        +int size
        +FAnnotationBlock comment
    }
    
    Model --> FType : contains
    Model --> Package : contains
    FType <|-- FStructType
    FType <|-- FEnumerationType
    FType <|-- FArrayType
    FType <|-- FTypeDef
    FStructType --> FField : contains
    FStructType --> FStructType : extends
```

## 4. Test Architecture

### 4.1 Test Suite Organization

```mermaid
graph TD
    subgraph "Test Configuration"
        Config[TestConfiguration<br/>Central test suite definitions]
        Manager[TestSuiteManager<br/>Suite execution controller]
    end
    
    subgraph "Test Suites"
        Unit[Unit Tests<br/>TemplateLoaderTest]
        Integration[Integration Tests<br/>GeneratorTest]
        Parsing[Parsing Tests<br/>MyDslParsingTest]
        Smoke[Smoke Tests<br/>Quick validation]
        All[All Tests<br/>Complete suite]
    end
    
    subgraph "Test Runners"
        Maven[Maven/Tycho<br/>Plugin execution]
        Standalone[StandaloneTestRunner<br/>Direct JUnit execution]
        BuildScript[build-and-test.sh<br/>Shell automation]
    end
    
    Config --> Manager
    Manager --> Unit
    Manager --> Integration
    Manager --> Parsing
    Manager --> Smoke
    Manager --> All
    
    BuildScript --> Manager
    Maven --> Manager
    Standalone --> Manager
```

### 4.2 Test Execution Flow

```mermaid
sequenceDiagram
    participant User
    participant BuildScript as build-and-test.sh
    participant Maven
    participant TestConfig as TestConfiguration
    participant TestSuite as Test Suite
    participant JaCoCo
    participant Reports
    
    User->>BuildScript: ./build-and-test.sh --suite integration
    BuildScript->>Maven: Check prerequisites
    BuildScript->>TestConfig: Get test pattern for suite
    TestConfig-->>BuildScript: Return pattern (e.g., "**/Generator*Test")
    BuildScript->>Maven: mvn verify -Dtest=pattern
    Maven->>JaCoCo: Instrument classes
    Maven->>TestSuite: Execute tests
    TestSuite-->>Maven: Test results
    Maven->>JaCoCo: Collect coverage data
    JaCoCo->>Reports: Generate coverage report
    Maven->>Reports: Generate surefire report
    BuildScript->>Reports: Archive and display
    Reports-->>User: Open in browser
```

## 5. Build System Architecture

### 5.1 Build Pipeline

```mermaid
graph LR
    subgraph "Build Phases"
        Clean[Clean<br/>Remove artifacts]
        Generate[Generate Sources<br/>MWE2 & Xtend]
        Compile[Compile<br/>Java & Xtend]
        Test[Test<br/>Execute tests]
        Package[Package<br/>Create JARs]
        Install[Install<br/>Local repository]
        Verify[Verify<br/>Coverage & reports]
    end
    
    Clean --> Generate
    Generate --> Compile
    Compile --> Test
    Test --> Package
    Package --> Install
    Install --> Verify
```

### 5.2 Maven Profile Structure

```mermaid
graph TD
    subgraph "Maven Profiles"
        Default[Default Profile<br/>Standard build]
        Coverage[Coverage Profile<br/>JaCoCo instrumentation]
        MacOS[MacOS Profile<br/>Platform-specific settings]
        JDK9[JDK9+ Profile<br/>Module system support]
    end
    
    subgraph "Activation"
        Manual[Manual Activation<br/>-Pcoverage]
        OSDetect[OS Detection<br/>Automatic]
        JDKDetect[JDK Detection<br/>Automatic]
    end
    
    Manual --> Coverage
    OSDetect --> MacOS
    JDKDetect --> JDK9
```

## 6. Code Generation Process

### 6.1 Template Processing Pipeline

```mermaid
flowchart TD
    Start([Model Input])
    LoadTemplate[Load Template File]
    Cache{Cache<br/>Enabled?}
    CheckCache{In Cache?}
    ReadFile[Read from Filesystem]
    ProcessVars[Replace Variables]
    Generate[Generate Output]
    Write[Write to FileSystem]
    
    Start --> LoadTemplate
    LoadTemplate --> Cache
    Cache -->|Yes| CheckCache
    Cache -->|No| ReadFile
    CheckCache -->|Yes| ProcessVars
    CheckCache -->|No| ReadFile
    ReadFile --> ProcessVars
    ProcessVars --> Generate
    Generate --> Write
```

### 6.2 Type Mapping Strategy

```mermaid
graph TD
    subgraph "DSL Types"
        DSLBasic[Basic Types<br/>uint32, String, etc.]
        DSLStruct[Struct Types]
        DSLEnum[Enum Types]
        DSLArray[Array Types]
        DSLTypedef[Typedef]
    end
    
    subgraph "C++ Mapping"
        CPPBasic[C++ Types<br/>uint32_t, std::string]
        CPPStruct[C++ Structs]
        CPPEnum[C++ Enum Classes]
        CPPVector[std::vector]
        CPPUsing[using declarations]
    end
    
    subgraph "Protobuf Mapping"
        ProtoBasic[Proto Types<br/>uint32, string]
        ProtoMessage[Proto Messages]
        ProtoEnum[Proto Enums]
        ProtoRepeated[repeated fields]
        ProtoAlias[Comments/Documentation]
    end
    
    DSLBasic --> CPPBasic
    DSLBasic --> ProtoBasic
    DSLStruct --> CPPStruct
    DSLStruct --> ProtoMessage
    DSLEnum --> CPPEnum
    DSLEnum --> ProtoEnum
    DSLArray --> CPPVector
    DSLArray --> ProtoRepeated
    DSLTypedef --> CPPUsing
    DSLTypedef --> ProtoAlias
```

## 7. Coverage Architecture

### 7.1 Coverage Collection Flow

```mermaid
flowchart LR
    subgraph "Test Execution"
        XtendTests[Xtend Tests]
        JavaTests[Java Tests]
    end
    
    subgraph "JaCoCo Agent"
        Instrument[Bytecode<br/>Instrumentation]
        Collect[Coverage<br/>Collection]
    end
    
    subgraph "Coverage Data"
        ExecFile[jacoco.exec<br/>Binary data]
        SourceMap[Source<br/>Mapping]
    end
    
    subgraph "Reports"
        ModuleReport[Module<br/>Report]
        AggregateReport[Aggregate<br/>Report]
        HTMLReport[HTML<br/>Output]
    end
    
    XtendTests --> Instrument
    JavaTests --> Instrument
    Instrument --> Collect
    Collect --> ExecFile
    ExecFile --> SourceMap
    SourceMap --> ModuleReport
    ModuleReport --> AggregateReport
    AggregateReport --> HTMLReport
```

### 7.2 Cross-Module Coverage Aggregation

```mermaid
graph TD
    subgraph "Module Coverage Files"
        Core[org.xtext.example.mydsl<br/>jacoco.exec]
        Tests[org.xtext.example.mydsl.tests<br/>jacoco.exec]
        IDE[org.xtext.example.mydsl.ide<br/>jacoco.exec]
    end
    
    subgraph "Aggregation Module"
        Merge[Merge Execution Data]
        MapSources[Map Source Files]
        MapClasses[Map Class Files]
        GenerateReport[Generate Aggregate Report]
    end
    
    Core --> Merge
    Tests --> Merge
    IDE --> Merge
    Merge --> MapSources
    MapSources --> MapClasses
    MapClasses --> GenerateReport
    GenerateReport --> Report[Aggregate Coverage Report<br/>HTML/XML/CSV]
```

## 8. File System Organization

### 8.1 Project Directory Structure

```mermaid
graph TD
    Root[Project Root]
    Parent[org.xtext.example.mydsl.parent]
    Core[org.xtext.example.mydsl]
    Tests[org.xtext.example.mydsl.tests]
    
    subgraph "Core Module Structure"
        CoreSrc[src/<br/>Grammar & Workflows]
        CoreSrcGen[src-gen/<br/>Generated Parser]
        CoreXtendGen[xtend-gen/<br/>Java from Xtend]
        CoreTarget[target/<br/>Build output]
        CoreLib[lib/<br/>Protobuf JAR]
    end
    
    subgraph "Test Module Structure"
        TestSrc[src/<br/>Test sources]
        TestXtendGen[xtend-gen/<br/>Generated tests]
        TestTarget[target/<br/>Test results]
        TestReports[target/site/<br/>Test reports]
    end
    
    Root --> Parent
    Root --> Core
    Root --> Tests
    Core --> CoreSrc
    Core --> CoreSrcGen
    Core --> CoreXtendGen
    Core --> CoreTarget
    Core --> CoreLib
    Tests --> TestSrc
    Tests --> TestXtendGen
    Tests --> TestTarget
    Tests --> TestReports
```

## 9. Deployment Architecture

### 9.1 Standalone Deployment

```mermaid
flowchart TD
    subgraph "Build Artifacts"
        CoreJar[mydsl.jar<br/>Core functionality]
        StandaloneJar[standalone-jar-with-dependencies.jar<br/>Executable JAR]
        Templates[Template Files]
    end
    
    subgraph "Runtime Dependencies"
        Xtext[Xtext Runtime]
        EMF[EMF Libraries]
        Protobuf[Protobuf Java]
        Guice[Google Guice]
    end
    
    subgraph "Execution"
        CLI[Command Line<br/>Interface]
        FileInput[.mydsl Files]
        FileOutput[Generated Code]
    end
    
    CoreJar --> StandaloneJar
    Xtext --> StandaloneJar
    EMF --> StandaloneJar
    Protobuf --> StandaloneJar
    Guice --> StandaloneJar
    Templates --> StandaloneJar
    
    CLI --> StandaloneJar
    FileInput --> StandaloneJar
    StandaloneJar --> FileOutput
```

## 10. Error Handling and Recovery

### 10.1 Error Handling Strategy

```mermaid
stateDiagram-v2
    [*] --> ParseDSL
    ParseDSL --> CheckErrors: Parse Complete
    
    CheckErrors --> ModelValid: No Errors
    CheckErrors --> ReportParseErrors: Has Errors
    
    ModelValid --> LoadTemplates
    LoadTemplates --> TemplatesLoaded: Success
    LoadTemplates --> UseDefaults: Template Missing
    
    TemplatesLoaded --> GenerateCode
    UseDefaults --> GenerateCode
    
    GenerateCode --> WriteFiles: Success
    GenerateCode --> HandleGenError: Generation Error
    
    HandleGenError --> PartialOutput: Recoverable
    HandleGenError --> Abort: Fatal
    
    WriteFiles --> [*]: Success
    PartialOutput --> [*]: Partial Success
    ReportParseErrors --> [*]: Failed
    Abort --> [*]: Failed
```

## 11. Template System Architecture

### 11.1 Template Resolution Strategy

```mermaid
flowchart TD
    Request["Template Request<br/>cpp/header.template"]
    
    CheckClasspath{Check<br/>Classpath}
    CheckFilesystem{Check<br/>Filesystem}
    CheckBasePath{Check with<br/>Base Path}
    
    LoadClasspath[Load from<br/>Classpath]
    LoadFilesystem[Load from<br/>Filesystem]
    LoadBasePath[Load from<br/>Base Path]
    
    Cache[Store in<br/>Cache]
    ReturnEmpty[Return<br/>Empty String]
    Process[Process<br/>Variables]
    
    Request --> CheckClasspath
    CheckClasspath -->|Found| LoadClasspath
    CheckClasspath -->|Not Found| CheckFilesystem
    CheckFilesystem -->|Found| LoadFilesystem
    CheckFilesystem -->|Not Found| CheckBasePath
    CheckBasePath -->|Found| LoadBasePath
    CheckBasePath -->|Not Found| ReturnEmpty
    
    LoadClasspath --> Cache
    LoadFilesystem --> Cache
    LoadBasePath --> Cache
    Cache --> Process
```

## 12. Key Design Patterns

### 12.1 Design Patterns Used

| Pattern             | Usage                            | Components                                           |
| ------------------- | -------------------------------- | ---------------------------------------------------- |
| **Singleton**       | Template loader, generators      | `@Singleton` annotation on generator classes         |
| **Template Method** | Code generation process          | Abstract generation methods overridden for each type |
| **Strategy**        | Type mapping                     | Different strategies for C++ vs Protobuf mapping     |
| **Builder**         | Protobuf descriptor construction | `FileDescriptorProto.Builder`                        |
| **Factory**         | Test suite creation              | `TestConfiguration` creates test suites              |
| **Visitor**         | Model traversal                  | EMF model navigation                                 |
| **Cache**           | Template caching                 | `TemplateLoader` cache mechanism                     |
| **Command**         | Build script operations          | Shell script command processing                      |

## 13. Performance Considerations

### 13.1 Optimization Strategies

- **Parallel Build**: Maven uses `-T 12` for parallel module builds
- **Template Caching**: Templates cached in memory to avoid repeated I/O
- **Lazy Loading**: Cross-references resolved only when needed
- **Incremental Build**: Only modified files recompiled
- **Test Filtering**: Selective test execution based on suites

## 14. Security Considerations

### 14.1 Security Measures

- **Input Validation**: DSL parser validates input syntax
- **Path Traversal Prevention**: Template paths sanitized
- **Binary File Handling**: Secure writing of binary descriptor files
- **Dependency Management**: Fixed versions for all dependencies
- **Code Injection Prevention**: Template variable replacement sanitized

## 15. Extensibility Points

### 15.1 Extension Mechanisms

```mermaid
graph TD
    subgraph "Extension Points"
        NewGenerators[New Code Generators]
        NewTypes[New DSL Types]
        NewTemplates[New Templates]
        NewTests[New Test Suites]
    end
    
    subgraph "Extension Process"
        Implement[Implement Interface]
        Register[Register with Guice]
        Configure[Configure in Grammar]
        Deploy[Deploy Module]
    end
    
    NewGenerators --> Implement
    NewTypes --> Configure
    NewTemplates --> Deploy
    NewTests --> Register
    
    Implement --> Deploy
    Register --> Deploy
    Configure --> Deploy
```

## 16. Conclusions

The MyDsl Xtext project demonstrates a well-architected DSL implementation with:

- **Modular Design**: Clear separation of concerns across modules
- **Extensible Generation**: Template-based code generation for multiple targets
- **Comprehensive Testing**: Multi-level test suite architecture with coverage
- **Build Automation**: Sophisticated build pipeline with Maven and shell scripting
- **Error Resilience**: Graceful error handling and partial output generation
- **Performance Optimization**: Caching, parallel builds, and incremental compilation

The architecture supports both IDE integration (Eclipse) and standalone command-line usage, making it suitable for various deployment scenarios.