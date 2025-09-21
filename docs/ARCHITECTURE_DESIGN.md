# System Architecture and Design

## Table of Contents
- [Project Overview](#project-overview)
- [Module Architecture](#module-architecture)
- [Build System Architecture](#build-system-architecture)
- [Test System Architecture](#test-system-architecture)
- [Code Generation Architecture](#code-generation-architecture)
- [Coverage Analysis Flow](#coverage-analysis-flow)
- [Deployment View](#deployment-view)

## Project Overview

The MyDsl Xtext project is a domain-specific language (DSL) implementation that generates C++ and Protobuf code from high-level type definitions. The system uses a multi-module Maven architecture with Tycho for Eclipse plugin development.

### High-Level Architecture

```mermaid
graph TB
    subgraph "Development Environment"
        IDE[IDE/Editor]
        CLI[Command Line]
    end
    
    subgraph "MyDsl System"
        DSL[DSL Files<br/>.mydsl]
        Parser[Xtext Parser]
        Model[EMF Model]
        Gen[Code Generators]
        Out[Generated Code]
    end
    
    subgraph "Output Artifacts"
        CPP[C++ Headers]
        PROTO[Protobuf Files]
        DESC[Binary Descriptors]
    end
    
    IDE --> DSL
    CLI --> DSL
    DSL --> Parser
    Parser --> Model
    Model --> Gen
    Gen --> CPP
    Gen --> PROTO
    Gen --> DESC
    
    style DSL fill:#e1f5fe
    style Model fill:#fff3e0
    style Gen fill:#f3e5f5
    style CPP fill:#e8f5e9
    style PROTO fill:#e8f5e9
    style DESC fill:#e8f5e9
```

## Module Architecture

### Project Structure

```mermaid
graph TD
    subgraph "Parent POM"
        Parent[org.xtext.example.mydsl.parent<br/>Aggregator POM]
    end
    
    subgraph "Core Modules"
        Main[org.xtext.example.mydsl<br/>Main DSL Implementation]
        Tests[org.xtext.example.mydsl.tests<br/>Test Suite]
        Target[org.xtext.example.mydsl.target<br/>Target Platform]
    end
    
    subgraph "UI Modules"
        IDE[org.xtext.example.mydsl.ide<br/>IDE Support]
        UI[org.xtext.example.mydsl.ui<br/>Eclipse UI]
        UITests[org.xtext.example.mydsl.ui.tests<br/>UI Tests]
    end
    
    subgraph "Additional Modules"
        Standalone[org.xtext.example.mydsl.standalone<br/>CLI Runner]
        Coverage[jacoco-aggregate-report<br/>Coverage Aggregator]
    end
    
    Parent --> Main
    Parent --> Tests
    Parent --> Target
    Parent --> IDE
    Parent --> UI
    Parent --> UITests
    Parent --> Standalone
    Parent --> Coverage
    
    Tests -.depends on.-> Main
    IDE -.depends on.-> Main
    UI -.depends on.-> IDE
    UI -.depends on.-> Main
    UITests -.depends on.-> UI
    Standalone -.depends on.-> Main
    Coverage -.aggregates.-> Tests
    Coverage -.aggregates.-> Main
    
    style Parent fill:#fff9c4
    style Main fill:#c5e1a5
    style Tests fill:#ffccbc
    style Coverage fill:#d1c4e9
```

### Module Dependencies

```mermaid
graph LR
    subgraph "External Dependencies"
        Xtext[Xtext 2.39.0]
        EMF[EMF/Ecore]
        Protobuf[Protobuf 3.21.12]
        JUnit5[JUnit 5.10.0]
        JaCoCo[JaCoCo 0.8.11]
    end
    
    subgraph "Main Module"
        Grammar[MyDsl.xtext]
        Generator[Generators]
        Templates[Templates]
    end
    
    subgraph "Test Module"
        TestConfig[TestConfiguration]
        TestSuites[Test Suites]
        TestClasses[Test Classes]
    end
    
    Grammar --> Xtext
    Generator --> EMF
    Generator --> Protobuf
    Templates --> Generator
    
    TestConfig --> TestSuites
    TestSuites --> TestClasses
    TestClasses --> JUnit5
    TestClasses --> Generator
    TestClasses --> JaCoCo
    
    style Xtext fill:#e3f2fd
    style EMF fill:#e3f2fd
    style Protobuf fill:#e3f2fd
    style JUnit5 fill:#e3f2fd
    style JaCoCo fill:#e3f2fd
```

## Build System Architecture

### Maven/Tycho Build Flow

```mermaid
flowchart TD
    Start([Build Start])
    Clean[Clean Phase<br/>mvn clean]
    Target[Build Target Platform]
    MWE2[Run MWE2 Workflow<br/>Generate Xtext Artifacts]
    Xtend[Compile Xtend<br/>xtend-maven-plugin]
    Java[Compile Java<br/>maven-compiler-plugin]
    Package[Package Modules<br/>tycho-packaging-plugin]
    Test[Run Tests<br/>tycho-surefire-plugin]
    Coverage[Generate Coverage<br/>jacoco-maven-plugin]
    Site[Generate Site<br/>maven-site-plugin]
    End([Build Complete])
    
    Start --> Clean
    Clean --> Target
    Target --> MWE2
    MWE2 --> Xtend
    Xtend --> Java
    Java --> Package
    Package --> Test
    Test --> Coverage
    Coverage --> Site
    Site --> End
    
    style Start fill:#e8f5e9
    style End fill:#e8f5e9
    style Test fill:#fff3e0
    style Coverage fill:#f3e5f5
```

### Build Script Execution Flow

```mermaid
flowchart LR
    subgraph "build-and-test.sh"
        ParseArgs[Parse Arguments]
        CheckMaven[Check Maven/Java]
        ConfigTest[Load Test Config]
        CleanPhase{Clean?}
        BuildPhase{Build?}
        TestPhase{Test?}
        ReportGen[Generate Reports]
        Archive[Archive Results]
    end
    
    subgraph "Test Configuration"
        TestConfig[TestConfiguration.xtend]
        SuiteMgr[TestSuiteManager]
    end
    
    ParseArgs --> CheckMaven
    CheckMaven --> ConfigTest
    ConfigTest --> CleanPhase
    CleanPhase -->|Yes| BuildPhase
    CleanPhase -->|No| BuildPhase
    BuildPhase -->|Yes| TestPhase
    BuildPhase -->|Skip| TestPhase
    TestPhase -->|Run| ReportGen
    TestPhase -->|Skip| Archive
    ReportGen --> Archive
    
    ConfigTest -.reads.-> TestConfig
    ConfigTest -.uses.-> SuiteMgr
    TestPhase -.queries.-> TestConfig
    
    style ParseArgs fill:#e1f5fe
    style TestConfig fill:#fff9c4
    style ReportGen fill:#f3e5f5
```

## Test System Architecture

### Test Execution Flow

```mermaid
sequenceDiagram
    participant User
    participant Script as build-and-test.sh
    participant TestMgr as TestSuiteManager
    participant Config as TestConfiguration
    participant Maven
    participant Surefire as Tycho Surefire
    participant JaCoCo
    
    User->>Script: ./build-and-test.sh --suite unit
    Script->>TestMgr: get-pattern "unit"
    TestMgr->>Config: getSuite("unit")
    Config-->>TestMgr: TestSuite object
    TestMgr-->>Script: "**/TemplateLoader*Test"
    
    Script->>Maven: mvn verify -Dtest="pattern"
    Maven->>JaCoCo: prepare-agent
    JaCoCo-->>Maven: tycho.testArgLine
    Maven->>Surefire: execute tests
    Surefire->>Surefire: run matching tests
    Surefire-->>Maven: test results
    Maven->>JaCoCo: generate report
    JaCoCo-->>Maven: coverage data
    Maven-->>Script: execution complete
    
    Script->>Script: generate summary
    Script-->>User: reports location
```

### Test Suite Configuration Architecture

```mermaid
classDiagram
    class TestConfiguration {
        -Map~String,TestSuite~ SUITES
        +getSuite(name) TestSuite
        +getMavenPattern(name) String
        +getTestClasses(name) List
        +exportAsProperties() void
    }
    
    class TestSuite {
        +String name
        +String displayName
        +String description
        +List~Class~ testClasses
        +String mavenPattern
        +List~String~ tags
    }
    
    class TestSuiteManager {
        +main(args) void
        +listSuites() void
        +describeSuite(name) void
        +getPattern(name) String
    }
    
    class GeneratorTest {
        +testStructGeneration()
        +testEnumGeneration()
        +testPackageGeneration()
        +testComplexModel()
    }
    
    class TemplateLoaderTest {
        +testLoadTemplate()
        +testCaching()
        +testVariables()
    }
    
    class MyDslParsingTest {
        +loadModel()
        +validateStructure()
    }
    
    TestConfiguration "1" *-- "*" TestSuite : contains
    TestSuite "1" o-- "*" GeneratorTest : includes
    TestSuite "1" o-- "*" TemplateLoaderTest : includes
    TestSuite "1" o-- "*" MyDslParsingTest : includes
    TestSuiteManager ..> TestConfiguration : uses
```

## Code Generation Architecture

### Generator Components

```mermaid
graph TB
    subgraph "Input Layer"
        DSLFile[.mydsl File]
        Parser[Xtext Parser]
    end
    
    subgraph "Model Layer"
        EMFModel[EMF Model]
        Model[Model<br/>Types, Packages]
    end
    
    subgraph "Generator Layer"
        MyDslGen[MyDslGenerator<br/>Orchestrator]
        DataTypeGen[DataTypeGenerator<br/>C++ Generation]
        ProtoGen[ProtobufGenerator<br/>Proto Generation]
        TmplLoader[TemplateLoader<br/>Template Engine]
    end
    
    subgraph "Template Layer"
        CppTmpl[C++ Templates]
        ProtoTmpl[Proto Templates]
        CmakeTmpl[CMake Templates]
    end
    
    subgraph "Output Layer"
        FSA[IFileSystemAccess2]
        Files[Generated Files]
    end
    
    DSLFile --> Parser
    Parser --> EMFModel
    EMFModel --> Model
    Model --> MyDslGen
    MyDslGen --> DataTypeGen
    MyDslGen --> ProtoGen
    DataTypeGen --> TmplLoader
    ProtoGen --> TmplLoader
    TmplLoader --> CppTmpl
    TmplLoader --> ProtoTmpl
    TmplLoader --> CmakeTmpl
    DataTypeGen --> FSA
    ProtoGen --> FSA
    FSA --> Files
    
    style DSLFile fill:#e1f5fe
    style Model fill:#fff3e0
    style MyDslGen fill:#f3e5f5
    style Files fill:#e8f5e9
```

### Template Processing Flow

```mermaid
flowchart TD
    subgraph "Template Processing"
        Load[Load Template File]
        Cache{Cached?}
        ReadFile[Read from Filesystem]
        ReadCP[Read from Classpath]
        Store[Store in Cache]
        Process[Process Variables]
        Replace[Replace Placeholders]
        Return[Return Content]
    end
    
    Load --> Cache
    Cache -->|Yes| Process
    Cache -->|No| ReadFile
    ReadFile -->|Found| Store
    ReadFile -->|Not Found| ReadCP
    ReadCP --> Store
    Store --> Process
    Process --> Replace
    Replace --> Return
    
    style Load fill:#e1f5fe
    style Process fill:#fff3e0
    style Return fill:#e8f5e9
```

### Code Generation Detailed Flow

```mermaid
sequenceDiagram
    participant Resource as EMF Resource
    participant MainGen as MyDslGenerator
    participant DTGen as DataTypeGenerator
    participant PBGen as ProtobufGenerator
    participant Template as TemplateLoader
    participant FSA as FileSystemAccess
    
    Resource->>MainGen: doGenerate(resource)
    MainGen->>MainGen: extract Model
    
    par C++ Generation
        MainGen->>DTGen: generate(model, fsa)
        DTGen->>DTGen: generateTypesHeader()
        DTGen->>Template: processTemplate("cpp/header.template")
        Template-->>DTGen: processed content
        DTGen->>FSA: generateFile("Types.h", content)
        
        loop For each type
            DTGen->>DTGen: generateTypeHeader(type)
            DTGen->>Template: processTemplate("cpp/struct.template")
            Template-->>DTGen: content
            DTGen->>FSA: generateFile(fileName, content)
        end
    and Protobuf Generation
        MainGen->>PBGen: generate(model, fsa, binary)
        PBGen->>PBGen: generateProtoFile()
        PBGen->>Template: processTemplate("proto/file.template")
        Template-->>PBGen: processed content
        PBGen->>FSA: generateFile("datatypes.proto", content)
        
        opt Generate Binary
            PBGen->>PBGen: generateDescriptorSet()
            PBGen->>FSA: writeBinaryDescriptor()
        end
    end
    
    MainGen-->>Resource: generation complete
```

## Coverage Analysis Flow

### JaCoCo Coverage Collection

```mermaid
flowchart TB
    subgraph "Test Execution"
        Agent[JaCoCo Agent<br/>Instrument Classes]
        Tests[Run Tests]
        Exec[Generate jacoco.exec]
    end
    
    subgraph "Report Generation"
        Collect[Collect .exec Files]
        Merge[Merge Execution Data]
        Analyze[Analyze Coverage]
        GenReport[Generate HTML Report]
    end
    
    subgraph "Aggregation"
        ModuleA[Module A Coverage]
        ModuleB[Module B Coverage]
        Aggregate[Aggregate Report]
    end
    
    Agent --> Tests
    Tests --> Exec
    Exec --> Collect
    Collect --> Merge
    Merge --> Analyze
    Analyze --> GenReport
    
    ModuleA --> Aggregate
    ModuleB --> Aggregate
    Merge --> Aggregate
    
    style Agent fill:#f3e5f5
    style Aggregate fill:#e8f5e9
```

### Coverage Report Structure

```mermaid
graph TD
    subgraph "Coverage Reports"
        Root[coverage-reports/]
        TestMod[jacoco-test-module/]
        AggReport[jacoco-aggregate/]
        
        TestIndex[index.html]
        TestPkg[Package Reports]
        TestClass[Class Reports]
        
        AggIndex[index.html]
        AggPkg[Cross-Module Packages]
        AggClass[All Classes]
    end
    
    Root --> TestMod
    Root --> AggReport
    
    TestMod --> TestIndex
    TestMod --> TestPkg
    TestMod --> TestClass
    
    AggReport --> AggIndex
    AggReport --> AggPkg
    AggReport --> AggClass
    
    style Root fill:#f5f5f5
    style AggReport fill:#e8f5e9
    style TestMod fill:#fff3e0
```

## Deployment View

### Build Pipeline

```mermaid
flowchart LR
    subgraph "Development"
        Dev[Developer<br/>Workstation]
        Git[Git Repository]
    end
    
    subgraph "CI/CD Pipeline"
        Trigger[Build Trigger]
        CI[CI Server]
        BuildJob[Build Job]
        TestJob[Test Job]
        Package[Package]
        Artifacts[Artifact Store]
    end
    
    subgraph "Deployment"
        P2[P2 Repository]
        UpdateSite[Update Site]
        Users[End Users]
    end
    
    Dev --> Git
    Git --> Trigger
    Trigger --> CI
    CI --> BuildJob
    BuildJob --> TestJob
    TestJob --> Package
    Package --> Artifacts
    Artifacts --> P2
    P2 --> UpdateSite
    UpdateSite --> Users
    
    style Dev fill:#e1f5fe
    style CI fill:#fff3e0
    style UpdateSite fill:#e8f5e9
```

### Component Deployment

```mermaid
graph TB
    subgraph "Runtime Environment"
        subgraph "Eclipse IDE"
            Plugin[MyDsl Plugin]
            XtextRT[Xtext Runtime]
            EMF[EMF Runtime]
        end
        
        subgraph "Standalone"
            CLI[CLI Application]
            Generator[Generator Engine]
        end
        
        subgraph "File System"
            Input[Input .mydsl Files]
            Output[Generated Code]
            Templates[Template Files]
        end
    end
    
    Plugin --> XtextRT
    Plugin --> EMF
    Plugin --> Generator
    CLI --> Generator
    Generator --> Templates
    Input --> Plugin
    Input --> CLI
    Generator --> Output
    
    style Plugin fill:#c5e1a5
    style CLI fill:#ffccbc
    style Output fill:#e8f5e9
```

## Key Design Decisions

### 1. Centralized Test Configuration
- **Decision**: All test suite definitions in `TestConfiguration.xtend`
- **Rationale**: Single source of truth, type safety, easier maintenance
- **Trade-offs**: Requires recompilation for changes

### 2. Template-Based Generation
- **Decision**: External template files with variable substitution
- **Rationale**: Separation of concerns, easier template updates
- **Trade-offs**: Additional I/O overhead, caching complexity

### 3. Multi-Module Maven Structure
- **Decision**: Separate modules for different concerns
- **Rationale**: Clear separation, parallel builds, independent versioning
- **Trade-offs**: Complex dependency management, longer initial setup

### 4. Tycho for Eclipse Plugin Development
- **Decision**: Use Tycho instead of pure Maven
- **Rationale**: Eclipse plugin compatibility, OSGi support
- **Trade-offs**: Learning curve, limited to Eclipse ecosystem

### 5. JaCoCo for Coverage Analysis
- **Decision**: JaCoCo with aggregate reporting
- **Rationale**: Xtend support, cross-module coverage, good IDE integration
- **Trade-offs**: Configuration complexity, performance overhead

## Performance Considerations

```mermaid
graph LR
    subgraph "Optimization Points"
        Cache[Template Caching]
        Parallel[Parallel Builds<br/>-T 12]
        Incremental[Incremental Compilation]
        LazyLoad[Lazy Model Loading]
    end
    
    subgraph "Bottlenecks"
        MWE2[MWE2 Generation]
        XtendComp[Xtend Compilation]
        Coverage[Coverage Analysis]
    end
    
    Cache -.mitigates.-> MWE2
    Parallel -.mitigates.-> XtendComp
    Incremental -.mitigates.-> XtendComp
    LazyLoad -.mitigates.-> Coverage
    
    style Cache fill:#e8f5e9
    style Parallel fill:#e8f5e9
    style MWE2 fill:#ffccbc
```

## Security Considerations

1. **Template Injection**: Templates use simple string replacement, not evaluation
2. **File System Access**: Controlled through `IFileSystemAccess2` interface
3. **Binary Generation**: Protobuf descriptors validated before writing
4. **Dependency Management**: All dependencies from trusted repositories
5. **Code Generation**: No execution of generated code during build

## Future Enhancements

1. **Incremental Generation**: Only regenerate changed files
2. **Distributed Testing**: Run test suites in parallel on multiple machines
3. **Cloud-Based CI/CD**: Integrate with cloud build services
4. **Language Server Protocol**: Add LSP support for broader IDE compatibility
5. **Real-Time Validation**: Validate DSL as user types
6. **Generated Code Optimization**: Analyze and optimize generated code patterns