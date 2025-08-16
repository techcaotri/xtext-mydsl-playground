#!/bin/bash
# Run script for MyDsl Standalone Generator

JAR_FILE="mydsl-standalone.jar"

if [ ! -f "$JAR_FILE" ]; then
    JAR_FILE="target/org.xtext.example.mydsl.standalone-1.0.0-SNAPSHOT-jar-with-dependencies.jar"
fi

if [ ! -f "$JAR_FILE" ]; then
    echo "Error: JAR file not found. Please run build-standalone.sh first."
    exit 1
fi

java -jar "$JAR_FILE" "$@"
