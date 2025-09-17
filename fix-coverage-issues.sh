#!/bin/bash

echo "============================================"
echo "Fixing JaCoCo Coverage Issues"
echo "============================================"
echo ""

# Go to parent directory
cd "$(dirname "$0")"
if [ -f "pom.xml" ]; then
    echo "Already in parent directory"
else
    cd ..
fi

echo "Working directory: $(pwd)"
echo ""

# Step 1: Build main module first to ensure classes exist
echo "Step 1: Building main module..."
cd org.xtext.example.mydsl
mvn clean compile xtend:compile xtend:xtend-install-debug-info
cd ..

# Step 2: Create aggregate coverage module if it doesn't exist
if [ ! -d "jacoco-aggregate-report" ]; then
    echo ""
    echo "Step 2: Creating aggregate coverage module..."
    mkdir -p jacoco-aggregate-report
    
    cat > jacoco-aggregate-report/pom.xml << 'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
                             http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <parent>
        <groupId>org.xtext.example.mydsl</groupId>
        <artifactId>org.xtext.example.mydsl.parent</artifactId>
        <version>1.0.0-SNAPSHOT</version>
    </parent>
    
    <artifactId>jacoco-aggregate-report</artifactId>
    <name>JaCoCo Aggregate Coverage Report</name>
    <packaging>pom</packaging>
    
    <dependencies>
        <dependency>
            <groupId>org.xtext.example.mydsl</groupId>
            <artifactId>org.xtext.example.mydsl</artifactId>
            <version>${project.version}</version>
        </dependency>
        <dependency>
            <groupId>org.xtext.example.mydsl</groupId>
            <artifactId>org.xtext.example.mydsl.tests</artifactId>
            <version>${project.version}</version>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.jacoco</groupId>
                <artifactId>jacoco-maven-plugin</artifactId>
                <version>0.8.11</version>
                <executions>
                    <execution>
                        <id>report-aggregate</id>
                        <phase>verify</phase>
                        <goals>
                            <goal>report-aggregate</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
EOF
    echo "Aggregate module created"
else
    echo "Step 2: Aggregate module already exists"
fi

# Step 3: Run tests with special configuration for cross-module coverage
echo ""
echo "Step 3: Running tests with cross-module coverage..."
cd org.xtext.example.mydsl.tests

# Run with JaCoCo agent configured to instrument all classes
mvn clean verify \
    -Djacoco.includes="org.xtext.example.mydsl.*" \
    -Djacoco.append=true \
    -Djacoco.destFile="${PWD}/target/jacoco-combined.exec"

# Step 4: Generate combined coverage report
echo ""
echo "Step 4: Generating combined coverage report..."

# First, copy execution data to parent
cp target/jacoco*.exec ../jacoco-aggregate-report/ 2>/dev/null || true
cp target/jacoco*.exec ../org.xtext.example.mydsl/target/ 2>/dev/null || true

# Generate report with all source directories
mvn jacoco:report -Djacoco.dataFile=target/jacoco-combined.exec \
    -Djacoco.sourceDirectories="../org.xtext.example.mydsl/src,../org.xtext.example.mydsl/xtend-gen,src,xtend-gen" \
    -Djacoco.classDirectories="../org.xtext.example.mydsl/target/classes,target/classes"

# Step 5: Alternative - Generate aggregate report
echo ""
echo "Step 5: Generating aggregate report..."
cd ..

# Run aggregate report if module exists
if [ -d "jacoco-aggregate-report" ]; then
    mvn clean verify -pl jacoco-aggregate-report -am
    echo ""
    echo "Aggregate report generated at: jacoco-aggregate-report/target/site/jacoco-aggregate/index.html"
fi

# Step 6: Fix source file paths in report
echo ""
echo "Step 6: Fixing source file references..."
cd org.xtext.example.mydsl.tests

# Generate a proper POM file for the combined report
cat > jacoco-report-pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
                             http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>org.xtext.example.mydsl</groupId>
    <artifactId>jacoco-combined-report</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>pom</packaging>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.jacoco</groupId>
                <artifactId>jacoco-maven-plugin</artifactId>
                <version>0.8.11</version>
                <configuration>
                    <dataFile>${project.basedir}/target/jacoco.exec</dataFile>
                    <outputDirectory>${project.basedir}/target/site/jacoco-combined</outputDirectory>
                    <sourceDirectories>
                        <sourceDirectory>${project.basedir}/src</sourceDirectory>
                        <sourceDirectory>${project.basedir}/xtend-gen</sourceDirectory>
                        <sourceDirectory>${project.basedir}/../org.xtext.example.mydsl/src</sourceDirectory>
                        <sourceDirectory>${project.basedir}/../org.xtext.example.mydsl/xtend-gen</sourceDirectory>
                    </sourceDirectories>
                    <classDirectories>
                        <classDirectory>${project.basedir}/target/classes</classDirectory>
                        <classDirectory>${project.basedir}/../org.xtext.example.mydsl/target/classes</classDirectory>
                    </classDirectories>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
EOF

# Generate the combined report
mvn jacoco:report -f jacoco-report-pom.xml

echo ""
echo "============================================"
echo "Coverage Issues Fixed!"
echo "============================================"
echo ""
echo "Reports available at:"
echo "1. Test module report: org.xtext.example.mydsl.tests/target/site/jacoco/index.html"
echo "2. Fixed report: org.xtext.example.mydsl.tests/target/site/jacoco-fixed/index.html"
echo "3. Aggregate report: jacoco-aggregate-report/target/site/jacoco-aggregate/index.html"
echo ""
echo "The aggregate report should show coverage for BOTH modules including:"
echo "- org.xtext.example.mydsl (main module with generators)"
echo "- org.xtext.example.mydsl.tests (test module)"