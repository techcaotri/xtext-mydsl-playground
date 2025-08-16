#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pushd .

echo -e "${GREEN}=== Enter 'org.xtext.example.mydsl' and Compile ... ===${NC}"
cd org.xtext.example.mydsl && \
mvn xtend:compile install -DskipTests -q -T 12 && \
echo -e "${GREEN}=== Enter 'org.xtext.example.mydsl.standalone' and Generate .jar generator ... ===${NC}"
cd ../org.xtext.example.mydsl.standalone && \
mvn package -DskipTests -q -T 12 && \
echo -e "${GREEN}✓ JAR ready at: org.xtext.example.mydsl.standalone/target/org.xtext.example.mydsl.standalone-1.0.0-SNAPSHOT-jar-with-dependencies.jar${NC}"

popd
