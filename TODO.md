21-Sep-2025:
  1. Fix the copy test report
  2. Study which mechanism to include the test case classes: mvn build commands or xtend file or java file
    * The Java file is not relevant -> removed
    * The `build-and-test.sh` defines the test classes of the running test suite which will be reflected in the Surefire Test report via -Dtest= argument.
    * The `pom.xml` defines which test classes are running.
